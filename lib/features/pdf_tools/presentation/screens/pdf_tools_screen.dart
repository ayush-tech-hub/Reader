import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../generated/app_localizations.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../providers/pdf_tools_providers.dart';

/// Hub for all PDF utilities. Each tile picks inputs, asks for the
/// minimum options it needs, then delegates to [PdfToolsNotifier].
class PdfToolsScreen extends ConsumerWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(pdfToolsProvider);

    final tools = <_Tool>[
      _Tool(Icons.merge, l10n.mergePdf, () => _merge(context, ref)),
      _Tool(Icons.call_split, l10n.splitPdf, () => _split(context, ref)),
      _Tool(Icons.compress, l10n.compressPdf, () => _compress(context, ref)),
      _Tool(Icons.image, l10n.imagesToPdf, () => _imagesToPdf(context, ref)),
      _Tool(
        Icons.low_priority,
        l10n.reorderPages,
        () => _pagesOp(context, ref, _PagesOp.reorder),
      ),
      _Tool(
        Icons.delete_sweep,
        l10n.deletePages,
        () => _pagesOp(context, ref, _PagesOp.delete),
      ),
      _Tool(
        Icons.rotate_90_degrees_cw,
        l10n.rotatePages,
        () => _pagesOp(context, ref, _PagesOp.rotate),
      ),
      _Tool(
        Icons.file_copy,
        l10n.extractPages,
        () => _extractPages(context, ref),
      ),
      _Tool(
        Icons.branding_watermark,
        l10n.watermarkPdf,
        () => _watermark(context, ref),
      ),
      _Tool(Icons.edit_note, l10n.editMetadata, () => _metadata(context, ref)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pdfTools)),
      body: Column(
        children: [
          if (state.isWorking) const LinearProgressIndicator(),
          if (state.lastError != null)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(state.lastError!),
            ),
          if (state.lastOutputs.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l10n.outputCreated),
              subtitle: Text(state.lastOutputs.join('\n')),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return Card(
                  child: InkWell(
                    onTap: state.isWorking ? null : tool.onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tool.icon, size: 32),
                        const SizedBox(height: 8),
                        Text(tool.label, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Pickers -------------------------------------------------------

  static Future<List<String>?> _pickPdfs({bool multiple = true}) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: multiple,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final paths = picked?.paths.whereType<String>().toList();
    return (paths == null || paths.isEmpty) ? null : paths;
  }

  static Future<String?> _pickOutputDir() =>
      FilePicker.platform.getDirectoryPath();

  static String _outPath(String dir, String source, String suffix) => p.join(
        dir,
        '${p.basenameWithoutExtension(source)}_$suffix.pdf',
      );

  // ---- Tool flows ------------------------------------------------------

  static Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs();
    if (sources == null || sources.length < 2) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await ref
        .read(pdfToolsProvider.notifier)
        .merge(sources, _outPath(dir, sources.first, 'merged'));
  }

  static Future<void> _split(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final ranges = await _promptRanges(context);
    if (ranges == null || ranges.isEmpty) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await ref.read(pdfToolsProvider.notifier).split(sources.single, ranges, dir);
  }

  static Future<void> _compress(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await ref.read(pdfToolsProvider.notifier).compress(
          sources.single,
          _outPath(dir, sources.single, 'compressed'),
          CompressionQuality.medium,
        );
  }

  static Future<void> _imagesToPdf(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    final images = picked?.paths.whereType<String>().toList();
    if (images == null || images.isEmpty) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await ref
        .read(pdfToolsProvider.notifier)
        .imagesToPdf(images, _outPath(dir, images.first, 'images'));
  }

  static Future<void> _pagesOp(
    BuildContext context,
    WidgetRef ref,
    _PagesOp op,
  ) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final pages = await _promptPageList(context);
    if (pages == null || pages.isEmpty) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    final notifier = ref.read(pdfToolsProvider.notifier);
    final source = sources.single;
    switch (op) {
      case _PagesOp.reorder:
        await notifier.reorderPages(
          source,
          _outPath(dir, source, 'reordered'),
          pages,
        );
      case _PagesOp.delete:
        await notifier.deletePages(
          source,
          _outPath(dir, source, 'edited'),
          pages,
        );
      case _PagesOp.rotate:
        await notifier.rotatePages(
          source,
          _outPath(dir, source, 'rotated'),
          pages,
          90,
        );
    }
  }

  static Future<void> _extractPages(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final ranges = await _promptRanges(context);
    if (ranges == null || ranges.isEmpty) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await ref.read(pdfToolsProvider.notifier).extractPages(
          sources.single,
          _outPath(dir, sources.single, 'extract'),
          ranges.first,
        );
  }

  static Future<void> _watermark(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final text = await _promptText(
      context,
      AppLocalizations.of(context).watermarkText,
    );
    if (text == null || text.isEmpty) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await ref.read(pdfToolsProvider.notifier).watermark(
          sources.single,
          _outPath(dir, sources.single, 'watermarked'),
          WatermarkSpec(text: text),
        );
  }

  static Future<void> _metadata(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    final notifier = ref.read(pdfToolsProvider.notifier);
    final current = await notifier.getMetadata(sources.single);
    if (!context.mounted) return;
    final updated = await showDialog<PdfMetadata>(
      context: context,
      builder: (context) =>
          _MetadataDialog(initial: current ?? const PdfMetadata()),
    );
    if (updated == null) return;
    final dir = await _pickOutputDir();
    if (dir == null) return;
    await notifier.setMetadata(
      sources.single,
      _outPath(dir, sources.single, 'meta'),
      updated,
    );
  }

  // ---- Prompts --------------------------------------------------------

  static Future<String?> _promptText(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  /// Parses "1-3, 5, 8-10" into page ranges.
  static Future<List<PageRange>?> _promptRanges(BuildContext context) async {
    final raw = await _promptText(
      context,
      AppLocalizations.of(context).pageRangesHint,
    );
    if (raw == null) return null;
    return parsePageRanges(raw);
  }

  /// Parses "1, 3, 5" into a page list.
  static Future<List<int>?> _promptPageList(BuildContext context) async {
    final raw = await _promptText(
      context,
      AppLocalizations.of(context).pageListHint,
    );
    if (raw == null) return null;
    return [
      for (final range in parsePageRanges(raw))
        for (var page = range.start; page <= range.end; page++) page,
    ];
  }
}

