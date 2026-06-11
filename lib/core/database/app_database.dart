import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';

/// Owns the single SQLite connection. Schema is mirrored in
/// docs/database_schema.sql — update both together and bump
/// [AppConstants.databaseVersion] with a migration in [_onUpgrade].
class AppDatabase {
  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('AppDatabase.open() must be called before use');
    }
    return database;
  }

  Future<void> open({String? overridePath}) async {
    if (_db != null) return;
    final path = overridePath ??
        p.join(await getDatabasesPath(), AppConstants.databaseName);
    _db = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE recent_documents (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        path            TEXT    NOT NULL UNIQUE,
        name            TEXT    NOT NULL,
        last_page       INTEGER NOT NULL DEFAULT 1,
        total_pages     INTEGER NOT NULL DEFAULT 0,
        zoom            REAL    NOT NULL DEFAULT 1.0,
        pinned          INTEGER NOT NULL DEFAULT 0,
        last_opened_at  INTEGER NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_recent_documents_opened '
        'ON recent_documents (last_opened_at DESC)');
    batch.execute('''
      CREATE TABLE bookmarks (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path   TEXT    NOT NULL,
        page            INTEGER NOT NULL,
        label           TEXT    NOT NULL DEFAULT '',
        created_at      INTEGER NOT NULL,
        UNIQUE (document_path, page)
      )''');
    batch.execute('CREATE INDEX idx_bookmarks_document '
        'ON bookmarks (document_path)');
    batch.execute('''
      CREATE TABLE annotations (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        document_path   TEXT    NOT NULL,
        page            INTEGER NOT NULL,
        type            TEXT    NOT NULL,
        color           INTEGER NOT NULL,
        opacity         REAL    NOT NULL DEFAULT 1.0,
        stroke_width    REAL    NOT NULL DEFAULT 2.0,
        geometry        TEXT    NOT NULL,
        note            TEXT    NOT NULL DEFAULT '',
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_annotations_document_page '
        'ON annotations (document_path, page)');
    batch.execute('''
      CREATE TABLE favorites (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        path            TEXT    NOT NULL UNIQUE,
        name            TEXT    NOT NULL,
        is_directory    INTEGER NOT NULL DEFAULT 0,
        added_at        INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE recent_files (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        path            TEXT    NOT NULL UNIQUE,
        name            TEXT    NOT NULL,
        accessed_at     INTEGER NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_recent_files_accessed '
        'ON recent_files (accessed_at DESC)');
    batch.execute('''
      CREATE TABLE archive_jobs (
        id              TEXT    PRIMARY KEY,
        type            TEXT    NOT NULL,
        format          TEXT    NOT NULL,
        archive_path    TEXT    NOT NULL,
        target_path     TEXT    NOT NULL,
        status          TEXT    NOT NULL DEFAULT 'queued',
        progress        REAL    NOT NULL DEFAULT 0.0,
        error           TEXT,
        created_at      INTEGER NOT NULL,
        completed_at    INTEGER
      )''');
    batch.execute('''
      CREATE TABLE app_settings (
        key             TEXT PRIMARY KEY,
        value           TEXT NOT NULL
      )''');
    _createV2Tables(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      _createV2Tables(batch);
      await batch.commit(noResult: true);
    }
  }

  /// v2: tagging, full-text document index, folder sync pairs.
  void _createV2Tables(Batch batch) {
    batch.execute('''
      CREATE TABLE tags (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL UNIQUE,
        color INTEGER NOT NULL DEFAULT 0xFF1565C0
      )''');
    batch.execute('''
      CREATE TABLE file_tags (
        file_path TEXT    NOT NULL,
        tag_id    INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (file_path, tag_id)
      )''');
    // FTS5 ships in the bundled SQLite on both Android and iOS.
    batch.execute('''
      CREATE VIRTUAL TABLE doc_index USING fts5(
        path UNINDEXED, page UNINDEXED, content
      )''');
    batch.execute('''
      CREATE TABLE indexed_documents (
        path        TEXT PRIMARY KEY,
        modified_at INTEGER NOT NULL,
        indexed_at  INTEGER NOT NULL,
        pages       INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE sync_pairs (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        source          TEXT    NOT NULL,
        destination     TEXT    NOT NULL,
        delete_orphans  INTEGER NOT NULL DEFAULT 0,
        last_synced_at  INTEGER
      )''');
  }
}
