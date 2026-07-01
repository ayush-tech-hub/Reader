import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal streak-based reading habit tracker.
///
/// Users check in each day — the screen shows a 12-week grid of days
/// (GitHub-style contribution map) coloured by whether the day was checked in.
class HabitTrackerScreen extends StatefulWidget {
  const HabitTrackerScreen({super.key});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  static const _key = 'reading_habit_v1';
  Set<String> _checkedDays = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _checkedDays = list.map((e) => e as String).toSet();
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_checkedDays.toList()));
  }

  void _toggleToday() {
    final today = _fmt(DateTime.now());
    setState(() {
      if (_checkedDays.contains(today)) {
        _checkedDays.remove(today);
      } else {
        _checkedDays.add(today);
      }
    });
    _save();
  }

  int get _currentStreak {
    int streak = 0;
    var d = DateTime.now();
    while (_checkedDays.contains(_fmt(d))) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get _longestStreak {
    if (_checkedDays.isEmpty) return 0;
    final sorted = _checkedDays.toList()..sort();
    int longest = 1, current = 1;
    for (var i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final today = _fmt(DateTime.now());
    final checkedToday = _checkedDays.contains(today);
    final scheme = Theme.of(context).colorScheme;

    // Build 12-week grid ending today
    final now = DateTime.now();
    final gridStart = now.subtract(Duration(days: 83)); // 12 weeks - 1 day

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Habit Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Current streak',
                  value: '${_currentStreak}',
                  suffix: 'days',
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Longest streak',
                  value: '${_longestStreak}',
                  suffix: 'days',
                  icon: Icons.emoji_events_outlined,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Total days',
                  value: '${_checkedDays.length}',
                  suffix: 'logged',
                  icon: Icons.calendar_today_outlined,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Check-in button
          FilledButton.icon(
            onPressed: _toggleToday,
            icon: Icon(checkedToday
                ? Icons.check_circle
                : Icons.radio_button_unchecked),
            label: Text(
                checkedToday ? 'Logged today!' : 'Log today\'s reading'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor:
                  checkedToday ? Colors.green : scheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // 12-week contribution grid
          Text('Last 12 weeks',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ContributionGrid(
            startDate: gridStart,
            checkedDays: _checkedDays,
            scheme: scheme,
          ),
          const SizedBox(height: 24),

          // Month breakdown
          Text('Monthly breakdown',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _MonthBreakdown(checkedDays: _checkedDays, scheme: scheme),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(suffix,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
}

class _ContributionGrid extends StatelessWidget {
  const _ContributionGrid({
    required this.startDate,
    required this.checkedDays,
    required this.scheme,
  });

  final DateTime startDate;
  final Set<String> checkedDays;
  final ColorScheme scheme;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const cellSize = 14.0;
    const gap = 2.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day labels
          Column(
            children: [
              for (final (i, label) in [
                'M', '', 'W', '', 'F', '', 'S'
              ].indexed)
                SizedBox(
                  height: cellSize + gap,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.grey)),
                ),
            ],
          ),
          const SizedBox(width: 4),
          // Weeks
          for (var w = 0; w < 12; w++)
            Padding(
              padding: const EdgeInsets.only(right: gap),
              child: Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Builder(builder: (ctx) {
                      final date = startDate.add(Duration(days: w * 7 + d));
                      final key = _fmt(date);
                      final checked = checkedDays.contains(key);
                      final isToday = key == _fmt(DateTime.now());
                      return Container(
                        width: cellSize,
                        height: cellSize,
                        margin: const EdgeInsets.only(bottom: gap),
                        decoration: BoxDecoration(
                          color: checked
                              ? Colors.green
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(2),
                          border: isToday
                              ? Border.all(
                                  color: scheme.primary, width: 1.5)
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthBreakdown extends StatelessWidget {
  const _MonthBreakdown(
      {required this.checkedDays, required this.scheme});

  final Set<String> checkedDays;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // Group by year-month
    final months = <String, int>{};
    for (final day in checkedDays) {
      final ym = day.substring(0, 7);
      months[ym] = (months[ym] ?? 0) + 1;
    }
    final sorted = months.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sorted.isEmpty) {
      return Text('No data yet.',
          style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Column(
      children: [
        for (final ym in sorted.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(ym,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (months[ym] ?? 0) / 31,
                      minHeight: 14,
                      color: Colors.green,
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${months[ym]}d',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}