/// "1-3,5" -> [PageRange(1,3), PageRange(5,5)]. Exposed for tests.
List<PageRange> parsePageRanges(String input) {
  final ranges = <PageRange>[];
  for (final part in input.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final dash = trimmed.indexOf('-');
    if (dash < 0) {
      final page = int.tryParse(trimmed);
      if (page != null && page >= 1) ranges.add(PageRange(page, page));
    } else {
      final start = int.tryParse(trimmed.substring(0, dash).trim());
      final end = int.tryParse(trimmed.substring(dash + 1).trim());
      if (start != null && end != null && start >= 1 && end >= start) {
        ranges.add(PageRange(start, end));
      }
    }
  }
  return ranges;
}

enum _PagesOp { reorder, delete, rotate }

class _Tool {
  const _Tool(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MetadataDialog extends StatefulWidget {
  const _MetadataDialog({required this.initial});

  final PdfMetadata initial;

  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _author = TextEditingController(text: widget.initial.author);
  late final _subject = TextEditingController(text: widget.initial.subject);
  late final _keywords = TextEditingController(text: widget.initial.keywords);

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _subject.dispose();
    _keywords.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editMetadata),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.metaTitle),
            ),
            TextField(
              controller: _author,
              decoration: InputDecoration(labelText: l10n.metaAuthor),
            ),
            TextField(
              controller: _subject,
              decoration: InputDecoration(labelText: l10n.metaSubject),
            ),
            TextField(
              controller: _keywords,
              decoration: InputDecoration(labelText: l10n.metaKeywords),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            PdfMetadata(
              title: _title.text,
              author: _author.text,
              subject: _subject.text,
              keywords: _keywords.text,
              creator: widget.initial.creator,
              producer: widget.initial.producer,
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
