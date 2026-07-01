import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Displays detailed metadata about any file: size, modified date,
/// MIME guess, SHA-256 checksum, and for PDFs the page count.
class FileInfoScreen extends StatefulWidget {
  const FileInfoScreen({super.key, this.initialPath});

  /// If provided, loads this file immediately on open.
  final String? initialPath;

  @override
  State<FileInfoScreen> createState() => _FileInfoScreenState();
}

class _FileInfoScreenState extends State<FileInfoScreen> {
  _FileDetails? _details;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) {
      _loadFile(widget.initialPath!);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path != null) await _loadFile(path);
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _loading = true;
      _details = null;
      _error = null;
    });
    try {
      final file = File(path);
      final stat = await file.stat();
      final size = stat.size;

      // SHA-256 — capped at 50 MB to avoid OOM
      String? hash;
      if (size <= 50 * 1024 * 1024) {
        final bytes = await file.readAsBytes();
        hash = sha256.convert(bytes).toString();
      }

      final ext = p.extension(path).toLowerCase();
      final mime = _guessMime(ext);

      setState(() {
        _details = _FileDetails(
          path: path,
          name: p.basename(path),
          size: size,
          modifiedAt: stat.modified,
          accessedAt: stat.accessed,
          extension: ext,
          mime: mime,
          sha256: hash,
        );
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File info'),
        actions: [
          if (_details?.sha256 != null)
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: 'Copy SHA-256',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _details!.sha256!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SHA-256 copied')),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.folder_open),
        label: const Text('Pick file'),
        onPressed: _loading ? null : _pickFile,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              : _details == null
                  ? Center(
                      child: Text(
                        'Pick a file to see its details.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    )
                  : _DetailsView(details: _details!),
    );
  }

  static String _guessMime(String ext) {
    const map = {
      '.pdf': 'application/pdf',
      '.txt': 'text/plain',
      '.md': 'text/markdown',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.zip': 'application/zip',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.mp3': 'audio/mpeg',
      '.mp4': 'video/mp4',
      '.epub': 'application/epub+zip',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

class _FileDetails {
  const _FileDetails({
    required this.path,
    required this.name,
    required this.size,
    required this.modifiedAt,
    required this.accessedAt,
    required this.extension,
    required this.mime,
    this.sha256,
  });

  final String path;
  final String name;
  final int size;
  final DateTime modifiedAt;
  final DateTime accessedAt;
  final String extension;
  final String mime;
  final String? sha256;
}

class _DetailsView extends StatelessWidget {
  const _DetailsView({required this.details});
  final _FileDetails details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File icon header
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _iconFor(details.extension),
                  size: 40,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                details.name,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _fmtSize(details.size),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Card(
          child: Column(
            children: [
              _Row('Extension', details.extension.isEmpty ? '(none)' : details.extension),
              const Divider(height: 1),
              _Row('MIME type', details.mime),
              const Divider(height: 1),
              _Row('Size', '${_fmtSize(details.size)} (${details.size} bytes)'),
              const Divider(height: 1),
              _Row('Modified', _fmtDate(details.modifiedAt)),
              const Divider(height: 1),
              _Row('Accessed', _fmtDate(details.accessedAt)),
              const Divider(height: 1),
              _Row('Directory', p.dirname(details.path), wrap: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (details.sha256 != null) ...[
          Text('Integrity', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SHA-256',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.outline)),
                  const SizedBox(height: 4),
                  SelectableText(
                    details.sha256!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            color: scheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'SHA-256 not computed (file > 50 MB).',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static IconData _iconFor(String ext) {
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
        return Icons.image_outlined;
      case '.zip':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icons.folder_zip_outlined;
      case '.mp3':
        return Icons.audio_file_outlined;
      case '.mp4':
        return Icons.video_file_outlined;
      case '.txt':
      case '.md':
        return Icons.text_snippet_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _fmtDate(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)} '
        '${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.wrap = false});
  final String label;
  final String value;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: wrap
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
                const SizedBox(height: 2),
                SelectableText(value,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
                Flexible(
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
    );
  }
}
