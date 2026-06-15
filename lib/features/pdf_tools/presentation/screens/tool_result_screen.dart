import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../generated/app_localizations.dart';

/// Full-screen result shown after every PDF tool operation succeeds.
///
/// Displays file name, sizes, save location, processing time, and actions:
/// Open, Share, Rename, Delete, View Folder, Process Another.
class ToolResultScreen extends StatefulWidget {
  const ToolResultScreen({
    super.key,
    required this.outputPaths,
    required this.operationName,
    this.processingTimeMs,
    this.inputSizeBytes,
    this.outputSizeBytes,
    this.onProcessAnother,
  });

  final List<String> outputPaths;
  final String operationName;
  final int? processingTimeMs;
  final int? inputSizeBytes;
  final int? outputSizeBytes;
  final VoidCallback? onProcessAnother;

  @override
  State<ToolResultScreen> createState() => _ToolResultScreenState();
}

class _ToolResultScreenState extends State<ToolResultScreen> {
  late List<String> _paths;

  @override
  void initState() {
    super.initState();
    _paths = List.of(widget.outputPaths);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.outputCreated),
        actions: [
          if (_paths.length == 1)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: l10n.shareFile,
              onPressed: () => _share(_paths.first),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Success banner
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: colorScheme.onPrimaryContainer, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.outputCreated,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.processingTimeMs != null)
                          Text(
                            l10n.processingTime(widget.processingTimeMs!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Size info (single file only)
          if (widget.inputSizeBytes != null &&
              widget.outputSizeBytes != null &&
              _paths.length == 1)
            _SizeInfoCard(
              input: widget.inputSizeBytes!,
              output: widget.outputSizeBytes!,
            ),

          const SizedBox(height: 12),

          // Output file(s)
          ..._paths.asMap().entries.map(
                (entry) => _FileCard(
                  path: entry.value,
                  onRename: (newPath) =>
                      setState(() => _paths[entry.key] = newPath),
                  onDelete: () => setState(() => _paths.removeAt(entry.key)),
                ),
              ),

          const SizedBox(height: 12),

          // Privacy notice
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.privacyNotice,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          if (_paths.length == 1) ...[
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.openFile),
              onPressed: () => _openFile(_paths.first),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal.icon(
              icon: const Icon(Icons.share),
              label: Text(l10n.shareFile),
              onPressed: () => _share(_paths.first),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.viewFolder),
              onPressed: () => _viewFolder(_paths.first),
            ),
          ] else ...[
            FilledButton.tonal.icon(
              icon: const Icon(Icons.share),
              label: Text(l10n.shareFile),
              onPressed: () => _shareAll(_paths),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.viewFolder),
              onPressed: () => _viewFolder(_paths.first),
            ),
          ],

          if (widget.onProcessAnother != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.processAnother),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onProcessAnother!();
              },
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _share(String path) async {
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _shareAll(List<String> paths) async {
    await Share.shareXFiles(paths.map(XFile.new).toList());
  }

  // Opens the file using the platform's default viewer via an implicit intent.
  // On Android this is usually handled by an installed PDF viewer.
  void _openFile(String path) {
    // Use a method channel to trigger ACTION_VIEW on Android.
    // Fallback: show a snackbar with the path.
    const channel = MethodChannel('opendocs/file_open');
    channel.invokeMethod<void>('open', {'path': path}).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path)),
        );
      }
    });
  }

  void _viewFolder(String filePath) {
    const channel = MethodChannel('opendocs/file_open');
    channel.invokeMethod<void>('open', {'path': p.dirname(filePath)}).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(p.dirname(filePath))),
        );
      }
    });
  }
}

class _SizeInfoCard extends StatelessWidget {
  const _SizeInfoCard({required this.input, required this.output});

  final int input;
  final int output;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saved = input - output;
    final percent = input > 0 ? (saved / input * 100).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _SizeStat(
                label: l10n.inputSize,
                bytes: input,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const Icon(Icons.arrow_forward, size: 20),
            Expanded(
              child: _SizeStat(
                label: l10n.outputSize,
                bytes: output,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (saved > 0)
              Chip(
                label: Text(l10n.savedSpace(percent)),
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
              ),
          ],
        ),
      ),
    );
  }
}

class _SizeStat extends StatelessWidget {
  const _SizeStat({
    required this.label,
    required this.bytes,
    required this.color,
  });

  final String label;
  final int bytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(
          _fmt(bytes),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.path,
    required this.onRename,
    required this.onDelete,
  });

  final String path;
  final void Function(String newPath) onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = p.basename(path);
    final dir = p.dirname(path);
    final exists = File(path).existsSync();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, size: 40),
        title: Text(name, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.saveLocation}: $dir',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            if (!exists)
              Text(
                'File not found',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        trailing: PopupMenuButton<_Action>(
          onSelected: (action) => _handle(context, action),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _Action.rename,
              child: ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(l10n.renameFile),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: _Action.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(l10n.delete),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, _Action action) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case _Action.rename:
        final controller =
            TextEditingController(text: p.basenameWithoutExtension(path));
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.renameFile),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.newFileName),
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
        if (newName != null && newName.isNotEmpty) {
          final ext = p.extension(path);
          final newPath = p.join(p.dirname(path), '$newName$ext');
          try {
            File(path).renameSync(newPath);
            onRename(newPath);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }
        }
      case _Action.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.delete),
            content: Text(l10n.deleteConfirm(1)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            File(path).deleteSync();
          } catch (_) {}
          onDelete();
        }
    }
  }
}

enum _Action { rename, delete }
