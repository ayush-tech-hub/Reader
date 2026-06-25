import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/reader_entities.dart';
import '../../domain/repositories/pdf_reader_repository.dart';
import '../datasources/reader_local_datasource.dart';

class PdfReaderRepositoryImpl implements PdfReaderRepository {
  const PdfReaderRepositoryImpl(this._local);

  final ReaderLocalDataSource _local;

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } catch (e) {
      return Err(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<RecentDocument>>> getRecentDocuments() =>
      _guard(_local.getRecentDocuments);

  @override
  Future<Result<void>> recordDocumentOpened({
    required String path,
    required int totalPages,
  }) =>
      _guard(
        () => _local.upsertRecentDocument(path: path, totalPages: totalPages),
      );

  @override
  Future<Result<void>> saveReadingPosition({
    required String path,
    required int page,
    required double zoom,
  }) =>
      _guard(
        () => _local.saveReadingPosition(path: path, page: page, zoom: zoom),
      );

  @override
  Future<Result<void>> removeRecentDocument(String path) =>
      _guard(() => _local.removeRecentDocument(path));

  @override
  Future<Result<List<Bookmark>>> getBookmarks(String documentPath) =>
      _guard(() => _local.getBookmarks(documentPath));

  @override
  Future<Result<Bookmark>> addBookmark(Bookmark bookmark) =>
      _guard(() => _local.insertBookmark(bookmark));

  @override
  Future<Result<void>> removeBookmark(int id) =>
      _guard(() => _local.deleteBookmark(id));

  @override
  Future<Result<List<Annotation>>> getAnnotations(String documentPath) =>
      _guard(() => _local.getAnnotations(documentPath));

  @override
  Future<Result<Annotation>> addAnnotation(Annotation annotation) =>
      _guard(() => _local.insertAnnotation(annotation));

  @override
  Future<Result<void>> updateAnnotation(Annotation annotation) =>
      _guard(() => _local.updateAnnotation(annotation));

  @override
  Future<Result<void>> removeAnnotation(int id) =>
      _guard(() => _local.deleteAnnotation(id));
}
