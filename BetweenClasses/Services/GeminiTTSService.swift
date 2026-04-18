import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class GeminiTTSService: NSObject {
    var amplitude: Float = 0
    var isSpeaking: Bool = false

    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-tts-preview:generateContent"

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var onFinish: (() -> Void)?

    private var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.geminiKey)) ?? ""
    }

    func speak(_ text: String) async throws {
        guard !apiKey.isEmpty else { throw GeminiTTSError.notConfigured }

        var req = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)")!)
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

        try await playAudio(pcm: pcm)
    }

    private func playAudio(pcm: Data) async throws {
        let wavData = makeWAV(pcm: pcm)

        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try AVAudioSession.sharedInstance().setActive(true)

        player = try AVAudioPlayer(data: wavData, fileTypeHint: AVFileType.wav.rawValue)
        player?.delegate = self
        player?.isMeteringEnabled = true
        player?.play()

        isSpeaking = true
        startMetering()

        await withCheckedContinuation { continuation in
            self.onFinish = { continuation.resume() }
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func makeWAV(pcm: Data) -> Data {
        let sampleRate: UInt32 = 24000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcm.count)
        let chunkSize = 36 + dataSize

        var header = Data(capacity: 44)
        header.append(contentsOf: Array("RIFF".utf8))
        header.appendLE(chunkSize)
        header.append(contentsOf: Array("WAVE".utf8))
        header.append(contentsOf: Array("fmt ".utf8))
        header.appendLE(UInt32(16))
        header.appendLE(UInt16(1))
        header.appendLE(channels)
        header.appendLE(sampleRate)
        header.appendLE(byteRate)
        header.appendLE(blockAlign)
        header.appendLE(bitsPerSample)
        header.append(contentsOf: Array("data".utf8))
        header.appendLE(dataSize)
        return header + pcm
    }

    private func startMetering() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAmplitude))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateAmplitude() {
        player?.updateMeters()
        let db = player?.averagePower(forChannel: 0) ?? -160
        amplitude = max(0, (db + 60) / 60)
    }

    func stop() {
        player?.stop()
        displayLink?.invalidate()
        isSpeaking = false
        amplitude = 0
        onFinish = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension GeminiTTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            self.amplitude = 0
            self.displayLink?.invalidate()
            self.onFinish?()
            self.onFinish = nil
        }
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

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
}
