import Flutter
import PDFKit
import UIKit
import Vision

/// On-device OCR for scanned PDFs: renders each page with PDFKit and
/// recognizes text with the Vision framework — fully offline.
final class OcrHandler {

  private let queue = DispatchQueue(label: "opendocs.ocr", qos: .userInitiated)

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizePdf",
      let args = call.arguments as? [String: Any?],
      let path = args["path"] as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    queue.async { [weak self] in
      guard let self else { return }
      do {
        let pages = try self.recognizePdf(path: path)
        DispatchQueue.main.async { result(pages) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(code: "OCR_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func recognizePdf(path: String) throws -> [String] {
    guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
      throw NSError(
        domain: "opendocs.ocr", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF: \(path)"])
    }
    var pages: [String] = []
    for index in 0..<document.pageCount {
      guard let page = document.page(at: index) else {
        pages.append("")
        continue
      }
      let bounds = page.bounds(for: .mediaBox)
      let scale: CGFloat = min(2.0, 3000 / max(bounds.width, bounds.height))
      let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
      let renderer = UIGraphicsImageRenderer(size: size)
      let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        context.cgContext.translateBy(x: 0, y: size.height)
        context.cgContext.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: context.cgContext)
      }
      guard let cgImage = image.cgImage else {
        pages.append("")
        continue
      }
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      try handler.perform([request])
      let text = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
      pages.append(text)
    }
    return pages
  }
}
