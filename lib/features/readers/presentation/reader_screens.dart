import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../core/di/providers.dart';
import '../../../core/plugins/document_plugin.dart';
import 'mobi_reader_screen.dart';
import 'office_reader_screens.dart';

/// Registers the built-in viewers with the plugin registry. Third-party
/// plugins use exactly the same interface.
void registerBuiltInPlugins() {
  PluginRegistry.instance
    ..register(_MarkdownPlugin())
    ..register(_EpubPlugin())
    ..register(_ComicPlugin())
    ..register(_TxtPlugin())
    ..register(_CsvPlugin())
    ..register(_JsonPlugin())
    ..register(_XmlViewerPlugin())
    ..register(_ImagePlugin())
    ..register(_DocxPlugin())
    ..register(_XlsxPlugin())
    ..register(_PptxPlugin())
    ..register(_MobiPlugin());
}

class _MarkdownPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.markdown';
  @override
  Set<String> get extensions => const {'.md', '.markdown'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      MarkdownReaderScreen(path: path);
}

class _EpubPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.epub';
  @override
  Set<String> get extensions => const {'.epub'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      EpubReaderScreen(path: path);
}

class _ComicPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.comic';
  @override
  Set<String> get extensions => const {'.cbz', '.cbr'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      ComicReaderScreen(path: path);
}

class _TxtPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.txt';
  @override
  Set<String> get extensions => const {'.txt', '.log', '.rtf'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      TxtReaderScreen(path: path);
}

class _CsvPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.csv';
  @override
  Set<String> get extensions => const {'.csv'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      CsvViewerScreen(path: path);
}

class _JsonPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.json';
  @override
  Set<String> get extensions => const {'.json'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      JsonViewerScreen(path: path);
}

class _XmlViewerPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.xml';
  @override
  Set<String> get extensions => const {'.xml'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      XmlViewerScreen(path: path);
}

class _ImagePlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.image';
  @override
  Set<String> get extensions => const {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
        '.svg',
      };
  @override
  Widget buildViewer(BuildContext context, String path) =>
      ImageViewerScreen(path: path);
}

class _DocxPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.docx';
  @override
  Set<String> get extensions => const {'.docx', '.doc'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      DocxReaderScreen(path: path);
}

class _XlsxPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.xlsx';
  @override
  Set<String> get extensions => const {'.xlsx', '.xls'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      XlsxReaderScreen(path: path);
}

class _PptxPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.pptx';
  @override
  Set<String> get extensions => const {'.pptx', '.ppt'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      PptxReaderScreen(path: path);
}

class _MobiPlugin implements DocumentPlugin {
  @override
  String get id => 'opendocs.mobi';
  @override
  Set<String> get extensions => const {'.mobi', '.azw', '.azw3'};
  @override
  Widget buildViewer(BuildContext context, String path) =>
      MobiReaderScreen(path: path);
}

/// Hosts whichever plugin claims [path]; routed as /plugin-view.
class PluginViewerScreen extends StatelessWidget {
  const PluginViewerScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final plugin = PluginRegistry.instance.forPath(path);
    if (plugin == null) {
      return Scaffold(
        appBar: AppBar(title: Text(p.basename(path))),
        body: const Center(child: Icon(Icons.extension_off, size: 48)),
      );
    }
    return plugin.buildViewer(context, path);
  }
}

// ---- Markdown -------------------------------------------------------

class MarkdownReaderScreen extends StatelessWidget {
  const MarkdownReaderScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<String>(
        future: File(path).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Markdown(
            data: snapshot.data!,
            selectable: true,
            padding: const EdgeInsets.all(16),
          );
        },
      ),
    );
  }
}

// ---- EPUB ------------------------------------------------------------

/// Minimal offline EPUB model: an EPUB is a ZIP with an OPF manifest
/// whose spine lists the XHTML chapters in reading order.
class EpubBook {
  const EpubBook({required this.title, required this.chapters});

  final String title;
  final List<(String title, String text)> chapters;

