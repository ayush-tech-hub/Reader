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

/// Crops whitespace margins from PDF pages.
///
/// Uses the same render-then-repack approach as the watermark/page-numbers
/// screens.  The user sets uniform or per-side crop amounts (in points,
/// which equals pixels at 1× scale) and the app renders each page, clips
/// the specified number of pixels from each edge, then saves a new PDF.
class PdfCropScreen extends StatefulWidget {
  const PdfCropScreen({super.key});

  @override
  State<PdfCropScreen> createState() => _PdfCropScreenState();
}

class _PdfCropScreenState extends State<PdfCropScreen> {
  String? _path;
  PdfDocument? _doc;
  bool _loading = false;
  bool _processing = false;
  String? _savedPath;
  String? _error;

  bool _uniform = true;
  double _all = 36;
  double _top = 36;
  double _right = 36;
  double _bottom = 36;
  double _left = 36;

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

  Future<void> _apply() async {
    final doc = _doc;
    final path = _path;
    if (doc == null || path == null) return;

    final cropT = _uniform ? _all : _top;
    final cropR = _uniform ? _all : _right;
    final cropB = _uniform ? _all : _bottom;
    final cropL = _uniform ? _all : _left;

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

        final fullW = rendered.width.toDouble();
        final fullH = rendered.height.toDouble();

        // Convert point crop values to pixel values at current scale
        final pxT = (cropT * scale).clamp(0, fullH / 2);
        final pxR = (cropR * scale).clamp(0, fullW / 2);
        final pxB = (cropB * scale).clamp(0, fullH / 2);
        final pxL = (cropL * scale).clamp(0, fullW / 2);

        final outW = (fullW - pxL - pxR).clamp(1.0, fullW);
        final outH = (fullH - pxT - pxB).clamp(1.0, fullH);

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(
            recorder, Rect.fromLTWH(0, 0, outW, outH));
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(pxL.toDouble(), pxT.toDouble(), outW, outH),
          Rect.fromLTWH(0, 0, outW, outH),
          Paint(),
        );
        final picture = recorder.endRecording();
        final cropped =
            await picture.toImage(outW.toInt(), outH.toInt());
        final byteData =
            await cropped.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat(
              page.width - (cropL + cropR),
              page.height - (cropT + cropB)),
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
      final outName = '${p.basenameWithoutExtension(path)}_cropped.pdf';
      final outPath = '${dir.path}/$outName';
      await File(outPath).writeAsBytes(await pdfDoc.save());
      if (mounted) setState(() => _savedPath = outPath);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Widget _cropSlider(String label, double value, ValueChanged<double> onChange) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 144,
            divisions: 72,
            label: '${value.round()}pt',
            onChanged: onChange,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${value.round()}pt',
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Crop Margins')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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

          SwitchListTile(
            title: const Text('Uniform crop (all sides)'),
            value: _uniform,
            onChanged: (v) => setState(() => _uniform = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),

          if (_uniform)
            _cropSlider('All', _all,
                (v) => setState(() => _all = v))
          else ...[
            _cropSlider('Top', _top, (v) => setState(() => _top = v)),
            _cropSlider('Right', _right, (v) => setState(() => _right = v)),
            _cropSlider('Bottom', _bottom,
                (v) => setState(() => _bottom = v)),
            _cropSlider('Left', _left, (v) => setState(() => _left = v)),
          ],
          const SizedBox(height: 8),
          Text(
            '1 point ≈ 1/72 inch.  '
            'A typical 1-inch margin is 72pt.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _doc != null && !_processing ? _apply : null,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.crop),
            label: Text(_processing ? 'Processing…' : 'Crop PDF'),
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
    );
  }
}
