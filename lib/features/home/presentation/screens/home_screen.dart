import 'package:file_picker/file_picker.dart';
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

/// Adaptive app shell: bottom NavigationBar on phones, NavigationRail on
/// tablets (>= 840dp, Material 3 expanded breakpoint).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  void _selectTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;

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

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final (icon, sel, label) in destinations)
                NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(sel),
                    label: Text(label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, sel, label) in destinations)
            NavigationDestination(
                icon: Icon(icon), selectedIcon: Icon(sel), label: label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard tab
// ---------------------------------------------------------------------------

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({required this.onSelectTab});
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _StorageOverviewCard(),
          ),
          const SizedBox(height: 20),

          // OCR Suite
          _SectionHeader('OCR Suite'),
          _HorizontalCardRow(items: [
            _CardItem(Icons.image_search, 'Image OCR', route: '/ocr/image'),
            _CardItem(Icons.picture_as_pdf, 'PDF OCR', route: Routes.pdfTools),
            _CardItem(Icons.camera_alt, 'Camera OCR', route: '/ocr/camera'),
            _CardItem(Icons.document_scanner, 'Scan Document',
                route: '/ocr/camera'),
            _CardItem(Icons.find_in_page, 'Searchable PDF',
                route: '/ocr/searchable-pdf'),
            _CardItem(Icons.history, 'OCR History', route: '/ocr/history'),
            _CardItem(Icons.dynamic_feed, 'Batch OCR', route: '/ocr/batch'),
          ]),
          const SizedBox(height: 20),

          // Readers
          _SectionHeader('Readers'),
          _HorizontalCardRow(items: [
            _CardItem(Icons.menu_book, 'PDF Reader',
                extensions: ['pdf'], routeAfterPick: Routes.reader),
            _CardItem(Icons.article, 'Document Reader',
                extensions: ['doc', 'docx', 'odt', 'rtf'],
                routeAfterPick: Routes.reader),
            _CardItem(Icons.book, 'EPUB Reader',
                extensions: ['epub'], routeAfterPick: Routes.reader),
            _CardItem(Icons.code, 'Markdown Reader',
                extensions: ['md', 'markdown'], routeAfterPick: Routes.reader),
            _CardItem(Icons.text_fields, 'Text Reader', route: '/reader/txt'),
            _CardItem(Icons.image, 'Image Viewer',
                extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
                routeAfterPick: '/reader/image'),
            _CardItem(Icons.table_chart, 'Excel Viewer',
                extensions: ['xls', 'xlsx', 'ods', 'csv'],
                routeAfterPick: Routes.reader),
            _CardItem(Icons.slideshow, 'PowerPoint Viewer',
                extensions: ['ppt', 'pptx', 'odp'],
                routeAfterPick: Routes.reader),
            _CardItem(Icons.folder_open, 'All Files', route: Routes.browser),
          ]),
          const SizedBox(height: 20),

          // PDF Tools
          _SectionHeader('PDF Tools'),
          _HorizontalCardRow(items: [
            _CardItem(Icons.edit_document, 'PDF Editor',
                route: Routes.pdfTools),
            _CardItem(Icons.merge, 'Merge PDFs', route: Routes.pdfTools),
            _CardItem(Icons.call_split, 'Split PDF', route: Routes.pdfTools),
            _CardItem(Icons.compress, 'Compress PDF', route: Routes.pdfTools),
          ]),
          const SizedBox(height: 20),

          const _PinnedFoldersSection(),
          const SizedBox(height: 20),

          // Storage shortcuts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
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
            ]),
          ),
          const SizedBox(height: 20),

          // Recent files
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.recentFilesSection,
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                    onPressed: () => onSelectTab(1), child: Text(l10n.viewAll)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _RecentFilesList(),
          ),
          const SizedBox(height: 20),

          // More tools
          _SectionHeader(l10n.moreTools),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

// ---------------------------------------------------------------------------
// Horizontal scrollable card row
// ---------------------------------------------------------------------------