  static Future<EpubBook> open(String path) async {
    final inputStream = InputFileStream(path);
    final zip = ZipDecoder().decodeBuffer(inputStream);
    try {
      String read(String name) {
        final file = zip.files.firstWhere(
          (f) => f.isFile && f.name == name,
          orElse: () => throw const FormatException('Missing EPUB entry'),
        );
        return utf8.decode(file.content as List<int>, allowMalformed: true);
      }

      // META-INF/container.xml -> rootfile (the OPF package document).
      final container = XmlDocument.parse(read('META-INF/container.xml'));
      final opfPath = container
          .findAllElements('rootfile')
          .first
          .getAttribute('full-path')!;
      final opf = XmlDocument.parse(read(opfPath));
      final opfDir = p.posix.dirname(opfPath);

      final title = opf
          .findAllElements('title', namespace: '*')
          .map((e) => e.innerText)
          .firstWhere((t) => t.isNotEmpty, orElse: () => '')
          .trim();

      final hrefById = {
        for (final item in opf.findAllElements('item'))
          item.getAttribute('id')!: item.getAttribute('href')!,
      };
      final chapters = <(String, String)>[];
      for (final itemref in opf.findAllElements('itemref')) {
        final href = hrefById[itemref.getAttribute('idref')];
        if (href == null) continue;
        final entry = p.posix.normalize(opfDir == '.' ? href : '$opfDir/$href');
        try {
          final html = read(Uri.decodeComponent(entry));
          final text = htmlToText(html);
          if (text.isEmpty) continue;
          final heading = RegExp(
            r'<h[1-6][^>]*>(.*?)</h[1-6]>',
            dotAll: true,
          ).firstMatch(html)?.group(1);
          chapters.add((
            heading == null ? p.basename(entry) : htmlToText(heading),
            text,
          ));
        } on FormatException {
          continue;
        }
      }
      return EpubBook(title: title, chapters: chapters);
    } finally {
      await inputStream.close();
    }
  }
}

final _tagPattern = RegExp(r'<[^>]+>', dotAll: true);
final _blockPattern = RegExp(
  r'</?(p|div|br|h[1-6]|li|tr)[^>]*>',
  caseSensitive: false,
);

