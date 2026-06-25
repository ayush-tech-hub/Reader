import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../core/plugins/document_plugin.dart';

/// Registers the built-in viewers with the plugin registry. Third-party
/// plugins use exactly the same interface.
void registerBuiltInPlugins() {
  PluginRegistry.instance
    ..register(_MarkdownPlugin())
    ..register(_EpubPlugin())
    ..register(_ComicPlugin());
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

class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({super.key, required this.path});

  final String path;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late final Future<EpubBook> _book = EpubBook.open(widget.path);
  int _chapterIndex = 0;

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
                  setState(() => _chapterIndex = i);
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
                      ? () => setState(() => _chapterIndex = index - 1)
                      : null,
                ),
                Text('${index + 1} / ${chapters.length}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: index < chapters.length - 1
                      ? () => setState(() => _chapterIndex = index + 1)
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
