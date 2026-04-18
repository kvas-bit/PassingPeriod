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
    var isPreparingQuiz: Bool = false

    private(set) var questions: [QuizQuestion] = []
    private var session: QuizSession?
    private let tts = GeminiTTSService()
    private let stt = SpeechService()
    private var modelContext: ModelContext?
    private var activeRunToken = UUID()

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func start(subject: Subject, topicName: String? = nil, noteIDs: [UUID] = []) async {
        guard !isPreparingQuiz else { return }
        errorMessage = nil
        isPreparingQuiz = true
        let runToken = UUID()
        activeRunToken = runToken
        defer {
            if activeRunToken == runToken {
                isPreparingQuiz = false
            }
        }

        let scopedNotes: [Note]
        if !noteIDs.isEmpty {
            let noteIDSet = Set(noteIDs)
            scopedNotes = subject.notes.filter { noteIDSet.contains($0.id) }
        } else if let topicName, !topicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scopedNotes = subject.notes.filter {
                $0.topicName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(topicName) == .orderedSame
            }
        } else {
            scopedNotes = subject.notes
        }

        let notesWithText = scopedNotes.filter { !$0.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if notesWithText.isEmpty {
            let scopeLabel = topicName ?? subject.name
            statusLabel = "No notes for \(scopeLabel) yet — capture notes first."
            state = .noContent
            return
        }

        statusLabel = "Preparing quiz…"
        var allQuestions = await ensureQuestionsForScopedNotes(notesWithText, questionTarget: 5, runToken: runToken)
        guard activeRunToken == runToken else { return }
        if allQuestions.isEmpty {
            allQuestions = generateFallbackQuestions(from: notesWithText)
        }
        guard !allQuestions.isEmpty else {
            statusLabel = "Couldn’t build quiz questions from these notes yet."
            state = .noContent
            return
        }

        questions = Array(allQuestions.shuffled().prefix(5))
        currentIndex = 0

        let sess = QuizSession(subjectID: subject.id)
        sess.totalQuestions = questions.count
        modelContext?.insert(sess)
        session = sess

        await runQuestion(at: 0, runToken: runToken)
    }

    func stop() {
        activeRunToken = UUID()
        isPreparingQuiz = false
        tts.stop()
        _ = stt.stopListening()
        statusLabel = ""
        state = .idle
    }

    // MARK: - Question generation

    private func ensureQuestionsForScopedNotes(_ notes: [Note], questionTarget: Int, runToken: UUID) async -> [QuizQuestion] {
        var collected = notes.flatMap { $0.questions }
        if collected.count >= questionTarget {
            return collected
        }

        guard let modelContext else { return collected }

        let notesNeedingQuestions = notes.filter {
            $0.questions.isEmpty && !$0.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        for note in notesNeedingQuestions {
            if activeRunToken != runToken { break }
            statusLabel = notes.count == 1 ? "Generating quiz questions…" : "Generating quiz questions from your notes…"
            let generated = await GeminiService.generateQuestionsWithFallback(
                from: note.extractedText,
                noteID: note.id
            )
            guard !generated.isEmpty else { continue }

            for question in generated {
                modelContext.insert(question)
                note.questions.append(question)
            }
            try? modelContext.save()

            collected.append(contentsOf: generated)
            if collected.count >= questionTarget { break }
        }

        if collected.count < questionTarget {
            let fallback = generateFallbackQuestions(from: notes)
            for question in fallback where collected.count < questionTarget && collected.contains(where: { $0.question == question.question }) == false {
                collected.append(question)
            }
        }

        return collected
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

    private func runQuestion(at index: Int, runToken: UUID) async {
        guard activeRunToken == runToken else { return }
        guard index < questions.count else {
            finishSession(runToken: runToken)
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

        guard activeRunToken == runToken else { return }

        // Listen for answer
        state = .listening
        statusLabel = "Listening…"

        do {
            try stt.startListening { [weak self] transcript in
                guard let self else { return }
                Task {
                    await self.handleAnswer(transcript: transcript, question: q, index: index, runToken: runToken)
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
            await runQuestion(at: index + 1, runToken: runToken)
        }
    }

    private func handleAnswer(transcript: String, question: QuizQuestion, index: Int, runToken: UUID) async {
        guard activeRunToken == runToken else { return }
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
            result = EvaluationResult(correct: false, feedback: "Let's keep going.", explanation: nil)
        }

        guard activeRunToken == runToken else { return }

        question.wasCorrect = result.correct
        if result.correct { session?.score += 1 }

        // Speak feedback — if wrong, also explain the correct answer so they learn
        state = .speaking
        var feedbackText: String
        if result.correct {
            feedbackText = "Correct! \(result.feedback)"
        } else {
            let explanation = result.explanation.flatMap { $0.isEmpty ? nil : $0 } ?? question.expectedAnswer
            feedbackText = "Not quite. \(result.feedback) Here's what to remember: \(explanation)"
        }
        statusLabel = feedbackText

        let toneTag = result.correct ? "[encouraging] " : "[supportive] "
        do {
            try await tts.speak(toneTag + feedbackText)
        } catch {}

        // Issue D: small delay after TTS before next question
        try? await Task.sleep(for: .milliseconds(300))
        guard activeRunToken == runToken else { return }

        // Issue E: properly increment and detect end
        await runQuestion(at: index + 1, runToken: runToken)
    }

    private func finishSession(runToken: UUID) {
        guard activeRunToken == runToken else { return }
        let score = session?.score ?? 0
        let total = questions.count
        session?.totalQuestions = total
        try? modelContext?.save()
        state = .complete(score: score, total: total)
        statusLabel = ""
    }
}
