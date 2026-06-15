import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/services/save_location_service.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../providers/pdf_tools_providers.dart';
import 'tool_result_screen.dart';

enum PdfEditorMode { merge, split, reorder, delete, rotate, extract }

class _PageEntry {
  _PageEntry({
    required this.sourcePath,
    required this.sourcePageIndex,
    this.markedForDeletion = false,
    this.pendingRotation = 0,
  });

  final String sourcePath;
  final int sourcePageIndex; // 0-based

  bool markedForDeletion;
  int pendingRotation; // 0 | 90 | 180 | 270

  _PageEntry copy() => _PageEntry(
        sourcePath: sourcePath,
        sourcePageIndex: sourcePageIndex,
        markedForDeletion: markedForDeletion,
        pendingRotation: pendingRotation,
      );
}

class PdfEditorScreen extends ConsumerStatefulWidget {
  const PdfEditorScreen({
    super.key,
    required this.mode,
    required this.sourcePaths,
  });

  final PdfEditorMode mode;
  final List<String> sourcePaths;

  @override
  ConsumerState<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends ConsumerState<PdfEditorScreen> {
  final Map<String, PdfDocument> _docs = {};
  bool _loading = true;
  String? _loadError;

  List<_PageEntry> _pages = [];

  final List<List<_PageEntry>> _undoStack = [];
  final List<List<_PageEntry>> _redoStack = [];

  // Split mode: page indices before which a split occurs
  final Set<int> _splitBefore = {};

  // Rotate mode
  final Set<int> _selectedForRotate = {};
  int _rotateDegrees = 90;

  // Extract mode
  int? _extractStart;
  int? _extractEnd;

  bool _isApplying = false;

  static final _saveService = SaveLocationService();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    for (final doc in _docs.values) {
      doc.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    try {
      for (final path in widget.sourcePaths) {
        final doc = await PdfDocument.openFile(path);
        if (!mounted) return;
        _docs[path] = doc;
        if (widget.mode == PdfEditorMode.merge) {
          _pages.add(_PageEntry(sourcePath: path, sourcePageIndex: 0));
        } else {
          for (var i = 0; i < doc.pages.length; i++) {
            _pages.add(_PageEntry(sourcePath: path, sourcePageIndex: i));
          }
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ---- History -----------------------------------------------------------

  void _pushHistory() {
    _undoStack.add(_pages.map((e) => e.copy()).toList());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_pages.map((e) => e.copy()).toList());
    setState(() => _pages = _undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_pages.map((e) => e.copy()).toList());
    setState(() => _pages = _redoStack.removeLast());
  }

  // ---- Tile tap ----------------------------------------------------------

  void _handleTileTap(int index) {
    switch (widget.mode) {
      case PdfEditorMode.delete:
        _pushHistory();
        setState(
          () =>
              _pages[index].markedForDeletion =
                  !_pages[index].markedForDeletion,
        );
      case PdfEditorMode.rotate:
        setState(() {
          if (_selectedForRotate.contains(index)) {
            _selectedForRotate.remove(index);
          } else {
            _selectedForRotate.add(index);
          }
        });
      case PdfEditorMode.extract:
        setState(() {
          if (_extractStart == null || (_extractEnd != null && index < _extractStart!)) {
            _extractStart = index;
            _extractEnd = index;
          } else if (index >= _extractStart!) {
            _extractEnd = index;
          } else {
            _extractStart = index;
          }
        });
      case PdfEditorMode.split:
        if (index > 0) {
          setState(() {
            if (_splitBefore.contains(index)) {
              _splitBefore.remove(index);
            } else {
              _splitBefore.add(index);
            }
          });
        }
      default:
        break;
    }
  }

  // ---- Apply -------------------------------------------------------------

  Future<void> _applyAndSave() async {
    setState(() => _isApplying = true);
    try {
      final notifier = ref.read(pdfToolsProvider.notifier);
      final dir = await _saveService.getDefaultSaveDir();
      final source = widget.sourcePaths.first;

      String out(String suffix) =>
          p.join(dir, '${p.basenameWithoutExtension(source)}_$suffix.pdf');

      switch (widget.mode) {
        case PdfEditorMode.merge:
          final ordered = _pages.map((e) => e.sourcePath).toList();
          await notifier.merge(ordered, out('merged'));
        case PdfEditorMode.split:
          if (_splitBefore.isEmpty) {
            _showSnack('Add split points first: tap a page to split before it');
            setState(() => _isApplying = false);
            return;
          }
          await notifier.split(source, _buildSplitRanges(), dir);
        case PdfEditorMode.reorder:
          final newOrder = _pages.map((e) => e.sourcePageIndex + 1).toList();
          await notifier.reorderPages(source, out('reordered'), newOrder);
        case PdfEditorMode.delete:
          final toDelete = _pages
              .where((e) => e.markedForDeletion)
              .map((e) => e.sourcePageIndex + 1)
              .toList();
          if (toDelete.isEmpty) {
            _showSnack('Tap pages to mark them for deletion first');
            setState(() => _isApplying = false);
            return;
          }
          await notifier.deletePages(source, out('edited'), toDelete);
        case PdfEditorMode.rotate:
          final pages = _selectedForRotate.isEmpty
              ? <int>[]
              : _selectedForRotate
                    .map((i) => _pages[i].sourcePageIndex + 1)
                    .toList();
          await notifier.rotatePages(source, out('rotated'), pages, _rotateDegrees);
        case PdfEditorMode.extract:
          final start = _extractStart;
          final end = _extractEnd;
          if (start == null || end == null) {
            _showSnack('Select the page range to extract first');
            setState(() => _isApplying = false);
            return;
          }
          final range = PageRange(
            _pages[start].sourcePageIndex + 1,
            _pages[end].sourcePageIndex + 1,
          );
          await notifier.extractPages(source, out('extract'), range);
      }

      if (!mounted) return;
      final state = ref.read(pdfToolsProvider);
      if (state.lastError != null) {
        _showSnack(state.lastError!);
        setState(() => _isApplying = false);
        return;
      }
      if (state.lastOutputs.isEmpty) {
        setState(() => _isApplying = false);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ToolResultScreen(
            outputPaths: state.lastOutputs,
            operationName: state.operationName ?? '',
            processingTimeMs: state.processingTimeMs,
            inputSizeBytes: state.inputSizeBytes,
            outputSizeBytes: state.outputSizeBytes,
          ),
        ),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  List<PageRange> _buildSplitRanges() {
    final total = _pages.length;
    final sorted = _splitBefore.toList()..sort();
    final bounds = [0, ...sorted, total];
    return [
      for (var i = 0; i < bounds.length - 1; i++)
        PageRange(
          _pages[bounds[i]].sourcePageIndex + 1,
          _pages[bounds[i + 1] - 1].sourcePageIndex + 1,
        ),
    ];
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- Add more PDFs (merge only) ----------------------------------------

  Future<void> _addMorePdfs() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final paths = result?.paths.whereType<String>().toList();
    if (paths == null || paths.isEmpty) return;
    for (final path in paths) {
      if (_docs.containsKey(path)) continue;
      try {
        final doc = await PdfDocument.openFile(path);
        if (!mounted) return;
        _docs[path] = doc;
        setState(
          () => _pages.add(_PageEntry(sourcePath: path, sourcePageIndex: 0)),
        );
      } catch (_) {}
    }
  }

  // ---- Build -------------------------------------------------------------

  String _modeTitle(AppLocalizations l10n) => switch (widget.mode) {
        PdfEditorMode.merge => l10n.mergePdf,
        PdfEditorMode.split => l10n.splitPdf,
        PdfEditorMode.reorder => l10n.reorderPages,
        PdfEditorMode.delete => l10n.deletePages,
        PdfEditorMode.rotate => l10n.rotatePages,
        PdfEditorMode.extract => l10n.extractPages,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_modeTitle(l10n)),
        actions: [
          if (widget.mode == PdfEditorMode.merge)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add more PDFs',
              onPressed: _isApplying ? null : _addMorePdfs,
            ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undoStack.isEmpty || _isApplying ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: _redoStack.isEmpty || _isApplying ? null : _redo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(message: _loadError!)
              : _isApplying
                  ? const _ApplyingView()
                  : _buildEditor(context),
      bottomNavigationBar:
          _loading || _isApplying || _loadError != null ? null : _buildBottomBar(l10n),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return switch (widget.mode) {
      PdfEditorMode.merge || PdfEditorMode.reorder => _buildReorderList(),
      _ => _buildTapGrid(context),
    };
  }

  // ---- Reorder list (merge / reorder) ------------------------------------

  Widget _buildReorderList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      itemCount: _pages.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        _pushHistory();
        setState(() {
          if (oldIndex < newIndex) newIndex--;
          _pages.insert(newIndex, _pages.removeAt(oldIndex));
        });
      },
      itemBuilder: (ctx, i) {
        final entry = _pages[i];
        final doc = _docs[entry.sourcePath];
        return _ReorderTile(
          key: ValueKey('${entry.sourcePath}-${entry.sourcePageIndex}-$i'),
          index: i,
          entry: entry,
          doc: doc,
          isMergeMode: widget.mode == PdfEditorMode.merge,
          onRemove: _pages.length > 1
              ? () {
                  _pushHistory();
                  setState(() => _pages.removeAt(i));
                }
              : null,
        );
      },
    );
  }

  // ---- Tap grid (delete / rotate / extract / split) ----------------------

  Widget _buildTapGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.65,
      ),
      itemCount: _pages.length,
      itemBuilder: (ctx, i) {
        final entry = _pages[i];
        final doc = _docs[entry.sourcePath];
        return GestureDetector(
          onTap: () => _handleTileTap(i),
          child: _PageThumbnailCard(
            entry: entry,
            pageNumber: i + 1,
            doc: doc,
            overlay: _buildOverlay(i, entry, colorScheme),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(int i, _PageEntry entry, ColorScheme cs) {
    switch (widget.mode) {
      case PdfEditorMode.delete:
        if (entry.markedForDeletion) {
          return Container(
            color: cs.error.withValues(alpha: 0.6),
            alignment: Alignment.center,
            child: Icon(Icons.delete, color: cs.onError, size: 32),
          );
        }
        return const SizedBox.expand();

      case PdfEditorMode.rotate:
        if (_selectedForRotate.contains(i)) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.primary, width: 3),
            ),
            alignment: Alignment.topRight,
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_rotateDegrees°',
                style: TextStyle(color: cs.onPrimary, fontSize: 11),
              ),
            ),
          );
        }
        return const SizedBox.expand();

      case PdfEditorMode.extract:
        final inRange = _extractStart != null &&
            _extractEnd != null &&
            i >= _extractStart! &&
            i <= _extractEnd!;
        if (inRange) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.tertiary, width: 3),
              color: cs.tertiary.withValues(alpha: 0.15),
            ),
          );
        }
        return const SizedBox.expand();

      case PdfEditorMode.split:
        if (i > 0 && _splitBefore.contains(i)) {
          return Column(
            children: [
              Container(height: 4, color: cs.error),
              const Spacer(),
            ],
          );
        }
        return const SizedBox.expand();

      default:
        return const SizedBox.expand();
    }
  }

  // ---- Bottom bar --------------------------------------------------------

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHint(l10n),
            const SizedBox(height: 8),
            // Rotation selector shown inside bottom bar for rotate mode
            if (widget.mode == PdfEditorMode.rotate) ...[
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 90, label: Text('90°')),
                  ButtonSegment(value: 180, label: Text('180°')),
                  ButtonSegment(value: 270, label: Text('270°')),
                ],
                selected: {_rotateDegrees},
                onSelectionChanged: (s) =>
                    setState(() => _rotateDegrees = s.first),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(l10n.save),
                onPressed: _applyAndSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHint(AppLocalizations l10n) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );
    return switch (widget.mode) {
      PdfEditorMode.merge => Text(
          '${_pages.length} PDFs · drag to reorder · tap ✕ to remove',
          style: style,
        ),
      PdfEditorMode.split => Text(
          '${_splitBefore.length + 1} part(s) · tap page to set split point',
          style: style,
        ),
      PdfEditorMode.reorder => Text(
          '${_pages.length} pages · drag to reorder',
          style: style,
        ),
      PdfEditorMode.delete => Text(
          '${_pages.where((p) => p.markedForDeletion).length} pages marked · tap to toggle',
          style: style,
        ),
      PdfEditorMode.rotate => Text(
          _selectedForRotate.isEmpty
              ? 'Tap pages to select (empty selection = all pages)'
              : '${_selectedForRotate.length} pages selected',
          style: style,
        ),
      PdfEditorMode.extract => Text(
          _extractStart == null
              ? 'Tap first page of range'
              : _extractEnd == _extractStart
                  ? 'Start: p${_extractStart! + 1} · tap last page'
                  : 'Pages ${_extractStart! + 1}–${_extractEnd! + 1} selected',
          style: style,
        ),
    };
  }
}

