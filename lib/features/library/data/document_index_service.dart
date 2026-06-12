import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

/// Builds and queries the offline full-text index (`doc_index`, FTS5)
/// that powers smart search, cross-document semantic search and the
/// document assistant. Incremental: unchanged files are skipped.
class DocumentIndexService {
  const DocumentIndexService(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// Indexes every PDF under [rootPath]. Emits (done, total, path).
  Stream<(int done, int total, String path)> indexTree(String rootPath) async* {
    final pdfs = <File>[];
    final pending = [Directory(rootPath)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Directory) pending.add(entity);
          if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
            pdfs.add(entity);
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    var done = 0;
    for (final file in pdfs) {
      await _indexFile(file);
      done++;
      yield (done, pdfs.length, file.path);
    }
  }

  /// Indexes (or refreshes) a single PDF.
  Future<void> indexFile(String path) => _indexFile(File(path));

  Future<void> _indexFile(File file) async {
    final stat = await file.stat();
    final existing = await _db.query(
      'indexed_documents',
      where: 'path = ?',
      whereArgs: [file.path],
    );
    if (existing.isNotEmpty &&
        existing.first['modified_at'] == stat.modified.millisecondsSinceEpoch) {
      return; // unchanged
    }
    try {
      final document = await PdfDocument.openFile(file.path);
      try {
        await _db
            .delete('doc_index', where: 'path = ?', whereArgs: [file.path]);
        final batch = _db.batch();
        for (final page in document.pages) {
          final text = await page.loadText();
          final content = text.fullText.trim();
          if (content.isEmpty) continue;
          batch.insert('doc_index', {
            'path': file.path,
            'page': page.pageNumber,
            'content': content,
          });
        }
        batch.insert(
          'indexed_documents',
          {
            'path': file.path,
            'modified_at': stat.modified.millisecondsSinceEpoch,
            'indexed_at': DateTime.now().millisecondsSinceEpoch,
            'pages': document.pages.length,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await batch.commit(noResult: true);
      } finally {
        await document.dispose();
      }
    } catch (_) {
      // Encrypted/corrupt PDFs are skipped; search simply won't see them.
    }
  }

  /// Adds externally produced text (e.g. OCR output) to the index.
  Future<void> indexExternalText({
    required String path,
    required List<String> pageTexts,
  }) async {
    await _db.delete('doc_index', where: 'path = ?', whereArgs: [path]);
    final batch = _db.batch();
    for (var i = 0; i < pageTexts.length; i++) {
      if (pageTexts[i].trim().isEmpty) continue;
      batch.insert('doc_index', {
        'path': path,
        'page': i + 1,
        'content': pageTexts[i],
      });
    }
    batch.insert(
      'indexed_documents',
      {
        'path': path,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
        'indexed_at': DateTime.now().millisecondsSinceEpoch,
        'pages': pageTexts.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  /// FTS5 keyword search across all indexed documents.
  Future<List<IndexHit>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return const [];
    final sanitized = query.replaceAll('"', '""');
    final rows = await _db.rawQuery(
      '''
      SELECT path, page,
             snippet(doc_index, 2, '[', ']', '…', 12) AS snippet,
             content
      FROM doc_index WHERE doc_index MATCH ? LIMIT ?
      ''',
      ['"$sanitized"', limit],
    );
    return [
      for (final row in rows)
        IndexHit(
          path: row['path'] as String,
          page: row['page'] as int,
          snippet: row['snippet'] as String,
          content: row['content'] as String,
        ),
    ];
  }

  /// Loose candidate fetch (OR over terms) for TF-IDF reranking.
  Future<List<IndexHit>> candidates(String query, {int limit = 200}) async {
    final terms = query
        .split(RegExp(r'\W+'))
        .where((t) => t.length > 1)
        .map((t) => '"${t.replaceAll('"', '')}"')
        .toList();
    if (terms.isEmpty) return const [];
    final rows = await _db.rawQuery(
      'SELECT path, page, content FROM doc_index WHERE doc_index MATCH ? '
      'LIMIT ?',
      [terms.join(' OR '), limit],
    );
    return [
      for (final row in rows)
        IndexHit(
          path: row['path'] as String,
          page: row['page'] as int,
          snippet: '',
          content: row['content'] as String,
        ),
    ];
  }

  /// Full text of one indexed document (for summarization/assistant).
  Future<String> documentText(String path) async {
    final rows = await _db.query(
      'doc_index',
      columns: ['content'],
      where: 'path = ?',
      whereArgs: [path],
      orderBy: 'page ASC',
    );
    return rows.map((r) => r['content'] as String).join('\n');
  }
}

class IndexHit {
  const IndexHit({
    required this.path,
    required this.page,
    required this.snippet,
    required this.content,
  });

  final String path;
  final int page;
  final String snippet;
  final String content;

  String get name => p.basename(path);
}
