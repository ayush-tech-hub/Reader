import 'dart:async';

import 'package:flutter/material.dart';

/// Pomodoro-style reading session timer.
///
/// Focus durations: 15 / 25 / 45 / 60 minutes with a 5-minute break.
/// The timer shows a circular progress arc, elapsed time, and simple
/// start / pause / reset controls.  Sessions completed in the current
/// app session are shown in a summary at the bottom.
class ReadingTimerScreen extends StatefulWidget {
  const ReadingTimerScreen({super.key});

  @override
  State<ReadingTimerScreen> createState() => _ReadingTimerScreenState();
}

class _ReadingTimerScreenState extends State<ReadingTimerScreen>
    with SingleTickerProviderStateMixin {
  static const _presets = [15, 25, 45, 60]; // minutes
  int _goalMinutes = 25;
  int _secondsElapsed = 0;
  bool _running = false;
  bool _onBreak = false;
  int _sessionsCompleted = 0;
  int _totalSecondsToday = 0;
  Timer? _timer;
  late final AnimationController _pulseCtrl;

  int get _goalSeconds => _goalMinutes * 60;
  int get _breakSeconds => 5 * 60;
  int get _currentGoal => _onBreak ? _breakSeconds : _goalSeconds;
  double get _progress =>
      (_secondsElapsed / _currentGoal).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
        if (_secondsElapsed >= _currentGoal) {
          _timer?.cancel();
          _running = false;
          if (!_onBreak) {
            _sessionsCompleted++;
            _totalSecondsToday += _goalSeconds;
            _onBreak = true;
          } else {
            _onBreak = false;
          }
          _secondsElapsed = 0;
        }
      });
    });
    setState(() => _running = true);
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _secondsElapsed = 0;
      _onBreak = false;
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTotal(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = _currentGoal - _secondsElapsed;
    final phaseColor = _onBreak ? Colors.green : scheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Timer')),
      body: Column(
        children: [
          // Goal preset chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Focus: '),
                const SizedBox(width: 8),
                for (final min in _presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${min}m'),
                      selected: _goalMinutes == min,
                      onSelected: _running
                          ? null
                          : (_) => setState(() {
                                _goalMinutes = min;
                                _secondsElapsed = 0;
                                _onBreak = false;
                              }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Phase label
          Text(
            _onBreak ? 'Break' : 'Focus',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: phaseColor,
                  fontWeight: FontWeight.w600,
                ),
          ),

          // Circular progress + time
          Expanded(
            child: Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 10,
                        backgroundColor:
                            scheme.surfaceContainerHighest,
                        color: phaseColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(remaining),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: phaseColor,
                              ),
                        ),
                        Text(
                          'remaining',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                  onPressed: _reset,
                  iconSize: 28,
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: FilledButton(
                    onPressed: _running ? _pause : _start,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: phaseColor,
                    ),
                    child: Icon(
                      _running ? Icons.pause : Icons.play_arrow,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton.outlined(
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Skip phase',
                  iconSize: 28,
                  onPressed: () {
                    _timer?.cancel();
                    setState(() {
                      _running = false;
                      _secondsElapsed = 0;
                      if (!_onBreak) {
                        _sessionsCompleted++;
                        _totalSecondsToday += _goalSeconds;
                      }
                      _onBreak = !_onBreak;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Today's summary
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  label: 'Sessions',
                  value: '$_sessionsCompleted',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                _Stat(
                  label: 'Focus time',
                  value: _formatTotal(_totalSecondsToday),
                  icon: Icons.timer_outlined,
                  color: scheme.primary,
                ),
                _Stat(
                  label: 'Break due',
                  value: _sessionsCompleted > 0 &&
                          _sessionsCompleted % 4 == 0
                      ? 'Long!'
                      : '${4 - (_sessionsCompleted % 4)} left',
                  icon: Icons.coffee_outlined,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
