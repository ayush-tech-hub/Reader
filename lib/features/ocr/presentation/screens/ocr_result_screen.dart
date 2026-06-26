import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/ocr_export_service.dart';
import '../../domain/entities/ocr_result.dart';
import '../providers/ocr_providers.dart';

/// Full-featured OCR result viewer.
///
/// Supports copy-all, share, and export (TXT / Markdown / HTML / JSON / CSV).
/// Multi-page results are shown in a [TabBar]; single-page results show a
/// direct scrollable view.
class OcrResultScreen extends ConsumerWidget {
  const OcrResultScreen({super.key, required this.result});

  final OcrResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return result.pageCount > 1
        ? _MultiPageView(result: result)
        : _SinglePageView(result: result);
  }
}

// ── Shared AppBar + actions ───────────────────────────────────────────────────

class _OcrAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _OcrAppBar({required this.result});

  final OcrResult result;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('OCR Result'),
      actions: [
        // Copy all text
        IconButton(
          icon: const Icon(Icons.copy_all),
          tooltip: 'Copy all text',
          onPressed: () => _copyAll(context),
        ),
        // Share
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share',
          onPressed: () => _share(),
        ),
        // Export popup
        PopupMenuButton<_ExportChoice>(
          icon: const Icon(Icons.ios_share),
          tooltip: 'Export',
          onSelected: (choice) => _export(context, ref, choice),
          itemBuilder: (context) => [
            _exportItem(_ExportChoice.txt, 'TXT', Icons.text_snippet_outlined),
            _exportItem(
                _ExportChoice.markdown, 'Markdown', Icons.code_outlined),
            _exportItem(_ExportChoice.html, 'HTML', Icons.html_outlined),
            _exportItem(_ExportChoice.json, 'JSON', Icons.data_object_outlined),
            _exportItem(_ExportChoice.csv, 'CSV',
                Icons.table_chart_outlined),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<_ExportChoice> _exportItem(
    _ExportChoice choice,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem<_ExportChoice>(
      value: choice,
      child: ListTile(
        leading: Icon(icon),
        title: Text('Export as $label'),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }

  void _copyAll(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _share() {
    Share.share(result.fullText, subject: result.sourceFileName);
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    _ExportChoice choice,
  ) async {
    final service = ref.read(ocrExportServiceProvider);
    try {
      final path = await _callExport(service, choice);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<String> _callExport(OcrExportService service, _ExportChoice choice) {
    switch (choice) {
      case _ExportChoice.txt:
        return service.exportAsTxt(result);
      case _ExportChoice.markdown:
        return service.exportAsMarkdown(result);
      case _ExportChoice.html:
        return service.exportAsHtml(result);
      case _ExportChoice.json:
        return service.exportAsJson(result);
      case _ExportChoice.csv:
        return service.exportAsCsv(result);
    }
  }
}

enum _ExportChoice { txt, markdown, html, json, csv }

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.result});

  final OcrResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          Chip(
            avatar: const Icon(Icons.text_fields, size: 16),
            label: Text('${result.wordCount} words'),
          ),
          Chip(
            avatar: const Icon(Icons.format_size, size: 16),
            label: Text('${result.fullText.length} chars'),
          ),
          Chip(
            avatar: const Icon(Icons.description_outlined, size: 16),
            label: Text(
              result.pageCount == 1
                  ? '1 page'
                  : '${result.pageCount} pages',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page text card ────────────────────────────────────────────────────────────

class _PageCard extends StatelessWidget {
  const _PageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          text.isEmpty ? '(no text recognised on this page)' : text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
        ),
      ),
    );
  }
}

// ── Single-page layout ────────────────────────────────────────────────────────

class _SinglePageView extends ConsumerWidget {
  const _SinglePageView({required this.result});

  final OcrResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _OcrAppBar(result: result),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Share.share(result.fullText, subject: result.sourceFileName),
        tooltip: 'Share',
        child: const Icon(Icons.share),
      ),
      body: ListView(
        children: [
          _StatsRow(result: result),
          _PageCard(text: result.pageTexts.first),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }
}

// ── Multi-page layout ─────────────────────────────────────────────────────────

class _MultiPageView extends ConsumerWidget {
  const _MultiPageView({required this.result});

  final OcrResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: result.pageCount,
      child: Scaffold(
        appBar: _MultiPageAppBar(result: result),
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              Share.share(result.fullText, subject: result.sourceFileName),
          tooltip: 'Share',
          child: const Icon(Icons.share),
        ),
        body: Column(
          children: [
            _StatsRow(result: result),
            Expanded(
              child: TabBarView(
                children: [
                  for (final text in result.pageTexts)
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _PageCard(text: text),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiPageAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _MultiPageAppBar({required this.result});

  final OcrResult result;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('OCR Result'),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_all),
          tooltip: 'Copy all text',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: result.fullText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share',
          onPressed: () =>
              Share.share(result.fullText, subject: result.sourceFileName),
        ),
        PopupMenuButton<_ExportChoice>(
          icon: const Icon(Icons.ios_share),
          tooltip: 'Export',
          onSelected: (choice) => _export(context, ref, choice),
          itemBuilder: (context) => [
            _exportItem(_ExportChoice.txt, 'TXT', Icons.text_snippet_outlined),
            _exportItem(
                _ExportChoice.markdown, 'Markdown', Icons.code_outlined),
            _exportItem(_ExportChoice.html, 'HTML', Icons.html_outlined),
            _exportItem(_ExportChoice.json, 'JSON', Icons.data_object_outlined),
            _exportItem(
                _ExportChoice.csv, 'CSV', Icons.table_chart_outlined),
          ],
        ),
      ],
      bottom: TabBar(
        isScrollable: result.pageCount > 5,
        tabs: [
          for (var i = 0; i < result.pageCount; i++) Tab(text: 'Page ${i + 1}'),
        ],
      ),
    );
  }

  PopupMenuItem<_ExportChoice> _exportItem(
    _ExportChoice choice,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem<_ExportChoice>(
      value: choice,
      child: ListTile(
        leading: Icon(icon),
        title: Text('Export as $label'),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    _ExportChoice choice,
  ) async {
    final service = ref.read(ocrExportServiceProvider);
    try {
      final path = await _callExport(service, choice);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<String> _callExport(OcrExportService service, _ExportChoice choice) {
    switch (choice) {
      case _ExportChoice.txt:
        return service.exportAsTxt(result);
      case _ExportChoice.markdown:
        return service.exportAsMarkdown(result);
      case _ExportChoice.html:
        return service.exportAsHtml(result);
      case _ExportChoice.json:
        return service.exportAsJson(result);
      case _ExportChoice.csv:
        return service.exportAsCsv(result);
    }
  }
}
