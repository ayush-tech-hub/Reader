import '../../../../core/utils/result.dart';
import '../entities/file_entry.dart';
import '../repositories/file_manager_repository.dart';

class ListDirectory {
  const ListDirectory(this._repository);
  final FileManagerRepository _repository;

  Future<Result<List<FileEntry>>> call(
    String path, {
    required bool showHidden,
    required FileSortField sortField,
    required bool ascending,
  }) async {
    final result = await _repository.listDirectory(
      path,
      showHidden: showHidden,
    );
    return result.fold(
      Err.new,
      (entries) => Ok(sortEntries(entries, sortField, ascending)),
    );
  }

  /// Directories first, then the chosen field. Exposed for tests.
  static List<FileEntry> sortEntries(
    List<FileEntry> entries,
    FileSortField field,
    bool ascending,
  ) {
    int compare(FileEntry a, FileEntry b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final cmp = switch (field) {
        FileSortField.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        FileSortField.size => a.size.compareTo(b.size),
        FileSortField.date => a.modifiedAt.compareTo(b.modifiedAt),
      };
      return ascending ? cmp : -cmp;
    }

    return [...entries]..sort(compare);
  }
}

class CopyEntries {
  const CopyEntries(this._repository);
  final FileManagerRepository _repository;

  Future<Result<void>> call(List<String> sources, String destinationDir) =>
      _repository.copy(sources, destinationDir);
}

class MoveEntries {
  const MoveEntries(this._repository);
  final FileManagerRepository _repository;

  Future<Result<void>> call(List<String> sources, String destinationDir) =>
      _repository.move(sources, destinationDir);
}

class DeleteEntries {
  const DeleteEntries(this._repository);
  final FileManagerRepository _repository;

  Future<Result<void>> call(List<String> paths) => _repository.delete(paths);
}

class RenameEntry {
  const RenameEntry(this._repository);
  final FileManagerRepository _repository;

  Future<Result<void>> call(String path, String newName) =>
      _repository.rename(path, newName);
}

class CreateFolder {
  const CreateFolder(this._repository);
  final FileManagerRepository _repository;

  Future<Result<void>> call(String parentPath, String name) =>
      _repository.createDirectory(parentPath, name);
}

class SearchFiles {
  const SearchFiles(this._repository);
  final FileManagerRepository _repository;

  Stream<FileEntry> call(String rootPath, String query) =>
      _repository.search(rootPath, query);
}
