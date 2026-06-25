import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../generated/app_localizations.dart';
import '../data/storage_root.dart';
import '../data/storage_scanner.dart';

enum _SortField { name, size, date }

class StorageCategoryScreen extends ConsumerStatefulWidget {
  const StorageCategoryScreen({super.key, required this.category, this.bucket});

  final StorageCategory category;

  /// Pre-computed from a prior whole-device scan (passed via route `extra`);
  /// null when this screen is reached directly (e.g. deep link) and a fresh
  /// scan is required.
  final CategoryBucket? bucket;

  @override
  ConsumerState<StorageCategoryScreen> createState() =>
      _StorageCategoryScreenState();
}

class _StorageCategoryScreenState extends ConsumerState<StorageCategoryScreen> {
  List<ScannedFile> _files = const [];
  bool _loading = false;
  String _query = '';
  _SortField _sortField = _SortField.size;
  bool _sortAscending = false;
  final Set<String> _selection = {};

  bool get _selectionMode => _selection.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final bucket = widget.bucket;
    if (bucket != null) {
      _files = List.of(bucket.files);
    } else {
      Future.microtask(_rescan);
    }
  }

  Future<void> _rescan() async {
    final root = await acquireStorageRootPath();
    if (root == null) return;
    setState(() => _loading = true);
    CategoryBucket? found;
    await for (final progress in ref.read(storageScannerProvider).scan(root)) {
      if (progress.done) found = progress.report?.buckets[widget.category];
    }
    if (!mounted) return;
    setState(() {
      _files = found == null ? const [] : List.of(found.files);
      _loading = false;
    });
  }

  List<ScannedFile> get _visibleFiles {
    var files = _files;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      files = files
          .where((f) => p.basename(f.path).toLowerCase().contains(q))
          .toList();
    }
    final sorted = List.of(files);
    sorted.sort((a, b) {
      final cmp = switch (_sortField) {
        _SortField.name =>
          p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase()),
        _SortField.size => a.size.compareTo(b.size),
        _SortField.date => a.modifiedMs.compareTo(b.modifiedMs),
      };
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  void _toggleSelection(String path) {
    HapticFeedback.selectionClick();
    setState(() {
      _selection.contains(path)
          ? _selection.remove(path)
          : _selection.add(path);
    });
  }

  void _open(ScannedFile file) {
    if (_selectionMode) {
      _toggleSelection(file.path);
      return;
    }
    final ext = p.extension(file.path).toLowerCase();
    if (AppConstants.pdfExtensions.contains(ext)) {
      final uri = Uri(queryParameters: {'path': file.path});
      context.push('${Routes.reader}?${uri.query}');
      return;
    }
    if (AppConstants.archiveExtensions.contains(ext)) {
      final uri = Uri(queryParameters: {'path': file.path});
      context.push('${Routes.archive}?${uri.query}');
      return;
    }
    OpenFile.open(file.path);
  }

  Future<void> _share() async {
    final paths = _selection.toList();
    await Share.shareXFiles(paths.map(XFile.new).toList());
  }

  Future<void> _copyPath() async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _selection.single));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
    setState(() => _selection.clear());
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final path = _selection.single;
    final controller = TextEditingController(text: p.basename(path));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameFile),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final result = await ref
        .read(fileManagerRepositoryProvider)
        .rename(path, name);
    result.fold((failure) => _showMessage(failure.message), (_) {
      setState(() {
        _files = _files.where((f) => f.path != path).toList();
        _selection.clear();
      });
    });
  }

  Future<void> _move() async {
    final destination = await FilePicker.platform.getDirectoryPath();
    if (destination == null) return;
    final paths = _selection.toList();
    final result = await ref
        .read(fileManagerRepositoryProvider)
        .move(paths, destination);
    result.fold((failure) => _showMessage(failure.message), (_) {
      setState(() {
        _files = _files.where((f) => !paths.contains(f.path)).toList();
        _selection.clear();
      });
    });
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final paths = _selection.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm(paths.length)),
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
    final result = await ref.read(fileManagerRepositoryProvider).delete(paths);
    result.fold((failure) => _showMessage(failure.message), (_) {
      setState(() {
        _files = _files.where((f) => !paths.contains(f.path)).toList();
        _selection.clear();
      });
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _promptSearch() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _query);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.searchFiles),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (query == null) return;
    setState(() => _query = query);
  }

  String _categoryLabel(AppLocalizations l10n) => switch (widget.category) {
    StorageCategory.images => l10n.categoryImages,
    StorageCategory.videos => l10n.categoryVideos,
    StorageCategory.audio => l10n.categoryAudio,
    StorageCategory.documents => l10n.categoryDocuments,
    StorageCategory.apks => l10n.categoryApks,
    StorageCategory.archives => l10n.categoryArchives,
    StorageCategory.downloads => l10n.categoryDownloads,
    StorageCategory.hidden => l10n.categoryHidden,
    StorageCategory.largeFiles => l10n.categoryLargeFiles,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final files = _visibleFiles;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selection.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          title: _selectionMode
              ? Text(l10n.itemsSelected(_selection.length))
              : Text(_categoryLabel(l10n)),
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selection.clear),
                )
              : null,
          actions: _selectionMode
              ? [
                  IconButton(
                    tooltip: l10n.share,
                    icon: const Icon(Icons.share),
                    onPressed: _share,
                  ),
                  IconButton(
                    tooltip: l10n.moveTo,
                    icon: const Icon(Icons.drive_file_move),
                    onPressed: _move,
                  ),
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete),
                    onPressed: _delete,
                  ),
                  if (_selection.length == 1) ...[
                    IconButton(
                      tooltip: l10n.rename,
                      icon: const Icon(Icons.drive_file_rename_outline),
                      onPressed: _rename,
                    ),
                    IconButton(
                      tooltip: l10n.copyPath,
                      icon: const Icon(Icons.copy),
                      onPressed: _copyPath,
                    ),
                  ],
                ]
              : [
                  IconButton(
                    tooltip: l10n.search,
                    icon: const Icon(Icons.search),
                    onPressed: _promptSearch,
                  ),
                  PopupMenuButton<_SortField>(
                    onSelected: (field) => setState(() {
                      _sortAscending = _sortField == field
                          ? !_sortAscending
                          : true;
                      _sortField = field;
                    }),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _SortField.name,
                        child: Text(l10n.sortByName),
                      ),
                      PopupMenuItem(
                        value: _SortField.size,
                        child: Text(l10n.sortBySize),
                      ),
                      PopupMenuItem(
                        value: _SortField.date,
                        child: Text(l10n.sortByDate),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: l10n.rescan,
                    icon: const Icon(Icons.refresh),
                    onPressed: _loading ? null : _rescan,
                  ),
                ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : files.isEmpty
            ? Center(child: Text(l10n.noFilesInCategory))
            : ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  final selected = _selection.contains(file.path);
                  return ListTile(
                    selected: selected,
                    leading: CircleAvatar(
                      child: Icon(widget.category.icon, size: 18),
                    ),
                    title: Text(
                      p.basename(file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${formatBytes(file.size)} · ${p.dirname(file.path)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: selected ? const Icon(Icons.check_circle) : null,
                    onTap: () => _open(file),
                    onLongPress: () => _toggleSelection(file.path),
                  );
                },
              ),
      ),
    );
  }
}
