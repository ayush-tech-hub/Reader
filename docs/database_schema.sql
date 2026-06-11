-- OpenDocs Manager — SQLite schema (database: opendocs.db)
-- Mirrored by lib/core/database/app_database.dart (schema version 1).

PRAGMA foreign_keys = ON;

-- Reading history for the PDF reader.
CREATE TABLE IF NOT EXISTS recent_documents (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  path            TEXT    NOT NULL UNIQUE,
  name            TEXT    NOT NULL,
  last_page       INTEGER NOT NULL DEFAULT 1,
  total_pages     INTEGER NOT NULL DEFAULT 0,
  zoom            REAL    NOT NULL DEFAULT 1.0,
  pinned          INTEGER NOT NULL DEFAULT 0,          -- bool
  last_opened_at  INTEGER NOT NULL                      -- epoch millis
);
CREATE INDEX IF NOT EXISTS idx_recent_documents_opened
  ON recent_documents (last_opened_at DESC);

-- User bookmarks (distinct from the PDF's own outline/ToC).
CREATE TABLE IF NOT EXISTS bookmarks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  document_path   TEXT    NOT NULL,
  page            INTEGER NOT NULL,
  label           TEXT    NOT NULL DEFAULT '',
  created_at      INTEGER NOT NULL,
  UNIQUE (document_path, page)
);
CREATE INDEX IF NOT EXISTS idx_bookmarks_document
  ON bookmarks (document_path);

-- Annotations are stored app-side and rendered as an overlay.
-- type: highlight | underline | strikeout | ink | note
-- geometry: JSON — for text markup a list of page-space rects
--   [{"l":..,"t":..,"r":..,"b":..}, ...]; for ink a list of strokes
--   [[{"x":..,"y":..}, ...], ...]. Coordinates in PDF page points.
CREATE TABLE IF NOT EXISTS annotations (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  document_path   TEXT    NOT NULL,
  page            INTEGER NOT NULL,
  type            TEXT    NOT NULL,
  color           INTEGER NOT NULL,                     -- ARGB
  opacity         REAL    NOT NULL DEFAULT 1.0,
  stroke_width    REAL    NOT NULL DEFAULT 2.0,
  geometry        TEXT    NOT NULL,
  note            TEXT    NOT NULL DEFAULT '',
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_annotations_document_page
  ON annotations (document_path, page);

-- File-manager favorites (files or folders).
CREATE TABLE IF NOT EXISTS favorites (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  path            TEXT    NOT NULL UNIQUE,
  name            TEXT    NOT NULL,
  is_directory    INTEGER NOT NULL DEFAULT 0,           -- bool
  added_at        INTEGER NOT NULL
);

-- File-manager access history.
CREATE TABLE IF NOT EXISTS recent_files (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  path            TEXT    NOT NULL UNIQUE,
  name            TEXT    NOT NULL,
  accessed_at     INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_recent_files_accessed
  ON recent_files (accessed_at DESC);

-- Durable ledger for background compression/extraction jobs.
-- type: create | extract     status: queued | running | done | failed | cancelled
-- format: zip | sevenZ | tar | gzip
CREATE TABLE IF NOT EXISTS archive_jobs (
  id              TEXT    PRIMARY KEY,                  -- UUID
  type            TEXT    NOT NULL,
  format          TEXT    NOT NULL,
  archive_path    TEXT    NOT NULL,
  target_path     TEXT    NOT NULL,
  status          TEXT    NOT NULL DEFAULT 'queued',
  progress        REAL    NOT NULL DEFAULT 0.0,         -- 0..1
  error           TEXT,
  created_at      INTEGER NOT NULL,
  completed_at    INTEGER
);

-- App-wide key/value settings (theme mode, view mode, sort order,
-- show_hidden, reader page mode, ...).
CREATE TABLE IF NOT EXISTS app_settings (
  key             TEXT PRIMARY KEY,
  value           TEXT NOT NULL
);

-- ===== v2 =================================================================

-- File tagging.
CREATE TABLE IF NOT EXISTS tags (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT    NOT NULL UNIQUE,
  color INTEGER NOT NULL DEFAULT 0xFF1565C0
);
CREATE TABLE IF NOT EXISTS file_tags (
  file_path TEXT    NOT NULL,
  tag_id    INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (file_path, tag_id)
);

-- Full-text index over per-page PDF text (and OCR output); powers
-- smart search, semantic reranking and the local document assistant.
CREATE VIRTUAL TABLE IF NOT EXISTS doc_index USING fts5(
  path UNINDEXED, page UNINDEXED, content
);
CREATE TABLE IF NOT EXISTS indexed_documents (
  path        TEXT PRIMARY KEY,
  modified_at INTEGER NOT NULL,   -- source mtime for incremental reindex
  indexed_at  INTEGER NOT NULL,
  pages       INTEGER NOT NULL
);

-- One-way folder mirror pairs.
CREATE TABLE IF NOT EXISTS sync_pairs (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  source          TEXT    NOT NULL,
  destination     TEXT    NOT NULL,
  delete_orphans  INTEGER NOT NULL DEFAULT 0,
  last_synced_at  INTEGER
);