// ---- Supporting widgets ----------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _ApplyingView extends StatelessWidget {
  const _ApplyingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Applying changes…'),
        ],
      ),
    );
  }
}

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    required super.key,
    required this.index,
    required this.entry,
    required this.doc,
    required this.isMergeMode,
    required this.onRemove,
  });

  final int index;
  final _PageEntry entry;
  final PdfDocument? doc;
  final bool isMergeMode;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 72,
              height: 96,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: _PageThumbnailContent(
                  doc: doc,
                  pageIndex: entry.sourcePageIndex,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMergeMode
                        ? p.basename(entry.sourcePath)
                        : 'Page ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isMergeMode
                        ? p.dirname(entry.sourcePath)
                        : 'Original page ${entry.sourcePageIndex + 1}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onRemove,
              ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageThumbnailCard extends StatelessWidget {
  const _PageThumbnailCard({
    required this.entry,
    required this.pageNumber,
    required this.doc,
    required this.overlay,
  });

  final _PageEntry entry;
  final int pageNumber;
  final PdfDocument? doc;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PageThumbnailContent(
            doc: doc,
            pageIndex: entry.sourcePageIndex,
            quarterTurns: entry.pendingRotation ~/ 90,
          ),
          overlay,
          // Page number badge
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pageNumber',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a single PDF page as a thumbnail using pdfrx.
class _PageThumbnailContent extends StatefulWidget {
  const _PageThumbnailContent({
    required this.doc,
    required this.pageIndex,
    this.quarterTurns = 0,
  });

  final PdfDocument? doc;
  final int pageIndex; // 0-based
  final int quarterTurns;

  @override
  State<_PageThumbnailContent> createState() => _PageThumbnailContentState();
}

class _PageThumbnailContentState extends State<_PageThumbnailContent> {
  ui.Image? _image;
  bool _rendering = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant _PageThumbnailContent old) {
    super.didUpdateWidget(old);
    if (old.doc != widget.doc || old.pageIndex != widget.pageIndex) {
      _image = null;
      _render();
    }
  }

  Future<void> _render() async {
    final doc = widget.doc;
    if (doc == null || _rendering) return;
    _rendering = true;
    try {
      final page = doc.pages[widget.pageIndex];
      const targetW = 120.0;
      final scale = targetW / page.width;
      final pdfImage = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (!mounted || pdfImage == null) return;

      final rawPixels = pdfImage.pixels;
      if (rawPixels == null) return;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rawPixels,
        pdfImage.width,
        pdfImage.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final uiImage = await completer.future;
      if (mounted) setState(() => _image = uiImage);
    } catch (_) {
      // Rendering failed — show placeholder
    } finally {
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    Widget rendered = RawImage(image: image, fit: BoxFit.cover);
    if (widget.quarterTurns != 0) {
      rendered = RotatedBox(quarterTurns: widget.quarterTurns, child: rendered);
    }
    return rendered;
  }
}

