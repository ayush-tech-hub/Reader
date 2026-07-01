// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/ocr_providers.dart';
import '../widgets/ocr_script_selector.dart';
import 'ocr_result_screen.dart';

enum _ScanMode {
  general,
  idCard,
  passport,
  receipt,
  businessCard,
  book,
  whiteboard;

  String get label => switch (this) {
        general => 'General',
        idCard => 'ID Card',
        passport => 'Passport',
        receipt => 'Receipt',
        businessCard => 'Business Card',
        book => 'Book',
        whiteboard => 'Whiteboard',
      };

  IconData get icon => switch (this) {
        general => Icons.document_scanner_outlined,
        idCard => Icons.badge_outlined,
        passport => Icons.book_outlined,
        receipt => Icons.receipt_long_outlined,
        businessCard => Icons.contact_page_outlined,
        book => Icons.menu_book_outlined,
        whiteboard => Icons.present_to_all_outlined,
      };

  String get tip => switch (this) {
        general => 'Ensure good lighting and hold the camera steady.',
        idCard =>
          'Lay the card on a flat surface. Capture the full card including all four corners.',
        passport =>
          'Open to the photo page. Ensure the MRZ (two lines at the bottom) is fully visible.',
        receipt =>
          'Flatten the receipt. Capture from top to bottom to include all line items and totals.',
        businessCard =>
          'Lay the card flat. Both sides may need separate scans.',
        book =>
          'Hold the book flat and open. Avoid shadows across the text and scan one page at a time.',
        whiteboard =>
          'Stand directly in front of the board. Avoid reflections from windows or lights.',
      };
}

/// Screen for camera-based OCR.
///
/// Supports specialized scanning modes (ID card, passport, receipt, etc.)
/// with contextual tips and the same underlying ML Kit OCR engine.
class CameraOcrScreen extends ConsumerStatefulWidget {
  const CameraOcrScreen({super.key});

  @override
  ConsumerState<CameraOcrScreen> createState() => _CameraOcrScreenState();
}

class _CameraOcrScreenState extends ConsumerState<CameraOcrScreen> {
  final _picker = ImagePicker();
  bool _isRunning = false;
  String? _script;
  _ScanMode _mode = _ScanMode.general;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${_mode.label} Scanner')),
      body: Column(
        children: [
          // Mode selector
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _ScanMode.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final mode = _ScanMode.values[i];
                final selected = mode == _mode;
                return FilterChip(
                  avatar: Icon(mode.icon, size: 16),
                  label: Text(mode.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _mode = mode),
                );
              },
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_mode.icon, size: 72, color: scheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      '${_mode.label} Scanner',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 16, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _mode.tip,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OcrScriptSelector(
                      value: _script,
                      onChanged: (v) => setState(() => _script = v),
                    ),
                    const SizedBox(height: 16),
                    if (_isRunning)
                      const CircularProgressIndicator()
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.camera),
                            label: const Text('Open Camera'),
                            onPressed: _captureAndRecognize,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                            onPressed: _pickAndRecognize,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndRecognize() async {
    XFile? captured;
    try {
      captured = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
    } catch (e) {
      _showError(_permissionMessage(e.toString()));
      return;
    }
    if (captured == null) return;
    await _recognize(captured.path);
  }

  Future<void> _pickAndRecognize() async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      _showError(e.toString());
      return;
    }
    if (picked == null) return;
    await _recognize(picked.path);
  }

  Future<void> _recognize(String path) async {
    if (!mounted) return;
    setState(() => _isRunning = true);

    final result = await ref
        .read(ocrJobProvider.notifier)
        .recognizeImage(path, script: _script);

    if (!mounted) return;
    setState(() => _isRunning = false);

    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OcrResultScreen(result: result),
        ),
      );
    } else {
      final error = ref.read(ocrJobProvider).error ?? 'Recognition failed';
      _showError(error);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _permissionMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Camera permission denied. '
          'Please grant access in your device settings.';
    }
    return raw;
  }
}
