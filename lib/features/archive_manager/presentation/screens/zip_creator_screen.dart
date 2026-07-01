import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Creates a ZIP archive from one or more selected files.
class ZipCreatorScreen extends StatefulWidget {
  const ZipCreatorScreen({super.key});

  @override
  State<ZipCreatorScreen> createState() => _ZipCreatorScreenState();
}

class _ZipCreatorScreenState extends State<ZipCreatorScreen> {
  final List<File> _files = [];
  final _nameCtrl = TextEditingController(text: 'archive');
  bool _processing = false;
  String? _savedPath;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _files.addAll(result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!)));
      _savedPath = null;
      _error = null;
    });
  }

  Future<void> _create() async {
    if (_files.isEmpty) return;
    setState(() {
      _processing = true;
      _savedPath = null;
      _error = null;
    });
    try {
      final encoder = ZipFileEncoder();

      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }

      final outName = '${_nameCtrl.text.trim().isEmpty ? 'archive' : _nameCtrl.text.trim()}.zip';
      final outPath = '${dir.path}/$outName';
      encoder.create(outPath);

      for (final file in _files) {
        if (file.existsSync()) {
          encoder.addFile(file);
        }
      }
      encoder.close();

      if (mounted) setState(() => _savedPath = outPath);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalSize =
        _files.fold<int>(0, (s, f) => s + (f.existsSync() ? f.lengthSync() : 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Create ZIP Archive')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Archive name
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Archive name',
                suffixText: '.zip',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _processing ? null : _pickFiles,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add Files'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),

            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${_files.length} file(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_fmtSize(totalSize),
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(p.basename(f.path),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          f.existsSync() ? _fmtSize(f.lengthSync()) : 'Missing'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18,
                            color: Colors.red),
                        onPressed: () =>
                            setState(() => _files.removeAt(i)),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.archive_outlined,
                          size: 64,
                          color: scheme.onSurfaceVariant.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('Tap "Add Files" to select files to zip.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _files.isNotEmpty && !_processing ? _create : null,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.compress),
              label: Text(_processing ? 'Creating…' : 'Create ZIP'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_savedPath != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Saved: ${p.basename(_savedPath!)}',
                        style: const TextStyle(color: Colors.green)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () =>
                        Share.shareXFiles([XFile(_savedPath!)]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
