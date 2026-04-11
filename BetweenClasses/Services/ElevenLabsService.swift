import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class ElevenLabsService: NSObject {
    var amplitude: Float = 0
    var isSpeaking: Bool = false

    private let voiceID = "21m00Tcm4TlvDq8ikWAM" // Rachel — swap as needed
    private let endpoint = "https://api.elevenlabs.io/v1/text-to-speech"

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    private var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.elevenLabsKey)) ?? ""
    }

    func speak(_ text: String) async throws {
        guard !apiKey.isEmpty else { throw ElevenLabsError.notConfigured }

        let url = URL(string: "\(endpoint)/\(voiceID)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ElevenLabsError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        try await playAudio(data: data)
    }

    private func playAudio(data: Data) async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bc_tts_\(UUID().uuidString).mp3")
        try data.write(to: tmp)

        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try AVAudioSession.sharedInstance().setActive(true)

        player = try AVAudioPlayer(contentsOf: tmp)
        player?.delegate = self
        player?.isMeteringEnabled = true
        player?.play()

        isSpeaking = true
        startMetering()

        await withCheckedContinuation { continuation in
            self.onFinish = { continuation.resume() }
        }

        // Deactivate playback session so SpeechService can take over recording
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private var onFinish: (() -> Void)?

    private func startMetering() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAmplitude))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateAmplitude() {
        player?.updateMeters()
        let db = player?.averagePower(forChannel: 0) ?? -160
        let normalized = max(0, (db + 60) / 60)
        amplitude = normalized
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

extension ElevenLabsService: AVAudioPlayerDelegate {
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

enum ElevenLabsError: Error, LocalizedError {
    case notConfigured
    case httpError(statusCode: Int)
    case playbackError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ElevenLabs API key not configured. Add it in Settings."
        case .httpError(let code):
            return "ElevenLabs request failed (HTTP \(code))."
        case .playbackError:
            return "Audio playback failed."
        }
    }
}
