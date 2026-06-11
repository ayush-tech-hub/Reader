import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/di/providers.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../generated/app_localizations.dart';
import '../../archive_manager/domain/entities/archive_entities.dart';
import '../data/file_tools_service.dart';
import '../data/tags_datasource.dart';

// ---- Duplicate finder ---------------------------------------------------

class DuplicatesScreen extends ConsumerStatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  ConsumerState<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends ConsumerState<DuplicatesScreen> {
  List<List<String>>? _groups;
  bool _busy = false;

  Future<void> _scan() async {
    final root = await FilePicker.platform.getDirectoryPath();
    if (root == null) return;
    setState(() => _busy = true);
    final groups =
        await ref.read(fileToolsServiceProvider).findDuplicates(root);
    if (mounted) {
      setState(() {
        _groups = groups;
        _busy = false;
      });
    }
  }

  Future<void> _delete(String path, int group) async {
    await ref.read(fileManagerRepositoryProvider).delete([path]);
    setState(() {
      _groups![group].remove(path);
      _groups!.removeWhere((g) => g.length < 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.duplicateFinder)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.search),
        label: Text(l10n.scan),
        onPressed: _busy ? null : _scan,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : groups == null
              ? Center(child: Text(l10n.scanHint))
              : groups.isEmpty
                  ? Center(child: Text(l10n.noDuplicates))
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, groupIndex) {
                        final group = groups[groupIndex];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Column(
                            children: [
                              for (final path in group)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    p.basename(path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    p.dirname(path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _delete(path, groupIndex),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ---- Storage analyzer -----------------------------------------------------

class StorageAnalyzerScreen extends ConsumerStatefulWidget {
  const StorageAnalyzerScreen({super.key});

  @override
  ConsumerState<StorageAnalyzerScreen> createState() =>
      _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState extends ConsumerState<StorageAnalyzerScreen> {
  StorageReport? _report;
  bool _busy = false;

  Future<void> _analyze() async {
    final root = await FilePicker.platform.getDirectoryPath();
    if (root == null) return;
    setState(() => _busy = true);
    final report =
        await ref.read(fileToolsServiceProvider).analyzeStorage(root);
    if (mounted) {
      setState(() {
        _report = report;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageAnalyzer)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.pie_chart),
        label: Text(l10n.scan),
        onPressed: _busy ? null : _analyze,
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : report == null
              ? Center(child: Text(l10n.scanHint))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(formatBytes(report.totalBytes)),
                        subtitle: Text('${report.fileCount} files'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.byFileType,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final entry in report.byExtension.take(10))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.category_outlined),
                        title: Text(entry.key),
                        trailing: Text(formatBytes(entry.value)),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.largestFiles,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final (path, size) in report.largestFiles)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(
                          p.basename(path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(formatBytes(size)),
                      ),
                  ],
                ),
    );
  }
}

// ---- Batch tools ---------------------------------------------------------

class BatchToolsScreen extends ConsumerStatefulWidget {
  const BatchToolsScreen({super.key});

  @override
  ConsumerState<BatchToolsScreen> createState() => _BatchToolsScreenState();
}

class _BatchToolsScreenState extends ConsumerState<BatchToolsScreen> {
  String _log = '';
  bool _busy = false;

  Future<void> _run(Future<String> Function() task) async {
    setState(() {
      _busy = true;
      _log = '';
    });
    try {
      final result = await task();
      if (mounted) setState(() => _log = result);
    } catch (e) {
      if (mounted) setState(() => _log = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Extract every archive in a chosen folder into sibling directories.
  Future<void> _batchExtract() => _run(() async {
        final dir = await FilePicker.platform.getDirectoryPath();
        if (dir == null) return '';
        final entries = await ref
            .read(fileManagerRepositoryProvider)
            .listDirectory(dir, showHidden: false);
        final archives = (entries.valueOrNull ?? [])
            .where((e) =>
                !e.isDirectory && ArchiveFormat.fromPath(e.path) != null)
            .toList();
        final repo = ref.read(archiveRepositoryProvider);
        final lines = <String>[];
        for (final archive in archives) {
          final destination =
              p.join(dir, p.basenameWithoutExtension(archive.name));
          final result = await repo.extractArchive(
            archivePath: archive.path,
            destinationDir: destination,
          );
          lines.add(result.fold(
            (failure) => '✗ ${archive.name}: ${failure.message}',
            (_) => '✓ ${archive.name}',
          ));
        }
        return lines.isEmpty ? 'No archives found' : lines.join('\n');
      });

  /// Convert every image in a chosen folder into a single PDF.
  Future<void> _batchConvert() => _run(() async {
        final dir = await FilePicker.platform.getDirectoryPath();
        if (dir == null) return '';
        final entries = await ref
            .read(fileManagerRepositoryProvider)
            .listDirectory(dir, showHidden: false);
        final images = (entries.valueOrNull ?? [])
            .where((e) => !e.isDirectory && _isImage(e.path))
            .map((e) => e.path)
            .toList()
          ..sort();
        if (images.isEmpty) return 'No images found';
        final output = p.join(dir, '${p.basename(dir)}.pdf');
        final result = await ref
            .read(pdfToolsRepositoryProvider)
            .imagesToPdf(imagePaths: images, outputPath: output);
        return result.fold((f) => f.message, (path) => '✓ $path');
      });

  Future<void> _batchRename() => _run(() async {
        final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
        final paths = picked?.paths.whereType<String>().toList();
        if (paths == null || paths.isEmpty) return '';
        if (!mounted) return '';
        final controller =
            TextEditingController(text: '{name}_{n}{ext}');
        final pattern = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).renamePattern),
            content: TextField(
              controller: controller,
              decoration:
                  const InputDecoration(helperText: '{name} {n} {ext}'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text),
                child: Text(AppLocalizations.of(context).ok),
              ),
            ],
          ),
        );
        if (pattern == null || pattern.isEmpty) return '';
        final plan = FileToolsService.planRename(paths, pattern);
        final renamed =
            await ref.read(fileToolsServiceProvider).applyRename(plan);
        return '✓ $renamed';
      });

  static bool _isImage(String path) => const {
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.bmp',
      }.contains(p.extension(path).toLowerCase());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.batchTools)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_busy) const LinearProgressIndicator(),
          ListTile(
            leading: const Icon(Icons.unarchive),
            title: Text(l10n.batchExtract),
            onTap: _busy ? null : _batchExtract,
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: Text(l10n.batchConvert),
            onTap: _busy ? null : _batchConvert,
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: Text(l10n.batchRename),
            onTap: _busy ? null : _batchRename,
          ),
          if (_log.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(_log),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Folder sync ----------------------------------------------------------

class FolderSyncScreen extends ConsumerStatefulWidget {
  const FolderSyncScreen({super.key});

  @override
  ConsumerState<FolderSyncScreen> createState() => _FolderSyncScreenState();
}

class _FolderSyncScreenState extends ConsumerState<FolderSyncScreen> {
  List<Map<String, Object?>> _pairs = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final rows = await ref
        .read(appDatabaseProvider)
        .db
        .query('sync_pairs', orderBy: 'id ASC');
    if (mounted) setState(() => _pairs = rows);
  }

  Future<void> _addPair() async {
    final source = await FilePicker.platform.getDirectoryPath();
    if (source == null) return;
    final destination = await FilePicker.platform.getDirectoryPath();
    if (destination == null) return;
    await ref.read(appDatabaseProvider).db.insert(
      'sync_pairs',
      {'source': source, 'destination': destination, 'delete_orphans': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _load();
  }

  Future<void> _sync(Map<String, Object?> pair) async {
    setState(() => _busy = true);
    final result = await ref.read(fileToolsServiceProvider).syncFolders(
          sourceDir: pair['source'] as String,
          destinationDir: pair['destination'] as String,
          deleteOrphans: (pair['delete_orphans'] as int) != 0,
        );
    await ref.read(appDatabaseProvider).db.update(
      'sync_pairs',
      {'last_synced_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [pair['id']],
    );
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('↑ ${result.copied}  ✗ ${result.deleted}')),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.folderSync)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addSyncPair),
        onPressed: _addPair,
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _pairs.length,
              itemBuilder: (context, index) {
                final pair = _pairs[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.sync),
                    title: Text(
                      p.basename(pair['source'] as String),
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      '→ ${pair['destination']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _busy ? null : () => _sync(pair),
                      child: Text(l10n.syncNow),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Tags -------------------------------------------------------------------

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  List<Tag> _tags = const [];
  Tag? _selected;
  List<String> _paths = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final tags = await ref.read(tagsDataSourceProvider).getTags();
    if (mounted) setState(() => _tags = tags);
  }

  Future<void> _select(Tag tag) async {
    final paths =
        await ref.read(tagsDataSourceProvider).getPathsWithTag(tag.id);
    if (mounted) {
      setState(() {
        _selected = tag;
        _paths = paths;
      });
    }
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).newTag),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(AppLocalizations.of(context).create),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(tagsDataSourceProvider).createTag(name.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tags)),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTag,
        child: const Icon(Icons.new_label),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: [
                for (final tag in _tags)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tag.name),
                      selected: _selected?.id == tag.id,
                      onSelected: (_) => _select(tag),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _paths.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(p.basename(_paths[index])),
                subtitle: Text(
                  p.dirname(_paths[index]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog that assigns tags to a file; used by the file browser.
Future<void> showAssignTagsDialog(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final tagsSource = ref.read(tagsDataSourceProvider);
  final tags = await tagsSource.getTags();
  final selected = await tagsSource.getFileTagIds(path);
  if (!context.mounted) return;
  final result = await showDialog<Set<int>>(
    context: context,
    builder: (context) {
      final working = {...selected};
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context).assignTags),
          content: SizedBox(
            width: double.maxFinite,
            child: tags.isEmpty
                ? Text(AppLocalizations.of(context).newTag)
                : Wrap(
                    spacing: 8,
                    children: [
                      for (final tag in tags)
                        FilterChip(
                          label: Text(tag.name),
                          selected: working.contains(tag.id),
                          onSelected: (on) => setState(() {
                            on ? working.add(tag.id) : working.remove(tag.id);
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(working),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      );
    },
  );
  if (result != null) await tagsSource.setFileTags(path, result);
}
