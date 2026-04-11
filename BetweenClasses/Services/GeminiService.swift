import Foundation
import UIKit

struct GeminiService {
    /// Stable Flash model for question + evaluation calls.
    private static let modelName = "gemini-2.5-flash"
    private static let flashOCRModelName = "gemini-2.5-flash"
    private static let proOCRModelName = "gemini-2.5-pro"

    private static func endpoint(for model: String) -> String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }

    private static var endpoint: String {
        endpoint(for: modelName)
    }

    private static var apiKey: String {
        (try? KeychainService.retrieve(KeychainKey.geminiKey)) ?? ""
    }

    private static let maxNoteCharsForPrompt = 14_000

    // MARK: - OCR

    static func extractStructuredOCR(from imageData: Data, localText: String, preferPro: Bool) async throws -> OCRDraft {
        let prompt = """
        You are doing OCR cleanup for a student note-capture app.

        You will receive:
        1. the raw page image
        2. a rough local OCR transcript that may be incomplete or wrong

        Your job:
        - recover the clearest possible note text from the image
        - preserve line breaks where they help readability
        - do not hallucinate details not visible in the image
        - propose a short title and a likely topic / lecture label
        - call out unreadable regions briefly

        Return JSON only with this exact shape:
        {
          "raw_text": "best cleaned transcript",
          "title": "short note title or empty string",
          "likely_topic": "lecture/topic label or empty string",
          "confidence": "one short sentence about confidence",
          "unreadable_regions": ["brief note", "brief note"]
        }

        If the local OCR below is useful, use it as a hint, but trust the image more.

        Local OCR hint:
        \(localText.isEmpty ? "(empty)" : truncateForPrompt(localText))
        """

        let raw = try await requestMultimodal(
            prompt: prompt,
            imageData: imageData,
            model: preferPro ? proOCRModelName : flashOCRModelName,
            jsonMode: true,
            temperature: 0.1
        )
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else { throw GeminiError.parseError }
        let payload = try JSONDecoder().decode(OCRResponse.self, from: data)

        let text = payload.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeminiError.parseError }

        return OCRDraft(
            text: text,
            source: preferPro ? .geminiPro : .geminiFlash,
            suggestedTitle: nilIfEmpty(payload.title),
            suggestedTopic: nilIfEmpty(payload.likelyTopic),
            confidenceSummary: nilIfEmpty(payload.confidence),
            unreadableRegions: payload.unreadableRegions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
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
        return makeFallbackQuestions(from: text, noteID: noteID)
    }

    /// Low-level call — throws on any failure. Prefer `generateQuestionsWithFallback`.
    static func generateQuestions(from text: String, noteID: UUID) async throws -> [QuizQuestion] {
        let body = truncateForPrompt(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !body.isEmpty else { throw GeminiError.parseError }

        do {
            let anchors = try await extractStudyAnchors(from: body)
            if anchors.count >= 2 {
                return try await synthesizeQuestionsFromAnchors(
                    anchors: anchors,
                    noteContext: body,
                    noteID: noteID
                )
            }
        } catch {
            // Fall through to single-shot path
        }

        return try await generateQuestionsSingleShot(from: body, noteID: noteID)
    }

    // MARK: - Two-phase question loop

    /// Pass 1: infer themes, causal links, and misconceptions from messy OCR notes.
    private static func extractStudyAnchors(from noteText: String) async throws -> [StudyAnchor] {
        let prompt = """
        You are a learning scientist helping a university student study from messy OCR class notes.

        Read the notes and extract 6 to 8 DISTINCT study anchors. Each anchor must be conceptual (not a trivia fact or acronym gloss).
        For every anchor, ground it in the notes using "anchorPhraseFromNotes": copy a short phrase (5–20 words) that actually appears in the notes, or "" if impossible.

        Return JSON only with this exact shape (no markdown):
        {"anchors":[{"title":"short label","bigIdea":"what a professor wants them to understand","whyItMatters":"exam or problem-solving relevance","relationships":"how it connects to another idea in these notes, or \"standalone\"","misconception":"a wrong belief students often have here","anchorPhraseFromNotes":"verbatim snippet or empty"}]}

        Notes:
        \(noteText)
        """

        let raw = try await request(prompt: prompt, jsonMode: true, temperature: 0.35)
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else { throw GeminiError.parseError }

        let payload = try JSONDecoder().decode(AnchorEnvelope.self, from: data)
        return payload.anchors.filter { !$0.bigIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Pass 2: turn anchors into spoken active-recall items with rubric-grade expected answers.
    private static func synthesizeQuestionsFromAnchors(
        anchors: [StudyAnchor],
        noteContext: String,
        noteID: UUID
    ) async throws -> [QuizQuestion] {
        let anchorJSON: String
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys]
            let data = try enc.encode(anchors)
            anchorJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            throw GeminiError.parseError
        }

        let prompt = """
        You write voice-quiz questions for a mobile app. The student only hears the question and speaks an answer (no visuals).

        You are given JSON "anchors" — high-level ideas already inferred from their notes — plus the raw notes for fact-checking.

        Anchors (use every anchor at least once across the set when there are enough anchors):
        \(anchorJSON)

        Raw notes (verify you do not invent topics absent from here):
        \(noteContext)

        Produce EXACTLY 5 questions with these rules:
        1. Each question must push understanding: cause/effect, tradeoffs, when to use vs not use, how two ideas interact, limits of a model, or "what would go wrong if…". No pure "define X" or "what does acronym mean" unless the notes are only glossaries.
        2. Questions must be conversational, 18–45 spoken words, self-contained (repeat key nouns; no "this/the above").
        3. expectedAnswer must be 2–4 sentences: the ideal spoken response a strong student would give. It may paraphrase the notes; it must be checkable against the notes and anchors.
        4. Spread difficulty: include at least one integration question that ties two anchors together.
        5. Return JSON only: an array of objects with keys "question" and "expectedAnswer" only. No markdown.

        Example shape (replace with real content):
        [{"question":"...","expectedAnswer":"..."}]
        """

        let raw = try await request(prompt: prompt, jsonMode: true, temperature: 0.45)
        let decoded = try decodeQAPairs(raw, noteID: noteID, minimum: 3, maximum: 5)
        if decoded.count == 5 { return decoded }
        return await fillQuestionListUpToFive(decoded, noteID: noteID, context: noteContext)
    }

    /// Single API call when two-phase path fails or notes are thin.
    private static func generateQuestionsSingleShot(from noteText: String, noteID: UUID) async throws -> [QuizQuestion] {
        let prompt = """
        You generate active recall questions for a university student reviewing OCR class notes in a voice quiz.

        First, silently identify 3–5 major conceptual threads in the notes. Then output EXACTLY 5 questions that test those threads.

        Each question must require the student to explain WHY/HOW, compare mechanisms, justify a choice, predict an outcome, or connect two ideas. Avoid trivia, acronym expansion, or "what is the definition of…" unless the notes are purely definitional.

        Voice constraints: 18–45 spoken words, conversational, self-contained.

        expectedAnswer: 2–4 sentences representing a strong spoken answer grounded in the notes (paraphrase allowed; do not invent facts not supported by the notes).

        Return JSON only: a JSON array of 5 objects with keys "question" and "expectedAnswer". No markdown.

        Notes:
        \(noteText)
        """

        let raw = try await request(prompt: prompt, jsonMode: true, temperature: 0.45)
        return try decodeQAPairs(raw, noteID: noteID, minimum: 5, maximum: 5)
    }

    /// Completes a partial list (from two-phase synthesis) to five items without nesting single-shot recursion.
    private static func fillQuestionListUpToFive(_ questions: [QuizQuestion], noteID: UUID, context: String) async -> [QuizQuestion] {
        if questions.count >= 5 { return Array(questions.prefix(5)) }
        var out = questions
        let fallbacks = makeFallbackQuestions(from: context, noteID: noteID)
        for q in fallbacks where out.count < 5 && !out.contains(where: { $0.question == q.question }) {
            out.append(q)
        }
        let backupPrompts = [
            "How do the main ideas in these notes connect to each other? Give a concise spoken summary.",
            "What is the most exam-worthy relationship in these notes, and how would you explain it out loud?",
            "If a classmate only memorized bullet facts from this page, what conceptual step are they missing?"
        ]
        for line in backupPrompts where out.count < 5 && !out.contains(where: { $0.question == line }) {
            out.append(QuizQuestion(
                question: line,
                expectedAnswer: String(context.prefix(400)),
                noteID: noteID
            ))
        }
        var slot = out.count
        while out.count < 5 {
            slot += 1
            out.append(QuizQuestion(
                question: "Quick recall \(slot): what big idea do these notes keep returning to, and what detail supports it?",
                expectedAnswer: String(context.prefix(400)),
                noteID: noteID
            ))
        }
        return Array(out.prefix(5))
    }

    // MARK: - Fallback question generation (no API required)

    static func makeFallbackQuestions(from text: String, noteID: UUID) -> [QuizQuestion] {
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        let chunks: [String]
        if paragraphs.count >= 3 {
            chunks = paragraphs
        } else {
            chunks = text
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 20 }
        }

        let targets = Array(chunks.prefix(5))
        guard !targets.isEmpty else {
            return [QuizQuestion(
                question: "Walk me through the main ideas in these notes and how they fit together.",
                expectedAnswer: String(text.prefix(400)),
                noteID: noteID
            )]
        }

        return targets.map { chunk in
            let words = chunk.split(separator: " ").prefix(5).joined(separator: " ")
            let topic = words.trimmingCharacters(in: .punctuationCharacters)
            return QuizQuestion(
                question: "In your own words, what is the important idea behind \"\(topic)\" in these notes, and why would a professor care that you understand it?",
                expectedAnswer: String(chunk.prefix(300)),
                noteID: noteID
            )
        }
    }

    // MARK: - Evaluate Answer

    static func evaluateAnswer(question: String, expected: String, userAnswer: String) async throws -> EvaluationResult {
        let prompt = """
        You grade a student's SPOKEN answer in an active recall voice quiz.

        Return JSON only with keys: "correct" (boolean), "feedback" (one sentence), "explanation" (string).
        If correct is true, set "explanation" to "".
        If correct is false, "explanation" must be 1–2 sentences teaching the right idea (plain language).

        Rubric:
        - Mark correct if they demonstrate the same conceptual structure as the expected answer, even with different wording or ordering.
        - Accept partial credit as correct only when the missing piece is minor; if the main causal claim or comparison is wrong, mark incorrect.
        - If the answer is empty, off-topic, or "I don't know", mark incorrect with kind feedback.
        - Do not require verbatim quotes from the expected answer.

        Question: \(question)
        Expected answer rubric: \(expected)
        Student said: \(userAnswer.isEmpty ? "(no answer given)" : userAnswer)
        """

        let raw = try await request(prompt: prompt, jsonMode: true, temperature: 0.2)
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8),
              let result = try? JSONDecoder().decode(EvaluationResult.self, from: data) else {
            return EvaluationResult(correct: !userAnswer.isEmpty, feedback: "Good effort, keep going!", explanation: nil)
        }
        return result
    }

    // MARK: - Core request

    private static func request(prompt: String, jsonMode: Bool, temperature: Double) async throws -> String {
        try await requestParts(
            parts: [["text": prompt]],
            model: modelName,
            jsonMode: jsonMode,
            temperature: temperature
        )
    }

    private static func requestMultimodal(
        prompt: String,
        imageData: Data,
        model: String,
        jsonMode: Bool,
        temperature: Double
    ) async throws -> String {
        let upload = normalizedUploadPayload(for: imageData)
        return try await requestParts(
            parts: [
                ["text": prompt],
                ["inline_data": [
                    "mime_type": upload.mimeType,
                    "data": upload.data.base64EncodedString()
                ]]
            ],
            model: model,
            jsonMode: jsonMode,
            temperature: temperature
        )
    }

    private static func requestParts(
        parts: [[String: Any]],
        model: String,
        jsonMode: Bool,
        temperature: Double
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.noAPIKey }

        let urlString = "\(endpoint(for: model))?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiError.httpError }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var generationConfig: [String: Any] = [
            "temperature": temperature
        ]
        if jsonMode {
            generationConfig["responseMimeType"] = "application/json"
        }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": generationConfig
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeminiError.httpError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.parseError
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.parseError
        }
        return text
    }

    // MARK: - Helpers

    private static func truncateForPrompt(_ text: String) -> String {
        guard text.count > maxNoteCharsForPrompt else { return text }
        let prefix = String(text.prefix(maxNoteCharsForPrompt))
        return prefix + "\n\n[Notes truncated for the model context limit.]"
    }

    private static func stripCodeFences(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nilIfEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func normalizedUploadPayload(for imageData: Data) -> (data: Data, mimeType: String) {
        if imageData.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return (imageData, "image/png")
        }
        if imageData.starts(with: [0xFF, 0xD8, 0xFF]) {
            return (imageData, "image/jpeg")
        }
        if let image = UIImage(data: imageData), let jpegData = image.jpegData(compressionQuality: 0.92) {
            return (jpegData, "image/jpeg")
        }
        return (imageData, "image/jpeg")
    }

    private static func decodeQAPairs(_ raw: String, noteID: UUID, minimum: Int, maximum: Int) throws -> [QuizQuestion] {
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else { throw GeminiError.parseError }
        let pairs = try JSONDecoder().decode([QAPair].self, from: data)
        let trimmed = pairs
            .filter { !$0.question.isEmpty && !$0.expectedAnswer.isEmpty }
            .prefix(maximum)
        guard trimmed.count >= minimum else { throw GeminiError.parseError }
        return trimmed.map { QuizQuestion(question: $0.question, expectedAnswer: $0.expectedAnswer, noteID: noteID) }
    }
}

// MARK: - Supporting types

private struct StudyAnchor: Codable {
    let title: String
    let bigIdea: String
    let whyItMatters: String
    let relationships: String?
    let misconception: String?
    let anchorPhraseFromNotes: String?
}

private struct AnchorEnvelope: Codable {
    let anchors: [StudyAnchor]
}

private struct OCRResponse: Decodable {
    let rawText: String
    let title: String?
    let likelyTopic: String?
    let confidence: String?
    let unreadableRegions: [String]

    enum CodingKeys: String, CodingKey {
        case rawText = "raw_text"
        case title
        case likelyTopic = "likely_topic"
        case confidence
        case unreadableRegions = "unreadable_regions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawText = try container.decode(String.self, forKey: .rawText)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        likelyTopic = try container.decodeIfPresent(String.self, forKey: .likelyTopic)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence)
        unreadableRegions = try container.decodeIfPresent([String].self, forKey: .unreadableRegions) ?? []
    }
}

struct QAPair: Decodable {
    let question: String
    let expectedAnswer: String
}

struct EvaluationResult: Decodable {
    let correct: Bool
    let feedback: String
    let explanation: String?
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
