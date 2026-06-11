import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;

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

class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({super.key, required this.path});

  final String path;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late final Future<epub.EpubBook> _book =
      File(widget.path).readAsBytes().then(epub.EpubReader.readBook);
  int _chapterIndex = 0;

  static final _tagPattern = RegExp(r'<[^>]+>');
  static final _blockPattern =
      RegExp(r'</?(p|div|br|h[1-6]|li|tr)[^>]*>', caseSensitive: false);

  /// Basic HTML → text rendering: block tags become line breaks, the
  /// rest is stripped. Keeps the reader dependency-light and offline.
  static String htmlToText(String html) => html
      .replaceAll(_blockPattern, '\n')
      .replaceAll(_tagPattern, '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  List<epub.EpubChapter> _flatChapters(epub.EpubBook book) {
    final flat = <epub.EpubChapter>[];
    void walk(List<epub.EpubChapter>? chapters) {
      for (final chapter in chapters ?? const <epub.EpubChapter>[]) {
        flat.add(chapter);
        walk(chapter.SubChapters);
      }
    }

    walk(book.Chapters);
    return flat;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<epub.EpubBook>(
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
        final chapters = _flatChapters(book);
        final index = _chapterIndex.clamp(0, chapters.length - 1);
        final content = chapters.isEmpty
            ? ''
            : htmlToText(chapters[index].HtmlContent ?? '');
        return Scaffold(
          appBar: AppBar(
            title: Text(book.Title ?? p.basename(widget.path)),
          ),
          drawer: Drawer(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(chapters[i].Title ?? 'Chapter ${i + 1}'),
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
