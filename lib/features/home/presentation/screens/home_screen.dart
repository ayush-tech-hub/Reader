import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../generated/app_localizations.dart';
import '../../../archive_manager/presentation/screens/archive_screen.dart';
import '../../../file_manager/presentation/providers/file_manager_providers.dart';
import '../../../file_manager/presentation/screens/file_browser_screen.dart';
import '../../../pdf_reader/presentation/providers/reader_providers.dart';
import '../../../pdf_tools/presentation/screens/pdf_tools_screen.dart';

/// Adaptive app shell: bottom NavigationBar on phones, NavigationRail
/// on tablets (>= 840dp, Material 3 expanded breakpoint).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isExpanded = MediaQuery.sizeOf(context).width >= 840;

    final destinations = [
      (Icons.home_outlined, Icons.home, l10n.home),
      (Icons.folder_outlined, Icons.folder, l10n.files),
      (Icons.archive_outlined, Icons.archive, l10n.archives),
      (Icons.build_outlined, Icons.build, l10n.pdfTools),
    ];

    final body = switch (_index) {
      0 => const _DashboardTab(),
      1 => const FileBrowserScreen(),
      2 => const ArchiveScreen(),
      _ => const PdfToolsScreen(),
    };

    if (isExpanded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selectedIcon, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selectedIcon),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final (icon, selectedIcon, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recents = ref.watch(recentDocumentsProvider);
    final favorites = ref.watch(favoritesProvider);
    final recentFiles = ref.watch(recentFilesProvider);
    final themeMode = ref.watch(themeModeProvider);

    final moreTools = <(IconData, String, String)>[
      (Icons.auto_awesome, l10n.aiAssistant, Routes.aiTools),
      (Icons.manage_search, l10n.smartSearch, Routes.smartSearch),
      (Icons.tab, l10n.workspace, Routes.workspace),
      (Icons.copy_all, l10n.duplicateFinder, Routes.duplicates),
      (Icons.pie_chart_outline, l10n.storageAnalyzer, Routes.storageAnalyzer),
      (Icons.dynamic_feed, l10n.batchTools, Routes.batchTools),
      (Icons.sync, l10n.folderSync, Routes.folderSync),
      (Icons.label_outline, l10n.tags, Routes.tags),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.toggleTheme,
            icon: Icon(
              switch (themeMode) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.brightness_auto,
              },
            ),
            onPressed: () {
              final next = switch (themeMode) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              };
              ref.read(themeModeProvider.notifier).setMode(next);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentDocumentsProvider);
          ref.invalidate(favoritesProvider);
          ref.invalidate(recentFilesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.moreTools,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (icon, label, route) in moreTools)
                  ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    onPressed: () => context.push(route),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.recentDocuments,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            recents.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (docs) => docs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l10n.noRecentDocuments),
                    )
                  : Column(
                      children: [
                        for (final doc in docs.take(10))
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.picture_as_pdf),
                              title: Text(
                                doc.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                l10n.pageOfPages(
                                  doc.lastPage,
                                  doc.totalPages,
                                ),
                              ),
                              trailing: doc.pinned
                                  ? const Icon(Icons.push_pin, size: 18)
                                  : null,
                              onTap: () => context.push(
                                Uri(
                                  path: Routes.reader,
                                  queryParameters: {'path': doc.path},
                                ).toString(),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.favorites,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            favorites.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l10n.noFavorites),
                    )
                  : Column(
                      children: [
                        for (final favorite in items)
                          ListTile(
                            leading: Icon(
                              favorite.isDirectory ? Icons.folder : Icons.star,
                            ),
                            title: Text(favorite.name),
                            onTap: () => context.push(
                              Uri(
                                path: favorite.isDirectory
                                    ? Routes.browser
                                    : Routes.reader,
                                queryParameters: {'path': favorite.path},
                              ).toString(),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.recentFiles,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            recentFiles.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(error.toString()),
              data: (files) => files.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(l10n.noRecentFiles),
                    )
                  : Column(
                      children: [
                        for (final file in files.take(10))
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              final route = AppConstants.pdfExtensions
                                      .contains(file.extension)
                                  ? Routes.reader
                                  : AppConstants.archiveExtensions
                                          .contains(file.extension)
                                      ? Routes.archive
                                      : null;
                              if (route == null) return;
                              context.push(
                                Uri(
                                  path: route,
                                  queryParameters: {'path': file.path},
                                ).toString(),
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
