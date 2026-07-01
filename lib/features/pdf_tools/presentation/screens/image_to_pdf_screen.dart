import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Combines one or more images into a single PDF, one image per page.
class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<File> _images = [];
  bool _processing = false;
  String? _savedPath;
  String? _error;

  // Page size options
  static const _pageSizes = [
    ('A4', PdfPageFormat.a4),
    ('A3', PdfPageFormat.a3),
    ('Letter', PdfPageFormat.letter),
    ('Legal', PdfPageFormat.legal),
    ('Fit to image', null),
  ];

  PdfPageFormat? _pageFormat; // null = fit to image

  bool get _fitToImage => _pageFormat == null;

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _images.addAll(result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!)));
      _savedPath = null;
      _error = null;
    });
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() {
      _processing = true;
      _savedPath = null;
      _error = null;
    });
    try {
      final pdfDoc = pw.Document();

      for (final file in _images) {
        final bytes = await file.readAsBytes();
        final img = pw.MemoryImage(bytes);

        PdfPageFormat format;
        if (_fitToImage) {
          // Decode natural size — use A4 proportions scaled to image
          format = PdfPageFormat.a4;
          // We'll use fill so the image fills the page regardless
        } else {
          format = _pageFormat!;
        }

        pdfDoc.addPage(pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(img, fit: pw.BoxFit.contain),
        ));
      }

      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }

      final firstName = p.basenameWithoutExtension(_images.first.path);
      final outName = '${firstName}_images.pdf';
      final outPath = '${dir.path}/$outName';
      await File(outPath).writeAsBytes(await pdfDoc.save());
      if (mounted) setState(() => _savedPath = outPath);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Currently selected label
    final sizeLabel = _pageSizes
        .firstWhere(
          (s) => s.$2 == _pageFormat,
          orElse: () => _pageSizes.last,
        )
        .$1;

    return Scaffold(
      appBar: AppBar(title: const Text('Images to PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page size picker
            DropdownButtonFormField<String>(
              value: sizeLabel,
              decoration: const InputDecoration(
                labelText: 'Page size',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final (label, _) in _pageSizes)
                  DropdownMenuItem(value: label, child: Text(label)),
              ],
              onChanged: (label) {
                setState(() {
                  _pageFormat = _pageSizes
                      .firstWhere((s) => s.$1 == label)
                      .$2;
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _processing ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Images'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),

            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${_images.length} image(s)',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _images.length,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx--;
                      final f = _images.removeAt(oldIdx);
                      _images.insert(newIdx, f);
                    });
                  },
                  itemBuilder: (_, i) {
                    final file = _images[i];
                    return ListTile(
                      key: ValueKey(file.path),
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.file(file, fit: BoxFit.cover),
                      ),
                      title: Text(p.basename(file.path),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Page ${i + 1}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_handle, color: Colors.grey),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red),
                            onPressed: () =>
                                setState(() => _images.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 64,
                          color:
                              scheme.onSurfaceVariant.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('Tap "Add Images" to select images.\n'
                          'They will appear as pages in order.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
            FilledButton.icon(
              onPressed: _images.isNotEmpty && !_processing
                  ? _convert
                  : null,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label:
                  Text(_processing ? 'Converting…' : 'Convert to PDF'),
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
