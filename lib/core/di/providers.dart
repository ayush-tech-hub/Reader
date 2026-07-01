import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ai/data/ml_engines.dart';
import '../../features/archive_manager/data/datasources/archive_engine.dart';
import '../../features/archive_manager/data/datasources/archive_jobs_datasource.dart';
import '../../features/archive_manager/data/datasources/dart_archive_engine.dart';
import '../../features/archive_manager/data/datasources/native_archive_engine.dart';
import '../../features/archive_manager/data/repositories/archive_repository_impl.dart';
import '../../features/archive_manager/domain/repositories/archive_repository.dart';
import '../../features/file_manager/data/datasources/file_manager_local_datasource.dart';
import '../../features/file_manager/data/datasources/file_system_datasource.dart';
import '../../features/file_manager/data/repositories/file_manager_repository_impl.dart';
import '../../features/file_manager/domain/repositories/file_manager_repository.dart';
import '../../features/file_manager/domain/usecases/file_usecases.dart';
import '../../features/files_plus/data/file_tools_service.dart';
import '../../features/files_plus/data/storage_scanner.dart';
import '../../features/files_plus/data/tags_datasource.dart';
import '../../features/library/data/document_index_service.dart';
import '../../features/reading_stats/data/reading_stats_service.dart';
import '../../features/pdf_reader/data/datasources/reader_local_datasource.dart';
import '../../features/pdf_reader/data/repositories/pdf_reader_repository_impl.dart';
import '../../features/pdf_reader/domain/repositories/pdf_reader_repository.dart';
import '../../features/pdf_reader/domain/usecases/reader_usecases.dart';
import '../../features/pdf_tools/data/datasources/pdf_tools_engine.dart';
import '../../features/pdf_tools/data/repositories/pdf_tools_repository_impl.dart';
import '../../features/pdf_tools/domain/repositories/pdf_tools_repository.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';

/// Composition root. Tests swap implementations via ProviderScope
/// overrides — nothing below is reachable any other way.

// ---- Infrastructure --------------------------------------------------

/// Overridden in main() with the opened database.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// Overridden in main() with whether the onboarding intro has already
/// been completed (read once from shared_preferences at boot).
final onboardingCompleteProvider = Provider<bool>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

// ---- PDF reader ------------------------------------------------------

final readerLocalDataSourceProvider = Provider<ReaderLocalDataSource>(
  (ref) => ReaderLocalDataSource(ref.watch(appDatabaseProvider)),
);

final pdfReaderRepositoryProvider = Provider<PdfReaderRepository>(
  (ref) => PdfReaderRepositoryImpl(ref.watch(readerLocalDataSourceProvider)),
);

final getRecentDocumentsProvider = Provider<GetRecentDocuments>(
  (ref) => GetRecentDocuments(ref.watch(pdfReaderRepositoryProvider)),
);

final saveReadingPositionProvider = Provider<SaveReadingPosition>(
  (ref) => SaveReadingPosition(ref.watch(pdfReaderRepositoryProvider)),
);

final toggleBookmarkProvider = Provider<ToggleBookmark>(
  (ref) => ToggleBookmark(ref.watch(pdfReaderRepositoryProvider)),
);

// ---- File manager ----------------------------------------------------

final fileSystemDataSourceProvider = Provider<FileSystemDataSource>(
  (ref) => FileSystemDataSource(),
);

final fileManagerLocalDataSourceProvider = Provider<FileManagerLocalDataSource>(
  (ref) => FileManagerLocalDataSource(ref.watch(appDatabaseProvider)),
);

final fileManagerRepositoryProvider = Provider<FileManagerRepository>(
  (ref) => FileManagerRepositoryImpl(
    ref.watch(fileSystemDataSourceProvider),
    ref.watch(fileManagerLocalDataSourceProvider),
  ),
);

final listDirectoryProvider = Provider<ListDirectory>(
  (ref) => ListDirectory(ref.watch(fileManagerRepositoryProvider)),
);

// ---- Archive manager ---------------------------------------------------

final archiveEngineProvider = Provider<ArchiveEngine>((ref) {
  // Native engine on mobile; pure-Dart fallback elsewhere (dev/tests).
  if (Platform.isAndroid || Platform.isIOS) return NativeArchiveEngine();
  final engine = DartArchiveEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final archiveJobsDataSourceProvider = Provider<ArchiveJobsDataSource>(
  (ref) => ArchiveJobsDataSource(ref.watch(appDatabaseProvider)),
);

final archiveRepositoryProvider = Provider<ArchiveRepository>(
  (ref) => ArchiveRepositoryImpl(
    ref.watch(archiveEngineProvider),
    ref.watch(archiveJobsDataSourceProvider),
  ),
);

// ---- PDF tools ---------------------------------------------------------

final pdfToolsEngineProvider = Provider<PdfToolsEngine>(
  (ref) => PdfToolsEngine(),
);

final pdfToolsRepositoryProvider = Provider<PdfToolsRepository>(
  (ref) => PdfToolsRepositoryImpl(ref.watch(pdfToolsEngineProvider)),
);

// ---- Library, file intelligence & on-device AI ------------------------

final documentIndexServiceProvider = Provider<DocumentIndexService>(
  (ref) => DocumentIndexService(ref.watch(appDatabaseProvider)),
);

final readingStatsServiceProvider = Provider<ReadingStatsService>(
  (ref) => ReadingStatsService(ref.watch(appDatabaseProvider)),
);

final fileToolsServiceProvider = Provider<FileToolsService>(
  (ref) => const FileToolsService(),
);

final tagsDataSourceProvider = Provider<TagsDataSource>(
  (ref) => TagsDataSource(ref.watch(appDatabaseProvider)),
);

final storageScannerProvider = Provider<StorageScanner>(
  (ref) => const StorageScanner(),
);

final ocrEngineProvider = Provider<OcrEngine>((ref) => OcrEngine());

final translateEngineProvider = Provider<TranslateEngine>(
  (ref) => TranslateEngine(),
);

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

// ---- Settings ------------------------------------------------------------

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(SettingKeys.themeMode);
    if (stored != null) {
      state = ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingKeys.themeMode, mode.name);
  }
}

// ---- Accessibility -------------------------------------------------------

final highContrastProvider = NotifierProvider<HighContrastNotifier, bool>(
  HighContrastNotifier.new,
);

class HighContrastNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(SettingKeys.highContrast) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingKeys.highContrast, state);
  }
}

/// Allowed discrete font-scale factors.
const kFontScales = [0.85, 1.0, 1.15, 1.3, 1.5];

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

class FontScaleNotifier extends Notifier<double> {
  @override
  double build() {
    _load();
    return 1.0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(SettingKeys.fontScale) ?? 1.0;
  }

  Future<void> setScale(double scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(SettingKeys.fontScale, scale);
  }
}
