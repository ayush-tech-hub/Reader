import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/file_entry.dart';

/// SQLite access for favorites and recent files.
class FileManagerLocalDataSource {
  const FileManagerLocalDataSource(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<Favorite>> getFavorites() async {
    final rows = await _db.query('favorites', orderBy: 'added_at DESC');
    return rows
        .map(
          (row) => Favorite(
            path: row['path'] as String,
            name: row['name'] as String,
            isDirectory: (row['is_directory'] as int) != 0,
            addedAt: DateTime.fromMillisecondsSinceEpoch(
              row['added_at'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<void> addFavorite(Favorite favorite) async {
    await _db.insert('favorites', {
      'path': favorite.path,
      'name': favorite.name,
      'is_directory': favorite.isDirectory ? 1 : 0,
      'added_at': favorite.addedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavorite(String path) async {
    await _db.delete('favorites', where: 'path = ?', whereArgs: [path]);
  }

  Future<List<String>> getRecentFilePaths() async {
    final rows = await _db.query(
      'recent_files',
      orderBy: 'accessed_at DESC',
      limit: AppConstants.maxRecentFiles,
    );
    return rows.map((row) => row['path'] as String).toList();
  }

  Future<void> recordFileAccess(String path) async {
    await _db.insert('recent_files', {
      'path': path,
      'name': p.basename(path),
      'accessed_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
