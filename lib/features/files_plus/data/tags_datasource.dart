import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class Tag {
  const Tag({required this.id, required this.name, required this.color});

  final int id;
  final String name;
  final int color;
}

/// File tagging: tags are global, assignments are per-path.
class TagsDataSource {
  const TagsDataSource(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<List<Tag>> getTags() async {
    final rows = await _db.query('tags', orderBy: 'name ASC');
    return [
      for (final row in rows)
        Tag(
          id: row['id'] as int,
          name: row['name'] as String,
          color: row['color'] as int,
        ),
    ];
  }

  Future<Tag> createTag(String name, {int color = 0xFF1565C0}) async {
    final id = await _db.insert('tags', {
      'name': name,
      'color': color,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (id == 0) {
      final existing = await _db.query(
        'tags',
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      final row = existing.first;
      return Tag(
        id: row['id'] as int,
        name: row['name'] as String,
        color: row['color'] as int,
      );
    }
    return Tag(id: id, name: name, color: color);
  }

  Future<void> deleteTag(int id) async {
    await _db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFileTags(String path, Set<int> tagIds) async {
    final batch = _db.batch();
    batch.delete('file_tags', where: 'file_path = ?', whereArgs: [path]);
    for (final tagId in tagIds) {
      batch.insert('file_tags', {'file_path': path, 'tag_id': tagId});
    }
    await batch.commit(noResult: true);
  }

  Future<Set<int>> getFileTagIds(String path) async {
    final rows = await _db.query(
      'file_tags',
      where: 'file_path = ?',
      whereArgs: [path],
    );
    return rows.map((r) => r['tag_id'] as int).toSet();
  }

  Future<List<String>> getPathsWithTag(int tagId) async {
    final rows = await _db.query(
      'file_tags',
      where: 'tag_id = ?',
      whereArgs: [tagId],
      orderBy: 'file_path ASC',
    );
    return rows.map((r) => r['file_path'] as String).toList();
  }
}
