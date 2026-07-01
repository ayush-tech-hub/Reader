import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class ReadingSession {
  const ReadingSession({
    this.id,
    required this.path,
    required this.name,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.pagesStart,
    required this.pagesEnd,
  });

  final int? id;
  final String path;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int pagesStart;
  final int pagesEnd;

  int get pagesRead => (pagesEnd - pagesStart).abs();
}

class BookStats {
  const BookStats({
    required this.path,
    required this.name,
    required this.totalSeconds,
    required this.totalPagesRead,
    required this.sessions,
    required this.lastReadAt,
  });

  final String path;
  final String name;
  final int totalSeconds;
  final int totalPagesRead;
  final int sessions;
  final DateTime lastReadAt;
}

class DayStats {
  const DayStats({
    required this.date,
    required this.totalSeconds,
    required this.totalPagesRead,
  });

  final DateTime date;
  final int totalSeconds;
  final int totalPagesRead;
}

class OverallStats {
  const OverallStats({
    required this.totalSeconds,
    required this.totalPagesRead,
    required this.totalBooks,
    required this.longestStreakDays,
    required this.currentStreakDays,
    required this.todaySeconds,
    required this.weekSeconds,
  });

  final int totalSeconds;
  final int totalPagesRead;
  final int totalBooks;
  final int longestStreakDays;
  final int currentStreakDays;
  final int todaySeconds;
  final int weekSeconds;
}

class ReadingStatsService {
  ReadingStatsService(this._db);

  final AppDatabase _db;

  Database get _database => _db.db;

  Future<int> startSession({
    required String path,
    required int startPage,
  }) async {
    final now = DateTime.now();
    return _database.insert('reading_sessions', {
      'path': path,
      'name': p.basename(path),
      'started_at': now.millisecondsSinceEpoch,
      'pages_start': startPage,
      'pages_end': startPage,
    });
  }

  Future<void> endSession({
    required int sessionId,
    required int endPage,
  }) async {
    final now = DateTime.now();
    final rows = await _database.query(
      'reading_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (rows.isEmpty) return;
    final startMs = rows.first['started_at'] as int;
    final durationS = ((now.millisecondsSinceEpoch - startMs) / 1000).round();
    await _database.update(
      'reading_sessions',
      {
        'ended_at': now.millisecondsSinceEpoch,
        'duration_s': durationS,
        'pages_end': endPage,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<OverallStats> getOverallStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    final weekStart = now
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;

    final allRows = await _database.query(
      'reading_sessions',
      columns: ['path', 'duration_s', 'pages_start', 'pages_end',
                'started_at'],
      where: 'ended_at IS NOT NULL',
      orderBy: 'started_at ASC',
    );

    int totalSeconds = 0;
    int totalPagesRead = 0;
    int todaySeconds = 0;
    int weekSeconds = 0;
    final uniqueBooks = <String>{};

    for (final row in allRows) {
      final dur = row['duration_s'] as int;
      final pStart = row['pages_start'] as int;
      final pEnd = row['pages_end'] as int;
      final startMs = row['started_at'] as int;
      final path = row['path'] as String;

      totalSeconds += dur;
      totalPagesRead += (pEnd - pStart).abs();
      uniqueBooks.add(path);

      if (startMs >= todayStart) todaySeconds += dur;
      if (startMs >= weekStart) weekSeconds += dur;
    }

    final streaks = _computeStreaks(allRows);

    return OverallStats(
      totalSeconds: totalSeconds,
      totalPagesRead: totalPagesRead,
      totalBooks: uniqueBooks.length,
      longestStreakDays: streaks.$1,
      currentStreakDays: streaks.$2,
      todaySeconds: todaySeconds,
      weekSeconds: weekSeconds,
    );
  }

  (int longest, int current) _computeStreaks(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return (0, 0);

    // Collect unique calendar dates that had a session.
    final days = <int>{};
    for (final row in rows) {
      final ms = row['started_at'] as int;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      final dayKey = DateTime(d.year, d.month, d.day)
          .millisecondsSinceEpoch;
      days.add(dayKey);
    }

    final sorted = days.toList()..sort();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day)
        .millisecondsSinceEpoch;
    const dayMs = 86400000;

    int longest = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] == dayMs) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    // Current streak: count backwards from today.
    int current = 0;
    int check = todayKey;
    for (int i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i] == check) {
        current++;
        check -= dayMs;
      } else if (sorted[i] < check) {
        break;
      }
    }

    return (longest, current);
  }

  Future<List<BookStats>> getBookStats({int limit = 20}) async {
    final rows = await _database.rawQuery('''
      SELECT path, name,
             SUM(duration_s)                         AS total_s,
             SUM(ABS(pages_end - pages_start))       AS total_pages,
             COUNT(*)                                AS sessions,
             MAX(started_at)                         AS last_read
      FROM reading_sessions
      WHERE ended_at IS NOT NULL
      GROUP BY path
      ORDER BY last_read DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((row) {
      final ms = row['last_read'] as int;
      return BookStats(
        path: row['path'] as String,
        name: row['name'] as String,
        totalSeconds: (row['total_s'] as int?) ?? 0,
        totalPagesRead: (row['total_pages'] as int?) ?? 0,
        sessions: (row['sessions'] as int?) ?? 0,
        lastReadAt: DateTime.fromMillisecondsSinceEpoch(ms),
      );
    }).toList();
  }

  Future<List<DayStats>> getDailyStats({int days = 30}) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final rows = await _database.rawQuery('''
      SELECT
        (started_at / 86400000) * 86400000          AS day_ms,
        SUM(duration_s)                              AS total_s,
        SUM(ABS(pages_end - pages_start))            AS total_pages
      FROM reading_sessions
      WHERE ended_at IS NOT NULL AND started_at >= ?
      GROUP BY day_ms
      ORDER BY day_ms ASC
    ''', [cutoff]);

    return rows.map((row) {
      final ms = row['day_ms'] as int;
      return DayStats(
        date: DateTime.fromMillisecondsSinceEpoch(ms),
        totalSeconds: (row['total_s'] as int?) ?? 0,
        totalPagesRead: (row['total_pages'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<void> clearAll() async {
    await _database.delete('reading_sessions');
  }
}
