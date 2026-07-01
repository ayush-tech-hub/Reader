import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

// ── DOCX ──────────────────────────────────────────────────────────────────────

class DocxReaderScreen extends StatelessWidget {
  const DocxReaderScreen({super.key, required this.path});
  final String path;

  static Future<List<String>> _extract(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw const FormatException('Not a valid DOCX file'),
    );
    final doc = XmlDocument.parse(
      utf8.decode(entry.content as List<int>, allowMalformed: true),
    );
    final paragraphs = <String>[];
    for (final para in doc.findAllElements('w:p')) {
      // Preserve run spacing: join all <w:t> within the paragraph.
      final text = para.findAllElements('w:t').map((e) => e.innerText).join('');
      if (text.trim().isNotEmpty) paragraphs.add(text);
    }
    return paragraphs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<List<String>>(
        future: _extract(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final paras = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paras.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(paras[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── XLSX ──────────────────────────────────────────────────────────────────────

class XlsxReaderScreen extends StatelessWidget {
  const XlsxReaderScreen({super.key, required this.path});
  final String path;

  static const _maxRows = 200;

  static Future<({List<String> sheetNames, List<List<String>> rows})> _extract(
    String path,
  ) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile find(String name) =>
        archive.files.firstWhere((f) => f.name == name,
            orElse: () => throw FormatException('Missing $name'));

    // Shared strings (optional — some xlsx omit it).
    final sharedStrings = <String>[];
    try {
      final ssXml = XmlDocument.parse(
        utf8.decode(
            (find('xl/sharedStrings.xml').content as List<int>),
            allowMalformed: true),
      );
      for (final si in ssXml.findAllElements('si')) {
        sharedStrings
            .add(si.findAllElements('t').map((e) => e.innerText).join(''));
      }
    } catch (_) {}

    // Sheet names from workbook.
    final sheetNames = <String>[];
    try {
      final wbXml = XmlDocument.parse(
        utf8.decode(
            (find('xl/workbook.xml').content as List<int>),
            allowMalformed: true),
      );
      for (final sh in wbXml.findAllElements('sheet')) {
        sheetNames.add(sh.getAttribute('name') ?? '');
      }
    } catch (_) {}

    // First sheet rows.
    final sheetEntry = archive.files.firstWhere(
      (f) => RegExp(r'xl/worksheets/sheet1\.xml').hasMatch(f.name),
      orElse: () => throw const FormatException('No sheet found'),
    );
    final sheetXml = XmlDocument.parse(
      utf8.decode(sheetEntry.content as List<int>, allowMalformed: true),
    );
    final rows = <List<String>>[];
    for (final row in sheetXml.findAllElements('row')) {
      if (rows.length >= _maxRows) break;
      final cells = <String>[];
      for (final cell in row.findAllElements('c')) {
        final type = cell.getAttribute('t');
        final rawVal =
            cell.findElements('v').firstOrNull?.innerText ??
            cell.findElements('is').firstOrNull?.findElements('t').firstOrNull?.innerText ??
            '';
        String cellText;
        if (type == 's') {
          final idx = int.tryParse(rawVal) ?? -1;
          cellText =
              (idx >= 0 && idx < sharedStrings.length) ? sharedStrings[idx] : '';
        } else if (type == 'inlineStr') {
          cellText = rawVal;
        } else {
          cellText = rawVal;
        }
        cells.add(cellText);
      }
      if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
    }
    return (sheetNames: sheetNames, rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<({List<String> sheetNames, List<List<String>> rows})>(
        future: _extract(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final rows = data.rows;
          if (rows.isEmpty) {
            return const Center(child: Text('Empty spreadsheet'));
          }
          final colCount = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
          List<String> pad(List<String> r) =>
              List.generate(colCount, (i) => i < r.length ? r[i] : '');
          final headers = rows.first;
          final dataRows = rows.skip(1).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.sheetNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('Sheet: ${data.sheetNames.first}',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              if (rows.length >= _maxRows)
                const MaterialBanner(
                  content: Text('Showing first 200 rows only.'),
                  actions: [SizedBox.shrink()],
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        for (final h in pad(headers))
                          DataColumn(
                            label: Text(h,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                      rows: [
                        for (final row in dataRows)
                          DataRow(
                            cells: [
                              for (final c in pad(row)) DataCell(Text(c)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── PPTX ──────────────────────────────────────────────────────────────────────

class PptxReaderScreen extends StatefulWidget {
  const PptxReaderScreen({super.key, required this.path});
  final String path;

  @override
  State<PptxReaderScreen> createState() => _PptxReaderScreenState();
}

class _PptxReaderScreenState extends State<PptxReaderScreen> {
  late final Future<List<String>> _slides = _extract(widget.path);
  int _slideIndex = 0;

  static Future<List<String>> _extract(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final slidePattern = RegExp(r'ppt/slides/slide(\d+)\.xml$');
    final slideFiles = archive.files
        .where((f) => slidePattern.hasMatch(f.name))
        .toList()
      ..sort((a, b) {
        int idx(ArchiveFile f) =>
            int.tryParse(slidePattern.firstMatch(f.name)!.group(1)!) ?? 0;
        return idx(a).compareTo(idx(b));
      });

    final slides = <String>[];
    for (final file in slideFiles) {
      final content =
          utf8.decode(file.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(content);
      final text =
          doc.findAllElements('a:t').map((e) => e.innerText).join(' ').trim();
      slides.add(text.isEmpty ? '(no text on this slide)' : text);
    }
    return slides;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _slides,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(p.basename(widget.path))),
            body: Center(child: Text(snapshot.error.toString())),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(p.basename(widget.path))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final slides = snapshot.data!;
        if (slides.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(p.basename(widget.path))),
            body: const Center(child: Text('No slides found')),
          );
        }
        final idx = _slideIndex.clamp(0, slides.length - 1);
        return Scaffold(
          appBar: AppBar(
            title: Text(p.basename(widget.path)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('${idx + 1} / ${slides.length}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              slides[idx],
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: idx > 0
                      ? () => setState(() => _slideIndex = idx - 1)
                      : null,
                ),
                Text('Slide ${idx + 1}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: idx < slides.length - 1
                      ? () => setState(() => _slideIndex = idx + 1)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── RTF ───────────────────────────────────────────────────────────────────────

/// Extracts plain text from RTF (Rich Text Format) files.
///
/// Uses a lightweight state-machine pass rather than a full RTF parser:
/// - Ignorable destinations `{\*…}` are removed before text extraction
/// - `\par`, `\line`, `\page` become newlines; `\tab` becomes a tab
/// - `\uN?` sequences are decoded to Unicode code points
/// - `\'HH` sequences are decoded as Windows-1252 bytes
/// - All remaining control words and RTF group delimiters are stripped
class RtfReaderScreen extends StatelessWidget {
  const RtfReaderScreen({super.key, required this.path});
  final String path;

  static Future<String> _extract(String filePath) async {
    final raw = await File(filePath).readAsString(
      encoding: latin1, // RTF header specifies encoding; latin1 is a safe default
    );
    return _parseRtf(raw);
  }

  static String _parseRtf(String rtf) {
    // 1. Remove ignorable destinations: {\* ...} at the top level.
    //    We do a simple single-pass removal of flat {\*...} groups.
    var s = rtf.replaceAll(RegExp(r'\{\\\*[^{}]*\}'), '');

    // 2. Replace structural control words with whitespace equivalents.
    s = s
        .replaceAll(RegExp(r'\\par\b\s?'), '\n')
        .replaceAll(RegExp(r'\\line\b\s?'), '\n')
        .replaceAll(RegExp(r'\\page\b\s?'), '\n\n')
        .replaceAll(RegExp(r'\\tab\b\s?'), '\t')
        .replaceAll(RegExp(r'\\sect\b\s?'), '\n\n');

    // 3. Decode Unicode escapes: \uN? (N is a signed 16-bit decimal).
    s = s.replaceAllMapped(
      RegExp(r'\\u(-?\d+)\??'),
      (m) {
        var code = int.parse(m.group(1)!);
        if (code < 0) code += 65536;
        try {
          return String.fromCharCode(code);
        } catch (_) {
          return '';
        }
      },
    );

    // 4. Decode hex-encoded bytes: \'HH (Windows-1252).
    s = s.replaceAllMapped(
      RegExp(r"\\'([0-9a-fA-F]{2})"),
      (m) {
        final byte = int.parse(m.group(1)!, radix: 16);
        // Windows-1252 overrides for the 0x80-0x9F range
        const cp1252 = {
          0x80: '€', 0x82: '‚', 0x83: 'ƒ', 0x84: '„',
          0x85: '…', 0x86: '†', 0x87: '‡', 0x88: 'ˆ',
          0x89: '‰', 0x8A: 'Š', 0x8B: '‹', 0x8C: 'Œ',
          0x8E: 'Ž', 0x91: '‘', 0x92: '’', 0x93: '“',
          0x94: '”', 0x95: '•', 0x96: '–', 0x97: '—',
          0x98: '˜', 0x99: '™', 0x9A: 'š', 0x9B: '›',
          0x9C: 'œ', 0x9E: 'ž', 0x9F: 'Ÿ',
        };
        return cp1252[byte] ?? String.fromCharCode(byte);
      },
    );

    // 5. Remove all remaining control words and symbols.
    s = s.replaceAll(RegExp(r'\\[a-zA-Z]+\-?\d*\s?'), '');
    s = s.replaceAll(RegExp(r'\\[^a-zA-Z\r\n]'), '');

    // 6. Remove RTF group delimiters.
    s = s.replaceAll(RegExp(r'[{}]'), '');

    // 7. Normalise whitespace.
    s = s
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (s.isEmpty) throw const FormatException('No readable text found in RTF file');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<String>(
        future: _extract(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.data!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
    );
  }
}

// ── ODT ───────────────────────────────────────────────────────────────────────

/// Reads OpenDocument Text (.odt) files — the native format for
/// LibreOffice Writer and Apache OpenOffice Writer.
///
/// ODT is a ZIP archive containing `content.xml`. Text paragraphs live in
/// `<text:p>` elements; headings in `<text:h>`. Both are extracted and
/// joined with blank lines between them.
class OdtReaderScreen extends StatelessWidget {
  const OdtReaderScreen({super.key, required this.path});
  final String path;

  static Future<List<String>> _extract(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final entry = archive.files.firstWhere(
      (f) => f.name == 'content.xml',
      orElse: () => throw const FormatException('Not a valid ODT file'),
    );

    final doc = XmlDocument.parse(
      utf8.decode(entry.content as List<int>, allowMalformed: true),
    );

    final paragraphs = <String>[];
    // Both regular paragraphs and headings use the same text content structure.
    for (final el in doc.findAllElements('text:p')) {
      final text = _textOf(el);
      if (text.isNotEmpty) paragraphs.add(text);
    }
    for (final el in doc.findAllElements('text:h')) {
      final text = _textOf(el);
      if (text.isNotEmpty) paragraphs.add(text);
    }

    // Re-sort by document order using element index in the flat list.
    // findAllElements returns in document order, but we called it twice,
    // so merge and re-sort by the elements' positions in the document.
    // Simpler: collect once over the body with a combined selector.
    return _extractInOrder(doc);
  }

  static String _textOf(XmlElement el) {
    // <text:s c="N"/> → N spaces; <text:tab/> → tab; text nodes → literal text
    final buf = StringBuffer();
    for (final node in el.children) {
      if (node is XmlText) {
        buf.write(node.value);
      } else if (node is XmlElement) {
        if (node.name.local == 's') {
          final count = int.tryParse(node.getAttribute('text:c') ?? '1') ?? 1;
          buf.write(' ' * count);
        } else if (node.name.local == 'tab') {
          buf.write('\t');
        } else if (node.name.local == 'line-break') {
          buf.write('\n');
        } else {
          // Recurse into spans, anchors, etc.
          buf.write(_textOf(node));
        }
      }
    }
    return buf.toString().trim();
  }

  static List<String> _extractInOrder(XmlDocument doc) {
    final paragraphs = <String>[];
    // Walk body elements in document order.
    final body = doc
        .findAllElements('office:body')
        .firstOrNull
        ?.findAllElements('office:text')
        .firstOrNull;
    if (body == null) {
      // Fallback: collect all text:p in document order
      for (final el in doc.findAllElements('text:p')) {
        final t = _textOf(el);
        if (t.isNotEmpty) paragraphs.add(t);
      }
      return paragraphs;
    }
    for (final el in body.children.whereType<XmlElement>()) {
      _collectText(el, paragraphs);
    }
    return paragraphs;
  }

  static void _collectText(XmlElement el, List<String> out) {
    final local = el.name.local;
    if (local == 'p' || local == 'h') {
      final t = _textOf(el);
      if (t.isNotEmpty) out.add(t);
    } else {
      for (final child in el.children.whereType<XmlElement>()) {
        _collectText(child, out);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<List<String>>(
        future: _extract(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final paras = snapshot.data!;
          if (paras.isEmpty) {
            return const Center(child: Text('Document appears to be empty'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paras.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(
                paras[i],
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        },
      ),
    );
  }
}
