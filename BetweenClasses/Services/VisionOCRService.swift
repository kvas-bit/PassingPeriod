import Vision
import UIKit
import ImageIO

struct OCRDraft {
    let text: String
    let source: OCRSource
    let suggestedTitle: String?
    let suggestedTopic: String?
    let confidenceSummary: String?
    let unreadableRegions: [String]

    var sourceLabel: String {
        switch source {
        case .appleVision:
            return "Apple OCR"
        case .geminiFlash:
            return "Gemini Flash fallback"
        case .geminiPro:
            return "Gemini Pro fallback"
        }
    }
}

enum OCRSource {
    case appleVision
    case geminiFlash
    case geminiPro
}

struct VisionOCRService {
    static func extractText(from imageData: Data) async throws -> String {
        let draft = try await extractDraft(from: imageData)
        return draft.text
    }

    static func extractDraft(from imageData: Data) async throws -> OCRDraft {
        guard UIImage(data: imageData) != nil else {
            throw OCRError.invalidImage
        }

        let localText = (try? await extractLocalText(from: imageData)) ?? ""
        let localDraft = OCRDraft(
            text: localText,
            source: .appleVision,
            suggestedTitle: nil,
            suggestedTopic: nil,
            confidenceSummary: ocrHealthSummary(for: localText),
            unreadableRegions: []
        )

        guard shouldUseGeminiFallback(for: localText) else {
            return localDraft
        }

        if let geminiDraft = try? await GeminiService.extractStructuredOCR(from: imageData, localText: localText, preferPro: false),
           !geminiDraft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return geminiDraft
        }

        if let geminiProDraft = try? await GeminiService.extractStructuredOCR(from: imageData, localText: localText, preferPro: true),
           !geminiProDraft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return geminiProDraft
        }

        return localDraft
    }

    private static func extractLocalText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func shouldUseGeminiFallback(for text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let lines = trimmed.split(separator: "\n").map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let symbolCount = trimmed.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace && !$0.isPunctuation }.count
        let suspiciousCharacters = Set<Character>(["[", "]", "{", "}", "|", "\\", "~", "`", "•"])
        let suspiciousCharacterCount = trimmed.filter { suspiciousCharacters.contains($0) }.count
        let weirdRatio = trimmed.isEmpty ? 0 : Double(symbolCount + suspiciousCharacterCount) / Double(trimmed.count)

        return trimmed.count < 120 || lines.count < 3 || words.count < 25 || weirdRatio > 0.08
    }

    private static func ocrHealthSummary(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Local OCR found almost nothing." }

        let lines = trimmed.split(separator: "\n").count
        let words = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        if trimmed.count < 120 || lines < 3 || words < 25 {
            return "Local OCR looked thin, so cloud fallback may help." }
        return "Local OCR looked usable."
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage

    var errorDescription: String? { "Could not read image data for OCR." }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
