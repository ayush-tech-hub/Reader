import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/save_location_service.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../providers/pdf_tools_providers.dart';
import 'pdf_editor_screen.dart';
import 'tool_result_screen.dart';

/// Hub for all PDF utilities. Each tile picks inputs, runs the operation
/// using the default save folder (CompressX/PDFs/ or CompressX/Images/), then
/// pushes [ToolResultScreen] on success.
///
/// When [initialAction] is provided (one of `'merge'`, `'split'`,
/// `'compress'`), the corresponding tool is triggered automatically after
/// the first frame.
class PdfToolsScreen extends ConsumerStatefulWidget {
  const PdfToolsScreen({super.key, this.initialAction});

  final String? initialAction;

  @override
  ConsumerState<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends ConsumerState<PdfToolsScreen> {
  @override
  void initState() {
    super.initState();
    final action = widget.initialAction;
    if (action != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (action) {
          case 'merge':
            _merge(context, ref).ignore();
            break;
          case 'split':
            _split(context, ref).ignore();
            break;
          case 'compress':
            _compress(context, ref).ignore();
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(pdfToolsProvider);

    // Show errors as dismissable SnackBars rather than a persisting tile.
    ref.listen(pdfToolsProvider.select((s) => s.lastError), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.onError),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l10n.ok,
            textColor: theme.colorScheme.onError,
            onPressed: () => ref.read(pdfToolsProvider.notifier).clearError(),
          ),
        ),
      );
    });

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
      _Tool(
        Icons.water_drop_outlined,
        l10n.removeWatermark,
        () => _removeWatermark(context, ref),
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
  static Future<String> _saveDirImages() => _saveService.getSubDir('Images');

  static String _outPath(String dir, String source, String suffix) =>
      p.join(dir, '${p.basenameWithoutExtension(source)}_$suffix.pdf');

  static Future<void> _changeOutputFolder(BuildContext context) async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    await _saveService.setCustomSaveDir(dir);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dir)));
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
      MaterialPageRoute<void>(
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
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PdfEditorScreen(mode: PdfEditorMode.merge, sourcePaths: sources),
      ),
    );
  }

  static Future<void> _split(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PdfEditorScreen(mode: PdfEditorMode.split, sourcePaths: sources),
      ),
    );
  }

  static Future<void> _compress(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final spec =
        await showDialog<(CompressionQuality, CustomCompressionSettings?)>(
      context: context,
      builder: (_) => const _CompressionDialog(),
    );
    if (spec == null) return;
    final (quality, custom) = spec;
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).compress(
          sources.single,
          _outPath(dir, sources.single, 'compressed'),
          quality,
          customSettings: custom,
        );
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _compress(context, ref),
    );
  }

  static Future<void> _imagesToPdf(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    final images = picked?.paths.whereType<String>().toList();
    if (images == null || images.isEmpty) return;
    final dir = await _saveDirImages();
    await ref
        .read(pdfToolsProvider.notifier)
        .imagesToPdf(images, _outPath(dir, images.first, 'images'));
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _imagesToPdf(context, ref),
    );
  }

  static Future<void> _pagesOp(
    BuildContext context,
    WidgetRef ref,
    _PagesOp op,
  ) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final mode = switch (op) {
      _PagesOp.reorder => PdfEditorMode.reorder,
      _PagesOp.delete => PdfEditorMode.delete,
      _PagesOp.rotate => PdfEditorMode.rotate,
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfEditorScreen(mode: mode, sourcePaths: sources),
      ),
    );
  }

  static Future<void> _extractPages(BuildContext context, WidgetRef ref) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PdfEditorScreen(mode: PdfEditorMode.extract, sourcePaths: sources),
      ),
    );
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
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _watermark(context, ref),
    );
  }

  static Future<void> _removeWatermark(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final sources = await _pickPdfs(multiple: false);
    if (sources == null) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Watermark'),
        content: const Text(
          'This will remove annotation-based watermarks and appended '
          'content-stream watermarks. Watermarks baked into the original '
          'page content cannot be removed.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final dir = await _saveDir();
    await ref.read(pdfToolsProvider.notifier).removeWatermark(
          sources.single,
          _outPath(dir, sources.single, 'no_watermark'),
        );
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _removeWatermark(context, ref),
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
    final dir = await _saveDir();
    await notifier.setMetadata(
      sources.single,
      _outPath(dir, sources.single, 'meta'),
      updated,
    );
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _metadata(context, ref),
    );
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
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _encrypt(context, ref),
    );
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
    if (!context.mounted) return;
    await _showResult(
      context,
      ref,
      onProcessAnother: () => _decrypt(context, ref),
    );
  }

  // ---- Prompts --------------------------------------------------------

  static Future<String?> _promptText(
    BuildContext context,
    String title, {
    bool obscure = false,
  }) {
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
}

