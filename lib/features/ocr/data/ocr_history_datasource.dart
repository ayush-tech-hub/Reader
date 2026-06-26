import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/entities/ocr_result.dart';

/// Local SQLite-backed storage for [OcrResult] objects.
///
/// Callers must await [init] before using any other method.  In practice this
/// is handled automatically by [ocrHistoryDatasourceProvider] in the Riverpod
/// layer.
class OcrHistoryDatasource {
  Database? _db;

  static const _dbName = 'ocr_history.db';
  static const _table = 'ocr_history';
  static const _version = 1;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Opens (or creates) the SQLite database and ensures the schema is current.
  Future<void> init() async {
    if (_db != null && _db!.isOpen) return;

    final dbPath = p.join(await getDatabasesPath(), _dbName);

    _db = await openDatabase(
      dbPath,
      version: _version,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id           TEXT    NOT NULL PRIMARY KEY,
        source_path  TEXT    NOT NULL,
        source_type  TEXT    NOT NULL,
        pages_json   TEXT    NOT NULL,
        language_code TEXT,
        created_at   INTEGER NOT NULL
      )
    ''');
  }

  Database get _database {
    assert(_db != null && _db!.isOpen,
        'OcrHistoryDatasource.init() must be awaited before use.');
    return _db!;
  }

  // ── Write operations ──────────────────────────────────────────────────────

  /// Persists [result] to the database.  Replaces any existing row with the
  /// same [OcrResult.id].
  Future<void> save(OcrResult result) async {
    await _database.insert(
      _table,
      _toRow(result),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes the row identified by [id].  No-op if the id is unknown.
  Future<void> delete(String id) async {
    await _database.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes every row in the history table.
  Future<void> clear() async {
    await _database.delete(_table);
  }

  // ── Read operations ───────────────────────────────────────────────────────

  /// Returns all stored results ordered from newest to oldest.
  Future<List<OcrResult>> getAll() async {
    final rows = await _database.query(
      _table,
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Returns the result with the given [id], or `null` if not found.
  Future<OcrResult?> getById(String id) async {
    final rows = await _database.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  // ── Row ↔ OcrResult conversion ────────────────────────────────────────────

  Map<String, dynamic> _toRow(OcrResult result) {
    return {
      'id': result.id,
      'source_path': result.sourcePath,
      'source_type': result.sourceType,
      'pages_json': jsonEncode(result.pageTexts),
      'language_code': result.languageCode,
      'created_at': result.createdAt.millisecondsSinceEpoch,
    };
  }

  OcrResult _fromRow(Map<String, dynamic> row) {
    final rawPages = row['pages_json'] as String;
    final List<dynamic> decoded = jsonDecode(rawPages) as List<dynamic>;
    final pages = decoded.map((e) => e.toString()).toList();

    return OcrResult(
      id: row['id'] as String,
      sourcePath: row['source_path'] as String,
      sourceType: row['source_type'] as String,
      pageTexts: pages,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      languageCode: row['language_code'] as String?,
    );
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
