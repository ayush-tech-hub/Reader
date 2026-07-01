// ignore_for_file: unawaited_futures

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/platform/native_channels.dart';

/// A detected barcode or QR code.
class BarcodeResult {
  const BarcodeResult({
    required this.format,
    required this.rawValue,
    required this.displayValue,
    required this.type,
    this.url,
  });

  factory BarcodeResult.fromMap(Map<dynamic, dynamic> map) {
    return BarcodeResult(
      format: map['format'] as String? ?? 'UNKNOWN',
      rawValue: map['rawValue'] as String? ?? '',
      displayValue: map['displayValue'] as String? ?? '',
      type: map['type'] as int? ?? 0,
      url: map['url'] as String?,
    );
  }

  final String format;
  final String rawValue;
  final String displayValue;
  final int type;
  final String? url;

  bool get isUrl => url != null && url!.isNotEmpty;

  String get label => displayValue.isNotEmpty ? displayValue : rawValue;
}

/// Scans QR codes and barcodes from a camera photo or image file.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  static const _channel = MethodChannel(NativeChannels.barcode);
  final _picker = ImagePicker();

  XFile? _image;
  bool _scanning = false;
  List<BarcodeResult>? _results;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _permissionMsg(e.toString()));
      return;
    }
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _image = picked;
      _scanning = true;
      _results = null;
      _error = null;
    });

    try {
      final raw = await _channel.invokeListMethod<dynamic>(
        'scanFromImage',
        {'path': picked.path},
      );
      if (!mounted) return;
      final results = (raw ?? [])
          .cast<Map<dynamic, dynamic>>()
          .map(BarcodeResult.fromMap)
          .toList();
      setState(() {
        _results = results;
        _scanning = false;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Scanning failed';
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _scanning = false;
        });
      }
    }
  }

  String _permissionMsg(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Camera or storage permission denied. '
          'Please grant access in device settings.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR & Barcode Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Source buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Use Camera'),
                    onPressed: _scanning
                        ? null
                        : () => _scan(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Pick Image'),
                    onPressed: _scanning
                        ? null
                        : () => _scan(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image preview
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.file(
                    File(_image!.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            if (_scanning) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Scanning for codes…')),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _error!),
            ],

            if (_results != null) ...[
              const SizedBox(height: 20),
              if (_results!.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No barcodes or QR codes detected.\n'
                      'Ensure the code is clearly visible and well-lit.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                Text(
                  '${_results!.length} code${_results!.length == 1 ? '' : 's'} found',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final r in _results!) _BarcodeCard(result: r),
              ],
            ],

            if (_results == null && !_scanning && _image == null) ...[
              const SizedBox(height: 48),
              Icon(
                Icons.qr_code_scanner,
                size: 96,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Take a photo or pick an image\ncontaining a QR code or barcode',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarcodeCard extends StatelessWidget {
  const _BarcodeCard({required this.result});
  final BarcodeResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(result.format),
                  labelStyle: const TextStyle(fontSize: 11),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.label));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
                if (result.isUrl)
                  Tooltip(
                    message: 'URL detected — copy and open in browser',
                    child: Icon(Icons.link, size: 18, color: scheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              result.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
