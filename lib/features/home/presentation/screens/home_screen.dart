import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../generated/app_localizations.dart';
import '../../../archive_manager/presentation/screens/archive_screen.dart';
import '../../../file_manager/domain/entities/file_entry.dart';
import '../../../file_manager/presentation/providers/file_manager_providers.dart';
import '../../../file_manager/presentation/screens/file_browser_screen.dart';
import '../../../files_plus/data/storage_scanner.dart';
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

  void _selectTab(int index) => setState(() => _index = index);

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
      0 => _DashboardTab(onSelectTab: _selectTab),
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
  const _DashboardTab({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);

    final quickActions = <(IconData, String, VoidCallback)>[
      (Icons.edit_document, l10n.pdfEditor, () => onSelectTab(3)),
      (Icons.folder_outlined, l10n.fileManager, () => onSelectTab(1)),
      (
        Icons.pie_chart_outline,
        l10n.storageAnalyzer,
        () => context.push(Routes.storageAnalyzer),
      ),
      (Icons.compress, l10n.compressPdfAction, () => onSelectTab(3)),
    ];

    final moreTools = <(IconData, String, String)>[
      (Icons.auto_awesome, l10n.aiAssistant, Routes.aiTools),
      (Icons.manage_search, l10n.smartSearch, Routes.smartSearch),
      (Icons.copy_all, l10n.duplicateFinder, Routes.duplicates),
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
            icon: Icon(switch (themeMode) {
              ThemeMode.light => Icons.light_mode,
              ThemeMode.dark => Icons.dark_mode,
              ThemeMode.system => Icons.brightness_auto,
            }),
            onPressed: () {
              final next = switch (themeMode) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              };
              ref.read(themeModeProvider.notifier).setMode(next);
            },
          ),
          IconButton(
            tooltip: l10n.about,
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(Routes.about),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StorageOverviewCard(),
          const SizedBox(height: 20),
          Text(
            l10n.quickActions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: [
              for (final (icon, label, onTap) in quickActions)
                _QuickActionCard(icon: icon, label: label, onTap: onTap),
            ],
          ),
          const SizedBox(height: 20),
          const _PinnedFoldersSection(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.layers_outlined,
                  label: l10n.largeFilesShortcut,
                  onTap: () => context.push(
                    '${Routes.storageCategory}?category=${StorageCategory.largeFiles.name}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.download_outlined,
                  label: l10n.downloadsShortcut,
                  onTap: () => context.push(
                    '${Routes.storageCategory}?category=${StorageCategory.downloads.name}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentFilesSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => onSelectTab(1),
                child: Text(l10n.viewAll),
              ),
            ],
          ),
          const _RecentFilesList(),
          const SizedBox(height: 20),
          Text(l10n.moreTools, style: Theme.of(context).textTheme.titleMedium),
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
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageOverviewCard extends ConsumerWidget {
  const _StorageOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rootsAsync = ref.watch(_storageRootsProvider);

    return rootsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (error, _) => const SizedBox.shrink(),
      data: (root) {
        if (root == null) return const SizedBox.shrink();
        final used = (root.totalBytes - root.freeBytes).clamp(
          0,
          root.totalBytes,
        );
        final fraction = root.totalBytes > 0 ? used / root.totalBytes : 0.0;
        return Card(
          child: InkWell(
            onTap: () => context.push(Routes.storageAnalyzer),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.storageOverview,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 10,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.usedOfTotal(
                      formatBytes(used),
                      formatBytes(root.totalBytes),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final _storageRootsProvider = FutureProvider.autoDispose((ref) async {
  final result =
      await ref.watch(fileManagerRepositoryProvider).getStorageRoots();
  return result.fold(
    (_) => null,
    (roots) => roots.isEmpty ? null : roots.first,
  );
});

class _PinnedFoldersSection extends ConsumerWidget {
  const _PinnedFoldersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favoritesAsync = ref.watch(favoritesProvider);
    final folders =
        favoritesAsync.valueOrNull?.where((f) => f.isDirectory).toList() ??
            const [];
    if (folders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.pinnedFolders,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: folders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ActionChip(
                avatar: const Icon(Icons.folder, size: 18),
                label: Text(folder.name),
                onPressed: () {
                  final uri = Uri(queryParameters: {'path': folder.path});
                  context.push('${Routes.browser}?${uri.query}');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentFilesList extends ConsumerWidget {
  const _RecentFilesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recentAsync = ref.watch(recentFilesProvider);

    return recentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => const SizedBox.shrink(),
      data: (files) {
        if (files.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.noRecentFiles,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return Column(
          children: [
            for (final file in files.take(5)) _RecentFileTile(file: file),
          ],
        );
      },
    );
  }
}

class _RecentFileTile extends StatelessWidget {
  const _RecentFileTile({required this.file});

  final FileEntry file;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatBytes(file.size)),
        onTap: () {
          final uri = Uri(queryParameters: {'path': file.path});
          if (AppConstants.pdfExtensions.contains(file.extension)) {
            context.push('${Routes.reader}?${uri.query}');
          } else if (AppConstants.archiveExtensions.contains(file.extension)) {
            context.push('${Routes.archive}?${uri.query}');
          } else {
            OpenFile.open(file.path);
          }
        },
      ),
    );
  }
}
