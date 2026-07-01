import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../data/reading_stats_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _overallStatsProvider = FutureProvider<OverallStats>((ref) async {
  return ref.watch(readingStatsServiceProvider).getOverallStats();
});

final _bookStatsProvider = FutureProvider<List<BookStats>>((ref) async {
  return ref.watch(readingStatsServiceProvider).getBookStats();
});

final _dailyStatsProvider = FutureProvider<List<DayStats>>((ref) async {
  return ref.watch(readingStatsServiceProvider).getDailyStats(days: 28);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ReadingStatsScreen extends ConsumerWidget {
  const ReadingStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overall = ref.watch(_overallStatsProvider);
    final books = ref.watch(_bookStatsProvider);
    final daily = ref.watch(_dailyStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all stats',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_overallStatsProvider);
          ref.invalidate(_bookStatsProvider);
          ref.invalidate(_dailyStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overall stats
            overall.when(
              data: (s) => _OverallCard(stats: s),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 16),

            // 28-day activity chart
            Text('Last 28 Days',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            daily.when(
              data: (days) => _ActivityChart(days: days),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 16),

            // Per-book stats
            Text('Books Read',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            books.when(
              data: (list) => list.isEmpty
                  ? const _EmptyHint()
                  : Column(
                      children: [
                        for (final b in list) _BookTile(stats: b),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear reading stats?'),
        content: const Text('All session history will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(readingStatsServiceProvider).clearAll();
    ref.invalidate(_overallStatsProvider);
    ref.invalidate(_bookStatsProvider);
    ref.invalidate(_dailyStatsProvider);
  }
}

// ── Overall summary card ──────────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.stats});
  final OverallStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCell(
                  icon: Icons.timer_outlined,
                  value: _fmtDuration(stats.totalSeconds),
                  label: 'Total time',
                ),
                _StatCell(
                  icon: Icons.menu_book_outlined,
                  value: stats.totalPagesRead.toString(),
                  label: 'Pages read',
                ),
                _StatCell(
                  icon: Icons.library_books_outlined,
                  value: stats.totalBooks.toString(),
                  label: 'Books',
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCell(
                  icon: Icons.today,
                  value: _fmtDuration(stats.todaySeconds),
                  label: 'Today',
                ),
                _StatCell(
                  icon: Icons.date_range,
                  value: _fmtDuration(stats.weekSeconds),
                  label: 'This week',
                ),
                _StatCell(
                  icon: Icons.local_fire_department_outlined,
                  value: '${stats.currentStreakDays}d',
                  label: 'Streak',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                )),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer.withOpacity(0.7),
                )),
      ],
    );
  }
}

// ── 28-day activity bar chart ─────────────────────────────────────────────────

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});
  final List<DayStats> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const _EmptyHint();
    }

    // Build a full 28-day grid keyed by date.
    final map = <int, DayStats>{};
    for (final d in days) {
      map[d.date.millisecondsSinceEpoch] = d;
    }

    final now = DateTime.now();
    final slots = <DayStats?>[];
    for (int i = 27; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      slots.add(map[d.millisecondsSinceEpoch]);
    }

    final maxS = slots
        .whereType<DayStats>()
        .fold(0, (m, d) => d.totalSeconds > m ? d.totalSeconds : m);

    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: slots.map((slot) {
          final frac = maxS == 0
              ? 0.0
              : ((slot?.totalSeconds ?? 0) / maxS).clamp(0.0, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message: slot == null
                    ? 'No reading'
                    : '${slot.totalSeconds ~/ 60}m · ${slot.totalPagesRead}p',
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: frac < 0.04 ? 0.04 : frac,
                  child: Container(
                    decoration: BoxDecoration(
                      color: slot == null
                          ? scheme.surfaceContainerHighest
                          : scheme.primary.withOpacity(0.2 + frac * 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Per-book tile ─────────────────────────────────────────────────────────────

class _BookTile extends StatelessWidget {
  const _BookTile({required this.stats});
  final BookStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mins = stats.totalSeconds ~/ 60;
    final timeLabel = mins < 60
        ? '${mins}m'
        : '${mins ~/ 60}h ${mins % 60}m';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Text(
            p.basenameWithoutExtension(stats.name)
                .characters
                .firstOrNull
                ?.toUpperCase() ??
                '?',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
        ),
        title: Text(
          p.basenameWithoutExtension(stats.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$timeLabel · ${stats.totalPagesRead} pages · '
          '${stats.sessions} session${stats.sessions != 1 ? 's' : ''}',
        ),
        trailing: Text(
          _relativeDate(stats.lastReadAt),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
        ),
      ),
    );
  }

  static String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    return '${diff.inDays ~/ 30}mo ago';
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No reading sessions yet.\nOpen a PDF to start tracking.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message,
            style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
