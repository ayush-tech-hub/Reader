import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

/// Adds a diagonal text watermark to every page of a PDF.
///
/// Approach:
///   1. Render each page to an image via pdfrx
///   2. Draw the watermark text on a dart:ui Canvas
///   3. Re-encode the composite as PNG
///   4. Build a new PDF from the page images using the `pdf` package
class PdfWatermarkScreen extends StatefulWidget {
  const PdfWatermarkScreen({super.key});

  @override
  State<PdfWatermarkScreen> createState() => _PdfWatermarkScreenState();
}

class _PdfWatermarkScreenState extends State<PdfWatermarkScreen> {
  final _textCtrl = TextEditingController(text: 'CONFIDENTIAL');
  String? _path;
  PdfDocument? _doc;
  bool _loading = false;
  bool _processing = false;
  String? _savedPath;
  String? _error;
  double _opacity = 0.25;
  bool _diagonal = true;
  Color _color = Colors.red;

  static const _colors = [
    (Colors.red, 'Red'),
    (Colors.grey, 'Grey'),
    (Colors.blue, 'Blue'),
    (Colors.green, 'Green'),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
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
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter watermark text first')),
      );
      return;
    }
    setState(() {
      _processing = true;
      _savedPath = null;
      _error = null;
    });
    try {
      final pdfDoc = pw.Document();
      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final pageBytes = await _renderWithWatermark(page, text);
        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            pw.MemoryImage(pageBytes),
            fit: pw.BoxFit.fill,
          ),
        ));
      }

      // Save output
      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      final outName = '${p.basenameWithoutExtension(path)}_watermarked.pdf';
      final outPath = '${dir.path}/$outName';
      await File(outPath).writeAsBytes(await pdfDoc.save());
      if (mounted) setState(() => _savedPath = outPath);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<Uint8List> _renderWithWatermark(PdfPage page, String text) async {
    const targetW = 1000.0;
    final scale = targetW / page.width;
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
    );
    if (rendered == null) {
      throw Exception('Failed to render page ${page.pageNumber}');
    }

    // Decode pixels to ui.Image
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

    // Draw the original page
    canvas.drawImage(img, Offset.zero, Paint());

    // Build watermark text as a paragraph
    final fontSize = w * 0.09;
    final paraBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
    ))
      ..pushStyle(ui.TextStyle(
        color: _color.withOpacity(_opacity),
        fontSize: fontSize,
        fontWeight: ui.FontWeight.bold,
      ))
      ..addText(text);
    final para = paraBuilder.build()
      ..layout(ui.ParagraphConstraints(width: w));

    // Draw at centre, optionally rotated
    canvas.save();
    canvas.translate(w / 2, h / 2);
    if (_diagonal) canvas.rotate(-pi / 4);
    canvas.drawParagraph(para, Offset(-para.maxIntrinsicWidth / 2, -fontSize / 2));
    canvas.restore();

    // Encode to PNG
    final picture = recorder.endRecording();
    final uiImg = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Watermark')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pick PDF
          OutlinedButton.icon(
            onPressed: _loading || _processing ? null : _pickPdf,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_path == null
                ? 'Choose PDF…'
                : p.basename(_path!)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_doc != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_doc!.pages.length} page(s)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),

          // Watermark text
          TextField(
            controller: _textCtrl,
            decoration: const InputDecoration(
              labelText: 'Watermark text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Opacity slider
          Row(
            children: [
              const SizedBox(width: 8),
              const Text('Opacity'),
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.05,
                  max: 0.8,
                  divisions: 15,
                  label: '${(_opacity * 100).round()}%',
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              Text('${(_opacity * 100).round()}%',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
            ],
          ),

          // Diagonal toggle
          SwitchListTile(
            title: const Text('Diagonal angle (45°)'),
            value: _diagonal,
            onChanged: (v) => setState(() => _diagonal = v),
            contentPadding: EdgeInsets.zero,
          ),

          // Color picker
          Row(
            children: [
              const SizedBox(width: 8),
              const Text('Colour:'),
              const SizedBox(width: 12),
              for (final (color, _) in _colors)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply button
          FilledButton.icon(
            onPressed: _doc != null && !_processing ? _apply : null,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.water_drop_outlined),
            label: Text(_processing ? 'Processing…' : 'Apply Watermark'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
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
