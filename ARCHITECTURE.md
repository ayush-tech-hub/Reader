# OpenDocs Manager — Architecture

## 1. Layering (clean architecture)

Every feature (`pdf_reader`, `file_manager`, `archive_manager`,
`pdf_tools`) is split into three layers with a strict inward dependency
rule — presentation → domain ← data:

```
presentation/   Widgets, screens, Riverpod providers/notifiers.
                Knows nothing about data sources.
domain/         Pure Dart: entities, repository *interfaces*, use cases.
                No Flutter imports, no I/O.
data/           Repository implementations, data sources
                (SQLite, filesystem, platform channels, pdfrx engine).
```

Cross-cutting concerns live in `lib/core/`:

- `core/database/` — single SQLite database (schema below) with a thin
  typed DAO per table.
- `core/platform/` — `MethodChannel`/`EventChannel` definitions shared
  with the native side (channel names, method names, payload keys).
- `core/di/` — composition root: Riverpod providers wiring data sources
  → repositories → use cases. Tests override these providers with fakes.
- `core/error/` — `AppException` hierarchy (data layer) and `Failure`
  hierarchy (domain layer); repositories translate the former into the
  latter, and `Result<T>` (`Ok`/`Err`) carries them to presentation.
- `core/theme/`, `core/router/`, `core/utils/`.

## 2. State management & dependency injection

**Riverpod** serves both roles:

- *DI*: `Provider`s in `core/di/providers.dart` build the object graph
  lazily. Repository interfaces are the only types presentation sees;
  swapping an implementation (or mocking in tests) is a one-line
  `ProviderScope(overrides: …)`.
- *State*: `Notifier`/`AsyncNotifier` classes own screen state
  (immutable state classes with `copyWith`). Long-running native work
  (archive jobs) is exposed as a `Stream<ArchiveProgress>` from an
  `EventChannel` and surfaced via `StreamProvider`.

Flow: `Widget → ref.read(notifier) → use case → repository (interface)
→ data source → (SQLite | filesystem | platform channel | pdfrx)`.

## 3. Database schema

One SQLite database (`opendocs.db`), versioned migrations in
`core/database/app_database.dart`. Canonical DDL:
[docs/database_schema.sql](docs/database_schema.sql). Tables:

| Table | Purpose |
| --- | --- |
| `recent_documents` | reading history: last page, total pages, pin flag |
| `bookmarks` | per-document bookmarked pages with labels |
| `annotations` | highlight/underline/strikeout/ink/note; geometry stored as JSON (page-space rects or stroke points) |
| `favorites` | starred files/folders for the file manager |
| `recent_files` | file-manager access history |
| `archive_jobs` | durable job ledger so background jobs survive process death |
| `app_settings` | key/value (theme, view mode, hidden-files toggle, …) |

Annotations are stored app-side (not embedded into the PDF) and drawn
as an overlay; "flattening" them into the file is a `pdf_tools`
operation so the original document stays untouched until the user asks.

## 4. PDF rendering architecture

```
ReaderScreen ──> PdfViewer (pdfrx widget, pdfium-backed)
     │                │
     ▼                ▼
ReaderNotifier   PdfEngine (data-source interface)
     │             • open(path, password?) -> PdfDocumentHandle
     ▼             • outline()  -> List<TocItem>
PdfReaderRepository• searchText(query) -> Stream<SearchHit>
   (bookmarks,     • extractText(pageRange)
    annotations,   • pageCount / page sizes
    recents via    
    SQLite DAOs)   
```

Performance for 1000+ page documents:

- pdfium renders **per-page, on demand**; pdfrx virtualizes pages and
  keeps a small render-ahead window, so memory is O(visible pages).
- Page raster caching with downscaled previews during fast scrolls.
- Text search runs incrementally and streams hits page-by-page.
- Password-protected files: the engine retries with a
  password provider callback; the UI shows a password dialog.
- Split-screen reading: two independent `PdfViewerController`s over the
  same (shared, ref-counted) document handle.

## 5. Compression engine architecture

```
ArchiveRepository (domain interface)
        │
ArchiveRepositoryImpl ──────────────┐
        │                           │
NativeArchiveEngine            DartArchiveEngine
(MethodChannel 'opendocs/archive'   (package:archive fallback —
 + EventChannel progress stream)     zip/tar/gz only, used on
        │                            dev desktops)
   ┌────┴─────┐
Android        iOS
Kotlin:        Swift:
 • zip4j (ZIP + AES)        • ZIPFoundation (ZIP)
 • commons-compress         • libarchive via SWCompression
   (7z, tar, gzip)            (7z/tar/gz)
 • WorkManager — background • BGProcessingTask — background
   jobs, battery-aware        jobs, battery-aware
```

Key properties:

- **Streamed I/O end-to-end** (fixed 1 MiB buffers, never whole-file in
  memory) → archives larger than 10 GB work on low-RAM devices.
- **Progress**: native engines emit `{jobId, bytesDone, bytesTotal,
  currentEntry}` over the `EventChannel`; Dart exposes it as a
  `Stream<ArchiveProgress>`.
- **Background & resilience**: each job is recorded in `archive_jobs`
  before starting; WorkManager/BGTaskScheduler constraints
  (battery-not-low) make jobs battery-efficient, and the ledger lets the
  UI reconcile state after process death.
- **Cancellation**: cooperative — native loops check a cancel flag
  between buffer writes.

## 6. PDF utilities (native engine)

`PdfToolsEngine` (MethodChannel `opendocs/pdf_tools`) delegates page
surgery to native libraries — **PdfBox-Android** (Apache-2.0) on
Android, **PDFKit** on iOS: merge, split, compress (image downsampling
+ stream re-encoding), reorder/delete/rotate/extract pages, watermark,
metadata read/write. Images→PDF is pure Dart (`package:pdf`). All
operations write to a new file and never mutate the source in place.

## 7. API abstraction layer (platform channels)

All native access goes through `core/platform/native_channels.dart` —
the single source of truth for channel/method names mirrored by
`MainActivity.kt` and `AppDelegate.swift`:

| Channel | Type | Purpose |
| --- | --- | --- |
| `opendocs/archive` | Method | create/extract/cancel archive jobs |
| `opendocs/archive_progress` | Event | job progress stream |
| `opendocs/pdf_tools` | Method | merge/split/compress/rotate/… |
| `opendocs/storage` | Method | storage roots, SAF/Files-app integration |

Dart never calls `MethodChannel` directly outside `data/datasources/`;
repositories depend on engine interfaces so unit tests run without a
platform.

## 8. Testing strategy

- **Unit tests** (`test/`): use cases and repositories against mocked
  data sources (mocktail); pure utils.
- **Widget tests**: screens with provider overrides.
- **Integration tests** (`integration_test/`): app boot, navigation,
  file-manager flows on a device/emulator via `integration_test`.

## 9. CI/CD

- `ci.yml` — on every push/PR: format check, `flutter analyze`,
  unit/widget tests with coverage, debug Android build.
- `release.yml` — on version tags (`v*`): builds signed Android
  appbundle + split APKs and an iOS IPA (signing via repo secrets),
  attaches artifacts to a GitHub release.
