// ignore_for_file: unawaited_futures

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/ocr_providers.dart';
import 'ocr_result_screen.dart';

/// Screen for picking one or more images and running OCR on them.
///
/// When no image has been selected the user is offered two actions:
/// [Pick from Gallery] and [Take Photo].  After an image is chosen a preview
/// is shown along with a "Recognize Text" button.  On success the screen
/// navigates to [OcrResultScreen].
class ImageOcrScreen extends ConsumerStatefulWidget {
  const ImageOcrScreen({super.key});

  @override
  ConsumerState<ImageOcrScreen> createState() => _ImageOcrScreenState();
}

class _ImageOcrScreenState extends ConsumerState<ImageOcrScreen> {
  final _picker = ImagePicker();
  XFile? _pickedFile;

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(ocrJobProvider);
    final isRunning = jobState.isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('Image OCR')),
      body: _pickedFile == null
          ? _EmptyState(
              onGallery: isRunning ? null : _pickFromGallery,
              onCamera: isRunning ? null : _takePhoto,
            )
          : _PreviewState(
              file: _pickedFile!,
              isRunning: isRunning,
              onRecognize: isRunning ? null : _runOcr,
              onClear:
                  isRunning ? null : () => setState(() => _pickedFile = null),
            ),
    );
  }

  // ── Image selection ───────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null && mounted) {
        setState(() => _pickedFile = file);
      }
    } catch (e) {
      _showError(_permissionMessage(e.toString()));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (file != null && mounted) {
        setState(() => _pickedFile = file);
      }
    } catch (e) {
      _showError(_permissionMessage(e.toString()));
    }
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    final path = _pickedFile?.path;
    if (path == null) return;

    final result = await ref.read(ocrJobProvider.notifier).recognizeImage(path);

    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).push(
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
      return 'Camera or storage permission denied. '
          'Please grant access in your device settings.';
    }
    return raw;
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGallery, required this.onCamera});

  final VoidCallback? onGallery;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_search, size: 80, color: scheme.primary),
            const SizedBox(height: 24),
            Text(
              'Pick an image to recognize text',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick from Gallery'),
                  onPressed: onGallery,
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                  onPressed: onCamera,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview state ─────────────────────────────────────────────────────────────

class _PreviewState extends StatelessWidget {
  const _PreviewState({
    required this.file,
    required this.isRunning,
    required this.onRecognize,
    required this.onClear,
  });

  final XFile file;
  final bool isRunning;
  final VoidCallback? onRecognize;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Image.file(
                File(file.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // File name
          Text(
            file.name,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          if (isRunning) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Text(
              'Recognizing…',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            FilledButton.icon(
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Recognize Text'),
              onPressed: onRecognize,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Choose Different Image'),
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}
