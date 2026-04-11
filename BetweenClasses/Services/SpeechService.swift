import Foundation
import Speech
import AVFoundation
import Observation

@Observable
@MainActor
final class SpeechService: NSObject {
    var liveTranscript: String = ""
    var amplitude: Float = 0
    var isListening: Bool = false
    var permissionGranted: Bool = false

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var silenceTimer: Timer?
    private var onSilence: ((String) -> Void)?
    private let silenceThreshold: TimeInterval = 1.5

    override init() {
        super.init()
        requestPermissions()
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.permissionGranted = status == .authorized
            }
        }
    }

    func startListening(onSilenceDetected: @escaping (String) -> Void) throws {
        guard permissionGranted else { throw SpeechError.notAuthorized }
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.recognizerUnavailable }

        stopListening()
        self.onSilence = onSilenceDetected

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { throw SpeechError.requestFailed }
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.liveTranscript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in self.stopListening() }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            let rms: Float = channelData.map { ptr in
                let sum = (0..<frameLength).reduce(0.0) { $0 + Double(ptr[$1] * ptr[$1]) }
                return Float(sqrt(sum / Double(frameLength)))
            } ?? 0
            Task { @MainActor in self?.amplitude = min(rms * 5, 1.0) }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        resetSilenceTimer()
    }

    func stopListening() -> String {
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        isListening = false
        amplitude = 0

        let result = liveTranscript
        liveTranscript = ""
        return result
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self else { return }
            let transcript = self.stopListening()
            self.onSilence?(transcript)
            self.onSilence = nil
        }
    }
}

enum SpeechError: Error, LocalizedError {
    case notAuthorized, recognizerUnavailable, requestFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:        return "Speech recognition permission not granted."
        case .recognizerUnavailable: return "Speech recognizer is unavailable."
        case .requestFailed:        return "Could not start recognition request."
        }
    }
}
