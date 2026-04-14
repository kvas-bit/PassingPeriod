import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class ElevenLabsService: NSObject {
    var amplitude: Float = 0
    var isSpeaking: Bool = false

    private var voiceID: String {
        // Retrieve from Keychain; fall back to "Rachel" default only if not set.
        // Users can change voice via Settings → Voice Selection.
        (try? KeychainService.retrieve(KeychainKey.elevenLabsVoiceID)) ?? "21m00Tcm4TlvDq8ikWAM"
    }

    private let endpoint = "https://api.elevenlabs.io/v1/text-to-speech"

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    private var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.elevenLabsKey)) ?? ""
    }

    // MARK: - Network configuration
    // Use a dedicated session with explicit timeouts (30 s request, 60 s resource).
    // Without this, URLSession defaults to ~60 s / 180 s which can cause long waits
    // on slow connectivity before the error surfaces.
    private static let sessionConfig: URLSessionConfiguration = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 60
        return cfg
    }()
    private let session = URLSession(configuration: Self.sessionConfig)

    func speak(_ text: String) async throws {
        // ElevenLabs API keys MUST be sent via Authorization header, NOT in the URL.
        // The API key identifies the user account; placing it in a URL exposes it in logs,
        // proxies, and browser history. The header approach is per ElevenLabs API docs.
        guard !apiKey.isEmpty else { throw ElevenLabsError.notConfigured }

        guard let url = URL(string: "\(endpoint)/\(voiceID)") else {
            throw ElevenLabsError.httpError(statusCode: -1, reason: "Invalid URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        // xi-api-key goes in the header — never in the URL.
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw ElevenLabsError.httpError(statusCode: -1, reason: "Non-HTTP response")
        }

        switch http.statusCode {
        case 200..<300: break
        case 401:       throw ElevenLabsError.httpError(statusCode: 401, reason: "Invalid API key")
        case 429:       throw ElevenLabsError.httpError(statusCode: 429, reason: "Rate limited")
        case 500..<600: throw ElevenLabsError.httpError(statusCode: http.statusCode, reason: "Server error")
        default:        throw ElevenLabsError.httpError(statusCode: http.statusCode, reason: nil)
        }

        try await playAudio(data: data)
    }

    private func playAudio(data: Data) async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bc_tts_\(UUID().uuidString).mp3")
        do {
            try data.write(to: tmp)
        } catch {
            throw ElevenLabsError.playbackError
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            throw ElevenLabsError.playbackError
        }

        guard let p = try? AVAudioPlayer(contentsOf: tmp) else {
            throw ElevenLabsError.playbackError
        }
        player = p
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
    case httpError(statusCode: Int, reason: String?)
    case playbackError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ElevenLabs API key not configured. Add it in Settings."
        case .httpError(let code, let reason):
            return reason != nil
                ? "ElevenLabs request failed (HTTP \(code)): \(reason!)"
                : "ElevenLabs request failed (HTTP \(code))."
        case .playbackError:
            return "Audio playback failed."
        }
    }
}
