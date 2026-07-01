import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _goalMinutesProvider =
    NotifierProvider<_GoalNotifier, int>(_GoalNotifier.new);

class _GoalNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 20;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(SettingKeys.dailyGoalMinutes) ?? 20;
  }

  Future<void> setGoal(int minutes) async {
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingKeys.dailyGoalMinutes, minutes);
  }
}

final _todayProgressProvider = FutureProvider<int>((ref) async {
  final stats = ref.watch(readingStatsServiceProvider);
  final overall = await stats.getOverallStats();
  return overall.todaySeconds ~/ 60;
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ReadingGoalsScreen extends ConsumerWidget {
  const ReadingGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(_goalMinutesProvider);
    final todayAsync = ref.watch(_todayProgressProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Goals')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Daily goal setting
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily reading goal',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$goal minutes per day',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Slider(
                    value: goal.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '$goal min',
                    onChanged: (v) =>
                        ref.read(_goalMinutesProvider.notifier).setGoal(v.round()),
                  ),
                  // Preset chips
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 20, 30, 45, 60].map((m) {
                      return ChoiceChip(
                        label: Text('${m}m'),
                        selected: goal == m,
                        onSelected: (_) =>
                            ref.read(_goalMinutesProvider.notifier).setGoal(m),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Today's progress
          todayAsync.when(
            data: (todayMins) {
              final progress = goal > 0
                  ? (todayMins / goal).clamp(0.0, 1.0)
                  : 0.0;
              final done = todayMins >= goal;

              return Card(
                color: done ? scheme.primaryContainer : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: done
                                ? scheme.onPrimaryContainer
                                : scheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Today's progress",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: done
                                      ? scheme.onPrimaryContainer
                                      : null,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: done
                            ? scheme.onPrimaryContainer.withOpacity(0.2)
                            : null,
                        color: done ? scheme.onPrimaryContainer : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        done
                            ? 'Goal reached! $todayMins / $goal minutes read today.'
                            : '$todayMins / $goal minutes read today. '
                                '${goal - todayMins} more to go!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: done ? scheme.onPrimaryContainer : null,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Tips
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tips',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final tip in const [
                    'Start with 5–10 minutes a day to build the habit.',
                    'Reading before bed improves retention.',
                    'Use Workspace to keep multiple books open at once.',
                    'Voice read-aloud lets you listen while commuting.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                              child: Text(tip,
                                  style:
                                      Theme.of(context).textTheme.bodySmall)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
