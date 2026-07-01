import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../generated/app_localizations.dart';
import '../../../reading_notes/presentation/reading_notes_screen.dart';
import '../../domain/entities/reader_entities.dart';
import '../providers/reader_providers.dart';
import '../widgets/annotation_overlay.dart';

/// Full-featured single-document reader.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _controller = PdfViewerController();
  late final _searcher = PdfTextSearcher(_controller);
  final _searchFieldController = TextEditingController();
  int _quarterTurns = 0;
  List<PdfOutlineNode> _outline = const [];
  int? _sessionId;

  ReaderNotifier get _notifier =>
      ref.read(readerProvider(widget.path).notifier);

  @override
  void dispose() {
    _endSession();
    _searcher.dispose();
    _searchFieldController.dispose();
    super.dispose();
  }

  Future<void> _startSession(int startPage) async {
    _sessionId = await ref
        .read(readingStatsServiceProvider)
        .startSession(path: widget.path, startPage: startPage);
  }

  void _endSession() {
    final sid = _sessionId;
    if (sid == null) return;
    _sessionId = null;
    final endPage =
        ref.read(readerProvider(widget.path)).currentPage;
    ref
        .read(readingStatsServiceProvider)
        .endSession(sessionId: sid, endPage: endPage);
  }

  Future<String?> _askPassword() async {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.passwordRequired),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.password),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.open),
          ),
        ],
      ),
    );
    return (password == null || password.isEmpty) ? null : password;
  }

  void _fitToWidth() {
    if (!_controller.isReady) return;
    // ignore: deprecated_member_use — pages is the stable synchronous API
    final pages = _controller.pages;
    final state = ref.read(readerProvider(widget.path));
    if (pages.isEmpty) return;
    final page = pages[(state.currentPage - 1).clamp(0, pages.length - 1)];
    final zoom = _controller.viewSize.width / page.width;
    _controller.setZoom(_controller.centerPosition, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Narrow selects so page turns (currentPage changes) don't rebuild
    // the viewer subtree; page-dependent widgets use their own Consumer.
    final provider = readerProvider(widget.path);
    final isSearching = ref.watch(provider.select((s) => s.isSearching));
    final pageMode = ref.watch(provider.select((s) => s.pageMode));
    final activeTool = ref.watch(provider.select((s) => s.activeTool));
    final toolColor = ref.watch(provider.select((s) => s.toolColor));
    final annotations = ref.watch(provider.select((s) => s.annotations));

    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: _searchFieldController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchInDocument,
                  border: InputBorder.none,
                ),
                onSubmitted: (query) {
                  _notifier.setSearchQuery(query);
                  _searcher.startTextSearch(query);
                },
              )
            : Text(p.basename(widget.path), overflow: TextOverflow.ellipsis),
        actions: [
          if (isSearching) ...[
            // Scoped to the searcher: match ticks repaint these two
            // buttons, not the whole screen.
            ListenableBuilder(
              listenable: _searcher,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.previousMatch,
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed:
                        _searcher.hasMatches ? _searcher.goToPrevMatch : null,
                  ),
                  IconButton(
                    tooltip: l10n.nextMatch,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed:
                        _searcher.hasMatches ? _searcher.goToNextMatch : null,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searcher.resetTextSearch();
                _searchFieldController.clear();
                _notifier.setSearching(false);
              },
            ),
          ] else ...[
            IconButton(
              tooltip: l10n.search,
              icon: const Icon(Icons.search),
              onPressed: () => _notifier.setSearching(true),
            ),
            Consumer(
              builder: (context, ref, _) {
                final bookmarked = ref.watch(
                  provider.select((s) => s.isCurrentPageBookmarked),
                );
                return IconButton(
                  tooltip: l10n.bookmarkPage,
                  icon: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  ),
                  onPressed: _notifier.toggleBookmark,
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: _onMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(value: 'toc', child: Text(l10n.tableOfContents)),
                PopupMenuItem(value: 'bookmarks', child: Text(l10n.bookmarks)),
                PopupMenuItem(
                  value: 'pageMode',
                  child: Text(
                    pageMode == ReaderPageMode.continuous
                        ? l10n.pageByPage
                        : l10n.continuousScroll,
                  ),
                ),
                PopupMenuItem(value: 'rotate', child: Text(l10n.rotate)),
                PopupMenuItem(value: 'fitWidth', child: Text(l10n.fitToWidth)),
                PopupMenuItem(value: 'split', child: Text(l10n.splitScreen)),
                PopupMenuItem(value: 'readAloud', child: Text(l10n.readAloud)),
                const PopupMenuItem(
                    value: 'docInfo', child: Text('Document info')),
                const PopupMenuItem(
                    value: 'allAnnotations',
                    child: Text('All annotations')),
                const PopupMenuItem(
                    value: 'pageNote', child: Text('Note for this page')),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'share', child: Text(l10n.shareFile)),
              ],
            ),
          ],
        ],
      ),
      body: RotatedBox(
        quarterTurns: _quarterTurns,
        child: PdfViewer.file(
          widget.path,
          controller: _controller,
          passwordProvider: _askPassword,
          params: PdfViewerParams(
            layoutPages:
                pageMode == ReaderPageMode.single ? _singlePageLayout : null,
            onViewerReady: (document, controller) async {
              await _notifier.onDocumentOpened(document.pages.length);
              final outline = await document.loadOutline();
              if (mounted) setState(() => _outline = outline);
              final startPage =
                  ref.read(readerProvider(widget.path)).currentPage;
              await _startSession(startPage);
            },
            onPageChanged: (pageNumber) {
              if (pageNumber != null) {
                _notifier.onPageChanged(pageNumber, _controller.currentZoom);
              }
            },
            pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
            pageOverlaysBuilder: (context, pageRect, page) {
              final scale = pageRect.width / page.width;
              return [
                IgnorePointer(
                  child: CustomPaint(
                    size: pageRect.size,
                    painter: AnnotationPainter(
                      annotations: annotations
                          .where((a) => a.page == page.pageNumber)
                          .toList(),
                      scale: scale,
                    ),
                  ),
                ),
                if (activeTool == ReaderTool.ink)
                  InkCaptureOverlay(
                    scale: scale,
                    color: Color(toolColor),
                    onStrokeFinished: (stroke) => _notifier.addAnnotation(
                      page: page.pageNumber,
                      type: AnnotationType.ink,
                      strokes: [stroke],
                    ),
                  ),
                if (activeTool == ReaderTool.note)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _addNoteAt(
                      page.pageNumber,
                      details.localPosition,
                      scale,
                    ),
                  ),
              ];
            },
            // Default selection menu already offers copy/select-all —
            // that's the "extract selected text" path.
            selectableRegionInjector: (context, child) => SelectionArea(
              contextMenuBuilder: (context, selectableRegionState) =>
                  AdaptiveTextSelectionToolbar.buttonItems(
                anchors: selectableRegionState.contextMenuAnchors,
                buttonItems: selectableRegionState.contextMenuButtonItems,
              ),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _AnnotationToolbar(path: widget.path),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final (current, total) = ref.watch(
            provider.select((s) => (s.currentPage, s.totalPages)),
          );
          if (total == 0) return const SizedBox.shrink();
          return _PageIndicator(
            current: current,
            total: total,
            onJump: (page) => _controller.goToPage(pageNumber: page),
          );
        },
      ),
    );
  }

  /// Lays pages out horizontally so each fills the viewport (page-by-
  /// page reading mode).
  static PdfPageLayout _singlePageLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    final height =
        pages.fold(0.0, (h, page) => h < page.height ? page.height : h) +
            params.margin * 2;
    final pageLayouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      pageLayouts.add(
        Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
      );
      x += page.width + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(x, height),
    );
  }

  Future<void> _addNoteAt(int pageNumber, Offset local, double scale) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    final x = local.dx / scale;
    final y = local.dy / scale;
    await _notifier.addAnnotation(
      page: pageNumber,
      type: AnnotationType.note,
      rects: [PageRect(x - 6, y - 6, x + 6, y + 6)],
      note: note,
    );
  }

  void _onMenuAction(String action) {
    final state = ref.read(readerProvider(widget.path));
    switch (action) {
      case 'toc':
        _showOutline();
      case 'bookmarks':
        _showBookmarks();
      case 'pageMode':
        _notifier.setPageMode(
          state.pageMode == ReaderPageMode.continuous
              ? ReaderPageMode.single
              : ReaderPageMode.continuous,
        );
      case 'rotate':
        setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
      case 'fitWidth':
        _fitToWidth();
      case 'split':
        unawaited(_openSplitView());
      case 'readAloud':
        unawaited(_toggleReadAloud());
      case 'docInfo':
        unawaited(_showDocInfo());
      case 'allAnnotations':
        unawaited(context.push(Routes.annotationsExport));
      case 'pageNote':
        unawaited(_openPageNote());
      case 'share':
        unawaited(Share.shareXFiles([XFile(widget.path)]));
    }
  }

  Future<void> _showDocInfo() async {
    final file = File(widget.path);
    final fileSizeBytes = file.existsSync() ? await file.length() : 0;
    final state = ref.read(readerProvider(widget.path));
    final totalPages = state.totalPages;

    // Count words across indexed content if available.
    int wordCount = 0;
    int charCount = 0;
    if (_controller.isReady) {
      // ignore: deprecated_member_use
      final pages = _controller.pages;
      for (final pg in pages.take(5)) {
        final text = await pg.loadText();
        charCount += text.fullText.length;
        wordCount += text.fullText
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
      }
      if (pages.length > 5) {
        // Extrapolate from first 5 pages.
        wordCount = (wordCount / 5 * pages.length).round();
        charCount = (charCount / 5 * pages.length).round();
      }
    }

    final readingMins = wordCount > 0 ? (wordCount / 200).ceil() : 0;
    final fileSizeMb = fileSizeBytes / (1024 * 1024);

    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Document info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow('Pages', '$totalPages'),
            _InfoRow('Est. words', _fmtNum(wordCount)),
            _InfoRow('Est. characters', _fmtNum(charCount)),
            _InfoRow('Reading time', '~$readingMins min'),
            _InfoRow(
              'File size',
              fileSizeMb < 1
                  ? '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB'
                  : '${fileSizeMb.toStringAsFixed(1)} MB',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ));
  }

  Future<void> _openPageNote() async {
    final current = ref.read(readerProvider(widget.path)).currentPage;
    if (!mounted) return;
    await NoteEditorSheet.show(
      context,
      documentPath: widget.path,
      page: current,
    );
  }

  static String _fmtNum(int n) {
    if (n == 0) return '–';
    if (n < 1000) return '$n';
    return '${(n / 1000).toStringAsFixed(1)}k';
  }

  /// Reads the current page aloud via the OS TTS engine; tapping the
  /// menu item again stops playback.
  Future<void> _toggleReadAloud() async {
    final tts = ref.read(ttsServiceProvider);
    if (tts.isSpeaking) {
      await tts.stop();
      return;
    }
    if (!_controller.isReady) return;
    // ignore: deprecated_member_use — pages is the stable synchronous API
    final pages = _controller.pages;
    if (pages.isEmpty) return;
    final current = ref.read(readerProvider(widget.path)).currentPage;
    final text =
        await pages[(current - 1).clamp(0, pages.length - 1)].loadText();
    await tts.speak(text.fullText);
  }

  /// Picks a second document and opens it side-by-side with this one.
  Future<void> _openSplitView() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final other = picked?.files.single.path;
    if (other == null || !mounted) return;
    unawaited(
      context.push(
        Uri(
          path: Routes.splitReader,
          queryParameters: {'left': widget.path, 'right': other},
        ).toString(),
      ),
    );
  }

  void _showOutline() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _OutlineList(
        outline: _outline,
        onTap: (page) {
          Navigator.of(context).pop();
          _controller.goToPage(pageNumber: page);
        },
      ),
    );
  }

  void _showBookmarks() {
    final state = ref.read(readerProvider(widget.path));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          for (final bookmark in state.bookmarks)
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text(
                bookmark.label.isEmpty
                    ? AppLocalizations.of(context).pageN(bookmark.page)
                    : bookmark.label,
              ),
              onTap: () {
                Navigator.of(context).pop();
                _controller.goToPage(pageNumber: bookmark.page);
              },
            ),
        ],
      ),
    );
  }
}

