# OpenDocs Manager

A cross-platform (Android + iOS) document powerhouse built with Flutter:
the reading experience of a professional PDF reader combined with a full
file manager and archiver — **fully offline, no ads, no paywall, no
subscription**.

## Features

| Module | Highlights |
| --- | --- |
| **PDF Reader** | pdfium-backed rendering (fast on 1000+ pages), continuous & page-by-page modes, dark/light themes, zoom/rotate/fit-to-width, text search, bookmarks, highlight/underline/strike-through, freehand ink, notes, table of contents, recents, text extraction, password-protected PDFs, split-screen reading |
| **File Manager** | internal + external storage, search, sort (name/size/date), grid & list views, copy/move/rename/delete, new folders, multi-select, favorites, recents, hidden-files toggle |
| **Archive Manager** | create/extract ZIP, 7Z, TAR, GZIP; AES-encrypted ZIPs; streamed I/O for >10 GB archives; progress reporting; battery-efficient background jobs (WorkManager / BGTaskScheduler) |
| **PDF Utilities** | merge, split, compress, images→PDF, reorder/delete/rotate/extract pages, watermark, metadata editor |
| **UX** | Material Design 3, adaptive tablet layout, gesture navigation, localization (en/es/hi), accessibility (semantics, large-text safe) |

## Architecture at a glance

Clean architecture with the repository pattern, Riverpod for state
management and dependency injection, SQLite for persistence, and
platform channels to native Kotlin/Swift engines for heavy lifting
(archives, PDF page surgery). See [ARCHITECTURE.md](ARCHITECTURE.md)
for the full design, and [docs/database_schema.sql](docs/database_schema.sql)
for the database schema.

```
lib/
├── core/           # theme, router, database, DI, errors, utils, platform channels
├── features/
│   ├── pdf_reader/      # domain / data / presentation
│   ├── file_manager/    # domain / data / presentation
│   ├── archive_manager/ # domain / data / presentation
│   ├── pdf_tools/       # domain / data / presentation
│   └── home/            # adaptive app shell
└── l10n/           # ARB localization files
android/…/kotlin/   # native archive + PDF tools engines (Kotlin)
ios/Runner/         # native archive + PDF tools engines (Swift)
```

## Getting started

```bash
# 1. Generate the remaining platform boilerplate (gradle wrapper,
#    Runner.xcodeproj, launcher icons). Existing source files —
#    including the custom Kotlin/Swift engines — are kept.
flutter create --org com.opendocs --project-name opendocs_manager .

# 2. Fetch dependencies and generate localizations
flutter pub get
flutter gen-l10n

# 3. Run
flutter run
```

### Tests

```bash
flutter test                 # unit + widget tests
flutter test integration_test # integration tests (device/emulator required)
```

### Release builds

CI builds releases automatically (see `.github/workflows/release.yml`).
Locally:

```bash
flutter build appbundle --release          # Android (Play Store)
flutter build apk --release --split-per-abi # Android (sideload)
flutter build ipa --release                # iOS (requires signing)
```

## License

Apache-2.0
