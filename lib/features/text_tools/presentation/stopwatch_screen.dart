import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stopwatch with lap tracking and countdown timer.
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stopwatch & Timer'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Stopwatch'), Tab(text: 'Countdown')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_StopwatchTab(), _CountdownTab()],
      ),
    );
  }
}

// ─── Stopwatch Tab ──────────────────────────────────────────────────────────

class _StopwatchTab extends StatefulWidget {
  const _StopwatchTab();

  @override
  State<_StopwatchTab> createState() => _StopwatchTabState();
}

class _StopwatchTabState extends State<_StopwatchTab> {
  final _sw = Stopwatch();
  Timer? _timer;
  final List<Duration> _laps = [];
  Duration _lastLap = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStop() {
    if (_sw.isRunning) {
      _sw.stop();
      _timer?.cancel();
      setState(() {});
    } else {
      _sw.start();
      _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _lap() {
    final current = _sw.elapsed;
    final lapTime = current - _lastLap;
    setState(() {
      _laps.insert(0, lapTime);
      _lastLap = current;
    });
  }

  void _reset() {
    _sw.stop();
    _sw.reset();
    _timer?.cancel();
    setState(() {
      _laps.clear();
      _lastLap = Duration.zero;
    });
  }

  String _fmt(Duration d) {
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    final s = d.inSeconds % 60;
    final m = d.inMinutes % 60;
    final h = d.inHours;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}.${ms.toString().padLeft(2,'0')}';
    }
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}.${ms.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elapsed = _sw.elapsed;
    final lapElapsed = elapsed - _lastLap;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Main display
          Text(
            _fmt(elapsed),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_sw.isRunning)
            Text(
              'Lap: ${_fmt(lapElapsed)}',
              style: TextStyle(color: scheme.primary, fontFamily: 'monospace'),
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: _reset,
                icon: const Icon(Icons.replay),
                iconSize: 28,
                tooltip: 'Reset',
              ),
              const SizedBox(width: 24),
              FilledButton(
                onPressed: _startStop,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 56),
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  _sw.isRunning ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
              ),
              const SizedBox(width: 24),
              IconButton.outlined(
                onPressed: _sw.isRunning ? _lap : null,
                icon: const Icon(Icons.flag_outlined),
                iconSize: 28,
                tooltip: 'Lap',
              ),
            ],
          ),
          if (_laps.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _laps.length,
                itemBuilder: (_, i) {
                  final lapNum = _laps.length - i;
                  final isLast = i == 0;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          isLast ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      child: Text(
                        '$lapNum',
                        style: TextStyle(
                            fontSize: 11,
                            color: isLast
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant),
                      ),
                    ),
                    title: Text(_fmt(_laps[i]),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: isLast ? FontWeight.bold : null,
                        )),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _fmt(_laps[i])));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Countdown Tab ──────────────────────────────────────────────────────────

class _CountdownTab extends StatefulWidget {
  const _CountdownTab();

  @override
  State<_CountdownTab> createState() => _CountdownTabState();
}

class _CountdownTabState extends State<_CountdownTab> {
  int _totalSeconds = 5 * 60;
  int _secondsLeft = 5 * 60;
  bool _running = false;
  bool _done = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStop() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else if (_secondsLeft > 0) {
      _done = false;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          _timer?.cancel();
          setState(() { _running = false; _done = true; });
        }
      });
      setState(() => _running = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _done = false;
      _secondsLeft = _totalSeconds;
    });
  }

  String _fmt(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    }
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _totalSeconds > 0 ? _secondsLeft / _totalSeconds : 0.0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!_running && !_done) ...[
            // Duration selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeWheel('Hours', _totalSeconds ~/ 3600, 24, (v) {
                  setState(() {
                    final prev = _totalSeconds;
                    _totalSeconds = v * 3600 + (prev % 3600);
                    _secondsLeft = _totalSeconds;
                  });
                }),
                const Text(' : ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                _TimeWheel('Mins', (_totalSeconds % 3600) ~/ 60, 60, (v) {
                  setState(() {
                    final h = _totalSeconds ~/ 3600;
                    final s = _totalSeconds % 60;
                    _totalSeconds = h * 3600 + v * 60 + s;
                    _secondsLeft = _totalSeconds;
                  });
                }),
                const Text(' : ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                _TimeWheel('Secs', _totalSeconds % 60, 60, (v) {
                  setState(() {
                    final rest = (_totalSeconds ~/ 60) * 60;
                    _totalSeconds = rest + v;
                    _secondsLeft = _totalSeconds;
                  });
                }),
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: _done ? scheme.error : scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                Text(
                  _done ? 'Done!' : _fmt(_secondsLeft),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: _done ? scheme.error : null,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: _reset,
                icon: const Icon(Icons.replay),
                iconSize: 28,
              ),
              const SizedBox(width: 24),
              FilledButton(
                onPressed: _totalSeconds == 0 ? null : _startStop,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 56),
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  _running ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
              ),
            ],
          ),
          if (!_running && !_done) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in [60, 300, 600, 900, 1800, 3600])
                  ActionChip(
                    label: Text(_fmt(preset)),
                    onPressed: () => setState(() {
                      _totalSeconds = preset;
                      _secondsLeft = preset;
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel(this.label, this.value, this.max, this.onChanged);
  final String label;
  final int value, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          SizedBox(
            height: 120,
            width: 60,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              diameterRatio: 1.5,
              onSelectedItemChanged: onChanged,
              controller: FixedExtentScrollController(initialItem: value),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: max,
                builder: (_, i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          i == value ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
