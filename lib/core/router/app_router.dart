import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_manager/presentation/screens/archive_screen.dart';
import '../../features/file_manager/presentation/screens/file_browser_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/pdf_reader/presentation/screens/reader_screen.dart';
import '../../features/pdf_tools/presentation/screens/pdf_tools_screen.dart';

abstract final class Routes {
  static const String home = '/';
  static const String browser = '/browser';
  static const String reader = '/reader';
  static const String splitReader = '/reader/split';
  static const String archive = '/archive';
  static const String pdfTools = '/pdf-tools';
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
    ],
  );
});
