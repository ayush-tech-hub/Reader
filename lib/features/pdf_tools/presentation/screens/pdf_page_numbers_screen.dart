import 'dart:async';
import 'dart:io';
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

/// Adds page numbers to every page of a PDF.
///
/// Uses the same render-composite approach as [PdfWatermarkScreen]:
/// each page is rendered to a bitmap, then a page-number label is drawn
/// on a dart:ui Canvas before re-encoding to PNG and assembling a new PDF.
class PdfPageNumbersScreen extends StatefulWidget {
  const PdfPageNumbersScreen({super.key});

  @override
  State<PdfPageNumbersScreen> createState() => _PdfPageNumbersScreenState();
}

enum _PageNumPosition {
  bottomCenter('Bottom Centre'),
  bottomLeft('Bottom Left'),
  bottomRight('Bottom Right'),
  topCenter('Top Centre'),
  topLeft('Top Left'),
  topRight('Top Right');

  const _PageNumPosition(this.label);
  final String label;
}

enum _PageNumFormat {
  number('1'),
  pageN('Page 1'),
  pageNofTotal('Page 1 of N'),
  nSlashTotal('1 / N');

  const _PageNumFormat(this.preview);
  final String preview;
}

class _PdfPageNumbersScreenState extends State<PdfPageNumbersScreen> {
  String? _path;
  PdfDocument? _doc;
  bool _loading = false;
  bool _processing = false;
  String? _savedPath;
  String? _error;

  int _startNumber = 1;
  _PageNumPosition _position = _PageNumPosition.bottomCenter;
  _PageNumFormat _format = _PageNumFormat.pageNofTotal;
  double _fontSize = 12;

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

  String _labelFor(int pageIndex, int total) {
    final n = pageIndex + _startNumber;
    return switch (_format) {
      _PageNumFormat.number => '$n',
      _PageNumFormat.pageN => 'Page $n',
      _PageNumFormat.pageNofTotal => 'Page $n of $total',
      _PageNumFormat.nSlashTotal => '$n / $total',
    };
  }

  Future<void> _apply() async {
    final doc = _doc;
    final path = _path;
    if (doc == null || path == null) return;

    setState(() {
      _processing = true;
      _savedPath = null;
      _error = null;
    });
    try {
      final total = doc.pages.length;
      final pdfDoc = pw.Document();

      for (var i = 0; i < total; i++) {
        final page = doc.pages[i];
        final pageBytes = await _renderWithLabel(page, _labelFor(i, total));
        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            pw.MemoryImage(pageBytes),
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
          '${p.basenameWithoutExtension(path)}_numbered.pdf';
      final outPath = '${dir.path}/$outName';
      await File(outPath).writeAsBytes(await pdfDoc.save());
      if (mounted) setState(() => _savedPath = outPath);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<Uint8List> _renderWithLabel(PdfPage page, String label) async {
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
    final scaledFont = _fontSize * scale;
    final margin = scaledFont * 1.5;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(img, Offset.zero, Paint());

    // Build label paragraph
    final paraBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: _textAlignFor(_position),
      fontSize: scaledFont,
    ))
      ..pushStyle(ui.TextStyle(
        color: Colors.black87,
        fontSize: scaledFont,
        fontWeight: ui.FontWeight.normal,
      ))
      ..addText(label);
    final para = paraBuilder.build()
      ..layout(ui.ParagraphConstraints(width: w - margin * 2));

    final dx = _dxFor(_position, w, para.maxIntrinsicWidth, margin);
    final dy = _dyFor(_position, h, scaledFont, margin);

    canvas.drawParagraph(para, Offset(dx, dy));

    final picture = recorder.endRecording();
    final uiImg = await picture.toImage(w.toInt(), h.toInt());
    final byteData =
        await uiImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  ui.TextAlign _textAlignFor(_PageNumPosition pos) {
    if (pos == _PageNumPosition.bottomLeft ||
        pos == _PageNumPosition.topLeft) return ui.TextAlign.left;
    if (pos == _PageNumPosition.bottomRight ||
        pos == _PageNumPosition.topRight) return ui.TextAlign.right;
    return ui.TextAlign.center;
  }

  double _dxFor(
      _PageNumPosition pos, double w, double textW, double margin) {
    switch (pos) {
      case _PageNumPosition.bottomLeft:
      case _PageNumPosition.topLeft:
        return margin;
      case _PageNumPosition.bottomRight:
      case _PageNumPosition.topRight:
        return w - textW - margin;
      default:
        return (w - textW) / 2;
    }
  }

  double _dyFor(
      _PageNumPosition pos, double h, double fontSize, double margin) {
    switch (pos) {
      case _PageNumPosition.topLeft:
      case _PageNumPosition.topCenter:
      case _PageNumPosition.topRight:
        return margin;
      default:
        return h - fontSize - margin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Page Numbers')),
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
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          const SizedBox(height: 20),

          // Position
          const Text('Position',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final pos in _PageNumPosition.values)
                ChoiceChip(
                  label: Text(pos.label),
                  selected: _position == pos,
                  onSelected: (_) => setState(() => _position = pos),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Format
          const Text('Format',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final fmt in _PageNumFormat.values)
                ChoiceChip(
                  label: Text(fmt.preview),
                  selected: _format == fmt,
                  onSelected: (_) => setState(() => _format = fmt),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Starting number
          Row(
            children: [
              const Text('Start at page'),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: '$_startNumber',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) {
                      setState(() => _startNumber = n);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Font size
          Row(
            children: [
              const SizedBox(width: 4),
              const Text('Font size'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 8,
                  max: 24,
                  divisions: 16,
                  label: '${_fontSize.round()}pt',
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              Text('${_fontSize.round()}pt',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
            ],
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
                : const Icon(Icons.numbers_outlined),
            label:
                Text(_processing ? 'Processing…' : 'Add Page Numbers'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red)),
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
