import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/save_location_service.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../providers/pdf_tools_providers.dart';
import 'tool_result_screen.dart';

/// Hub for all PDF utilities. Each tile picks inputs, runs the operation
/// using the default save folder (Downloads/PDF & Image Tools/), then
/// pushes [ToolResultScreen] on success.
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
      _Tool(Icons.lock, l10n.encryptPdf, () => _encrypt(context, ref)),
      _Tool(Icons.lock_open, l10n.decryptPdf, () => _decrypt(context, ref)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pdfTools),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: l10n.changeOutputFolder,
            onPressed: () => _changeOutputFolder(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.isWorking) ...[
            const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${state.operationName ?? ''}…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (state.lastError != null)
            ListTile(
              leading: Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(state.lastError!),
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

  // ---- Save location helpers ------------------------------------------

  static final _saveService = SaveLocationService();

  static Future<String> _saveDir() => _saveService.getDefaultSaveDir();

  static String _outPath(String dir, String source, String suffix) => p.join(
        dir,
        '${p.basenameWithoutExtension(source)}_$suffix.pdf',
      );

  static Future<void> _changeOutputFolder(BuildContext context) async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    await _saveService.setCustomSaveDir(dir);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dir)),
      );
    }
  }

  // ---- Result navigation ---------------------------------------------

  static Future<void> _showResult(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onProcessAnother,
  }) async {
    final state = ref.read(pdfToolsProvider);
    if (state.lastOutputs.isEmpty) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToolResultScreen(
          outputPaths: state.lastOutputs,
          operationName: state.operationName ?? '',
          processingTimeMs: state.processingTimeMs,
          inputSizeBytes: state.inputSizeBytes,
          outputSizeBytes: state.outputSizeBytes,
          onProcessAnother: onProcessAnother,
        ),
      ),
    );
  }

  // ---- Pickers -------------------------------------------------------

  static Future<List<String>?> _pickPdfs({bool multiple = true}) async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: multiple,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final paths = picked?.paths.whereType<String>().toList();
    return (paths == null || paths.isEmpty) ? null : paths;
  }

  // ---- Tool flows ----------------------------------------------------

  static Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs();
    if (sources == null || sources.length < 2) return;
    final dir = await _saveDir();
    await ref
        .read(pdfToolsProvider.notifier)
        .merge(sources, _outPath(dir, sources.first, 'merged'));
    await _showResult(context, ref,
        onProcessAnother: () => _merge(context, ref));
  }

  static Future<void> _split(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final ranges = await _promptRanges(context);
    if (ranges == null || ranges.isEmpty) return;
    final dir = await _saveDir();
    await ref
        .read(pdfToolsProvider.notifier)
        .split(sources.single, ranges, dir);
    await _showResult(context, ref,
        onProcessAnother: () => _split(context, ref));
  }

  static Future<void> _compress(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final quality = await _promptCompressionQuality(context);
    if (quality == null) return;
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).compress(
          sources.single,
          _outPath(dir, sources.single, 'compressed'),
          quality,
        );
    await _showResult(context, ref,
        onProcessAnother: () => _compress(context, ref));
  }

  static Future<void> _imagesToPdf(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    final images = picked?.paths.whereType<String>().toList();
    if (images == null || images.isEmpty) return;
    final dir = await _saveDir();
    await ref
        .read(pdfToolsProvider.notifier)
        .imagesToPdf(images, _outPath(dir, images.first, 'images'));
    await _showResult(context, ref,
        onProcessAnother: () => _imagesToPdf(context, ref));
  }

  static Future<void> _pagesOp(
    BuildContext context,
    WidgetRef ref,
    _PagesOp op,
  ) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;

    final source = sources.single;
    final dir = await _saveDir();
    final notifier = ref.read(pdfToolsProvider.notifier);

    switch (op) {
      case _PagesOp.reorder:
        final pages = await _promptPageList(context);
        if (pages == null || pages.isEmpty) return;
        await notifier.reorderPages(
            source, _outPath(dir, source, 'reordered'), pages);
      case _PagesOp.delete:
        final pages = await _promptPageList(context);
        if (pages == null || pages.isEmpty) return;
        await notifier.deletePages(
            source, _outPath(dir, source, 'edited'), pages);
      case _PagesOp.rotate:
        if (!context.mounted) return;
        final degrees = await _promptRotation(context);
        if (degrees == null) return;
        if (!context.mounted) return;
        final pages = await _promptPageListOrAll(context);
        if (pages == null) return;
        await notifier.rotatePages(
            source, _outPath(dir, source, 'rotated'), pages, degrees);
    }

    await _showResult(context, ref,
        onProcessAnother: () => _pagesOp(context, ref, op));
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
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).extractPages(
          sources.single,
          _outPath(dir, sources.single, 'extract'),
          ranges.first,
        );
    await _showResult(context, ref,
        onProcessAnother: () => _extractPages(context, ref));
  }

  static Future<void> _watermark(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final spec = await showDialog<WatermarkSpec>(
      context: context,
      builder: (context) => const _WatermarkDialog(),
    );
    if (spec == null) return;
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).watermark(
          sources.single,
          _outPath(dir, sources.single, 'watermarked'),
          spec,
        );
    await _showResult(context, ref,
        onProcessAnother: () => _watermark(context, ref));
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
    final dir = await _saveDir();
    await notifier.setMetadata(
      sources.single,
      _outPath(dir, sources.single, 'meta'),
      updated,
    );
    await _showResult(context, ref,
        onProcessAnother: () => _metadata(context, ref));
  }

  static Future<void> _encrypt(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final spec = await showDialog<PdfEncryptSpec>(
      context: context,
      builder: (context) => const _EncryptDialog(),
    );
    if (spec == null) return;
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).encrypt(
          sources.single,
          _outPath(dir, sources.single, 'encrypted'),
          spec,
        );
    await _showResult(context, ref,
        onProcessAnother: () => _encrypt(context, ref));
  }

  static Future<void> _decrypt(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final password = await _promptPassword(
      context,
      AppLocalizations.of(context).password,
    );
    if (password == null) return;
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).decrypt(
          sources.single,
          _outPath(dir, sources.single, 'unlocked'),
          password,
        );
    await _showResult(context, ref,
        onProcessAnother: () => _decrypt(context, ref));
  }

  // ---- Prompts --------------------------------------------------------

  static Future<String?> _promptText(BuildContext context, String title,
      {bool obscure = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
        ),
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

  static Future<String?> _promptPassword(BuildContext context, String title) =>
      _promptText(context, title, obscure: true);

  static Future<List<PageRange>?> _promptRanges(BuildContext context) async {
    final raw = await _promptText(
        context, AppLocalizations.of(context).pageRangesHint);
    if (raw == null) return null;
    return parsePageRanges(raw);
  }

  static Future<List<int>?> _promptPageList(BuildContext context) async {
    final raw =
        await _promptText(context, AppLocalizations.of(context).pageListHint);
    if (raw == null) return null;
    return [
      for (final range in parsePageRanges(raw))
        for (var page = range.start; page <= range.end; page++) page,
    ];
  }

  /// Returns null if cancelled, empty list if user chose "all pages".
  static Future<List<int>?> _promptPageListOrAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<_PageChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.rotatePages),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_PageChoice.all),
            child: const Text('All pages'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_PageChoice.select),
            child: Text(l10n.pageListHint),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    if (choice == _PageChoice.all) return const [];
    return _promptPageList(context);
  }

  static Future<int?> _promptRotation(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).rotate),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(90),
            child: const Text('90°'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(180),
            child: const Text('180°'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(270),
            child: const Text('270°'),
          ),
        ],
      ),
    );
  }

  static Future<CompressionQuality?> _promptCompressionQuality(
      BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<CompressionQuality>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.compressPdf),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(CompressionQuality.high),
            child: const ListTile(
              title: Text('High quality (larger file)'),
              leading: Icon(Icons.hd),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(CompressionQuality.medium),
            child: const ListTile(
              title: Text('Balanced (recommended)'),
              leading: Icon(Icons.tune),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(CompressionQuality.low),
            child: const ListTile(
              title: Text('Maximum compression (smaller file)'),
              leading: Icon(Icons.compress),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
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
enum _PageChoice { all, select }

class _Tool {
  const _Tool(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ---- Dialogs ---------------------------------------------------------------

class _WatermarkDialog extends StatefulWidget {
  const _WatermarkDialog();

  @override
  State<_WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<_WatermarkDialog> {
  final _text = TextEditingController();
  double _opacity = 0.25;
  double _fontSize = 48;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.watermarkPdf),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              decoration: InputDecoration(labelText: l10n.watermarkText),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Opacity'),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.05,
                    max: 1.0,
                    divisions: 19,
                    label: '${(_opacity * 100).round()}%',
                    onChanged: (v) => setState(() => _opacity = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Size'),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 12,
                    max: 120,
                    divisions: 18,
                    label: '${_fontSize.round()}pt',
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
              ],
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
          onPressed: _text.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    WatermarkSpec(
                      text: _text.text,
                      opacity: _opacity,
                      fontSize: _fontSize,
                    ),
                  ),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
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

class _EncryptDialog extends StatefulWidget {
  const _EncryptDialog();

  @override
  State<_EncryptDialog> createState() => _EncryptDialogState();
}

class _EncryptDialogState extends State<_EncryptDialog> {
  final _userPw = TextEditingController();
  final _ownerPw = TextEditingController();
  bool _allowPrinting = true;
  bool _allowCopying = false;
  bool _allowEditing = false;
  bool _allowAnnotating = true;

  @override
  void initState() {
    super.initState();
    _userPw.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _userPw.dispose();
    _ownerPw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.encryptPdf),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _userPw,
              decoration: InputDecoration(labelText: l10n.userPassword),
              obscureText: true,
              autofocus: true,
            ),
            TextField(
              controller: _ownerPw,
              decoration: InputDecoration(
                labelText: l10n.ownerPassword,
                hintText: '(optional)',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Text(l10n.permissions,
                style: Theme.of(context).textTheme.labelLarge),
            CheckboxListTile(
              dense: true,
              title: Text(l10n.allowPrinting),
              value: _allowPrinting,
              onChanged: (v) => setState(() => _allowPrinting = v ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              dense: true,
              title: Text(l10n.allowCopying),
              value: _allowCopying,
              onChanged: (v) => setState(() => _allowCopying = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              dense: true,
              title: Text(l10n.allowEditing),
              value: _allowEditing,
              onChanged: (v) => setState(() => _allowEditing = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              dense: true,
              title: Text(l10n.allowAnnotating),
              value: _allowAnnotating,
              onChanged: (v) => setState(() => _allowAnnotating = v ?? true),
              contentPadding: EdgeInsets.zero,
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
          onPressed: _userPw.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    PdfEncryptSpec(
                      userPassword: _userPw.text,
                      ownerPassword: _ownerPw.text,
                      allowPrinting: _allowPrinting,
                      allowCopying: _allowCopying,
                      allowEditing: _allowEditing,
                      allowAnnotating: _allowAnnotating,
                    ),
                  ),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
