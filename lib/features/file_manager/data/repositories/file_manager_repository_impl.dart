import 'dart:io';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/file_entry.dart';
import '../../domain/repositories/file_manager_repository.dart';
import '../datasources/file_manager_local_datasource.dart';
import '../datasources/file_system_datasource.dart';

class FileManagerRepositoryImpl implements FileManagerRepository {
  const FileManagerRepositoryImpl(this._fs, this._local);

  final FileSystemDataSource _fs;
  final FileManagerLocalDataSource _local;

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on FileSystemException2 catch (e) {
      return Err(FileSystemFailure(e.message));
    } on FileSystemException catch (e) {
      return Err(FileSystemFailure(e.message));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<StorageRoot>>> getStorageRoots() =>
      _guard(_fs.getStorageRoots);

  @override
  Future<Result<List<FileEntry>>> listDirectory(
    String path, {
    required bool showHidden,
  }) =>
      _guard(() => _fs.listDirectory(path, showHidden: showHidden));

  @override
  Stream<FileEntry> search(String rootPath, String query) =>
      _fs.search(rootPath, query);

  @override
  Future<Result<void>> copy(List<String> sources, String destinationDir) =>
      _guard(() => _fs.copy(sources, destinationDir));

  @override
  Future<Result<void>> move(List<String> sources, String destinationDir) =>
      _guard(() => _fs.move(sources, destinationDir));

  @override
  Future<Result<void>> rename(String path, String newName) =>
      _guard(() => _fs.rename(path, newName));

  @override
  Future<Result<void>> delete(List<String> paths) =>
      _guard(() => _fs.delete(paths));

  @override
  Future<Result<void>> createDirectory(String parentPath, String name) =>
      _guard(() => _fs.createDirectory(parentPath, name));

  @override
  Future<Result<List<Favorite>>> getFavorites() => _guard(_local.getFavorites);

  @override
  Future<Result<void>> addFavorite(Favorite favorite) =>
      _guard(() => _local.addFavorite(favorite));

  @override
  Future<Result<void>> removeFavorite(String path) =>
      _guard(() => _local.removeFavorite(path));

  @override
  Future<Result<List<FileEntry>>> getRecentFiles() => _guard(() async {
        final paths = await _local.getRecentFilePaths();
        final entries = <FileEntry>[];
        for (final path in paths) {
          final file = File(path);
          if (!await file.exists()) continue; // pruned lazily
          final stat = await file.stat();
          entries.add(
            FileEntry(
              path: path,
              name: file.uri.pathSegments.last,
              isDirectory: false,
              size: stat.size,
              modifiedAt: stat.modified,
            ),
          );
        }
        return entries;
      });

  @override
  Future<Result<void>> recordFileAccess(String path) =>
      _guard(() => _local.recordFileAccess(path));
}
