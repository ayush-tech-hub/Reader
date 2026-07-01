import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Reader for FictionBook 2 (.fb2) ebooks.
///
/// FB2 is an XML-based format popular in Russia and Eastern Europe.
/// Files may be gzip-compressed (.fb2.zip / .fbz); this reader
/// handles both the raw and zipped variants transparently.
///
/// Parsing:
///   - Book title from <book-title>
///   - Author from <author> > <first-name> / <last-name>
///   - Chapters: each top-level <section> in <body>
///   - Text: all <p>, <subtitle>, and <title> elements within a section
class Fb2ReaderScreen extends StatefulWidget {
  const Fb2ReaderScreen({super.key, required this.path});
  final String path;

  @override
  State<Fb2ReaderScreen> createState() => _Fb2ReaderScreenState();
}

class _Fb2ReaderScreenState extends State<Fb2ReaderScreen> {
  late final Future<_Fb2Book> _book = _parse(widget.path);
  int _chapter = 0;

  static Future<_Fb2Book> _parse(String filePath) async {
    var bytes = await File(filePath).readAsBytes();

    // Detect and decompress zip wrapper (.fb2.zip / .fbz)
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final fb2Entry = archive.files.firstWhere(
        (f) => f.name.toLowerCase().endsWith('.fb2'),
        orElse: () => archive.files.first,
      );
      bytes = Uint8List.fromList(fb2Entry.content as List<int>);
    }

    // Decode: prefer UTF-8 with BOM stripping, fall back to windows-1251
    String xml;
    try {
      xml = utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      xml = latin1.decode(bytes);
    }
    // Strip UTF-8 BOM if present
    if (xml.startsWith('﻿')) xml = xml.substring(1);

    final doc = XmlDocument.parse(xml);

    // Book title & author
    final titleEl = doc.findAllElements('book-title').firstOrNull;
    final bookTitle = titleEl?.innerText.trim() ?? '';

    final authorEls = doc.findAllElements('author');
    final author = authorEls.map((a) {
      final first = a.findElements('first-name').firstOrNull?.innerText ?? '';
      final last = a.findElements('last-name').firstOrNull?.innerText ?? '';
      return '$first $last'.trim();
    }).where((s) => s.isNotEmpty).join(', ');

    // Chapters: top-level <section> elements inside <body>
    final body = doc.findAllElements('body').firstOrNull;
    final sections = body?.childElements
        .where((e) => e.name.local == 'section')
        .toList() ?? [];

    List<_Chapter> chapters;
    if (sections.isEmpty) {
      // Flat structure: treat body as a single chapter
      final text = _bodyText(body);
      chapters = [_Chapter(title: bookTitle.isEmpty ? 'Book' : bookTitle,
          text: text)];
    } else {
      chapters = sections.map(_sectionToChapter).toList();
    }

    return _Fb2Book(title: bookTitle, author: author, chapters: chapters);
  }

  static _Chapter _sectionToChapter(XmlElement section) {
    // Chapter title: first <title> child
    final titleEl = section.childElements
        .where((e) => e.name.local == 'title')
        .firstOrNull;
    final title = titleEl?.findAllElements('p')
        .map((e) => e.innerText)
        .join(' ')
        .trim() ?? '';

    final buf = StringBuffer();
    for (final el in section.childElements) {
      if (el.name.local == 'title') continue; // already used
      buf.write(_elementText(el));
    }
    return _Chapter(title: title, text: buf.toString().trim());
  }

  static String _bodyText(XmlElement? el) {
    if (el == null) return '';
    final buf = StringBuffer();
    for (final child in el.childElements) {
      buf.write(_elementText(child));
    }
    return buf.toString().trim();
  }

  static String _elementText(XmlElement el) {
    final local = el.name.local;
    switch (local) {
      case 'p':
        return '${el.innerText.trim()}\n\n';
      case 'empty-line':
        return '\n';
      case 'v': // verse line
        return '${el.innerText.trim()}\n';
      case 'stanza':
        final lines = el.childElements
            .map(_elementText)
            .join('');
        return '$lines\n';
      case 'poem':
        return _blockText(el);
      case 'cite':
        return _blockText(el);
      case 'subtitle':
        return '— ${el.innerText.trim()} —\n\n';
      case 'title':
        final text = el.findAllElements('p')
            .map((p) => p.innerText.trim())
            .join(' ');
        return text.isEmpty ? '' : '$text\n\n';
      case 'section':
        return _bodyText(el);
      case 'epigraph':
        return _blockText(el);
      case 'image':
        return ''; // skip embedded images
      default:
        return el.innerText.isEmpty ? '' : '${el.innerText.trim()}\n';
    }
  }

  static String _blockText(XmlElement el) {
    final buf = StringBuffer();
    for (final child in el.childElements) {
      buf.write(_elementText(child));
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Fb2Book>(
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
        final idx = _chapter.clamp(0, (book.chapters.length - 1).clamp(0, 9999));
        final chapter = book.chapters.isEmpty
            ? _Chapter(title: 'Empty', text: '')
            : book.chapters[idx];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              book.title.isEmpty ? p.basename(widget.path) : book.title,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('${idx + 1}/${book.chapters.length}'),
                ),
              ),
            ],
          ),
          // Chapter list drawer
          drawer: Drawer(
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        book.title.isEmpty ? 'Book' : book.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.author.isNotEmpty)
                        Text(book.author,
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: book.chapters.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(
                        book.chapters[i].title.isEmpty
                            ? 'Chapter ${i + 1}'
                            : book.chapters[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: i == idx,
                      onTap: () {
                        setState(() => _chapter = i);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chapter.title.isNotEmpty) ...[
                  Text(chapter.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                ],
                SelectableText(
                  chapter.text.isEmpty ? '(No text in this chapter)' : chapter.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
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
                      ? () => setState(() => _chapter = idx - 1)
                      : null,
                ),
                Text('Chapter ${idx + 1}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: idx < book.chapters.length - 1
                      ? () => setState(() => _chapter = idx + 1)
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

// ── Data classes ──────────────────────────────────────────────────────────────

class _Fb2Book {
  const _Fb2Book({
    required this.title,
    required this.author,
    required this.chapters,
  });
  final String title;
  final String author;
  final List<_Chapter> chapters;
}

class _Chapter {
  const _Chapter({required this.title, required this.text});
  final String title;
  final String text;
}
