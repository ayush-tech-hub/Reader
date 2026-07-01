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

/// Sign a PDF: draw a signature, position it on a page, export signed PDF.
///
/// Approach: render the target page at high DPI, let the user draw a
/// signature with [_SignaturePad], then composite both into a new PDF using
/// the `pdf` Dart package.
class PdfSignScreen extends StatefulWidget {
  const PdfSignScreen({super.key});

  @override
  State<PdfSignScreen> createState() => _PdfSignScreenState();
}

class _PdfSignScreenState extends State<PdfSignScreen> {
  String? _pdfPath;
  PdfDocument? _doc;
  ui.Image? _pageImage;
  int _pageIndex = 0;
  bool _loading = false;
  bool _exporting = false;
  String? _savedPath;

  // Signature points collected from the pad.
  final List<List<Offset>> _signatureStrokes = [];
  bool _hasSig = false;

  // Signature placement on the page (normalised 0..1).
  double _sigX = 0.1;
  double _sigY = 0.8;
  double _sigW = 0.35;

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _loading = true);
    try {
      final doc = await PdfDocument.openFile(path);
      setState(() {
        _pdfPath = path;
        _doc = doc;
        _pageIndex = 0;
        _signatureStrokes.clear();
        _hasSig = false;
        _savedPath = null;
      });
      await _renderPage();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renderPage() async {
    final doc = _doc;
    if (doc == null) return;
    final page = doc.pages[_pageIndex];
    const targetW = 800.0;
    final scale = targetW / page.width;
    final img = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
    );
    if (img == null || !mounted) return;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      img.pixels,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final uiImg = await completer.future;
    if (mounted) setState(() => _pageImage = uiImg);
  }

  Future<void> _export() async {
    final src = _pdfPath;
    final doc = _doc;
    final page = _pageImage;
    if (src == null || doc == null || page == null || !_hasSig) return;

    setState(() {
      _exporting = true;
      _savedPath = null;
    });

    try {
      // Render the signature to a PNG at 300×90 px.
      final sigBytes = await _renderSignaturePng();

      // Render the original page to a PNG (already done in _pageImage).
      final pageByteData =
          await page.toByteData(format: ui.ImageByteFormat.png);
      if (pageByteData == null) throw Exception('Failed to encode page');

      // Composite page + signature into one image via dart:ui.
      final pdfPage = doc.pages[_pageIndex];
      final pageW = pdfPage.width.toDouble();
      final pageH = pdfPage.height.toDouble();

      final compositeBytes = await _composite(
        pageByteData.buffer.asUint8List(),
        page.width,
        page.height,
        sigBytes,
        sigX: _sigX,
        sigY: _sigY,
        sigW: _sigW,
      );

      final pdfDoc = pw.Document();
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageW, pageH),
          build: (_) => pw.Image(
            pw.MemoryImage(compositeBytes),
            fit: pw.BoxFit.fill,
          ),
        ),
      );

      Directory base;
      try {
        base = (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        base = await getApplicationDocumentsDirectory();
      }
      final stem = p.basenameWithoutExtension(src);
      final outPath = p.join(base.path, '${stem}_signed.pdf');
      await File(outPath).writeAsBytes(await pdfDoc.save());
      if (mounted) setState(() => _savedPath = outPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Composites the signature onto the page image at normalised coordinates.
  Future<Uint8List> _composite(
    Uint8List pageBytes,
    int pageW,
    int pageH,
    Uint8List sigBytes, {
    required double sigX,
    required double sigY,
    required double sigW,
  }) async {
    // Decode page image.
    final pageCodec = await ui.instantiateImageCodec(pageBytes);
    final pageFrame = await pageCodec.getNextFrame();
    final pageImg = pageFrame.image;

    // Decode signature image.
    final sigCodec = await ui.instantiateImageCodec(sigBytes);
    final sigFrame = await sigCodec.getNextFrame();
    final sigImg = sigFrame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(pageImg, Offset.zero, Paint());

    final sigDstW = sigW * pageW;
    final sigDstH = 0.08 * pageH;
    final sigDst = Rect.fromLTWH(
      sigX * pageW,
      sigY * pageH,
      sigDstW,
      sigDstH,
    );
    canvas.drawImageRect(
      sigImg,
      Rect.fromLTWH(0, 0, sigImg.width.toDouble(), sigImg.height.toDouble()),
      sigDst,
      Paint(),
    );

    final pic = recorder.endRecording();
    final composite = await pic.toImage(pageW, pageH);
    final bd = await composite.toByteData(format: ui.ImageByteFormat.png);
    composite.dispose();
    pageImg.dispose();
    sigImg.dispose();
    return bd!.buffer.asUint8List();
  }

  Future<Uint8List> _renderSignaturePng() async {
    const w = 300.0;
    const h = 90.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // White background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Scale strokes to fit the target dimensions.
    // We need the bounding box of all strokes to normalise them.
    final allPts = _signatureStrokes.expand((s) => s).toList();
    if (allPts.isEmpty) {
      final pic = recorder.endRecording();
      final img = await pic.toImage(w.toInt(), h.toInt());
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      return bd!.buffer.asUint8List();
    }

    double minX = allPts.first.dx;
    double minY = allPts.first.dy;
    double maxX = minX;
    double maxY = minY;
    for (final pt in allPts) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    final srcW = (maxX - minX).clamp(1.0, double.infinity);
    final srcH = (maxY - minY).clamp(1.0, double.infinity);
    const padding = 8.0;
    final scaleX = (w - padding * 2) / srcW;
    final scaleY = (h - padding * 2) / srcH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    Offset transform(Offset p) => Offset(
          (p.dx - minX) * scale + padding,
          (p.dy - minY) * scale + padding,
        );

    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _signatureStrokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(transform(stroke.first).dx, transform(stroke.first).dy);
      for (final pt in stroke.skip(1)) {
        path.lineTo(transform(pt).dx, transform(pt).dy);
      }
      canvas.drawPath(path, paint);
    }

    final pic = recorder.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _doc?.dispose();
    _pageImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign PDF'),
        actions: [
          if (_hasSig && _pageImage != null)
            IconButton(
              tooltip: 'Export signed PDF',
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              onPressed: _exporting ? null : _export,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── File picker ──────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(
                _pdfPath == null ? 'Pick a PDF to sign' : p.basename(_pdfPath!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.folder_open),
              onTap: _loading ? null : _pickPdf,
            ),
          ),
          // ── Page preview ─────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_pageImage != null)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child: RawImage(
                            image: _pageImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Align(
                          alignment: Alignment(
                            _sigX * 2 - 0.6,
                            _sigY * 2 - 0.6,
                          ),
                          child: GestureDetector(
                            onPanUpdate: (d) => setState(() {
                              _sigX = (_sigX + d.delta.dx / 300).clamp(0.0, 0.6);
                              _sigY = (_sigY + d.delta.dy / 300).clamp(0.1, 0.9);
                            }),
                            child: Container(
                              width: 140,
                              height: 42,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _hasSig
                                      ? scheme.primary
                                      : scheme.outline.withOpacity(0.5),
                                  width: 1.5,
                                  style: _hasSig
                                      ? BorderStyle.solid
                                      : BorderStyle.values.last,
                                ),
                                color: Colors.white.withOpacity(0.3),
                              ),
                              child: _hasSig
                                  ? CustomPaint(
                                      painter: _MiniSigPainter(
                                          _signatureStrokes),
                                    )
                                  : Center(
                                      child: Text(
                                        'Sign here (drag to move)',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: scheme.outline,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  'Pick a PDF to begin',
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            ),

          // ── Signature pad ─────────────────────────────────────────────
          if (_pdfPath != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('Draw signature:',
                      style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _signatureStrokes.clear();
                      _hasSig = false;
                    }),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Container(
              height: 100,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _SignaturePad(
                  strokes: _signatureStrokes,
                  onChanged: () => setState(() => _hasSig = true),
                ),
              ),
            ),
            if (_savedPath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text('Saved: $_savedPath',
                    style: TextStyle(color: scheme.primary, fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Signature pad ─────────────────────────────────────────────────────────────

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({required this.strokes, required this.onChanged});
  final List<List<Offset>> strokes;
  final VoidCallback onChanged;

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  List<Offset> _current = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        setState(() => _current = [d.localPosition]);
      },
      onPanUpdate: (d) {
        setState(() => _current.add(d.localPosition));
      },
      onPanEnd: (_) {
        if (_current.isNotEmpty) {
          widget.strokes.add(List.of(_current));
          widget.onChanged();
          setState(() => _current = []);
        }
      },
      child: CustomPaint(
        painter: _SigPainter(widget.strokes, _current),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter(this.strokes, this.current);
  final List<List<Offset>> strokes;
  final List<Offset> current;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in [...strokes, current]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final pt in stroke.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SigPainter old) => true;
}

class _MiniSigPainter extends CustomPainter {
  _MiniSigPainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final allPts = strokes.expand((s) => s).toList();
    if (allPts.isEmpty) return;

    double minX = allPts.first.dx, minY = allPts.first.dy;
    double maxX = minX, maxY = minY;
    for (final p in allPts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final srcW = (maxX - minX).clamp(1.0, double.infinity);
    final srcH = (maxY - minY).clamp(1.0, double.infinity);
    final scaleX = size.width / srcW;
    final scaleY = size.height / srcH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    Offset t(Offset p) =>
        Offset((p.dx - minX) * scale, (p.dy - minY) * scale);

    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(t(stroke.first).dx, t(stroke.first).dy);
      for (final pt in stroke.skip(1)) {
        path.lineTo(t(pt).dx, t(pt).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MiniSigPainter old) => true;
}