class _OutlineList extends StatelessWidget {
  const _OutlineList({required this.outline, required this.onTap});

  final List<PdfOutlineNode> outline;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final flat = <(int depth, PdfOutlineNode node)>[];
    void walk(List<PdfOutlineNode> nodes, int depth) {
      for (final node in nodes) {
        flat.add((depth, node));
        walk(node.children, depth + 1);
      }
    }

    walk(outline, 0);

    if (flat.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(AppLocalizations.of(context).noTableOfContents),
        ),
      );
    }
    return ListView.builder(
      itemCount: flat.length,
      itemBuilder: (context, index) {
        final (depth, node) = flat[index];
        final page = node.dest?.pageNumber;
        return ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
          title: Text(node.title),
          trailing: page == null ? null : Text('$page'),
          onTap: page == null ? null : () => onTap(page),
        );
      },
    );
  }
}

class _AnnotationToolbar extends ConsumerWidget {
  const _AnnotationToolbar({required this.path});

  final String path;

  static const _colors = [0xFFFFEB3B, 0xFFFF5252, 0xFF40C4FF, 0xFF69F0AE];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (activeTool, toolColor) = ref.watch(
      readerProvider(path).select((s) => (s.activeTool, s.toolColor)),
    );
    final notifier = ref.read(readerProvider(path).notifier);
    final l10n = AppLocalizations.of(context);

