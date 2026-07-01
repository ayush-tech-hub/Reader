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

/// Rotate all pages of a PDF by a selected angle.
class PdfRotateScreen extends StatefulWidget {
  const PdfRotateScreen({super.key});

  @override
  State<PdfRotateScreen> createState() => _PdfRotateScreenState();
}

class _PdfRotateScreenState extends State<PdfRotateScreen> {
  String? _path;
  PdfDocument? _doc;
  bool _loading = false;
  bool _processing = false;
  String? _savedPath;
  String? _error;

  int _rotation = 90; // degrees: 90, 180, 270

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

  Future<void> _rotate() async {
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
      final radians = _rotation * 3.141592653589793 / 180.0;

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

        final srcW = rendered.width.toDouble();
        final srcH = rendered.height.toDouble();

        // For 90/270° rotation, swap dimensions
        final rotated = _rotation == 90 || _rotation == 270;
        final outW = rotated ? srcH : srcW;
        final outH = rotated ? srcW : srcH;

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

        canvas.translate(outW / 2, outH / 2);
        canvas.rotate(radians);
        canvas.translate(-srcW / 2, -srcH / 2);
        canvas.drawImage(img, Offset.zero, Paint());

        final picture = recorder.endRecording();
        final rotImg = await picture.toImage(outW.toInt(), outH.toInt());
        final byteData =
            await rotImg.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        // Output page format matches rotated dimensions
        final pageW = rotated ? page.height : page.width;
        final pageH = rotated ? page.width : page.height;

        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat(pageW, pageH),
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
          '${p.basenameWithoutExtension(path)}_rotated${_rotation}.pdf';
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
      appBar: AppBar(title: const Text('Rotate PDF Pages')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _loading || _processing ? null : _pickPdf,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(_path == null
                  ? 'Choose PDF…'
                  : p.basename(_path!)),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            if (_doc != null) ...[
              const SizedBox(height: 4),
              Text('${_doc!.pages.length} page(s)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
            const SizedBox(height: 20),

            // Rotation picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rotation angle',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: 90,
                            label: Text('90°'),
                            icon: Icon(Icons.rotate_right)),
                        ButtonSegment(
                            value: 180,
                            label: Text('180°'),
                            icon: Icon(Icons.rotate_90_degrees_cw)),
                        ButtonSegment(
                            value: 270,
                            label: Text('270°'),
                            icon: Icon(Icons.rotate_left)),
                      ],
                      selected: {_rotation},
                      onSelectionChanged: (s) =>
                          setState(() => _rotation = s.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _doc != null && !_processing ? _rotate : null,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rotate_right),
              label: Text(_processing
                  ? 'Rotating…'
                  : 'Rotate All Pages $_rotation°'),
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
