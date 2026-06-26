import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/ocr_providers.dart';
import 'ocr_result_screen.dart';

/// Screen for camera-based OCR.
///
/// Opens the device camera, runs OCR on the captured image, and navigates to
/// [OcrResultScreen] on success.
class CameraOcrScreen extends ConsumerStatefulWidget {
  const CameraOcrScreen({super.key});

  @override
  ConsumerState<CameraOcrScreen> createState() => _CameraOcrScreenState();
}

class _CameraOcrScreenState extends ConsumerState<CameraOcrScreen> {
  final _picker = ImagePicker();
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Camera OCR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, size: 80, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                'Point your camera at the text you want to recognize',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: ensure good lighting for best results',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isRunning)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  icon: const Icon(Icons.camera),
                  label: const Text('Open Camera'),
                  onPressed: _captureAndRecognize,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Camera + OCR ──────────────────────────────────────────────────────────

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

    if (captured == null) return; // User cancelled
    if (!mounted) return;

    setState(() => _isRunning = true);

    final result = await ref
        .read(ocrJobProvider.notifier)
        // Camera captures are saved with sourceType = 'camera' internally
        // via recognizeImage; the notifier uses the image channel.
        .recognizeImage(captured.path);

    if (!mounted) return;
    setState(() => _isRunning = false);

    if (result != null) {
      // Replace this screen in the stack so Back returns to the caller.
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
