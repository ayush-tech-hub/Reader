import '../../../../core/utils/result.dart';
import '../entities/file_entry.dart';

abstract interface class FileManagerRepository {
  Future<Result<List<StorageRoot>>> getStorageRoots();

  Future<Result<List<FileEntry>>> listDirectory(
    String path, {
    required bool showHidden,
  });

  /// Recursive search rooted at [rootPath]; streams matches as found so
  /// the UI can render incrementally on large trees.
  Stream<FileEntry> search(String rootPath, String query);

  Future<Result<void>> copy(List<String> sources, String destinationDir);
  Future<Result<void>> move(List<String> sources, String destinationDir);
  Future<Result<void>> rename(String path, String newName);
  Future<Result<void>> delete(List<String> paths);
  Future<Result<void>> createDirectory(String parentPath, String name);

  // Favorites
  Future<Result<List<Favorite>>> getFavorites();
  Future<Result<void>> addFavorite(Favorite favorite);
  Future<Result<void>> removeFavorite(String path);

  // Recents
  Future<Result<List<FileEntry>>> getRecentFiles();
  Future<Result<void>> recordFileAccess(String path);
}