/// Basic HTML → text rendering: block tags become line breaks, the
/// rest is stripped. Keeps the reader dependency-light and offline.
String htmlToText(String html) => html
    .replaceAll(RegExp(r'<(style|script)[^>]*>.*?</\1>', dotAll: true), '')
    .replaceAll(_blockPattern, '\n')
    .replaceAll(_tagPattern, '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

class EpubReaderScreen extends ConsumerStatefulWidget {
  const EpubReaderScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  late final Future<EpubBook> _book = EpubBook.open(widget.path);
  int _chapterIndex = 0;
  bool _speaking = false;

  @override
  void dispose() {
    ref.read(ttsServiceProvider).stop();
    super.dispose();
  }

  Future<void> _ttsToggle(String text) async {
    final tts = ref.read(ttsServiceProvider);
    if (_speaking) {
      await tts.stop();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await tts.speak(text);
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EpubBook>(
      future: _book,
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
        final book = snapshot.data!;
        final chapters = book.chapters;
        final index =
            chapters.isEmpty ? 0 : _chapterIndex.clamp(0, chapters.length - 1);
        final content = chapters.isEmpty ? '' : chapters[index].$2;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              book.title.isEmpty ? p.basename(widget.path) : book.title,
            ),
            actions: [
              IconButton(
                icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                tooltip: _speaking ? 'Stop reading' : 'Read aloud',
                onPressed: () => _ttsToggle(content),
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(
                  chapters[i].$1.isEmpty ? 'Chapter ${i + 1}' : chapters[i].$1,
                ),
                selected: i == index,
                onTap: () {
                  setState(() {
                    _chapterIndex = i;
                    _speaking = false;
                  });
                  ref.read(ttsServiceProvider).stop();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(content),
          ),
          bottomNavigationBar: BottomAppBar(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: index > 0
                      ? () {
                          ref.read(ttsServiceProvider).stop();
                          setState(() {
                            _chapterIndex = index - 1;
                            _speaking = false;
                          });
                        }
                      : null,
                ),
                Text('${index + 1} / ${chapters.length}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: index < chapters.length - 1
                      ? () {
                          ref.read(ttsServiceProvider).stop();
                          setState(() {
                            _chapterIndex = index + 1;
                            _speaking = false;
                          });
                        }
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

// ---- Comics (CBZ; CBR is unsupported — RAR decoding is proprietary) ---

class ComicReaderScreen extends StatefulWidget {
  const ComicReaderScreen({super.key, required this.path});

  final String path;

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen> {
  late final Future<List<ArchiveFile>> _pages = _load();
  int _page = 0;

  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};

  Future<List<ArchiveFile>> _load() async {
    if (widget.path.toLowerCase().endsWith('.cbr')) {
      throw UnsupportedError(
        'CBR (RAR) comics are not supported; convert to CBZ.',
      );
    }
    final inputStream = InputFileStream(widget.path);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    final pages = archive.files
        .where(
          (f) =>
              f.isFile &&
              _imageExtensions.contains(p.extension(f.name).toLowerCase()),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(p.basename(widget.path))),
      body: FutureBuilder<List<ArchiveFile>>(
        future: _pages,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pages = snapshot.data!;
          return PageView.builder(
            itemCount: pages.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => InteractiveViewer(
              maxScale: 6,
              child: Image.memory(
                pages[index].content as Uint8List,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<ArchiveFile>>(
        future: _pages,
        builder: (context, snapshot) => snapshot.hasData
            ? BottomAppBar(
                height: 40,
                color: Colors.black,
                child: Center(
                  child: Text(
                    '${_page + 1} / ${snapshot.data!.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ---- TXT / LOG / RTF -------------------------------------------------------

/// A standalone screen for plain-text files, also exposed as a plugin.
class TxtReaderScreen extends ConsumerStatefulWidget {
  const TxtReaderScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends ConsumerState<TxtReaderScreen> {
  static const _maxBytes = 500 * 1024; // 500 KB
  static const _fontSizes = <String, double>{
    'S': 12,
    'M': 15,
    'L': 20,
  };

  late final Future<(String, bool)> _content = _load();
  String _sizeKey = 'M';
  bool _speaking = false;

  @override
  void dispose() {
    ref.read(ttsServiceProvider).stop();
    super.dispose();
  }

  Future<(String, bool)> _load() async {
    final file = File(widget.path);
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxBytes) {
      final truncated = utf8.decode(
        bytes.sublist(0, _maxBytes),
        allowMalformed: true,
      );
      return (truncated, true);
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    return (text, false);
  }

  Future<void> _ttsToggle(String text) async {
    final tts = ref.read(ttsServiceProvider);
    if (_speaking) {
      await tts.stop();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await tts.speak(text);
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.path)),
        actions: [
          for (final key in _fontSizes.keys)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Text(key),
                selected: _sizeKey == key,
                onSelected: (_) => setState(() => _sizeKey = key),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<(String, bool)>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (text, truncated) = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (truncated)
                const MaterialBanner(
                  content: Text('File truncated to first 500 KB.'),
                  actions: [SizedBox.shrink()],
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    text,
                    style: TextStyle(fontSize: _fontSizes[_sizeKey]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton.icon(
                  icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                  label: Text(_speaking ? 'Stop reading' : 'Read aloud'),
                  onPressed: () => _ttsToggle(text),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---- CSV -------------------------------------------------------------------

/// Parses CSV text into a list of rows (each row is a list of fields).
/// Handles double-quoted fields that may contain commas or newlines.
List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  final lines = <String>[];

  // Re-assemble lines while respecting quoted newlines.
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (ch == '"') {
      // Handle escaped quote ("")
      if (inQuotes && i + 1 < source.length && source[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if ((ch == '\n' || ch == '\r') && !inQuotes) {
      if (ch == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      lines.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) lines.add(buf.toString());

  for (final line in lines) {
    if (line.isEmpty) continue;
    final fields = <String>[];
    final fieldBuf = StringBuffer();
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          fieldBuf.write('"');
          i++;
        } else {
          inQ = !inQ;
        }
      } else if (ch == ',' && !inQ) {
        fields.add(fieldBuf.toString());
        fieldBuf.clear();
      } else {
        fieldBuf.write(ch);
      }
    }
    fields.add(fieldBuf.toString());
    rows.add(fields);
  }
  return rows;
}

class CsvViewerScreen extends StatelessWidget {
  const CsvViewerScreen({super.key, required this.path});

  final String path;

  static const _maxRows = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(path))),
      body: FutureBuilder<String>(
        future: File(path).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = _parseCsv(snapshot.data!);
          if (rows.isEmpty) {
            return const Center(child: Text('Empty file'));
          }
          final headers = rows.first;
          final dataRows = rows.skip(1).take(_maxRows).toList();
          final truncated = rows.length - 1 > _maxRows;
          final colCount = rows.fold<int>(
            0,
            (m, r) => r.length > m ? r.length : m,
          );
          // Pad all rows to colCount.
          List<String> pad(List<String> r) =>
              List.generate(colCount, (i) => i < r.length ? r[i] : '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (truncated)
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
                            label: Text(
                              h,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                      rows: [
                        for (final row in dataRows)
                          DataRow(
                            cells: [
                              for (final cell in pad(row)) DataCell(Text(cell)),
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

// ---- JSON ------------------------------------------------------------------

class JsonViewerScreen extends StatelessWidget {
  const JsonViewerScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(path)),
        actions: [
          FutureBuilder<String>(
            future: File(path).readAsString(),
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all',
              onPressed: snapshot.hasData
                  ? () {
                      Clipboard.setData(
                        ClipboardData(text: snapshot.data!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: File(path).readAsString(),
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
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }
}

// ---- XML -------------------------------------------------------------------

class XmlViewerScreen extends StatelessWidget {
  const XmlViewerScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(path)),
        actions: [
          FutureBuilder<String>(
            future: File(path).readAsString(),
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all',
              onPressed: snapshot.hasData
                  ? () {
                      Clipboard.setData(
                        ClipboardData(text: snapshot.data!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: File(path).readAsString(),
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
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }
}

// ---- Image -----------------------------------------------------------------

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.path});

  final String path;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.basename(widget.path))),
      body: GestureDetector(
        onDoubleTap: () => setState(() {
          _controller.value = Matrix4.identity();
        }),
        child: InteractiveViewer(
          transformationController: _controller,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.1,
          maxScale: 10.0,
          child: Center(
            child: Image.file(File(widget.path)),
          ),
        ),
      ),
    );
  }
}
