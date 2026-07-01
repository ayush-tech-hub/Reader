import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

/// Exports each page of a PDF as a PNG image.
class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  String? _pdfPath;
  bool _busy = false;
  String _status = '';
  double _progress = 0;
  String? _outputDir;

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _pdfPath = path;
      _outputDir = null;
      _status = '';
    });
  }

  Future<void> _export() async {
    final path = _pdfPath;
    if (path == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _outputDir = null;
      _status = 'Opening PDF…';
    });

    try {
      final doc = await PdfDocument.openFile(path);
      final total = doc.pages.length;

      // Save into <downloads>/<pdf-name>-images/
      Directory base;
      try {
        final ext = await getExternalStorageDirectory();
        base = ext ?? await getApplicationDocumentsDirectory();
      } catch (_) {
        base = await getApplicationDocumentsDirectory();
      }
      final stem = p.basenameWithoutExtension(path);
      final outDir = Directory(p.join(base.path, '${stem}_images'));
      await outDir.create(recursive: true);

      for (var i = 0; i < total; i++) {
        if (!mounted) break;
        setState(() => _status = 'Rendering page ${i + 1} / $total…');
        final page = doc.pages[i];
        const dpi = 150.0;
        final scale = dpi / 72.0;
        final w = page.width * scale;
        final h = page.height * scale;
        final pdfImage = await page.render(fullWidth: w, fullHeight: h);
        if (pdfImage == null) continue;

        // Encode to PNG via dart:ui
        final codec = await ui.ImageDescriptor.raw(
          await ui.ImmutableBuffer.fromUint8List(pdfImage.pixels),
          width: pdfImage.width,
          height: pdfImage.height,
          pixelFormat: ui.PixelFormat.rgba8888,
        ).instantiateCodec();
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        frame.image.dispose();
        if (byteData == null) continue;

        final file = File(p.join(outDir.path, 'page_${(i + 1).toString().padLeft(4, '0')}.png'));
        await file.writeAsBytes(byteData.buffer.asUint8List());

        if (mounted) setState(() => _progress = (i + 1) / total);
      }
      doc.dispose();

      if (mounted) {
        setState(() {
          _busy = false;
          _outputDir = outDir.path;
          _status = 'Exported $total page${total == 1 ? '' : 's'} to:\n${outDir.path}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PDF to images')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(
                  _pdfPath == null ? 'Pick a PDF file' : p.basename(_pdfPath!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.folder_open),
                onTap: _busy ? null : _pickPdf,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Resolution: 150 DPI\nFormat: PNG (lossless)\nEach page saved as page_NNNN.png',
                      style: TextStyle(
                        color: scheme.onSecondaryContainer.withOpacity(0.8),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: const Text('Export pages as images'),
              onPressed: _pdfPath != null && !_busy ? _export : null,
            ),
            const SizedBox(height: 20),
            if (_busy) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 8),
            ],
            if (_status.isNotEmpty)
              Text(
                _status,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (_outputDir != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Open output folder'),
                onPressed: () => OpenFile.open(_outputDir!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
