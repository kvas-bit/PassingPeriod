import Foundation

struct GeminiService {
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

    private static var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.geminiKey)) ?? ""
    }

    // MARK: - Generate Questions

    static func generateQuestions(from text: String, noteID: UUID) async throws -> [QuizQuestion] {
        let prompt = """
        Generate exactly 5 active recall question-and-answer pairs from the following notes.
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

    // MARK: - Evaluate Answer

    static func evaluateAnswer(question: String, expected: String, userAnswer: String) async throws -> EvaluationResult {
        let prompt = """
        You are an educational AI evaluating a student's spoken answer.
        Return ONLY valid JSON with no markdown, no code fences.
        Format: {"correct": true/false, "feedback": "one encouraging sentence of feedback"}

        Question: \(question)
        Expected answer: \(expected)
        Student said: \(userAnswer)
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
            return EvaluationResult(correct: !userAnswer.isEmpty, feedback: "Good effort, keep going!")
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
