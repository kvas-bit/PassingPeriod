import Foundation
import SwiftData
import Observation

enum QuizState: Equatable {
    case idle
    case speaking
    case listening
    case evaluating
    case complete(score: Int, total: Int)
    case noContent
}

@Observable
@MainActor
final class QuizSessionManager {
    var state: QuizState = .idle
    var currentQuestion: QuizQuestion?
    var currentIndex: Int = 0
    var statusLabel: String = ""
    var ttsAmplitude: Float = 0
    var micAmplitude: Float = 0

    private(set) var questions: [QuizQuestion] = []
    private var session: QuizSession?
    private let tts = ElevenLabsService()
    private let stt = SpeechService()
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func start(subject: Subject) async {
        let allQuestions = subject.notes.flatMap { $0.questions }
        guard !allQuestions.isEmpty else {
            statusLabel = "No notes for \(subject.name) yet — capture notes first."
            state = .noContent
            return
        }
        questions = Array(allQuestions.shuffled().prefix(5))
        currentIndex = 0

        let sess = QuizSession(subjectID: subject.id)
        sess.totalQuestions = questions.count
        modelContext?.insert(sess)
        session = sess

        await runQuestion(at: 0)
    }

    func stop() {
        tts.stop()
        _ = stt.stopListening()
        state = .idle
    }

    private func runQuestion(at index: Int) async {
        guard index < questions.count else {
            finishSession()
            return
        }

        currentIndex = index
        currentQuestion = questions[index]
        guard let q = currentQuestion else { return }

        // Speak the question
        state = .speaking
        statusLabel = "Speaking…"

        let intro = index == 0 ? "Let's review. " : ""
        let questionText = "\(intro)Question \(index + 1). \(q.question)"

        do {
            // Observe TTS amplitude
            Task {
                while case .speaking = self.state {
                    self.ttsAmplitude = self.tts.amplitude
                    try? await Task.sleep(for: .milliseconds(50))
                }
                self.ttsAmplitude = 0
            }
            try await tts.speak(questionText)
        } catch {
            // Continue even if TTS fails
        }

        // Listen for answer
        state = .listening
        statusLabel = "Listening…"

        do {
            try stt.startListening { [weak self] transcript in
                guard let self else { return }
                Task {
                    await self.handleAnswer(transcript: transcript, question: q, index: index)
                }
            }
            // Observe mic amplitude
            Task {
                while case .listening = self.state {
                    self.micAmplitude = self.stt.amplitude
                    try? await Task.sleep(for: .milliseconds(50))
                }
                self.micAmplitude = 0
            }
        } catch {
            await runQuestion(at: index + 1)
        }
    }

    private func handleAnswer(transcript: String, question: QuizQuestion, index: Int) async {
        state = .evaluating
        statusLabel = "Evaluating…"
        micAmplitude = 0

        question.userAnswer = transcript

        let result: EvaluationResult
        do {
            result = try await GeminiService.evaluateAnswer(
                question: question.question,
                expected: question.expectedAnswer,
                userAnswer: transcript
            )
        } catch {
            result = EvaluationResult(correct: false, feedback: "Let's keep going.")
        }

        question.wasCorrect = result.correct
        if result.correct { session?.score += 1 }

        // Speak feedback
        state = .speaking
        statusLabel = "Speaking…"
        let feedback = result.correct
            ? "Correct! \(result.feedback)"
            : "Not quite. \(result.feedback)"

        do {
            try await tts.speak(feedback)
        } catch {}

        await runQuestion(at: index + 1)
    }

    private func finishSession() {
        let score = session?.score ?? 0
        let total = questions.count
        session?.totalQuestions = total
        try? modelContext?.save()
        state = .complete(score: score, total: total)
        statusLabel = ""
    }
}
