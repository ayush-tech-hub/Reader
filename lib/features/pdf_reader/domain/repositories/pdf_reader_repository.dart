import '../../../../core/utils/result.dart';
import '../entities/reader_entities.dart';

/// Reading-session persistence and document metadata. Rendering itself
/// is a presentation concern (pdfium-backed viewer); this repository
/// owns everything that must survive the session.
abstract interface class PdfReaderRepository {
  // Recents / reading history
  Future<Result<List<RecentDocument>>> getRecentDocuments();
  Future<Result<void>> recordDocumentOpened({
    required String path,
    required int totalPages,
  });
  Future<Result<void>> saveReadingPosition({
    required String path,
    required int page,
    required double zoom,
  });
  Future<Result<void>> removeRecentDocument(String path);

  // Bookmarks
  Future<Result<List<Bookmark>>> getBookmarks(String documentPath);
  Future<Result<Bookmark>> addBookmark(Bookmark bookmark);
  Future<Result<void>> removeBookmark(int id);

  // Annotations
  Future<Result<List<Annotation>>> getAnnotations(String documentPath);
  Future<Result<Annotation>> addAnnotation(Annotation annotation);
  Future<Result<void>> updateAnnotation(Annotation annotation);
  Future<Result<void>> removeAnnotation(int id);
}
