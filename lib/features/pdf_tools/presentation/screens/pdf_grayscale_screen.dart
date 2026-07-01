import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

/// Converts a colour PDF to greyscale.
///
/// Each page is rendered via pdfrx, desaturated with a ColorMatrix on a
/// dart:ui Canvas, then re-packed into a new PDF using the `pdf` package.
/// The greyscale conversion uses the luminance formula:
///   Y = 0.299R + 0.587G + 0.114B
class PdfGrayscaleScreen extends StatefulWidget {
  const PdfGrayscaleScreen({super.key});

  @override
  State<PdfGrayscaleScreen> createState() => _PdfGrayscaleScreenState();
}

class _PdfGrayscaleScreenState extends State<PdfGrayscaleScreen> {
  String? _path;
  PdfDocument? _doc;
  bool _loading = false;
  bool _processing = false;
  String? _savedPath;
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
      _savedPath = null;
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

  Future<void> _convert() async {
    final doc = _doc;
    final path = _path;
    if (doc == null || path == null) return;

    setState(() {
      _processing = true;
      _savedPath = null;
      _error = null;
    });
    try {
      final pdfDoc = pw.Document();

      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        const targetW = 1000.0;
        final scale = targetW / page.width;

        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
        );
        if (rendered == null) {
          throw Exception('Failed to render page ${page.pageNumber}');
        }

        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          rendered.pixels,
          rendered.width,
          rendered.height,
          ui.PixelFormat.rgba8888,
          completer.complete,
        );
        final img = await completer.future;

        final w = rendered.width.toDouble();
        final h = rendered.height.toDouble();

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

        // Luminance desaturation matrix
        // [ R' ]   [ 0.299  0.587  0.114  0  0 ] [ R ]
        // [ G' ] = [ 0.299  0.587  0.114  0  0 ] [ G ]
        // [ B' ]   [ 0.299  0.587  0.114  0  0 ] [ B ]
        // [ A' ]   [ 0      0      0      1  0 ] [ A ]
        const grayMatrix = <double>[
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0,     0,     0,     1, 0,
        ];
        canvas.drawImage(
          img,
          Offset.zero,
          Paint()
            ..colorFilter = const ui.ColorFilter.matrix(grayMatrix),
        );

        final picture = recorder.endRecording();
        final grayImg = await picture.toImage(w.toInt(), h.toInt());
        final byteData =
            await grayImg.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            pw.MemoryImage(bytes),
            fit: pw.BoxFit.fill,
          ),
        ));
      }

      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      final outName =
          '${p.basenameWithoutExtension(path)}_grayscale.pdf';
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
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Greyscale')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _loading || _processing ? null : _pickPdf,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(_path == null ? 'Choose PDF…' : p.basename(_path!)),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            if (_doc != null) ...[
              const SizedBox(height: 4),
              Text('${_doc!.pages.length} page(s)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Colour swatch → grey swatch illustration
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.green, Colors.blue],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF555), Color(0xFFBBB)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Converts every page to greyscale using the '
                        'standard luminance formula (Rec. 601).',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _doc != null && !_processing ? _convert : null,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.invert_colors),
              label: Text(_processing ? 'Converting…' : 'Convert to Greyscale'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_savedPath != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved: ${p.basename(_savedPath!)}',
                      style: const TextStyle(color: Colors.green),
                    ),
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
