import 'package:flutter/material.dart';
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
  static const String pluginView = '/plugin-view';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
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
        path: Routes.browser,
        builder: (context, state) =>
            FileBrowserScreen(initialPath: state.uri.queryParameters['path']),
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
        path: Routes.pluginView,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null || path.isEmpty) {
            return _missingParam(context, Routes.pluginView, 'path');
          }
          return PluginViewerScreen(path: path);
        },
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
