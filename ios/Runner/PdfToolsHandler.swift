import Flutter
import Foundation
import PDFKit
import UIKit

/// PDF page surgery backed by Apple's PDFKit. Every method writes a new
/// output file; sources are never modified in place.
final class PdfToolsHandler {

  private let queue = DispatchQueue(label: "opendocs.pdftools", qos: .userInitiated)

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any?] else {
      result(FlutterError(code: "BAD_ARGS", message: "Expected map", details: nil))
      return
    }
    queue.async { [weak self] in
      guard let self else { return }
      do {
        let outcome: Any?
        switch call.method {
        case "merge": outcome = try self.merge(args)
        case "split": outcome = try self.split(args)
        case "compress": outcome = try self.compress(args)
        case "reorderPages": outcome = try self.reorderPages(args)
        case "deletePages": outcome = try self.deletePages(args)
        case "rotatePages": outcome = try self.rotatePages(args)
        case "extractPages": outcome = try self.extractPages(args)
        case "watermark": outcome = try self.watermark(args)
        case "getMetadata": outcome = try self.getMetadata(args)
        case "setMetadata": outcome = try self.setMetadata(args)
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(outcome) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "PDF_TOOLS_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - Operations

  private func merge(_ args: [String: Any?]) throws -> String {
    let sources = args["sources"] as! [String]
    let outputPath = args["outputPath"] as! String
    let output = PDFDocument()
    for source in sources {
      let document = try open(source)
      for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else { continue }
        output.insert(page, at: output.pageCount)
      }
    }
    try write(output, to: outputPath)
    return outputPath
  }

  private func split(_ args: [String: Any?]) throws -> [String] {
    let source = args["source"] as! String
    let ranges = args["ranges"] as! [[String: Int]]
    let outputDir = args["outputDir"] as! String
    let document = try open(source)
    let baseName = (source as NSString).lastPathComponent
      .replacingOccurrences(of: ".pdf", with: "")
    var outputs: [String] = []
    for (index, range) in ranges.enumerated() {
      let part = PDFDocument()
      let start = range["start"]!
      let end = min(range["end"]!, document.pageCount)
      for pageNumber in start...end {
        guard let page = document.page(at: pageNumber - 1) else { continue }
        part.insert(page, at: part.pageCount)
      }
      let path = (outputDir as NSString)
        .appendingPathComponent("\(baseName)_part\(index + 1).pdf")
      try write(part, to: path)
      outputs.append(path)
    }
    return outputs
  }

  /// Re-renders pages as JPEG-backed pages at a quality-dependent
  /// scale — effective for scanned/image-heavy documents.
  private func compress(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let quality = args["quality"] as? String ?? "medium"
    let (scale, jpegQuality): (CGFloat, CGFloat) = {
      switch quality {
      case "low": return (1.0, 0.5)
      case "high": return (2.0, 0.85)
      default: return (1.5, 0.7)
      }
    }()
    let document = try open(source)
    let output = PDFDocument()
    for index in 0..<document.pageCount {
      guard let page = document.page(at: index) else { continue }
      let bounds = page.bounds(for: .mediaBox)
      let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
      let renderer = UIGraphicsImageRenderer(size: size)
      let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        context.cgContext.translateBy(x: 0, y: size.height)
        context.cgContext.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: context.cgContext)
      }
      guard
        let jpeg = image.jpegData(compressionQuality: jpegQuality),
        let compressedImage = UIImage(data: jpeg),
        let newPage = PDFPage(image: compressedImage)
      else { continue }
      output.insert(newPage, at: output.pageCount)
    }
    try write(output, to: outputPath)
    return outputPath
  }

  private func reorderPages(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let order = args["order"] as! [Int]
    let document = try open(source)
    let output = PDFDocument()
    for pageNumber in order {
      guard let page = document.page(at: pageNumber - 1) else { continue }
      output.insert(page, at: output.pageCount)
    }
    try write(output, to: outputPath)
    return outputPath
  }

  private func deletePages(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let toDelete = Set(args["pages"] as! [Int])
    let document = try open(source)
    let output = PDFDocument()
    for pageNumber in 1...document.pageCount where !toDelete.contains(pageNumber) {
      guard let page = document.page(at: pageNumber - 1) else { continue }
      output.insert(page, at: output.pageCount)
    }
    try write(output, to: outputPath)
    return outputPath
  }

  private func rotatePages(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let pages = Set(args["pages"] as! [Int])
    let degrees = args["degrees"] as! Int
    let document = try open(source)
    for pageNumber in pages {
      guard let page = document.page(at: pageNumber - 1) else { continue }
      page.rotation = (page.rotation + degrees) % 360
    }
    try write(document, to: outputPath)
    return outputPath
  }

  private func extractPages(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let start = args["start"] as! Int
    let end = args["end"] as! Int
    let document = try open(source)
    let output = PDFDocument()
    for pageNumber in start...min(end, document.pageCount) {
      guard let page = document.page(at: pageNumber - 1) else { continue }
      output.insert(page, at: output.pageCount)
    }
    try write(output, to: outputPath)
    return outputPath
  }

  private func watermark(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let text = args["text"] as! String
    let fontSize = CGFloat(args["fontSize"] as? Double ?? 48)
    let opacity = CGFloat(args["opacity"] as? Double ?? 0.25)
    let rotation = CGFloat(args["rotation"] as? Double ?? 45)
    let document = try open(source)
    // Render each page with the watermark drawn on top into a new doc.
    let output = PDFDocument()
    for index in 0..<document.pageCount {
      guard let page = document.page(at: index) else { continue }
      let bounds = page.bounds(for: .mediaBox)
      let renderer = UIGraphicsImageRenderer(size: bounds.size)
      let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(bounds)
        context.cgContext.saveGState()
        context.cgContext.translateBy(x: 0, y: bounds.height)
        context.cgContext.scaleBy(x: 1, y: -1)
        page.draw(with: .mediaBox, to: context.cgContext)
        context.cgContext.restoreGState()

        context.cgContext.saveGState()
        context.cgContext.translateBy(x: bounds.midX, y: bounds.midY)
        context.cgContext.rotate(by: -rotation * .pi / 180)
        let attributes: [NSAttributedString.Key: Any] = [
          .font: UIFont.boldSystemFont(ofSize: fontSize),
          .foregroundColor: UIColor.gray.withAlphaComponent(opacity),
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
          at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2),
          withAttributes: attributes)
        context.cgContext.restoreGState()
      }
      guard let newPage = PDFPage(image: image) else { continue }
      output.insert(newPage, at: output.pageCount)
    }
    try write(output, to: outputPath)
    return outputPath
  }

  private func getMetadata(_ args: [String: Any?]) throws -> [String: String] {
    let source = args["source"] as! String
    let document = try open(source)
    let attributes = document.documentAttributes ?? [:]
    func read(_ key: PDFDocumentAttribute) -> String {
      attributes[key] as? String ?? ""
    }
    return [
      "title": read(.titleAttribute),
      "author": read(.authorAttribute),
      "subject": read(.subjectAttribute),
      "keywords": read(.keywordsAttribute),
      "creator": read(.creatorAttribute),
      "producer": read(.producerAttribute),
    ]
  }

  private func setMetadata(_ args: [String: Any?]) throws -> String {
    let source = args["source"] as! String
    let outputPath = args["outputPath"] as! String
    let document = try open(source)
    var attributes = document.documentAttributes ?? [:]
    attributes[PDFDocumentAttribute.titleAttribute] = args["title"] as? String
    attributes[PDFDocumentAttribute.authorAttribute] = args["author"] as? String
    attributes[PDFDocumentAttribute.subjectAttribute] = args["subject"] as? String
    attributes[PDFDocumentAttribute.keywordsAttribute] = args["keywords"] as? String
    attributes[PDFDocumentAttribute.creatorAttribute] = args["creator"] as? String
    attributes[PDFDocumentAttribute.producerAttribute] = args["producer"] as? String
    document.documentAttributes = attributes
    try write(document, to: outputPath)
    return outputPath
  }

  // MARK: - Helpers

  private func open(_ path: String) throws -> PDFDocument {
    guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
      throw PdfToolsError.cannotOpen(path)
    }
    return document
  }

  private func write(_ document: PDFDocument, to path: String) throws {
    guard document.write(to: URL(fileURLWithPath: path)) else {
      throw PdfToolsError.cannotWrite(path)
    }
  }

  enum PdfToolsError: LocalizedError {
    case cannotOpen(String)
    case cannotWrite(String)

    var errorDescription: String? {
      switch self {
      case .cannotOpen(let path): return "Cannot open PDF: \(path)"
      case .cannotWrite(let path): return "Cannot write PDF: \(path)"
      }
    }
  }
}
