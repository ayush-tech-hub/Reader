import Flutter
import Foundation
import PLzmaSDK
import ZIPFoundation

/// Streamed compression engine for iOS: ZIPFoundation for ZIP (with
/// progress), PLzmaSDK for 7z/tar, Apple compression for gzip. Long
/// jobs run on a utility queue; pair with BGProcessingTask scheduling
/// (battery-friendly) when invoked from the background API.
final class ArchiveEngineHandler: NSObject, FlutterStreamHandler {

  private let queue = DispatchQueue(label: "opendocs.archive", qos: .utility)
  private var eventSink: FlutterEventSink?
  private var cancelledJobs = Set<String>()
  private let cancelLock = NSLock()

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func emitProgress(jobId: String, done: Int64, total: Int64, entry: String) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?([
        "jobId": jobId,
        "bytesDone": done,
        "bytesTotal": total,
        "currentEntry": entry,
      ])
    }
  }

  private func isCancelled(_ jobId: String) -> Bool {
    cancelLock.lock()
    defer { cancelLock.unlock() }
    return cancelledJobs.contains(jobId)
  }

  // MARK: - Method calls

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any?] else {
      result(FlutterError(code: "BAD_ARGS", message: "Expected map", details: nil))
      return
    }
    switch call.method {
    case "cancel":
      if let jobId = args["jobId"] as? String {
        cancelLock.lock()
        cancelledJobs.insert(jobId)
        cancelLock.unlock()
      }
      result(nil)
    case "create", "extract", "list":
      queue.async { [weak self] in
        guard let self else { return }
        do {
          let outcome: Any?
          switch call.method {
          case "create": outcome = try self.create(args)
          case "extract": outcome = try self.extract(args)
          default: outcome = try self.list(args)
          }
          DispatchQueue.main.async { result(outcome) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "ARCHIVE_ERROR",
                message: error.localizedDescription,
                details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Create

  private func create(_ args: [String: Any?]) throws -> Any? {
    let jobId = args["jobId"] as! String
    let sources = (args["sources"] as! [String]).map { URL(fileURLWithPath: $0) }
    let archivePath = args["archivePath"] as! String
    let format = args["format"] as! String
    let password = args["password"] as? String

    switch format {
    case "zip":
      try createZip(jobId: jobId, sources: sources, archivePath: archivePath, password: password)
    case "sevenZ", "tar":
      try createWithPlzma(
        jobId: jobId, sources: sources, archivePath: archivePath,
        fileType: format == "tar" ? .tar : .sevenZ, password: password)
    case "gzip":
      try createGzip(jobId: jobId, sources: sources, archivePath: archivePath)
    default:
      throw ArchiveError.unsupported(format)
    }
    return nil
  }

  private func createZip(
    jobId: String, sources: [URL], archivePath: String, password: String?
  ) throws {
    // ZIPFoundation has no AES encryption. Falling back to another
    // container would silently produce a non-ZIP file with a .zip
    // name, so fail honestly instead.
    if password != nil {
      throw ArchiveError.unsupported(
        "Password-protected ZIP creation is not supported on iOS yet")
    }
    let archiveURL = URL(fileURLWithPath: archivePath)
    let archive = try Archive(url: archiveURL, accessMode: .create)
    let fileManager = FileManager.default
    for source in sources {
      if isCancelled(jobId) { throw ArchiveError.cancelled }
      var isDirectory: ObjCBool = false
      fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory)
      if isDirectory.boolValue {
        let enumerator = fileManager.enumerator(at: source, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
          if isCancelled(jobId) { throw ArchiveError.cancelled }
          let relative = file.path.replacingOccurrences(
            of: source.deletingLastPathComponent().path + "/", with: "")
          try archive.addEntry(
            with: relative, relativeTo: source.deletingLastPathComponent(),
            compressionMethod: .deflate)
          emitProgress(jobId: jobId, done: 0, total: 0, entry: relative)
        }
      } else {
        try archive.addEntry(
          with: source.lastPathComponent, relativeTo: source.deletingLastPathComponent(),
          compressionMethod: .deflate)
        emitProgress(jobId: jobId, done: 0, total: 0, entry: source.lastPathComponent)
      }
    }
  }

  private func createWithPlzma(
    jobId: String, sources: [URL], archivePath: String,
    fileType: PLzmaSDK.FileType, password: String?
  ) throws {
    let encoder = try Encoder(
      stream: OutStream(path: try Path(archivePath)),
      fileType: fileType,
      method: .LZMA2)
    if let password { try encoder.setPassword(password) }
    for source in sources {
      if isCancelled(jobId) { throw ArchiveError.cancelled }
      try encoder.add(path: try Path(source.path))
    }
    _ = try encoder.open()
    _ = try encoder.compress()
    emitProgress(jobId: jobId, done: 1, total: 1, entry: "")
  }

  private func createGzip(jobId: String, sources: [URL], archivePath: String) throws {
    guard let source = sources.first, sources.count == 1 else {
      throw ArchiveError.invalid("GZIP compresses a single file")
    }
    // This implementation buffers the input; refuse sizes that would
    // pressure memory until a compression_stream-based path lands.
    if let size = try FileManager.default.attributesOfItem(atPath: source.path)[.size]
      as? Int64, size > 1 << 30
    {
      throw ArchiveError.invalid(
        "GZIP of files larger than 1 GiB is not supported on iOS yet")
    }
    let data = try Data(contentsOf: source, options: .mappedIfSafe)
    let compressed = try (data as NSData).compressed(using: .zlib)
    // Wrap raw deflate in a gzip container (header + trailer).
    var gzip = Data([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13])
    gzip.append(compressed as Data)
    var crc = (data as NSData).crc32()
    withUnsafeBytes(of: &crc) { gzip.append(contentsOf: $0.prefix(4)) }
    var size = UInt32(truncatingIfNeeded: data.count)
    withUnsafeBytes(of: &size) { gzip.append(contentsOf: $0) }
    try gzip.write(to: URL(fileURLWithPath: archivePath))
    emitProgress(
      jobId: jobId, done: Int64(data.count), total: Int64(data.count),
      entry: source.lastPathComponent)
  }

  // MARK: - Extract

  private func extract(_ args: [String: Any?]) throws -> Any? {
    let jobId = args["jobId"] as! String
    let archivePath = args["archivePath"] as! String
    let destination = args["destinationDir"] as! String
    let password = args["password"] as? String
    let lower = archivePath.lowercased()

    if lower.hasSuffix(".zip") {
      // PLzmaSDK can't read ZIP containers, so an encrypted ZIP has no
      // working decode path on iOS yet — fail honestly.
      if password != nil {
        throw ArchiveError.unsupported(
          "Password-protected ZIP extraction is not supported on iOS yet")
      }
      let archiveURL = URL(fileURLWithPath: archivePath)
      let destinationURL = URL(fileURLWithPath: destination)
      let total = (try? FileManager.default.attributesOfItem(atPath: archivePath)[.size]
        as? Int64) ?? 0
      let progress = Progress()
      let observation = progress.observe(\.fractionCompleted) { [weak self] progress, _ in
        guard let self, total > 0 else { return }
        self.emitProgress(
          jobId: jobId, done: Int64(progress.fractionCompleted * Double(total)),
          total: total, entry: "")
      }
      defer { observation.invalidate() }
      try FileManager.default.unzipItem(at: archiveURL, to: destinationURL, progress: progress)
    } else {
      // 7z / tar via PLzmaSDK.
      let decoder = try Decoder(
        stream: InStream(path: try Path(archivePath)),
        fileType: Self.plzmaType(for: lower))
      if let password { try decoder.setPassword(password) }
      _ = try decoder.open()
      // PLzmaSDK gives no documented Zip-Slip guarantee: reject any
      // entry whose path is absolute or contains a ".." component
      // before extracting.
      let items = try decoder.items()
      for index in 0..<items.count {
        let entryPath = try items.item(at: index).path().description
        if entryPath.hasPrefix("/")
          || entryPath.split(separator: "/").contains("..")
          || entryPath.split(separator: "\\").contains("..")
        {
          throw ArchiveError.invalid("Archive entry escapes destination: \(entryPath)")
        }
      }
      if isCancelled(jobId) { throw ArchiveError.cancelled }
      _ = try decoder.extract(to: try Path(destination))
      emitProgress(jobId: jobId, done: 1, total: 1, entry: "")
    }
    return nil
  }

  // MARK: - List

  private func list(_ args: [String: Any?]) throws -> Any? {
    let archivePath = args["archivePath"] as! String
    let password = args["password"] as? String
    let lower = archivePath.lowercased()

    if lower.hasSuffix(".zip") {
      // ZIP central-directory listings are readable even for encrypted
      // archives; only entry contents are protected.
      let archive = try Archive(url: URL(fileURLWithPath: archivePath), accessMode: .read)
      return archive.map { entry in
        [
          "name": entry.path,
          "isDirectory": entry.type == .directory,
          "size": entry.uncompressedSize,
          "compressedSize": entry.compressedSize,
        ]
      }
    }
    let decoder = try Decoder(
      stream: InStream(path: try Path(archivePath)),
      fileType: Self.plzmaType(for: lower))
    if let password { try decoder.setPassword(password) }
    _ = try decoder.open()
    let items = try decoder.items()
    return try (0..<items.count).map { index -> [String: Any] in
      let item = try items.item(at: index)
      return [
        "name": try item.path().description,
        "isDirectory": item.isDir,
        "size": Int64(item.size),
        "compressedSize": Int64(item.packSize),
      ]
    }
  }

  private static func plzmaType(for lowerPath: String) -> PLzmaSDK.FileType {
    if lowerPath.hasSuffix(".tar") { return .tar }
    if lowerPath.hasSuffix(".xz") { return .xz }
    return .sevenZ
  }

  enum ArchiveError: LocalizedError {
    case cancelled
    case unsupported(String)
    case invalid(String)

    var errorDescription: String? {
      switch self {
      case .cancelled: return "Cancelled"
      case .unsupported(let format): return "Unsupported format: \(format)"
      case .invalid(let message): return message
      }
    }
  }
}

extension NSData {
  /// CRC32 needed for the gzip trailer.
  func crc32() -> UInt32 {
    var table = [UInt32](repeating: 0, count: 256)
    for index in 0..<256 {
      var c = UInt32(index)
      for _ in 0..<8 { c = (c & 1) == 1 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
      table[index] = c
    }
    var crc: UInt32 = 0xFFFF_FFFF
    let bytes = self.bytes.assumingMemoryBound(to: UInt8.self)
    for index in 0..<length {
      crc = table[Int((crc ^ UInt32(bytes[index])) & 0xFF)] ^ (crc >> 8)
    }
    return crc ^ 0xFFFF_FFFF
  }
}