    Widget toolButton(ReaderTool tool, IconData icon, String tooltip) =>
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          isSelected: activeTool == tool,
          onPressed: () => notifier.setTool(tool),
        );

    return BottomAppBar(
      height: 64,
      child: Row(
        children: [
          toolButton(ReaderTool.highlight, Icons.border_color, l10n.highlight),
          toolButton(
            ReaderTool.underline,
            Icons.format_underline,
            l10n.underline,
          ),
          toolButton(
            ReaderTool.strikeout,
            Icons.format_strikethrough,
            l10n.strikethrough,
          ),
          toolButton(ReaderTool.ink, Icons.draw, l10n.draw),
          toolButton(ReaderTool.note, Icons.note_add_outlined, l10n.addNote),
          const Spacer(),
          for (final color in _colors)
            GestureDetector(
              onTap: () => notifier.setToolColor(color),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: toolColor == color ? Border.all(width: 2) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.current,
    required this.total,
    required this.onJump,
  });

  final int current;
  final int total;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: null,
      onPressed: () async {
        final controller = TextEditingController();
        final page = await showDialog<int>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).goToPage),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              onSubmitted: (value) =>
                  Navigator.of(context).pop(int.tryParse(value)),
            ),
            actions: [
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(int.tryParse(controller.text)),
                child: Text(AppLocalizations.of(context).ok),
              ),
            ],
          ),
        );
        if (page != null && page >= 1 && page <= total) onJump(page);
      },
      label: Text('$current / $total'),
    );
  }
}

/// Side-by-side reading of two documents (or two views of one).
class SplitReaderScreen extends StatelessWidget {
  const SplitReaderScreen({
    super.key,
    required this.leftPath,
    required this.rightPath,
  });

  final String leftPath;
  final String rightPath;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final children = [
      Expanded(child: ReaderScreen(path: leftPath)),
      const SizedBox(width: 1, height: 1),
      Expanded(child: ReaderScreen(path: rightPath)),
    ];
    return Scaffold(
      body: SafeArea(
        child: isWide ? Row(children: children) : Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
