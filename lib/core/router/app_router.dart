import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_screen.dart';
import '../../features/annotations/presentation/annotations_export_screen.dart';
import '../../features/theme_picker/presentation/theme_picker_screen.dart';
import '../../features/bookmarks/presentation/bookmarks_screen.dart';
import '../../features/dictionary/presentation/dictionary_screen.dart';
import '../../features/reading_goals/presentation/reading_goals_screen.dart';
import '../../features/file_info/presentation/file_info_screen.dart';
import '../../features/batch_rename/presentation/batch_rename_screen.dart';
import '../../features/clipboard_history/presentation/clipboard_history_screen.dart';
import '../../features/speed_reader/presentation/speed_reader_screen.dart';
import '../../features/markdown_editor/presentation/markdown_editor_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_text_extract_screen.dart';
import '../../features/reading_notes/presentation/reading_notes_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_add_pages_screen.dart';
import '../../features/reading_stats/presentation/reading_stats_screen.dart';
import '../../features/workspace/presentation/workspace_screen.dart';
import '../../features/about/presentation/privacy_policy_screen.dart';
import '../../features/accessibility/presentation/accessibility_screen.dart';
import '../../features/ai/presentation/ai_tools_screen.dart';
import '../../features/document_compare/presentation/document_compare_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_to_images_screen.dart';
import '../../features/image_enhance/presentation/image_enhance_screen.dart';
import '../../features/invoice_scan/presentation/invoice_scan_screen.dart';
import '../../features/secure_folder/presentation/secure_folder_screen.dart';
import '../../features/ai/presentation/screens/language_pack_manager_screen.dart';
import '../../features/app_lock/presentation/app_lock_settings_screen.dart';
import '../../features/archive_manager/presentation/screens/archive_screen.dart';
import '../../features/barcode/presentation/qr_scanner_screen.dart';
import '../../features/file_manager/presentation/screens/favorites_screen.dart';
import '../../features/file_manager/presentation/screens/file_browser_screen.dart';
import '../../features/files_plus/data/storage_scanner.dart';
import '../../features/files_plus/presentation/file_tools_screens.dart';
import '../../features/files_plus/presentation/storage_analyzer_screen.dart';
import '../../features/files_plus/presentation/storage_category_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/smart_search_screen.dart';
import '../../features/recycle_bin/presentation/recycle_bin_screen.dart';
import '../../features/ocr/domain/entities/ocr_result.dart';
import '../../features/ocr/presentation/screens/batch_ocr_screen.dart';
import '../../features/ocr/presentation/screens/camera_ocr_screen.dart';
import '../../features/ocr/presentation/screens/image_ocr_screen.dart';
import '../../features/ocr/presentation/screens/ocr_history_screen.dart';
import '../../features/ocr/presentation/screens/ocr_result_screen.dart';
import '../../features/ocr/presentation/screens/searchable_pdf_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/pdf_reader/presentation/screens/reader_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_sign_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_tools_screen.dart';
import '../../features/readers/presentation/reader_screens.dart';
import '../../features/text_stats/presentation/text_stats_screen.dart';
import '../../features/citation/presentation/citation_screen.dart';
import '../../features/cloud/presentation/cloud_screen.dart';
import '../../features/markdown_editor/presentation/templates_screen.dart';
import '../../features/file_info/presentation/file_hash_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_watermark_screen.dart';
import '../di/providers.dart';