/// Model for a single card in a horizontal row.
class _CardItem {
  const _CardItem(
    this.icon,
    this.label, {
    this.route,
    this.extensions,
    this.routeAfterPick,
  });

  final IconData icon;
  final String label;

  /// Direct route — navigated to immediately on tap (no file pick).
  final String? route;

  /// If set, a file-picker sheet is shown using these extensions.
  final List<String>? extensions;

  /// Route pushed as `$route?path=...` after a successful file pick.
  final String? routeAfterPick;

  bool get needsPick => extensions != null;
}

class _HorizontalCardRow extends StatelessWidget {
  const _HorizontalCardRow({required this.items});
  final List<_CardItem> items;

  Future<void> _onTap(BuildContext context, _CardItem item) async {
    if (!item.needsPick) {
      if (item.route != null) context.push(item.route!);
      return;
    }
    final picked = await _pickFile(context, item);
    if (picked != null && context.mounted) {
      final route = item.routeAfterPick ?? Routes.reader;
      final uri = Uri(queryParameters: {'path': picked});
      context.push('$route?${uri.query}');
    }
  }

  Future<String?> _pickFile(BuildContext context, _CardItem item) async {
    String? path;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _FilePickerSheet(
        icon: item.icon,
        label: item.label,
        extensions: item.extensions!,
        onPicked: (p) => path = p,
      ),
    );
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          final scheme = Theme.of(context).colorScheme;
          return Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _onTap(context, item),
              child: SizedBox(
                width: 86,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Icon(item.icon, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File-picker bottom sheet
// ---------------------------------------------------------------------------

class _FilePickerSheet extends StatelessWidget {
  const _FilePickerSheet({
    required this.icon,
    required this.label,
    required this.extensions,
    required this.onPicked,
  });
  final IconData icon;
  final String label;
  final List<String> extensions;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Pick a file to open with $label',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Pick file'),
            onPressed: () async {
              Navigator.of(context).pop();
              final r = await FilePicker.platform.pickFiles(
                  type: FileType.custom, allowedExtensions: extensions);
              final p = r?.files.single.path;
              if (p != null) onPicked(p);
            },
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shortcut card
// ---------------------------------------------------------------------------

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard(
      {required this.icon, required this.label, required this.onTap});
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

// ---------------------------------------------------------------------------
// Storage overview card
// ---------------------------------------------------------------------------

class _StorageOverviewCard extends ConsumerWidget {
  const _StorageOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ref.watch(_storageRootsProvider).when(
          loading: () => const Card(
            child: Padding(
                padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (root) {
            if (root == null) return const SizedBox.shrink();
            final used =
                (root.totalBytes - root.freeBytes).clamp(0, root.totalBytes);
            final fraction = root.totalBytes > 0 ? used / root.totalBytes : 0.0;
            return Card(
              child: InkWell(
                onTap: () => context.push(Routes.storageAnalyzer),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.storageOverview,
                          style: Theme.of(context).textTheme.titleMedium),
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
                            formatBytes(used), formatBytes(root.totalBytes)),
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
      (_) => null, (roots) => roots.isEmpty ? null : roots.first);
});

// ---------------------------------------------------------------------------
// Pinned folders section
// ---------------------------------------------------------------------------

class _PinnedFoldersSection extends ConsumerWidget {
  const _PinnedFoldersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final folders = ref
            .watch(favoritesProvider)
            .valueOrNull
            ?.where((f) => f.isDirectory)
            .toList() ??
        const [];
    if (folders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.pinnedFolders,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: folders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final folder = folders[i];
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

// ---------------------------------------------------------------------------
// Recent files
// ---------------------------------------------------------------------------

class _RecentFilesList extends ConsumerWidget {
  const _RecentFilesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(recentFilesProvider).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (files) {
            if (files.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.noRecentFiles,
                    style: Theme.of(context).textTheme.bodySmall),
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
