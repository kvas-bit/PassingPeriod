import Vision
import UIKit

struct VisionOCRService {
    static func extractText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

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

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage

    var errorDescription: String? { "Could not read image data for OCR." }
}
