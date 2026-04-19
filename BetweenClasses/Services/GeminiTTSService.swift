import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class GeminiTTSService {
    var amplitude: Float = 0
    var isSpeaking: Bool = false

    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-tts-preview:streamGenerateContent"
    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24000, channels: 1, interleaved: false)!

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isMeteringTapInstalled = false

    private var pendingBufferCount = 0
    private var streamEnded = false
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    private var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.geminiKey)) ?? ""
    }

    func speak(_ text: String) async throws {
        guard !apiKey.isEmpty else { throw GeminiTTSError.notConfigured }

        var req = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)&alt=sse")!)
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

        try setupAudioEngine()

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            teardownAudioEngine()
            throw GeminiTTSError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        isSpeaking = true
        streamEnded = false
        pendingBufferCount = 0

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard jsonStr != "[DONE]",
                  let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let parts = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]],
                  let b64 = (parts.first?["inlineData"] as? [String: Any])?["data"] as? String,
                  let pcm = Data(base64Encoded: b64)
            else { continue }

            scheduleChunk(pcm)
        }

        streamEnded = true

        if pendingBufferCount == 0 {
            finishPlayback()
            return
        }

        await withCheckedContinuation { continuation in
            playbackContinuation = continuation
        }
    }

    private func setupAudioEngine() throws {
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

    private func scheduleChunk(_ pcm: Data) {
        guard let playerNode, let buffer = makePCMBuffer(from: pcm) else { return }
        pendingBufferCount += 1
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pendingBufferCount -= 1
                if self.pendingBufferCount == 0 && self.streamEnded {
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

    private func finishPlayback() {
        guard engine != nil else { return }
        isSpeaking = false
        amplitude = 0
        teardownAudioEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stop() {
        streamEnded = true
        pendingBufferCount = 0
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
