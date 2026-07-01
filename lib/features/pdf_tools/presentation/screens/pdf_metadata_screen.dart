import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

/// Displays PDF document metadata: title, author, subject, keywords,
/// creator, producer, creation/modification dates, and page count.
class PdfMetadataScreen extends StatefulWidget {
  const PdfMetadataScreen({super.key});

  @override
  State<PdfMetadataScreen> createState() => _PdfMetadataScreenState();
}

class _PdfMetadataScreenState extends State<PdfMetadataScreen> {
  String? _path;
  PdfDocument? _doc;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _loading = true;
      _path = path;
      _error = null;
    });
    try {
      final doc = await PdfDocument.openFile(path);
      if (mounted) setState(() => _doc = doc);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Metadata')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickPdf,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(_path == null
                  ? 'Choose PDF…'
                  : p.basename(_path!)),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_doc != null) ...[
              const SizedBox(height: 16),
              Expanded(child: _MetadataView(doc: _doc!, path: _path!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataView extends StatelessWidget {
  const _MetadataView({required this.doc, required this.path});

  final PdfDocument doc;
  final String path;

  @override
  Widget build(BuildContext context) {
    final info = doc.info;
    final file = File(path);
    final fileSizeBytes = file.existsSync() ? file.lengthSync() : 0;
    final fileSizeStr = _fmtSize(fileSizeBytes);

    final rows = <(String, String?)>[
      ('File name', p.basename(path)),
      ('File size', fileSizeStr),
      ('Page count', doc.pages.length.toString()),
      ('First page size', '${doc.pages.first.width.toStringAsFixed(1)} × '
          '${doc.pages.first.height.toStringAsFixed(1)} pt'),
      if (info != null) ...[
        ('Title', info.title),
        ('Author', info.author),
        ('Subject', info.subject),
        ('Keywords', info.keywords),
        ('Creator', info.creator),
        ('Producer', info.producer),
        ('Created', info.creationDate?.toLocal().toString()),
        ('Modified', info.modDate?.toLocal().toString()),
      ],
    ];

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final (label, value) = rows[i];
        final display =
            (value == null || value.trim().isEmpty) ? '—' : value;
        final isEmpty = display == '—';
        return ListTile(
          dense: true,
          title: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: SelectableText(
            display,
            style: TextStyle(
              fontSize: 13,
              color: isEmpty
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          trailing: isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: display));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$label copied!')),
                    );
                  },
                ),
        );
      },
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
