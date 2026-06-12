import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/plugins/document_plugin.dart';
import '../../../../core/router/app_router.dart';
import '../../../../generated/app_localizations.dart';
import '../../../files_plus/presentation/file_tools_screens.dart'
    show showAssignTagsDialog;
import '../../domain/entities/file_entry.dart';
import '../providers/file_manager_providers.dart';
import '../widgets/file_entry_tile.dart';

class FileBrowserScreen extends ConsumerStatefulWidget {
  const FileBrowserScreen({super.key, this.initialPath});

  final String? initialPath;

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null) {
      Future.microtask(
        () => ref.read(browserProvider.notifier).navigateTo(path),
      );
    }
  }

  BrowserNotifier get _notifier => ref.read(browserProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(browserProvider);

    return PopScope(
      canPop: !state.selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _notifier.clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          title: state.selectionMode
              ? Text(l10n.itemsSelected(state.selection.length))
              : Text(
                  state.currentPath.isEmpty
                      ? l10n.files
                      : p.basename(state.currentPath),
                ),
          leading: state.selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _notifier.clearSelection,
                )
              : null,
          actions: state.selectionMode
              ? [
                  IconButton(
                    tooltip: l10n.copy,
                    icon: const Icon(Icons.copy),
                    onPressed: () => _notifier.stageClipboard(isMove: false),
                  ),
                  IconButton(
                    tooltip: l10n.move,
                    icon: const Icon(Icons.drive_file_move),
                    onPressed: () => _notifier.stageClipboard(isMove: true),
                  ),
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete),
                    onPressed: _confirmDelete,
                  ),
                  if (state.selection.length == 1) ...[
                    IconButton(
                      tooltip: l10n.rename,
                      icon: const Icon(Icons.drive_file_rename_outline),
                      onPressed: _promptRename,
                    ),
                    IconButton(
                      tooltip: l10n.assignTags,
                      icon: const Icon(Icons.label_outline),
                      onPressed: () => showAssignTagsDialog(
                        context,
                        ref,
                        state.selection.single,
                      ),
                    ),
                  ],
                ]
              : [
                  IconButton(
                    tooltip: l10n.search,
                    icon: const Icon(Icons.search),
                    onPressed: _promptSearch,
                  ),
                  IconButton(
                    tooltip: state.viewMode == FileViewMode.list
                        ? l10n.gridView
                        : l10n.listView,
                    icon: Icon(
                      state.viewMode == FileViewMode.list
                          ? Icons.grid_view
                          : Icons.view_list,
                    ),
                    onPressed: () => _notifier.setViewMode(
                      state.viewMode == FileViewMode.list
                          ? FileViewMode.grid
                          : FileViewMode.list,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: _onMenuAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'sortName',
                        child: Text(l10n.sortByName),
                      ),
                      PopupMenuItem(
                        value: 'sortSize',
                        child: Text(l10n.sortBySize),
                      ),
                      PopupMenuItem(
                        value: 'sortDate',
                        child: Text(l10n.sortByDate),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        value: 'hidden',
                        checked: state.showHidden,
                        child: Text(l10n.showHiddenFiles),
                      ),
                      PopupMenuItem(
                        value: 'newFolder',
                        child: Text(l10n.newFolder),
                      ),
                    ],
                  ),
                ],
        ),
        body: Column(
          children: [
            _Breadcrumbs(
              path: state.currentPath,
              onNavigate: _notifier.navigateTo,
            ),
            Expanded(child: _buildBody(state, l10n)),
          ],
        ),
        floatingActionButton: state.clipboard != null
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.content_paste),
                label: Text(
                  l10n.pasteN(state.clipboard!.paths.length),
                ),
                onPressed: () async {
                  final failure = await _notifier.paste();
                  _showFailure(failure?.message);
                },
              )
            : null,
      ),
    );
  }

  Widget _buildBody(BrowserState state, AppLocalizations l10n) {
    final searchResults = state.searchResults;
    if (searchResults != null) {
      return _EntryListView(
        entries: searchResults,
        state: state,
        onOpen: _open,
        onToggleSelect: _notifier.toggleSelection,
      );
    }
    return state.entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
              onPressed: _notifier.retryInit,
            ),
          ],
        ),
      ),
      data: (entries) => entries.isEmpty
          ? Center(child: Text(l10n.emptyFolder))
          : RefreshIndicator(
              onRefresh: _notifier.refresh,
              child: _EntryListView(
                entries: entries,
                state: state,
                onOpen: _open,
                onToggleSelect: _notifier.toggleSelection,
              ),
            ),
    );
  }

  void _open(FileEntry entry) {
    if (ref.read(browserProvider).selectionMode) {
      _notifier.toggleSelection(entry.path);
      return;
    }
    if (entry.isDirectory) {
      _notifier.navigateTo(entry.path);
      return;
    }
    _notifier.recordAccess(entry.path);
    final uri = Uri(queryParameters: {'path': entry.path});
    if (AppConstants.pdfExtensions.contains(entry.extension)) {
      context.push('${Routes.reader}?${uri.query}');
    } else if (AppConstants.archiveExtensions.contains(entry.extension)) {
      context.push('${Routes.archive}?${uri.query}');
    } else if (PluginRegistry.instance.forPath(entry.path) != null) {
      context.push('${Routes.pluginView}?${uri.query}');
    }
  }

  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'sortName':
        await _notifier.setSort(FileSortField.name);
      case 'sortSize':
        await _notifier.setSort(FileSortField.size);
      case 'sortDate':
        await _notifier.setSort(FileSortField.date);
      case 'hidden':
        await _notifier.toggleShowHidden();
      case 'newFolder':
        await _promptNewFolder();
    }
  }

  Future<void> _promptNewFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptText(l10n.newFolder, l10n.folderName);
    if (name == null || name.isEmpty) return;
    final failure = await _notifier.createFolder(name);
    _showFailure(failure?.message);
  }

  Future<void> _promptRename() async {
    final l10n = AppLocalizations.of(context);
    final path = ref.read(browserProvider).selection.single;
    final name = await _promptText(l10n.rename, p.basename(path));
    if (name == null || name.isEmpty) return;
    final failure = await _notifier.rename(path, name);
    _notifier.clearSelection();
    _showFailure(failure?.message);
  }

  Future<void> _promptSearch() async {
    final l10n = AppLocalizations.of(context);
    final query = await _promptText(l10n.searchFiles, l10n.search);
    if (query == null) return;
    await _notifier.search(query);
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final count = ref.read(browserProvider).selection.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final failure = await _notifier.deleteSelection();
    _showFailure(failure?.message);
  }

  Future<String?> _promptText(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showFailure(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EntryListView extends StatelessWidget {
  const _EntryListView({
    required this.entries,
    required this.state,
    required this.onOpen,
    required this.onToggleSelect,
  });

  final List<FileEntry> entries;
  final BrowserState state;
  final ValueChanged<FileEntry> onOpen;
  final ValueChanged<String> onToggleSelect;

  @override
  Widget build(BuildContext context) {
    if (state.viewMode == FileViewMode.grid) {
      // Adaptive column count: more columns on tablets.
      final width = MediaQuery.sizeOf(context).width;
      final columns = (width / 140).floor().clamp(2, 8);
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return FileEntryGridTile(
            entry: entry,
            selected: state.selection.contains(entry.path),
            onTap: () => onOpen(entry),
            onLongPress: () => onToggleSelect(entry.path),
          );
        },
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return FileEntryTile(
          entry: entry,
          selected: state.selection.contains(entry.path),
          selectionMode: state.selectionMode,
          onTap: () => onOpen(entry),
          onLongPress: () => onToggleSelect(entry.path),
        );
      },
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.path, required this.onNavigate});

  final String path;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();
    final parts = p.split(path);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: parts.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 16),
        itemBuilder: (context, index) {
          final target = p.joinAll(parts.take(index + 1));
          return TextButton(
            onPressed: () => onNavigate(target),
            child: Text(parts[index] == p.separator ? '/' : parts[index]),
          );
        },
      ),
    );
  }
}
