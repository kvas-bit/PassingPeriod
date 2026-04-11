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
    var errorMessage: String? = nil
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
        errorMessage = nil
        var allQuestions = subject.notes.flatMap { $0.questions }

        // Issue A: fallback questions when notes have text but Gemini never ran
        if allQuestions.isEmpty {
            let notesWithText = subject.notes.filter { !$0.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if notesWithText.isEmpty {
                statusLabel = "No notes for \(subject.name) yet — capture notes first."
                state = .noContent
                return
            }
            allQuestions = generateFallbackQuestions(from: notesWithText)
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

    // MARK: - Fallback question generation

    private func generateFallbackQuestions(from notes: [Note]) -> [QuizQuestion] {
        var result: [QuizQuestion] = []
        for note in notes {
            let text = note.extractedText
            // Split into sentences and produce simple recall questions
            let sentences = text
                .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 20 }

            for sentence in sentences.prefix(3) {
                let words = sentence.split(separator: " ")
                guard words.count >= 4 else { continue }
                // Build a "What is X?" style question from the first meaningful chunk
                let keyPhrase = words.prefix(min(5, words.count / 2)).joined(separator: " ")
                let q = QuizQuestion(
                    question: "Explain in your own words: \"\(keyPhrase)…\"",
                    expectedAnswer: sentence,
                    noteID: note.id
                )
                result.append(q)
                if result.count >= 5 { return result }
            }
        }
        return result
    }

    // MARK: - State machine

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
        statusLabel = q.question   // Always display question text on screen

        let intro = index == 0 ? "Let's review. " : ""
        let questionText = "\(intro)Question \(index + 1). \(q.question)"

        var ttsFailed = false
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
            // Issue B: TTS failure — show question text (already set in statusLabel) and
            // wait a short delay before transitioning to listening so user can read it.
            ttsFailed = true
        }

        // Issue D: AVAudioSession conflict — add delay after TTS before starting mic
        if !ttsFailed {
            try? await Task.sleep(for: .milliseconds(300))
        } else {
            // Longer pause when TTS failed so user has time to read the question
            try? await Task.sleep(for: .milliseconds(1500))
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
            // Can't listen — skip this question and move on
            await runQuestion(at: index + 1)
        }
    }

    private func handleAnswer(transcript: String, question: QuizQuestion, index: Int) async {
        state = .evaluating
        statusLabel = "Evaluating…"
        micAmplitude = 0

        question.userAnswer = transcript

        // Issue C: Gemini evaluation failure — default to incorrect and keep going
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
        let feedbackText = result.correct
            ? "Correct! \(result.feedback)"
            : "Not quite. \(result.feedback)"
        statusLabel = feedbackText  // Show feedback text on screen regardless of TTS

        do {
            try await tts.speak(feedbackText)
        } catch {}

        // Issue D: small delay after TTS before next question
        try? await Task.sleep(for: .milliseconds(300))

        // Issue E: properly increment and detect end
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
