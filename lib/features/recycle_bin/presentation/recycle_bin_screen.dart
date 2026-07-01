import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/byte_formatter.dart';
import '../data/recycle_bin_service.dart';

/// Lists the contents of the app recycle bin with restore /
/// permanent-delete / empty-bin actions.
class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final _service = RecycleBinService();
  List<TrashItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.getItems();
    items.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _restore(TrashItem item) async {
    try {
      await _service.restore(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored "${item.name}"')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(TrashItem item) async {
    final confirmed = await _confirmDelete(
      'Delete "${item.name}" permanently?',
      'This cannot be undone.',
    );
    if (!confirmed) return;
    await _service.deletePermanently(item);
    await _load();
  }

  Future<void> _emptyTrash() async {
    final items = _items;
    if (items == null || items.isEmpty) return;
    final confirmed = await _confirmDelete(
      'Empty recycle bin?',
      '${items.length} item${items.length == 1 ? '' : 's'} will be permanently deleted.',
    );
    if (!confirmed) return;
    await _service.emptyTrash();
    await _load();
  }

  Future<bool> _confirmDelete(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle bin'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Empty bin',
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 80,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Recycle bin is empty',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleted files are kept here for 30 days\n'
                        'before being permanently removed.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _TrashItemTile(
                      item: item,
                      onRestore: () => _restore(item),
                      onDelete: () => _deleteItem(item),
                    );
                  },
                ),
    );
  }
}

class _TrashItemTile extends StatelessWidget {
  const _TrashItemTile({
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  final TrashItem item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ago = _timeAgo(item.trashedAt);
    final size = item.isDirectory ? null : _fileSize(item.trashPath);

    return ListTile(
      leading: Icon(
        item.isDirectory
            ? Icons.folder_outlined
            : Icons.insert_drive_file_outlined,
        color: scheme.primary,
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        size != null ? 'Deleted $ago · $size' : 'Deleted $ago',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: 'Delete permanently',
            icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  String _fileSize(String path) {
    try {
      return formatBytes(File(path).lengthSync());
    } catch (_) {
      return '';
    }
  }
}
