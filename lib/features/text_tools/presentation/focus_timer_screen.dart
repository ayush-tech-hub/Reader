import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Pomodoro-style focus timer with work/short-break/long-break phases.
class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

enum _Phase { work, shortBreak, longBreak }

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with SingleTickerProviderStateMixin {
  // Settings (minutes)
  int _workMins = 25;
  int _shortBreakMins = 5;
  int _longBreakMins = 15;
  int _longBreakInterval = 4; // pomodoros before long break

  _Phase _phase = _Phase.work;
  int _pomodorosCompleted = 0;
  int _secondsLeft = 0;
  bool _running = false;
  Timer? _timer;

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _workMins * 60;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  int get _phaseDuration {
    return switch (_phase) {
      _Phase.work => _workMins * 60,
      _Phase.shortBreak => _shortBreakMins * 60,
      _Phase.longBreak => _longBreakMins * 60,
    };
  }

  String get _phaseLabel => switch (_phase) {
        _Phase.work => 'Focus',
        _Phase.shortBreak => 'Short Break',
        _Phase.longBreak => 'Long Break',
      };

  Color _phaseColor(ColorScheme s) => switch (_phase) {
        _Phase.work => s.primary,
        _Phase.shortBreak => Colors.green,
        _Phase.longBreak => Colors.indigo,
      };

  void _startStop() {
    if (_running) {
      _timer?.cancel();
      _pulse.stop();
      setState(() => _running = false);
    } else {
      _pulse.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          _onPhaseComplete();
        }
      });
      setState(() => _running = true);
    }
  }

  void _onPhaseComplete() {
    _timer?.cancel();
    _pulse.stop();
    setState(() {
      _running = false;
      if (_phase == _Phase.work) {
        _pomodorosCompleted++;
        final isLong = _pomodorosCompleted % _longBreakInterval == 0;
        _phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
      } else {
        _phase = _Phase.work;
      }
      _secondsLeft = _phaseDuration;
    });
    _showCompleteSnack();
  }

  void _showCompleteSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_phaseLabel time! $_pomodorosCompleted 🍅 completed.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _reset() {
    _timer?.cancel();
    _pulse.stop();
    setState(() {
      _running = false;
      _secondsLeft = _phaseDuration;
    });
  }

  void _skipPhase() {
    _onPhaseComplete();
  }

  void _setPhase(_Phase p) {
    _timer?.cancel();
    _pulse.stop();
    setState(() {
      _running = false;
      _phase = p;
      _secondsLeft = _phaseDuration;
    });
  }

  String get _timeDisplay {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _phaseColor(scheme);
    final progress = _secondsLeft / _phaseDuration;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Phase selector
            SegmentedButton<_Phase>(
              segments: const [
                ButtonSegment(value: _Phase.work, label: Text('Focus')),
                ButtonSegment(value: _Phase.shortBreak, label: Text('Short')),
                ButtonSegment(value: _Phase.longBreak, label: Text('Long')),
              ],
              selected: {_phase},
              onSelectionChanged: (s) => _setPhase(s.first),
            ),
            const SizedBox(height: 40),

            // Circular timer
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final glow = _running ? _pulse.value * 0.3 : 0.0;
                return Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_running)
                        BoxShadow(
                          color: color.withOpacity(glow),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          color: color,
                          backgroundColor: color.withOpacity(0.15),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timeDisplay,
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.bold, color: color),
                          ),
                          Text(_phaseLabel,
                              style: TextStyle(color: color, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 48),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay),
                  tooltip: 'Reset',
                  iconSize: 28,
                ),
                const SizedBox(width: 24),
                FilledButton(
                  onPressed: _startStop,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size(120, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Icon(
                    _running ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton.outlined(
                  onPressed: _skipPhase,
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Skip phase',
                  iconSize: 28,
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Pomodoro count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < max(4, _pomodorosCompleted); i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '🍅',
                      style: TextStyle(
                        fontSize: 24,
                        color: i < _pomodorosCompleted
                            ? null
                            : scheme.onSurface.withOpacity(0.2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$_pomodorosCompleted pomodoro${_pomodorosCompleted == 1 ? '' : 's'} completed',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(
        workMins: _workMins,
        shortBreakMins: _shortBreakMins,
        longBreakMins: _longBreakMins,
        longBreakInterval: _longBreakInterval,
        onSave: (w, s, l, interval) {
          setState(() {
            _workMins = w;
            _shortBreakMins = s;
            _longBreakMins = l;
            _longBreakInterval = interval;
            _reset();
          });
        },
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.workMins,
    required this.shortBreakMins,
    required this.longBreakMins,
    required this.longBreakInterval,
    required this.onSave,
  });

  final int workMins, shortBreakMins, longBreakMins, longBreakInterval;
  final void Function(int, int, int, int) onSave;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late int _w, _s, _l, _n;

  @override
  void initState() {
    super.initState();
    _w = widget.workMins;
    _s = widget.shortBreakMins;
    _l = widget.longBreakMins;
    _n = widget.longBreakInterval;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Timer Settings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          _MinuteSlider('Focus (min)', _w, 5, 90, (v) => setState(() => _w = v)),
          _MinuteSlider('Short break (min)', _s, 1, 30, (v) => setState(() => _s = v)),
          _MinuteSlider('Long break (min)', _l, 5, 60, (v) => setState(() => _l = v)),
          _MinuteSlider('Long break every N 🍅', _n, 2, 8, (v) => setState(() => _n = v)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              widget.onSave(_w, _s, _l, _n);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _MinuteSlider extends StatelessWidget {
  const _MinuteSlider(this.label, this.value, this.min, this.max, this.onChanged);
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
              width: 180,
              child: Text('$label: $value')),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      );
}
