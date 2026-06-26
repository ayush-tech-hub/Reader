import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/ocr_export_service.dart';
import '../../domain/entities/ocr_result.dart';
import '../providers/ocr_providers.dart';
import 'ocr_result_screen.dart';

// ── Batch item data model ─────────────────────────────────────────────────────

enum _BatchStatus { waiting, processing, done, error }

class _BatchItem {
  _BatchItem({
    required this.path,
    this.status = _BatchStatus.waiting,
    this.result,
    this.error,
  });

  final String path;
  _BatchStatus status;
  OcrResult? result;
  String? error;

  String get name => path.split(Platform.pathSeparator).last;

  int get sizeBytes {
    try {
      return File(path).statSync().size;
    } catch (_) {
      return 0;
    }
  }

  bool get isImage {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.tiff') ||
        ext.endsWith('.tif');
  }

  bool get isPdf => path.toLowerCase().endsWith('.pdf');

  _BatchItem copyWith({
    _BatchStatus? status,
    OcrResult? result,
    String? error,
  }) =>
      _BatchItem(
        path: path,
        status: status ?? this.status,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Batch OCR: queue multiple image/PDF files, process them all sequentially.
class BatchOcrScreen extends ConsumerStatefulWidget {
  const BatchOcrScreen({super.key});

  @override
  ConsumerState<BatchOcrScreen> createState() => _BatchOcrScreenState();
}

class _BatchOcrScreenState extends ConsumerState<BatchOcrScreen> {
  final List<_BatchItem> _queue = [];
  bool _isProcessing = false;
  int _doneCount = 0;

  bool get _hasWaiting => _queue.any((i) => i.status == _BatchStatus.waiting);
  bool get _allDone =>
      _queue.isNotEmpty &&
      _queue.every((i) =>
          i.status == _BatchStatus.done || i.status == _BatchStatus.error);
  List<OcrResult> get _completedResults =>
      _queue.where((i) => i.result != null).map((i) => i.result!).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch OCR')),
      floatingActionButton: _allDone && _completedResults.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showResultsSheet,
              icon: const Icon(Icons.list_alt),
              label: const Text('View Results'),
            )
          : null,
      body: Column(
        children: [
          // File queue
          Expanded(child: _buildQueue()),

          // Progress bar
          if (_isProcessing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _queue.isEmpty ? 0 : _doneCount / _queue.length,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_doneCount of ${_queue.length} processed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 1),

          // Bottom action row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Files'),
                    onPressed: _isProcessing ? null : _addFiles,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Process All'),
                    onPressed:
                        (_isProcessing || !_hasWaiting) ? null : _processAll,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Queue list ────────────────────────────────────────────────────────────

  Widget _buildQueue() {
    if (_queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No files queued.\nTap "Add Files" to begin.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _queue.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _BatchItemTile(
        item: _queue[index],
        onRemove: _queue[index].status == _BatchStatus.waiting
            ? () => setState(() => _queue.removeAt(index))
            : null,
      ),
    );
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'bmp',
        'tiff',
        'tif',
        'pdf',
      ],
    );

    if (result == null || result.paths.isEmpty) return;

    final newPaths = result.paths
        .whereType<String>()
        .where((p) => !_queue.any((item) => item.path == p))
        .toList();

    if (newPaths.isNotEmpty) {
      setState(() {
        _queue.addAll(newPaths.map(_BatchItem.new));
      });
    }
  }

  // ── Processing ────────────────────────────────────────────────────────────

  Future<void> _processAll() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _doneCount = _queue.where((i) => i.status != _BatchStatus.waiting).length;
    });

    final notifier = ref.read(ocrJobProvider.notifier);

    for (var i = 0; i < _queue.length; i++) {
      final item = _queue[i];
      if (item.status != _BatchStatus.waiting) continue;

      setState(() => _queue[i].status = _BatchStatus.processing);

      OcrResult? result;
      String? errorMsg;

      try {
        if (item.isPdf) {
          result = await notifier.recognizePdf(item.path);
        } else {
          result = await notifier.recognizeImage(item.path);
        }
        if (result == null) {
          errorMsg = ref.read(ocrJobProvider).error ?? 'Recognition failed';
        }
      } catch (e) {
        errorMsg = e.toString();
      }

      if (!mounted) break;

      setState(() {
        _queue[i] = _BatchItem(
          path: item.path,
          status: result != null ? _BatchStatus.done : _BatchStatus.error,
          result: result,
          error: errorMsg,
        );
        _doneCount++;
      });
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  // ── Results bottom sheet ──────────────────────────────────────────────────

  void _showResultsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ResultsSheet(results: _completedResults),
    );
  }
}

// ── Batch item tile ───────────────────────────────────────────────────────────

class _BatchItemTile extends StatelessWidget {
  const _BatchItemTile({required this.item, required this.onRemove});

  final _BatchItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        item.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
        color: scheme.primary,
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_sizeLabel(item.sizeBytes)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(status: item.status, error: item.error),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.error});

  final _BatchStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (label, color, icon) = switch (status) {
      _BatchStatus.waiting => (
          'Waiting',
          scheme.outline,
          Icons.hourglass_empty,
        ),
      _BatchStatus.processing => (
          'Processing',
          scheme.primary,
          Icons.sync,
        ),
      _BatchStatus.done => (
          'Done',
          Colors.green,
          Icons.check_circle_outline,
        ),
      _BatchStatus.error => (
          'Error',
          scheme.error,
          Icons.error_outline,
        ),
    };

    return Tooltip(
      message: status == _BatchStatus.error ? (error ?? 'Error') : label,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Results bottom sheet ──────────────────────────────────────────────────────

class _ResultsSheet extends ConsumerWidget {
  const _ResultsSheet({required this.results});

  final List<OcrResult> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Results (${results.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share All'),
                    onPressed: () => _shareAll(context, ref),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      result.sourceFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${result.wordCount} words'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OcrResultScreen(result: result),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareAll(BuildContext context, WidgetRef ref) async {
    if (results.isEmpty) return;
    final service = ref.read(ocrExportServiceProvider);
    final paths = <String>[];
    for (final result in results) {
      try {
        final path = await service.exportAsTxt(result);
        paths.add(path);
      } catch (_) {
        // Skip files that fail to export.
      }
    }
    if (paths.isEmpty) return;
    await Share.shareXFiles(paths.map(XFile.new).toList());
  }
}
