import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Non-destructive image enhancement: brightness, contrast, saturation.
/// All adjustments use Flutter's ColorFilter.matrix — no pixel-level loop.
/// The original file is never modified; the result is saved as a new PNG.
class ImageEnhanceScreen extends StatefulWidget {
  const ImageEnhanceScreen({super.key});

  @override
  State<ImageEnhanceScreen> createState() => _ImageEnhanceScreenState();
}

class _ImageEnhanceScreenState extends State<ImageEnhanceScreen> {
  String? _imagePath;
  ui.Image? _sourceImage;

  double _brightness = 0.0; // -1.0 … +1.0
  double _contrast = 1.0; // 0.5 … 2.0
  double _saturation = 1.0; // 0.0 … 2.0

  bool _exporting = false;
  String? _savedPath;

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _imagePath = path;
        _sourceImage = frame.image;
        _savedPath = null;
      });
    }
  }

  /// Build a 4×5 color matrix for brightness / contrast / saturation.
  List<double> _colorMatrix() {
    final c = _contrast;
    final b = _brightness * 128;
    final t = (1.0 - c) * 128 + b;

    // Saturation: ITU-R BT.601 luminance weights.
    const lr = 0.299;
    const lg = 0.587;
    const lb = 0.114;
    final s = _saturation;
    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;

    return [
      c * (sr + s), c * sg, c * sb, 0, t,
      c * sr, c * (sg + s), c * sb, 0, t,
      c * sr, c * sg, c * (sb + s), 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _saveEnhanced() async {
    final src = _sourceImage;
    final path = _imagePath;
    if (src == null || path == null) return;

    setState(() {
      _exporting = true;
      _savedPath = null;
    });

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..colorFilter = ColorFilter.matrix(_colorMatrix());
      canvas.drawImage(src, Offset.zero, paint);
      final picture = recorder.endRecording();
      final enhanced = await picture.toImage(src.width, src.height);
      final byteData =
          await enhanced.toByteData(format: ui.ImageByteFormat.png);
      enhanced.dispose();

      if (byteData == null) throw Exception('Failed to encode image');

      Directory base;
      try {
        base = (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        base = await getApplicationDocumentsDirectory();
      }
      final stem = p.basenameWithoutExtension(path);
      final outPath = p.join(base.path, '${stem}_enhanced.png');
      await File(outPath).writeAsBytes(byteData.buffer.asUint8List());

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

  @override
  void dispose() {
    _sourceImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final src = _sourceImage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image enhancement'),
        actions: [
          if (src != null)
            IconButton(
              tooltip: 'Save enhanced image',
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              onPressed: _exporting ? null : _saveEnhanced,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Preview ───────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: src == null ? _pickImage : null,
              child: Container(
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: src == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 64, color: scheme.outline),
                          const SizedBox(height: 12),
                          const Text('Tap to pick an image'),
                        ],
                      )
                    : ColorFiltered(
                        colorFilter: ColorFilter.matrix(_colorMatrix()),
                        child: RawImage(image: src, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),

          // ── Controls ──────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_imagePath != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: Text(p.basename(_imagePath!)),
                    onPressed: _pickImage,
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Pick image'),
                    onPressed: _pickImage,
                  ),
                const SizedBox(height: 12),
                _AdjustRow(
                  label: 'Brightness',
                  value: _brightness,
                  min: -1.0,
                  max: 1.0,
                  onChanged: src == null
                      ? null
                      : (v) => setState(() => _brightness = v),
                ),
                _AdjustRow(
                  label: 'Contrast',
                  value: _contrast,
                  min: 0.5,
                  max: 2.0,
                  onChanged: src == null
                      ? null
                      : (v) => setState(() => _contrast = v),
                ),
                _AdjustRow(
                  label: 'Saturation',
                  value: _saturation,
                  min: 0.0,
                  max: 2.0,
                  onChanged: src == null
                      ? null
                      : (v) => setState(() => _saturation = v),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: src == null
                      ? null
                      : () => setState(() {
                            _brightness = 0;
                            _contrast = 1;
                            _saturation = 1;
                          }),
                  child: const Text('Reset to defaults'),
                ),
                if (_savedPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Saved: $_savedPath',
                      style: TextStyle(color: scheme.primary, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustRow extends StatelessWidget {
  const _AdjustRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
