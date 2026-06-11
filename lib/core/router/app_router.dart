import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/presentation/ai_tools_screen.dart';
import '../../features/archive_manager/presentation/screens/archive_screen.dart';
import '../../features/file_manager/presentation/screens/file_browser_screen.dart';
import '../../features/files_plus/presentation/file_tools_screens.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/smart_search_screen.dart';
import '../../features/pdf_reader/presentation/screens/reader_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_tools_screen.dart';
import '../../features/readers/presentation/reader_screens.dart';
import '../../features/workspace/presentation/workspace_screen.dart';

abstract final class Routes {
  static const String home = '/';
  static const String browser = '/browser';
  static const String reader = '/reader';
  static const String splitReader = '/reader/split';
  static const String archive = '/archive';
  static const String pdfTools = '/pdf-tools';
  static const String aiTools = '/tools/ai';
  static const String smartSearch = '/tools/search';
  static const String duplicates = '/tools/duplicates';
  static const String storageAnalyzer = '/tools/storage';
  static const String batchTools = '/tools/batch';
  static const String folderSync = '/tools/sync';
  static const String tags = '/tools/tags';
  static const String workspace = '/workspace';
  static const String pluginView = '/plugin-view';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.browser,
        builder: (context, state) => FileBrowserScreen(
          initialPath: state.uri.queryParameters['path'],
        ),
      ),
      GoRoute(
        path: Routes.reader,
        builder: (context, state) => ReaderScreen(
          path: state.uri.queryParameters['path']!,
        ),
      ),
      GoRoute(
        path: Routes.splitReader,
        builder: (context, state) => SplitReaderScreen(
          leftPath: state.uri.queryParameters['left']!,
          rightPath: state.uri.queryParameters['right']!,
        ),
      ),
      GoRoute(
        path: Routes.archive,
        builder: (context, state) => ArchiveScreen(
          archivePath: state.uri.queryParameters['path'],
        ),
      ),
      GoRoute(
        path: Routes.pdfTools,
        builder: (context, state) => const PdfToolsScreen(),
      ),
      GoRoute(
        path: Routes.aiTools,
        builder: (context, state) => const AiToolsScreen(),
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
        path: Routes.workspace,
        builder: (context, state) => WorkspaceScreen(
          initialPath: state.uri.queryParameters['path'],
        ),
      ),
      GoRoute(
        path: Routes.pluginView,
        builder: (context, state) => PluginViewerScreen(
          path: state.uri.queryParameters['path']!,
        ),
      ),
    ],
  );
});
