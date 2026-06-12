import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/reader_entities.dart';
import '../../domain/usecases/reader_usecases.dart';

enum ReaderPageMode { continuous, single }

enum ReaderTool { none, highlight, underline, strikeout, ink, note }

@immutable
class ReaderState {
  const ReaderState({
    required this.documentPath,
    this.currentPage = 1,
    this.totalPages = 0,
    this.pageMode = ReaderPageMode.continuous,
    this.activeTool = ReaderTool.none,
    this.toolColor = 0xFFFFEB3B,
    this.bookmarks = const [],
    this.annotations = const [],
    this.searchQuery = '',
    this.isSearching = false,
  });

  final String documentPath;
  final int currentPage;
  final int totalPages;
  final ReaderPageMode pageMode;
  final ReaderTool activeTool;
  final int toolColor;
  final List<Bookmark> bookmarks;
  final List<Annotation> annotations;
  final String searchQuery;
  final bool isSearching;

  bool get isCurrentPageBookmarked =>
      bookmarks.any((b) => b.page == currentPage);

  ReaderState copyWith({
    int? currentPage,
    int? totalPages,
    ReaderPageMode? pageMode,
    ReaderTool? activeTool,
    int? toolColor,
    List<Bookmark>? bookmarks,
    List<Annotation>? annotations,
    String? searchQuery,
    bool? isSearching,
  }) =>
      ReaderState(
        documentPath: documentPath,
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
        pageMode: pageMode ?? this.pageMode,
        activeTool: activeTool ?? this.activeTool,
        toolColor: toolColor ?? this.toolColor,
        bookmarks: bookmarks ?? this.bookmarks,
        annotations: annotations ?? this.annotations,
        searchQuery: searchQuery ?? this.searchQuery,
        isSearching: isSearching ?? this.isSearching,
      );
}

/// One reader session per document path (family) so split-screen mode
/// gets two independent sessions.
final readerProvider = NotifierProvider.autoDispose
    .family<ReaderNotifier, ReaderState, String>(ReaderNotifier.new);

class ReaderNotifier extends AutoDisposeFamilyNotifier<ReaderState, String> {
  Timer? _saveDebounce;
  int? _pendingPage;
  double? _pendingZoom;
  late SaveReadingPosition _savePosition;

  @override
  ReaderState build(String arg) {
    _savePosition = ref.read(saveReadingPositionProvider);
    ref.onDispose(() {
      _saveDebounce?.cancel();
      _flushPosition();
    });
    Future.microtask(_loadPersisted);
    return ReaderState(documentPath: arg);
  }

  Future<void> _loadPersisted() async {
    final repo = ref.read(pdfReaderRepositoryProvider);
    final bookmarks = await repo.getBookmarks(arg);
    final annotations = await repo.getAnnotations(arg);
    state = state.copyWith(
      bookmarks: bookmarks.valueOrNull ?? const [],
      annotations: annotations.valueOrNull ?? const [],
    );
  }

  Future<void> onDocumentOpened(int totalPages) async {
    state = state.copyWith(totalPages: totalPages);
    await ref
        .read(pdfReaderRepositoryProvider)
        .recordDocumentOpened(path: arg, totalPages: totalPages);
  }

  /// Updates UI state immediately but debounces the SQLite write so a
  /// fast fling through a long document doesn't cause a write storm.
  void onPageChanged(int page, double zoom) {
    state = state.copyWith(currentPage: page);
    _pendingPage = page;
    _pendingZoom = zoom;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _flushPosition);
  }

  void _flushPosition() {
    final page = _pendingPage;
    final zoom = _pendingZoom;
    if (page == null || zoom == null) return;
    _pendingPage = null;
    _pendingZoom = null;
    unawaited(_savePosition(path: arg, page: page, zoom: zoom));
  }

  void setPageMode(ReaderPageMode mode) =>
      state = state.copyWith(pageMode: mode);

  void setTool(ReaderTool tool) => state = state.copyWith(
        activeTool: state.activeTool == tool ? ReaderTool.none : tool,
      );

  void setToolColor(int color) => state = state.copyWith(toolColor: color);

  void setSearching(bool searching) =>
      state = state.copyWith(isSearching: searching, searchQuery: '');

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  Future<void> toggleBookmark() async {
    final result = await ref
        .read(toggleBookmarkProvider)
        .call(documentPath: arg, page: state.currentPage);
    if (result.isOk) {
      final bookmarks =
          await ref.read(pdfReaderRepositoryProvider).getBookmarks(arg);
      state = state.copyWith(bookmarks: bookmarks.valueOrNull ?? const []);
    }
  }

  /// Persists an annotation built by the overlay (markup or ink stroke).
  Future<void> addAnnotation({
    required int page,
    required AnnotationType type,
    List<PageRect> rects = const [],
    List<List<PagePoint>> strokes = const [],
    String note = '',
  }) async {
    final now = DateTime.now();
    final result = await ref.read(pdfReaderRepositoryProvider).addAnnotation(
          Annotation(
            documentPath: arg,
            page: page,
            type: type,
            color: state.toolColor,
            opacity: type == AnnotationType.highlight ? 0.4 : 1.0,
            rects: rects,
            strokes: strokes,
            note: note,
            createdAt: now,
            updatedAt: now,
          ),
        );
    result.fold(
      (_) {},
      (saved) =>
          state = state.copyWith(annotations: [...state.annotations, saved]),
    );
  }

  Future<void> removeAnnotation(Annotation annotation) async {
    final id = annotation.id;
    if (id == null) return;
    final result =
        await ref.read(pdfReaderRepositoryProvider).removeAnnotation(id);
    if (result.isOk) {
      state = state.copyWith(
        annotations: state.annotations.where((a) => a.id != id).toList(),
      );
    }
  }
}

/// Recent documents for the home screen.
final recentDocumentsProvider =
    FutureProvider.autoDispose<List<RecentDocument>>((ref) async {
  final result = await ref.watch(getRecentDocumentsProvider).call();
  return result.fold((failure) => throw failure, (docs) => docs);
});
