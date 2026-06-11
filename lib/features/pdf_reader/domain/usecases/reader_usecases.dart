import 'package:collection/collection.dart';

import '../../../../core/utils/result.dart';
import '../entities/reader_entities.dart';
import '../repositories/pdf_reader_repository.dart';

class GetRecentDocuments {
  const GetRecentDocuments(this._repository);
  final PdfReaderRepository _repository;

  Future<Result<List<RecentDocument>>> call() =>
      _repository.getRecentDocuments();
}

class SaveReadingPosition {
  const SaveReadingPosition(this._repository);
  final PdfReaderRepository _repository;

  Future<Result<void>> call({
    required String path,
    required int page,
    required double zoom,
  }) =>
      _repository.saveReadingPosition(path: path, page: page, zoom: zoom);
}

class ToggleBookmark {
  const ToggleBookmark(this._repository);
  final PdfReaderRepository _repository;

  /// Adds a bookmark on [page] if absent, removes it if present.
  /// Returns true when the page ends up bookmarked.
  Future<Result<bool>> call({
    required String documentPath,
    required int page,
    String label = '',
  }) async {
    final existing = await _repository.getBookmarks(documentPath);
    return switch (existing) {
      Err<List<Bookmark>>(:final failure) => Err(failure),
      Ok<List<Bookmark>>(:final value) => await _toggle(
          value, documentPath, page, label),
    };
  }

  Future<Result<bool>> _toggle(
    List<Bookmark> bookmarks,
    String documentPath,
    int page,
    String label,
  ) async {
    final match = bookmarks.where((b) => b.page == page).firstOrNull;
    if (match != null && match.id != null) {
      final removed = await _repository.removeBookmark(match.id!);
      return removed.fold(Err.new, (_) => const Ok(false));
    }
    final added = await _repository.addBookmark(
      Bookmark(
        documentPath: documentPath,
        page: page,
        label: label,
        createdAt: DateTime.now(),
      ),
    );
    return added.fold(Err.new, (_) => const Ok(true));
  }
}