// ---------------------------------------------------------------------------
// Custom Compression Dialog
// ---------------------------------------------------------------------------

class _CompressionDialog extends StatefulWidget {
  const _CompressionDialog();

  @override
  State<_CompressionDialog> createState() => _CompressionDialogState();
}

class _CompressionDialogState extends State<_CompressionDialog> {
  bool _isCustom = false;

  // preset
  CompressionQuality _preset = CompressionQuality.medium;

  // custom
  double _imageQuality = 75;
  int _dpi = 150;

  static const _dpiOptions = [72, 96, 150, 300];

  (CompressionQuality, CustomCompressionSettings?) get _result => _isCustom
      ? (
          CompressionQuality.medium,
          CustomCompressionSettings(
            imageQuality: _imageQuality.round(),
            dpi: _dpi,
          ),
        )
      : (_preset, null);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Compress PDF'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Presets')),
                ButtonSegment(value: true, label: Text('Custom')),
              ],
              selected: {_isCustom},
              onSelectionChanged: (s) => setState(() => _isCustom = s.first),
            ),
            const SizedBox(height: 16),
            if (!_isCustom) ...[
              _PresetTile(
                icon: Icons.hd,
                title: 'High quality',
                subtitle: 'Smaller reduction, better visual result',
                selected: _preset == CompressionQuality.high,
                onTap: () => setState(() => _preset = CompressionQuality.high),
              ),
              _PresetTile(
                icon: Icons.tune,
                title: 'Balanced',
                subtitle: 'Recommended for most documents',
                selected: _preset == CompressionQuality.medium,
                onTap: () =>
                    setState(() => _preset = CompressionQuality.medium),
              ),
              _PresetTile(
                icon: Icons.compress,
                title: 'Maximum compression',
                subtitle: 'Smallest file, reduced quality',
                selected: _preset == CompressionQuality.low,
                onTap: () => setState(() => _preset = CompressionQuality.low),
              ),
            ] else ...[
              Text(
                'Image quality: ${_imageQuality.round()}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Slider(
                value: _imageQuality,
                min: 10,
                max: 100,
                divisions: 18,
                label: '${_imageQuality.round()}%',
                onChanged: (v) => setState(() => _imageQuality = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Resolution (DPI)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final dpi in _dpiOptions)
                    ChoiceChip(
                      label: Text('$dpi'),
                      selected: _dpi == dpi,
                      onSelected: (_) => setState(() => _dpi = dpi),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _dpiDescription(_dpi),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_result),
          icon: const Icon(Icons.compress, size: 18),
          label: const Text('Compress'),
        ),
      ],
    );
  }

  String _dpiDescription(int dpi) => switch (dpi) {
        72 => 'Screen quality — smallest file size',
        96 => 'Low quality — good for email attachments',
        150 => 'Good quality — recommended for most uses',
        300 => 'Print quality — larger file size',
        _ => '',
      };
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? scheme.primaryContainer.withAlpha(128)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected ? scheme.primary : null,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: scheme.primary, size: 20),
          ],
        ),
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
            Text(
              l10n.permissions,
              style: Theme.of(context).textTheme.labelLarge,
            ),
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
