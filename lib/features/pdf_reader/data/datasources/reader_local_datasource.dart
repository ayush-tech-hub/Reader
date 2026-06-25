import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/reader_entities.dart';

/// SQLite access for reading history, bookmarks and annotations.
class ReaderLocalDataSource {
  const ReaderLocalDataSource(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  // ---- Recents -----------------------------------------------------

  Future<List<RecentDocument>> getRecentDocuments() async {
    final rows = await _db.query(
      'recent_documents',
      orderBy: 'pinned DESC, last_opened_at DESC',
      limit: AppConstants.maxRecentDocuments,
    );
    return rows.map(_recentFromRow).toList();
  }

  Future<void> upsertRecentDocument({
    required String path,
    required int totalPages,
  }) async {
    await _db.insert(
        'recent_documents',
        {
          'path': path,
          'name': p.basename(path),
          'total_pages': totalPages,
          'last_opened_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveReadingPosition({
    required String path,
    required int page,
    required double zoom,
  }) async {
    await _db.update(
      'recent_documents',
      {
        'last_page': page,
        'zoom': zoom,
        'last_opened_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> removeRecentDocument(String path) async {
    await _db.delete('recent_documents', where: 'path = ?', whereArgs: [path]);
  }

  // ---- Bookmarks ---------------------------------------------------

  Future<List<Bookmark>> getBookmarks(String documentPath) async {
    final rows = await _db.query(
      'bookmarks',
      where: 'document_path = ?',
      whereArgs: [documentPath],
      orderBy: 'page ASC',
    );
    return rows
        .map(
          (row) => Bookmark(
            id: row['id'] as int,
            documentPath: row['document_path'] as String,
            page: row['page'] as int,
            label: row['label'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<Bookmark> insertBookmark(Bookmark bookmark) async {
    final id = await _db.insert(
        'bookmarks',
        {
          'document_path': bookmark.documentPath,
          'page': bookmark.page,
          'label': bookmark.label,
          'created_at': bookmark.createdAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    return Bookmark(
      id: id,
      documentPath: bookmark.documentPath,
      page: bookmark.page,
      label: bookmark.label,
      createdAt: bookmark.createdAt,
    );
  }

  Future<void> deleteBookmark(int id) async {
    await _db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Annotations ---------------------------------------------------

  Future<List<Annotation>> getAnnotations(String documentPath) async {
    final rows = await _db.query(
      'annotations',
      where: 'document_path = ?',
      whereArgs: [documentPath],
      orderBy: 'page ASC, id ASC',
    );
    return rows.map(_annotationFromRow).toList();
  }

  Future<Annotation> insertAnnotation(Annotation annotation) async {
    final id = await _db.insert('annotations', _annotationToRow(annotation));
    return Annotation(
      id: id,
      documentPath: annotation.documentPath,
      page: annotation.page,
      type: annotation.type,
      color: annotation.color,
      opacity: annotation.opacity,
      strokeWidth: annotation.strokeWidth,
      rects: annotation.rects,
      strokes: annotation.strokes,
      note: annotation.note,
      createdAt: annotation.createdAt,
      updatedAt: annotation.updatedAt,
    );
  }

  Future<void> updateAnnotation(Annotation annotation) async {
    await _db.update(
      'annotations',
      _annotationToRow(annotation),
      where: 'id = ?',
      whereArgs: [annotation.id],
    );
  }

  Future<void> deleteAnnotation(int id) async {
    await _db.delete('annotations', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Mapping -------------------------------------------------------

  RecentDocument _recentFromRow(Map<String, Object?> row) => RecentDocument(
        path: row['path'] as String,
        name: row['name'] as String,
        lastPage: row['last_page'] as int,
        totalPages: row['total_pages'] as int,
        zoom: (row['zoom'] as num).toDouble(),
        pinned: (row['pinned'] as int) != 0,
        lastOpenedAt: DateTime.fromMillisecondsSinceEpoch(
          row['last_opened_at'] as int,
        ),
      );

  Map<String, Object?> _annotationToRow(Annotation a) => {
        'document_path': a.documentPath,
        'page': a.page,
        'type': a.type.name,
        'color': a.color,
        'opacity': a.opacity,
        'stroke_width': a.strokeWidth,
        'geometry': encodeGeometry(a),
        'note': a.note,
        'created_at': a.createdAt.millisecondsSinceEpoch,
        'updated_at': a.updatedAt.millisecondsSinceEpoch,
      };

  Annotation _annotationFromRow(Map<String, Object?> row) {
    final type = AnnotationType.values.byName(row['type'] as String);
    final geometry =
        jsonDecode(row['geometry'] as String) as Map<String, dynamic>;
    return Annotation(
      id: row['id'] as int,
      documentPath: row['document_path'] as String,
      page: row['page'] as int,
      type: type,
      color: row['color'] as int,
      opacity: (row['opacity'] as num).toDouble(),
      strokeWidth: (row['stroke_width'] as num).toDouble(),
      rects: decodeRects(geometry),
      strokes: decodeStrokes(geometry),
      note: row['note'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  // Geometry JSON codec — exposed static for tests.

  static String encodeGeometry(Annotation a) => jsonEncode({
        'rects': [
          for (final r in a.rects)
            {'l': r.left, 't': r.top, 'r': r.right, 'b': r.bottom},
        ],
        'strokes': [
          for (final stroke in a.strokes)
            [
              for (final point in stroke) {'x': point.x, 'y': point.y},
            ],
        ],
      });

  static List<PageRect> decodeRects(Map<String, dynamic> geometry) => [
        for (final raw in (geometry['rects'] as List<dynamic>? ?? []))
          PageRect(
            ((raw as Map<String, dynamic>)['l'] as num).toDouble(),
            (raw['t'] as num).toDouble(),
            (raw['r'] as num).toDouble(),
            (raw['b'] as num).toDouble(),
          ),
      ];

  static List<List<PagePoint>> decodeStrokes(Map<String, dynamic> geometry) => [
        for (final stroke in (geometry['strokes'] as List<dynamic>? ?? []))
          [
            for (final raw in stroke as List<dynamic>)
              PagePoint(
                ((raw as Map<String, dynamic>)['x'] as num).toDouble(),
                (raw['y'] as num).toDouble(),
              ),
          ],
      ];
}
