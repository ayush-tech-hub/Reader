import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchablePdfScreen extends ConsumerStatefulWidget {
  const SearchablePdfScreen({super.key});

  @override
  ConsumerState<SearchablePdfScreen> createState() =>
      _SearchablePdfScreenState();
}

class _SearchablePdfScreenState extends ConsumerState<SearchablePdfScreen> {
  static const _channel = MethodChannel('opendocs/ocr');

  String? _inputPath;
  bool _isProcessing = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _inputPath = result.files.single.path;
      });
    }
  }

  Future<void> _generateSearchablePdf() async {
    final inputPath = _inputPath;
    if (inputPath == null) return;

    final outputPath = inputPath.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false), '_searchable.pdf');

    setState(() => _isProcessing = true);
    try {
      final result = await _channel.invokeMethod<String>(
        'makeSearchable',
        {'inputPath': inputPath, 'outputPath': outputPath},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: ${result ?? outputPath}')),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Searchable PDF')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepTile(
              step: 1,
              label: 'Pick a PDF file',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_inputPath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _inputPath!,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickPdf,
                    icon: const Icon(Icons.folder_open),
                    label:
                        Text(_inputPath == null ? 'Select PDF' : 'Change PDF'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _StepTile(
              step: 2,
              label: 'Generate Searchable PDF',
              child: FilledButton.icon(
                onPressed: (_inputPath != null && !_isProcessing)
                    ? _generateSearchablePdf
                    : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isProcessing
                    ? 'Processing...'
                    : 'Generate Searchable PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile(
      {required this.step, required this.label, required this.child});

  final int step;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: Text('$step',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: child,
        ),
      ],
    );
  }
}
