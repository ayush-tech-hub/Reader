import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/ocr_result.dart';

/// Exports an [OcrResult] to various file formats and returns the path of the
/// written file.
///
/// Files are saved under `<external-or-documents-dir>/OCR_Exports/`.
class OcrExportService {
  static const _exportSubdir = 'OCR_Exports';

  // ── Directory resolution ──────────────────────────────────────────────────

  /// Resolves (and creates if necessary) the export output directory.
  ///
  /// Prefers external storage (Android SD-card / public Downloads) and falls
  /// back to the app documents directory on iOS or when external storage is
  /// unavailable.
  Future<Directory> _exportDir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();

    final dir = Directory(p.join(base.path, _exportSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ── Filename helpers ──────────────────────────────────────────────────────

  /// Returns a sanitised base name (no extension) for the export file.
  String _baseName(OcrResult result) {
    if (result.sourceType == 'camera') return 'Camera_OCR';
    final name = p.basenameWithoutExtension(result.sourcePath);
    // Replace characters that are problematic in file names.
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Future<String> _outputPath(OcrResult result, String ext) async {
    final dir = await _exportDir();
    final name = '${_baseName(result)}$ext';
    return p.join(dir.path, name);
  }

  // ── Public export methods ─────────────────────────────────────────────────

  /// Writes [result.fullText] as plain UTF-8 text.
  Future<String> exportAsTxt(OcrResult result) async {
    final path = await _outputPath(result, '.txt');
    await File(path)
        .writeAsString(result.fullText, encoding: utf8, flush: true);
    return path;
  }

  /// Writes a Markdown document with one `## Page N` section per page.
  Future<String> exportAsMarkdown(OcrResult result) async {
    final path = await _outputPath(result, '.md');

    final buf = StringBuffer();
    buf.writeln('# OCR Result');
    buf.writeln();
    buf.writeln('Source: ${result.sourceFileName}');
    buf.writeln('Date: ${_formatDate(result.createdAt)}');
    buf.writeln();

    for (var i = 0; i < result.pageTexts.length; i++) {
      buf.writeln('## Page ${i + 1}');
      buf.writeln();
      buf.writeln(result.pageTexts[i]);
      if (i < result.pageTexts.length - 1) buf.writeln();
    }

    await File(path).writeAsString(buf.toString(), encoding: utf8, flush: true);
    return path;
  }

  /// Writes a valid HTML 5 document with a `<pre>` block per page.
  Future<String> exportAsHtml(OcrResult result) async {
    final path = await _outputPath(result, '.html');

    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    buf.writeln('<head>');
    buf.writeln('  <meta charset="UTF-8">');
    buf.writeln(
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buf.writeln(
        '  <title>OCR Result – ${_escapeHtml(result.sourceFileName)}</title>');
    buf.writeln('  <style>');
    buf.writeln('    body { font-family: sans-serif; margin: 2rem; }');
    buf.writeln('    h1   { font-size: 1.4rem; }');
    buf.writeln('    h2   { font-size: 1.1rem; margin-top: 2rem; }');
    buf.writeln('    pre  { background: #f5f5f5; padding: 1rem; '
        'white-space: pre-wrap; word-break: break-word; border-radius: 4px; }');
    buf.writeln('    .meta { color: #555; font-size: 0.9rem; }');
    buf.writeln('  </style>');
    buf.writeln('</head>');
    buf.writeln('<body>');
    buf.writeln('  <h1>OCR Result</h1>');
    buf.writeln(
        '  <p class="meta">Source: ${_escapeHtml(result.sourceFileName)}'
        ' &nbsp;|&nbsp; Date: ${_formatDate(result.createdAt)}'
        ' &nbsp;|&nbsp; Pages: ${result.pageCount}</p>');

    for (var i = 0; i < result.pageTexts.length; i++) {
      buf.writeln('  <h2>Page ${i + 1}</h2>');
      buf.writeln('  <pre>${_escapeHtml(result.pageTexts[i])}</pre>');
    }

    buf.writeln('</body>');
    buf.writeln('</html>');

    await File(path).writeAsString(buf.toString(), encoding: utf8, flush: true);
    return path;
  }

  /// Writes the result as prettified JSON.
  Future<String> exportAsJson(OcrResult result) async {
    final path = await _outputPath(result, '.json');

    final data = {
      'id': result.id,
      'sourcePath': result.sourcePath,
      'sourceType': result.sourceType,
      'createdAt': result.createdAt.toIso8601String(),
      'languageCode': result.languageCode,
      'pages': result.pageTexts,
    };

    final encoder = const JsonEncoder.withIndent('  ');
    await File(path)
        .writeAsString(encoder.convert(data), encoding: utf8, flush: true);
    return path;
  }

  /// Writes a CSV where each row is `(page_number, line_text)`.
  ///
  /// The header row is: `page_number,line_text`.
  /// Values containing commas, double-quotes, or newlines are enclosed in
  /// double-quotes, with any embedded double-quotes doubled per RFC 4180.
  Future<String> exportAsCsv(OcrResult result) async {
    final path = await _outputPath(result, '.csv');

    final buf = StringBuffer();
    buf.writeln('page_number,line_text');

    for (var pageIdx = 0; pageIdx < result.pageTexts.length; pageIdx++) {
      final pageNumber = pageIdx + 1;
      final lines = result.pageTexts[pageIdx].split('\n');
      for (final line in lines) {
        buf.write(_csvField(pageNumber.toString()));
        buf.write(',');
        buf.writeln(_csvField(line));
      }
    }

    await File(path).writeAsString(buf.toString(), encoding: utf8, flush: true);
    return path;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Formats a [DateTime] for human-readable output.
  String _formatDate(DateTime dt) =>
      '${dt.year}-${_twoDigit(dt.month)}-${_twoDigit(dt.day)} '
      '${_twoDigit(dt.hour)}:${_twoDigit(dt.minute)}';

  String _twoDigit(int n) => n.toString().padLeft(2, '0');

  /// Escapes the five special HTML characters.
  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  /// Wraps [value] in double-quotes if it contains commas, double-quotes, or
  /// newlines, doubling any embedded double-quotes per RFC 4180.
  String _csvField(String value) {
    final needsQuoting =
        value.contains(',') || value.contains('"') || value.contains('\n');
    if (!needsQuoting) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
