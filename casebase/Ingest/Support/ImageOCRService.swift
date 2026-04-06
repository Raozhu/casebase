import AppKit
import Foundation
import Vision

final class ImageOCRService {
    func recognizeText(from imageURL: URL) throws -> String? {
        guard
            let image = NSImage(contentsOf: imageURL),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        try requestHandler.perform([request])

        let observations = (request.results ?? []).sorted(by: compareObservations)
        let lines = observations.compactMap { observation -> String? in
            observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private func compareObservations(
        lhs: VNRecognizedTextObservation,
        rhs: VNRecognizedTextObservation
    ) -> Bool {
        if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 0.02 {
            return lhs.boundingBox.minY > rhs.boundingBox.minY
        }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}
