import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/archive_entities.dart';

/// Durable ledger for archive jobs (`archive_jobs` table).
class ArchiveJobsDataSource {
  const ArchiveJobsDataSource(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<void> insert(ArchiveJob job) async {
    await _db.insert('archive_jobs', _toRow(job));
  }

  Future<void> update(ArchiveJob job) async {
    await _db.update(
      'archive_jobs',
      _toRow(job),
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<List<ArchiveJob>> getAll() async {
    final rows = await _db.query('archive_jobs', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Map<String, Object?> _toRow(ArchiveJob job) => {
    'id': job.id,
    'type': job.type.name,
    'format': job.format.wireName,
    'archive_path': job.archivePath,
    'target_path': job.targetPath,
    'status': job.status.name,
    'progress': job.progress,
    'error': job.error,
    'created_at': job.createdAt.millisecondsSinceEpoch,
    'completed_at': job.completedAt?.millisecondsSinceEpoch,
  };

  ArchiveJob _fromRow(Map<String, Object?> row) => ArchiveJob(
    id: row['id'] as String,
    type: ArchiveJobType.values.byName(row['type'] as String),
    format: ArchiveFormat.values.firstWhere(
      (f) => f.wireName == row['format'] as String,
    ),
    archivePath: row['archive_path'] as String,
    targetPath: row['target_path'] as String,
    status: ArchiveJobStatus.values.byName(row['status'] as String),
    progress: (row['progress'] as num).toDouble(),
    error: row['error'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    completedAt: row['completed_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['completed_at'] as int),
  );
}
