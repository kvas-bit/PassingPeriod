import Foundation

struct GeminiService {
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

    private static var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.geminiKey)) ?? ""
    }

    // MARK: - Generate Questions (with automatic fallback)

    /// Primary entry point. Always returns at least fallback questions so the
    /// quiz never silently fails due to a missing API key or network error.
    static func generateQuestionsWithFallback(from text: String, noteID: UUID) async -> [QuizQuestion] {
        if !apiKey.isEmpty {
            if let questions = try? await generateQuestions(from: text, noteID: noteID),
               !questions.isEmpty {
                return questions
            }
        }
        // API key missing or Gemini call failed — use rule-based fallback
        return makeFallbackQuestions(from: text, noteID: noteID)
    }

    /// Low-level call — throws on any failure. Prefer `generateQuestionsWithFallback`.
    static func generateQuestions(from text: String, noteID: UUID) async throws -> [QuizQuestion] {
        let prompt = """
        You are generating active recall questions for a university student reviewing their class notes.
        Generate exactly 5 questions that test DEEP understanding — not surface definitions.

        Question types to include (mix these):
        - HOW/WHY questions: mechanisms, causality, processes ("How does X work?", "Why does X cause Y?")
        - CONNECTION questions: relationships between concepts ("How does X relate to Y?", "What's the difference between X and Y?")
        - APPLICATION questions: real-world or scenario use ("In what situation would you use X?", "Give an example of X in practice")
        - SYNTHESIS questions: big-picture ("What is the key takeaway about X?", "How do these concepts fit together?")

        AVOID questions like "What is the definition of X?" or "What does X stand for?" — those are too surface-level.
        Make questions conversational since they will be spoken aloud.
        Expected answers should be 1-3 sentences that would count as a correct spoken response.

        Return ONLY a valid JSON array with no markdown, no code fences.
        Format: [{"question": "...", "expectedAnswer": "..."}]

        Notes:
        \(text)
        """

        let raw = try await request(prompt: prompt)
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let pairs = try? JSONDecoder().decode([QAPair].self, from: data) else {
            throw GeminiError.parseError
        }

        return pairs.map { QuizQuestion(question: $0.question, expectedAnswer: $0.expectedAnswer, noteID: noteID) }
    }

    // MARK: - Fallback question generation (no API required)

    /// Splits the note text into sentences/paragraphs and produces simple
    /// "What does this note say about X?" questions. Dumb but better than nothing.
    static func makeFallbackQuestions(from text: String, noteID: UUID) -> [QuizQuestion] {
        // Try paragraphs first, then sentences, then word-chunked lines
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        let chunks: [String]
        if paragraphs.count >= 3 {
            chunks = paragraphs
        } else {
            // Fall back to sentence splitting
            chunks = text
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 20 }
        }

        // Build up to 5 questions, each anchored to the first ~5 words of the chunk
        let targets = Array(chunks.prefix(5))
        guard !targets.isEmpty else {
            // Absolute last-resort: one generic question about the whole note
            return [QuizQuestion(
                question: "Summarize what these notes are about.",
                expectedAnswer: String(text.prefix(200)),
                noteID: noteID
            )]
        }

        return targets.map { chunk in
            let words = chunk.split(separator: " ").prefix(5).joined(separator: " ")
            let topic = words.trimmingCharacters(in: .punctuationCharacters)
            return QuizQuestion(
                question: "What do your notes say about \"\(topic)\"?",
                expectedAnswer: String(chunk.prefix(300)),
                noteID: noteID
            )
        }
    }

    // MARK: - Evaluate Answer

    static func evaluateAnswer(question: String, expected: String, userAnswer: String) async throws -> EvaluationResult {
        let prompt = """
        You are an educational AI evaluating a student's spoken answer during active recall practice.
        Return ONLY valid JSON with no markdown, no code fences.
        Format: {"correct": true/false, "feedback": "...", "explanation": "..."}

        Rules:
        - "correct": true if the student captured the core concept (doesn't need to be word-perfect)
        - "feedback": 1 sentence — if correct, affirm what they got right; if wrong, gently say what was missing
        - "explanation": if correct, empty string ""; if wrong, give a clear 1-2 sentence explanation of the correct answer so they actually learn it

        Question: \(question)
        Expected answer: \(expected)
        Student said: \(userAnswer.isEmpty ? "(no answer given)" : userAnswer)
        """

        let raw = try await request(prompt: prompt)
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let result = try? JSONDecoder().decode(EvaluationResult.self, from: data) else {
            // Fallback: mark as correct if answer is non-empty
            return EvaluationResult(correct: !userAnswer.isEmpty, feedback: "Good effort, keep going!", explanation: nil)
        }
        return result
    }

    // MARK: - Core request

    private static func request(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.noAPIKey }

        let url = URL(string: "\(endpoint)?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeminiError.httpError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.parseError
        }
        return text
    }
}

// MARK: - Supporting types

struct QAPair: Decodable {
    let question: String
    let expectedAnswer: String
}

struct EvaluationResult: Decodable {
    let correct: Bool
    let feedback: String
    let explanation: String?  // Correct answer explanation spoken when wrong
}

enum GeminiError: Error, LocalizedError {
    case noAPIKey, httpError, parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:    return "Gemini API key not set."
        case .httpError:   return "Gemini API request failed."
        case .parseError:  return "Could not parse Gemini response."
        }
    }
}
