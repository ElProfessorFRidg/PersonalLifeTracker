import Foundation
import UIKit
import Vision

/// Lecture de texte d'une photo de planning, entièrement sur l'appareil (Vision). Rien ne part sur le réseau.
/// La qualité de lecture ne peut se juger que sur un vrai iPhone avec de vrais plannings.
enum ScheduleOCRError: Error {
    case invalidImage
}

enum ScheduleOCR {

    /// Image redessinée à l'endroit (orientation appliquée) et réduite si elle est très grande.
    static func normalizedImage(_ image: UIImage, maxSide: CGFloat = 3200) -> CGImage? {
        let size = image.size
        let longest = max(size.width, size.height)
        if longest <= 0 { return nil }
        let factor: CGFloat = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: max(1, (size.width * factor).rounded()),
                            height: max(1, (size.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: CGPoint.zero, size: target))
        }
        return rendered.cgImage
    }

    /// Lignes de texte reconnues, avec leur position (origine en haut à gauche, 0 à 1).
    static func recognizeLines(in cgImage: CGImage, progress: ((Double) -> Void)? = nil) async throws -> [OCRTextLine] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[OCRTextLine], Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    // Les codes d'horaires ("9-16", "R") se font abîmer par la correction de langue.
                    request.usesLanguageCorrection = false
                    if let supported = try? request.supportedRecognitionLanguages(), supported.contains("fr-FR") {
                        request.recognitionLanguages = ["fr-FR"]
                    }
                    if let progress = progress {
                        request.progressHandler = { _, value, _ in
                            progress(value)
                        }
                    }
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                    let observations: [VNRecognizedTextObservation] = (request.results as? [VNRecognizedTextObservation]) ?? []
                    var lines: [OCRTextLine] = []
                    for observation in observations {
                        guard let top = observation.topCandidates(1).first else { continue }
                        let box = observation.boundingBox
                        lines.append(OCRTextLine(text: top.string,
                                                 minX: Double(box.minX),
                                                 minY: Double(1.0 - box.maxY),
                                                 width: Double(box.width),
                                                 height: Double(box.height),
                                                 confidence: Double(top.confidence)))
                    }
                    continuation.resume(returning: lines)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
