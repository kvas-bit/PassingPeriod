import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class GeminiTTSService {
    var amplitude: Float = 0
    var isSpeaking: Bool = false

    // High expressiveness — used for questions (pre-cached, latency hidden)
    static let questionModel = "gemini-3.1-flash-tts-preview"
    // Fastest engine — used for feedback where latency is felt in real-time
    static let feedbackModel = "gemini-2.5-flash-preview-tts"

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let websocketURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isMeteringTapInstalled = false
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    // Pre-generated audio cache: text → raw PCM data
    private var pcmCache: [String: Data] = [:]

    private var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.geminiKey)) ?? ""
    }

    /// Fire-and-forget: fetch audio for `text` using the given model and cache it.
    func prefetch(_ text: String, model: String = GeminiTTSService.questionModel) async {
        guard pcmCache[text] == nil, !apiKey.isEmpty else { return }
        guard let pcm = try? await fetchPCM(for: text, model: model) else { return }
        pcmCache[text] = pcm
    }

    func speak(_ text: String, model: String = GeminiTTSService.questionModel) async throws {
        guard !apiKey.isEmpty else { throw GeminiTTSError.notConfigured }

        let pcm: Data
        if let cached = pcmCache[text] {
            pcmCache.removeValue(forKey: text)
            pcm = cached
        } else {
            pcm = try await fetchPCM(for: text, model: model)
        }

        try await playPCM(pcm)
    }

    func clearCache() {
        pcmCache.removeAll()
    }

    private func fetchPCM(for text: String, model: String) async throws -> Data {
        if let streamed = try? await fetchPCMOverWebSocket(for: text, model: model), !streamed.isEmpty {
            return streamed
        }

        let urlString = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": text]]]],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": ["voiceName": "Aoede"]
                    ]
                ]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeminiTTSError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let candidates = json?["candidates"] as? [[String: Any]],
            let parts = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]],
            let b64 = (parts.first?["inlineData"] as? [String: Any])?["data"] as? String,
            let pcm = Data(base64Encoded: b64)
        else {
            throw GeminiTTSError.playbackError
        }

        return pcm
    }

    private func fetchPCMOverWebSocket(for text: String, model: String) async throws -> Data {
        guard let wsURL = URL(string: "\(websocketURL)?key=\(apiKey)") else {
            throw GeminiTTSError.playbackError
        }
        let task = URLSession.shared.webSocketTask(with: wsURL)
        task.resume()
        defer {
            task.cancel(with: .normalClosure, reason: nil)
        }

        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generation_config": [
                    "response_modalities": ["AUDIO"],
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": ["voice_name": "Aoede"]
                        ]
                    ]
                ]
            ]
        ]

        let setupData = try JSONSerialization.data(withJSONObject: setup)
        guard let setupText = String(data: setupData, encoding: .utf8) else {
            throw GeminiTTSError.playbackError
        }
        try await task.send(.string(setupText))

        let prompt: [String: Any] = [
            "client_content": [
                "turns": [["role": "user", "parts": [["text": text]]]],
                "turn_complete": true
            ]
        ]
        let promptData = try JSONSerialization.data(withJSONObject: prompt)
        guard let promptText = String(data: promptData, encoding: .utf8) else {
            throw GeminiTTSError.playbackError
        }
        try await task.send(.string(promptText))

        var pcm = Data()
        var receivedTurnComplete = false

        while !receivedTurnComplete {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let d):
                data = d
            case .string(let s):
                guard let d = s.data(using: .utf8) else { continue }
                data = d
            @unknown default:
                continue
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let serverContent = json["serverContent"] as? [String: Any] {
                if let modelTurn = serverContent["modelTurn"] as? [String: Any],
                   let parts = modelTurn["parts"] as? [[String: Any]] {
                    for part in parts {
                        if let inlineData = part["inlineData"] as? [String: Any],
                           let b64 = inlineData["data"] as? String,
                           let chunk = Data(base64Encoded: b64) {
                            pcm.append(chunk)
                        }
                    }
                }

                if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
                    receivedTurnComplete = true
                }
            }
        }

        if pcm.isEmpty { throw GeminiTTSError.playbackError }
        return pcm
    }

    private func playPCM(_ pcm: Data) async throws {
        teardownAudioEngine()

        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker])
        try AVAudioSession.sharedInstance().setActive(true)

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)

        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let floatData = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sumSquares: Float = 0
            for i in 0..<count { sumSquares += floatData[i] * floatData[i] }
            let rms = count > 0 ? sqrt(sumSquares / Float(count)) : 0
            Task { @MainActor [weak self] in self?.amplitude = rms }
        }
        isMeteringTapInstalled = true

        try engine.start()
        playerNode.play()

        self.engine = engine
        self.playerNode = playerNode

        guard let buffer = makePCMBuffer(from: pcm) else { throw GeminiTTSError.playbackError }

        isSpeaking = true

        await withCheckedContinuation { continuation in
            playbackContinuation = continuation
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let cont = self.playbackContinuation
                    self.playbackContinuation = nil
                    self.finishPlayback()
                    cont?.resume()
                }
            }
        }
    }

    private func makePCMBuffer(from pcmInt16Data: Data) -> AVAudioPCMBuffer? {
        let frameCount = pcmInt16Data.count / 2
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        guard let floatChannel = buffer.floatChannelData?[0] else { return nil }
        pcmInt16Data.withUnsafeBytes { rawBytes in
            guard let int16Ptr = rawBytes.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<frameCount {
                floatChannel[i] = Float(int16Ptr[i]) / 32768.0
            }
        }
        return buffer
    }

    private func teardownAudioEngine() {
        if isMeteringTapInstalled {
            engine?.mainMixerNode.removeTap(onBus: 0)
            isMeteringTapInstalled = false
        }
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
    }

    private func finishPlayback() {
        guard engine != nil || isSpeaking else { return }
        isSpeaking = false
        amplitude = 0
        teardownAudioEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stop() {
        let cont = playbackContinuation
        playbackContinuation = nil
        finishPlayback()
        cont?.resume()
    }
}

enum GeminiTTSError: Error, LocalizedError {
    case notConfigured
    case httpError(statusCode: Int)
    case playbackError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Gemini API key not configured. Add it in Settings."
        case .httpError(let code):
            return "Gemini TTS request failed (HTTP \(code))."
        case .playbackError:
            return "Audio playback failed."
        }
    }
}
