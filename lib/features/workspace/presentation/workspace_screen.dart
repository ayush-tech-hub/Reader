import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../generated/app_localizations.dart';
import '../../pdf_reader/presentation/screens/reader_screen.dart';

/// Workspace tabs: several documents open side by side as tabs, each
/// with its own independent reader session.
final workspaceTabsProvider =
    NotifierProvider<WorkspaceTabsNotifier, List<String>>(
  WorkspaceTabsNotifier.new,
);

class WorkspaceTabsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void open(String path) {
    if (!state.contains(path)) state = [...state, path];
  }

  void close(String path) => state = state.where((tab) => tab != path).toList();
}

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key, this.initialPath});

  final String? initialPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(workspaceTabsProvider.notifier);
    final initial = initialPath;
    if (initial != null) {
      Future.microtask(() => notifier.open(initial));
    }
    final tabs = ref.watch(workspaceTabsProvider);

    Future<void> addTab() async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = picked?.files.single.path;
      if (path != null) notifier.open(path);
    }

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workspace)),
        body: Center(
          child: FilledButton.icon(
            icon: const Icon(Icons.tab),
            label: Text(l10n.openDocumentTab),
            onPressed: addTab,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.workspace),
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: addTab),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final path in tabs)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.basename(path),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => notifier.close(path),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final path in tabs) ReaderScreen(path: path)],
        ),
      ),
    );
  }
}
