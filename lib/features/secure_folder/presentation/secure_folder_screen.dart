// ignore_for_file: unawaited_futures

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/byte_formatter.dart';
import '../data/secure_folder_service.dart';

/// PIN-locked vault screen. Prompts for PIN on entry, then lists/manages
/// files stored in the private on-device vault directory.
class SecureFolderScreen extends StatefulWidget {
  const SecureFolderScreen({super.key});

  @override
  State<SecureFolderScreen> createState() => _SecureFolderScreenState();
}

class _SecureFolderScreenState extends State<SecureFolderScreen> {
  final _service = SecureFolderService();

  bool _enabled = false;
  bool _unlocked = false;
  bool _loading = true;

  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final enabled = await _service.isEnabled();
    if (mounted) setState(() { _enabled = enabled; _loading = false; });
    if (enabled) _promptPin();
  }

  // ── PIN prompts ─────────────────────────────────────────────────────────────

  Future<void> _promptPin() async {
    final pin = await _showPinDialog('Enter secure folder PIN');
    if (pin == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final ok = await _service.verifyPin(pin);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      Navigator.of(context).pop();
      return;
    }
    setState(() => _unlocked = true);
    _loadFiles();
  }

  Future<void> _setupPin() async {
    final pin = await _showPinDialog('Create secure folder PIN');
    if (pin == null || pin.length < 4) return;
    final confirm = await _showPinDialog('Confirm PIN');
    if (confirm != pin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PINs do not match')));
      return;
    }
    await _service.enable(pin);
    if (mounted) setState(() { _enabled = true; _unlocked = true; });
    _loadFiles();
  }

  Future<String?> _showPinDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'PIN (4–8 digits)'),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── File operations ─────────────────────────────────────────────────────────

  Future<void> _loadFiles() async {
    final files = await _service.listFiles();
    if (mounted) setState(() => _files = files);
  }

  Future<void> _addFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      await _service.addFile(path);
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${p.basename(path)} to vault')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openFile(String path) async {
    await OpenFile.open(path);
  }

  Future<void> _restoreFile(String vaultPath) async {
    final ext = await getExternalStorageDirectoryOrDocs();
    try {
      await _service.restoreFile(vaultPath, ext);
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored to $ext')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteFile(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('"${p.basename(path)}" will be permanently removed from the vault.'),
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
    if (confirmed != true) return;
    await _service.deleteFile(path);
    await _loadFiles();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_enabled) {
      return _SetupView(onSetup: _setupPin);
    }

    if (!_unlocked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure folder'),
        actions: [
          IconButton(
            tooltip: 'Add file',
            icon: const Icon(Icons.add),
            onPressed: _addFile,
          ),
        ],
      ),
      body: _files.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 72,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('Vault is empty'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add a file'),
                    onPressed: _addFile,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final file = _files[i] as File;
                final name = p.basename(file.path);
                final size = _safeSize(file);
                return ListTile(
                  leading: Icon(
                    _iconFor(name),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: size != null ? Text(formatBytes(size)) : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'open') _openFile(file.path);
                      if (action == 'restore') _restoreFile(file.path);
                      if (action == 'delete') _deleteFile(file.path);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('Open')),
                      PopupMenuItem(value: 'restore', child: Text('Restore to storage')),
                      PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                    ],
                  ),
                  onTap: () => _openFile(file.path),
                );
              },
            ),
    );
  }

  int? _safeSize(File f) {
    try {
      return f.lengthSync();
    } catch (_) {
      return null;
    }
  }

  IconData _iconFor(String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext == '.pdf') return Icons.picture_as_pdf_outlined;
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
      return Icons.video_file_outlined;
    }
    if (['.mp3', '.wav', '.ogg', '.flac'].contains(ext)) {
      return Icons.audio_file_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

Future<String> getExternalStorageDirectoryOrDocs() async {
  try {
    final dir = await getExternalStorageDirectory();
    if (dir != null) return dir.path;
  } catch (_) {}
  final docs = await getApplicationDocumentsDirectory();
  return docs.path;
}

class _SetupView extends StatelessWidget {
  const _SetupView({required this.onSetup});
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Secure folder')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Secure folder',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Store private files in an encrypted vault '
                'protected by a separate PIN. Files moved here '
                'are hidden from the regular file browser.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open),
                label: const Text('Set up secure folder'),
                onPressed: onSetup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
