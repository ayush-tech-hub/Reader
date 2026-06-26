import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/ocr_export_service.dart';
import '../../domain/entities/ocr_result.dart';
import '../providers/ocr_providers.dart';
import 'ocr_result_screen.dart';

/// Shows all past OCR results stored in local history.
///
/// Each entry shows the source name, date, and word count.  A popup menu per
/// entry provides [Open], [Export TXT], [Share], and [Delete] actions.
class OcrHistoryScreen extends ConsumerWidget {
  const OcrHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(ocrHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load history:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) =>
            items.isEmpty ? const _EmptyHistory() : _HistoryList(items: items),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This will permanently delete all OCR results. '
          'Exported files will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(ocrHistoryProvider.notifier).clear();
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No OCR history yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ── History list ──────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});

  final List<OcrResult> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _HistoryTile(result: items[index]),
    );
  }
}

// ── History tile ──────────────────────────────────────────────────────────────

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.result});

  final OcrResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        child: Icon(_sourceIcon(result.sourceType)),
      ),
      title: Text(
        result.sourceFileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_subtitle(result)),
      trailing: PopupMenuButton<_TileAction>(
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _TileAction.open,
            child: ListTile(
              leading: Icon(Icons.open_in_new),
              title: Text('Open'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: _TileAction.exportTxt,
            child: ListTile(
              leading: Icon(Icons.text_snippet_outlined),
              title: Text('Export TXT'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: _TileAction.share,
            child: ListTile(
              leading: Icon(Icons.share_outlined),
              title: Text('Share'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: _TileAction.delete,
            child: ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
      onTap: () => _open(context),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OcrResultScreen(result: result),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _TileAction action,
  ) async {
    switch (action) {
      case _TileAction.open:
        _open(context);
      case _TileAction.exportTxt:
        await _exportTxt(context, ref);
      case _TileAction.share:
        await Share.share(result.fullText, subject: result.sourceFileName);
      case _TileAction.delete:
        await _delete(context, ref);
    }
  }

  Future<void> _exportTxt(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(ocrExportServiceProvider);
      final path = await service.exportAsTxt(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $path'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => Share.shareXFiles([XFile(path)]),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this result?'),
        content: Text('Remove "${result.sourceFileName}" from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(ocrHistoryProvider.notifier).delete(result.id);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData _sourceIcon(String sourceType) {
    switch (sourceType) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'camera':
        return Icons.camera_alt_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  String _subtitle(OcrResult result) {
    final fmt = DateFormat('MMM d, yyyy');
    final date = fmt.format(result.createdAt.toLocal());
    final words = result.wordCount;
    return '$date • $words words';
  }
}

enum _TileAction { open, exportTxt, share, delete }