abstract final class Routes {
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String about = '/about';
  static const String browser = '/browser';
  static const String favorites = '/favorites';
  static const String reader = '/reader';
  static const String splitReader = '/reader/split';
  static const String archive = '/archive';
  static const String pdfTools = '/pdf-tools';
  static const String aiTools = '/tools/ai';
  static const String languagePacks = '/tools/ai/languages';
  static const String smartSearch = '/tools/search';
  static const String duplicates = '/tools/duplicates';
  static const String storageAnalyzer = '/tools/storage';
  static const String storageCategory = '/tools/storage/category';
  static const String batchTools = '/tools/batch';
  static const String folderSync = '/tools/sync';
  static const String tags = '/tools/tags';
  static const String pluginView = '/plugin-view';
  static const String privacyPolicy = '/about/privacy';
  static const String imageOcr = '/ocr/image';
  static const String cameraOcr = '/ocr/camera';
  static const String ocrResult = '/ocr/result';
  static const String ocrHistory = '/ocr/history';
  static const String batchOcr = '/ocr/batch';
  static const String searchablePdf = '/ocr/searchable-pdf';
  static const String qrScanner = '/tools/qr';
  static const String appLockSettings = '/settings/app-lock';
  static const String accessibility = '/settings/accessibility';
  static const String documentCompare = '/tools/compare';
  static const String pdfToImages = '/tools/pdf-to-images';
  static const String secureFolder = '/files/vault';
  static const String imageEnhance = '/tools/image-enhance';
  static const String invoiceScan = '/tools/invoice-scan';
  static const String pdfSign = '/tools/pdf-sign';
  static const String recycleBin = '/files/trash';
  static const String txtReader = '/reader/txt';
  static const String imageReader = '/reader/image';
  static const String dictionary = '/tools/dictionary';
  static const String pdfAddPages = '/tools/pdf-add-pages';
  static const String readingStats = '/stats';
  static const String workspace = '/workspace';
  static const String bookmarks = '/bookmarks';
  static const String readingGoals = '/goals';
  static const String annotationsExport = '/annotations';
  static const String themePicker = '/settings/theme';
  static const String readingNotes = '/notes';
  static const String pdfTextExtract = '/tools/pdf-text';
  static const String fileInfo = '/tools/file-info';
  static const String markdownEditor = '/editor/markdown';
  static const String batchRename = '/tools/batch-rename';
  static const String clipboardHistory = '/clipboard';
  static const String speedReader = '/reader/speed';
  static const String textStats = '/tools/text-stats';
  static const String citation = '/tools/citation';
  static const String cloud = '/cloud';
  static const String templates = '/editor/templates';
  static const String fileHash = '/tools/file-hash';
  static const String pdfWatermark = '/tools/pdf-watermark';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ref.watch(onboardingCompleteProvider);
  return GoRouter(
    initialLocation: onboardingDone ? Routes.home : Routes.onboarding,
    // Surface routing errors as a Scaffold rather than a blank screen.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Navigation error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                state.error?.toString() ?? 'Unknown routing error',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) =>
            OnboardingScreen(onDone: () => context.go(Routes.home)),
      ),
      GoRoute(
        path: Routes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: Routes.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: Routes.browser,
        builder: (context, state) =>
            FileBrowserScreen(initialPath: state.uri.queryParameters['path']),
      ),
      GoRoute(
        path: Routes.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: Routes.reader,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null || path.isEmpty) {
            return _missingParam(context, Routes.reader, 'path');
          }
          return ReaderScreen(path: path);
        },
      ),
      GoRoute(
        path: Routes.splitReader,
        builder: (context, state) {
          final left = state.uri.queryParameters['left'];
          final right = state.uri.queryParameters['right'];
          if (left == null || right == null) {
            return _missingParam(context, Routes.splitReader, 'left/right');
          }
          return SplitReaderScreen(leftPath: left, rightPath: right);
        },
      ),
      GoRoute(
        path: Routes.archive,
        builder: (context, state) =>
            ArchiveScreen(archivePath: state.uri.queryParameters['path']),
      ),
      GoRoute(
        path: Routes.pdfTools,
        builder: (context, state) => PdfToolsScreen(
          initialAction: state.uri.queryParameters['action'],
        ),
      ),
      GoRoute(
        path: Routes.aiTools,
        builder: (context, state) => const AiToolsScreen(),
      ),
      GoRoute(
        path: Routes.languagePacks,
        builder: (context, state) => const LanguagePackManagerScreen(),
      ),
      GoRoute(
        path: Routes.smartSearch,
        builder: (context, state) => const SmartSearchScreen(),
      ),
      GoRoute(
        path: Routes.duplicates,
        builder: (context, state) => const DuplicatesScreen(),
      ),
      GoRoute(
        path: Routes.storageAnalyzer,
        builder: (context, state) => const StorageAnalyzerScreen(),
      ),
      GoRoute(
        path: Routes.storageCategory,
        builder: (context, state) {
          final code = state.uri.queryParameters['category'];
          final category = StorageCategory.values.firstWhere(
            (c) => c.name == code,
            orElse: () => StorageCategory.largeFiles,
          );
          return StorageCategoryScreen(
            category: category,
            bucket: state.extra as CategoryBucket?,
          );
        },
      ),
      GoRoute(
        path: Routes.batchTools,
        builder: (context, state) => const BatchToolsScreen(),
      ),
      GoRoute(
        path: Routes.folderSync,
        builder: (context, state) => const FolderSyncScreen(),
      ),
      GoRoute(
        path: Routes.tags,
        builder: (context, state) => const TagsScreen(),
      ),
      GoRoute(
        path: Routes.pluginView,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null || path.isEmpty) {
            return _missingParam(context, Routes.pluginView, 'path');
          }
          return PluginViewerScreen(path: path);
        },
      ),
      GoRoute(
        path: Routes.imageOcr,
        builder: (context, state) => const ImageOcrScreen(),
      ),
      GoRoute(
        path: Routes.cameraOcr,
        builder: (context, state) => const CameraOcrScreen(),
      ),
      GoRoute(
        path: Routes.ocrResult,
        builder: (context, state) {
          final result = state.extra as OcrResult?;
          if (result == null) {
            return _missingParam(context, Routes.ocrResult, 'result');
          }
          return OcrResultScreen(result: result);
        },
      ),
      GoRoute(
        path: Routes.ocrHistory,
        builder: (context, state) => const OcrHistoryScreen(),
      ),
      GoRoute(
        path: Routes.batchOcr,
        builder: (context, state) => const BatchOcrScreen(),
      ),
      GoRoute(
        path: Routes.txtReader,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null) {
            return _missingParam(context, Routes.txtReader, 'path');
          }
          return TxtReaderScreen(path: path);
        },
      ),
      GoRoute(
        path: Routes.searchablePdf,
        builder: (context, state) => const SearchablePdfScreen(),
      ),
      GoRoute(
        path: Routes.qrScanner,
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: Routes.appLockSettings,
        builder: (context, state) => const AppLockSettingsScreen(),
      ),
      GoRoute(
        path: Routes.accessibility,
        builder: (context, state) => const AccessibilityScreen(),
      ),
      GoRoute(
        path: Routes.documentCompare,
        builder: (context, state) => const DocumentCompareScreen(),
      ),
      GoRoute(
        path: Routes.pdfToImages,
        builder: (context, state) => const PdfToImagesScreen(),
      ),
      GoRoute(
        path: Routes.secureFolder,
        builder: (context, state) => const SecureFolderScreen(),
      ),
      GoRoute(
        path: Routes.imageEnhance,
        builder: (context, state) => const ImageEnhanceScreen(),
      ),
      GoRoute(
        path: Routes.invoiceScan,
        builder: (context, state) => const InvoiceScanScreen(),
      ),
      GoRoute(
        path: Routes.pdfSign,
        builder: (context, state) => const PdfSignScreen(),
      ),
      GoRoute(
        path: Routes.recycleBin,
        builder: (context, state) => const RecycleBinScreen(),
      ),
      GoRoute(
        path: Routes.imageReader,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null) {
            return _missingParam(context, Routes.imageReader, 'path');
          }
          return ImageViewerScreen(path: path);
        },
      ),
      GoRoute(
        path: Routes.dictionary,
        builder: (context, state) => const DictionaryScreen(),
      ),
      GoRoute(
        path: Routes.pdfAddPages,
        builder: (context, state) => const PdfAddPagesScreen(),
      ),
      GoRoute(
        path: Routes.readingStats,
        builder: (context, state) => const ReadingStatsScreen(),
      ),
      GoRoute(
        path: Routes.workspace,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          return WorkspaceScreen(initialPath: path);
        },
      ),
      GoRoute(
        path: Routes.bookmarks,
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(
        path: Routes.readingGoals,
        builder: (context, state) => const ReadingGoalsScreen(),
      ),
      GoRoute(
        path: Routes.annotationsExport,
        builder: (context, state) => const AnnotationsExportScreen(),
      ),
      GoRoute(
        path: Routes.themePicker,
        builder: (context, state) => const ThemePickerScreen(),
      ),
      GoRoute(
        path: Routes.readingNotes,
        builder: (context, state) => const ReadingNotesScreen(),
      ),
      GoRoute(
        path: Routes.pdfTextExtract,
        builder: (context, state) => const PdfTextExtractScreen(),
      ),
      GoRoute(
        path: Routes.fileInfo,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          return FileInfoScreen(initialPath: path);
        },
      ),
      GoRoute(
        path: Routes.markdownEditor,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          return MarkdownEditorScreen(path: path);
        },
      ),
      GoRoute(
        path: Routes.batchRename,
        builder: (context, state) => const BatchRenameScreen(),
      ),
      GoRoute(
        path: Routes.clipboardHistory,
        builder: (context, state) => const ClipboardHistoryScreen(),
      ),
      GoRoute(
        path: Routes.speedReader,
        builder: (context, state) {
          final text = state.uri.queryParameters['text'];
          return SpeedReaderScreen(text: text);
        },
      ),
      GoRoute(
        path: Routes.textStats,
        builder: (context, state) {
          final text = state.uri.queryParameters['text'];
          return TextStatsScreen(initialText: text);
        },
      ),
      GoRoute(
        path: Routes.citation,
        builder: (context, state) {
          final text = state.uri.queryParameters['text'];
          return CitationExtractorScreen(initialText: text);
        },
      ),
      GoRoute(
        path: Routes.cloud,
        builder: (context, state) => const CloudStorageScreen(),
      ),
      GoRoute(
        path: Routes.templates,
        builder: (context, state) => const DocumentTemplatesScreen(),
      ),
      GoRoute(
        path: Routes.fileHash,
        builder: (context, state) => const FileHashScreen(),
      ),
      GoRoute(
        path: Routes.pdfWatermark,
        builder: (context, state) => const PdfWatermarkScreen(),
      ),
    ],
  );
});

/// Returns a Scaffold that describes the missing parameter rather than
/// crashing with a Null check operator error in release builds.
Widget _missingParam(BuildContext context, String route, String param) {
  return Scaffold(
    appBar: AppBar(title: const Text('Navigation error')),
    body: Center(
      child: Text('Route $route is missing required parameter: $param'),
    ),
  );
}
