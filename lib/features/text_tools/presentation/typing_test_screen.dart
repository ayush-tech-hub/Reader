import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// WPM / accuracy typing speed test with selectable text length.
class TypingTestScreen extends StatefulWidget {
  const TypingTestScreen({super.key});

  @override
  State<TypingTestScreen> createState() => _TypingTestScreenState();
}

// Sample sentences for the test
const _sentences = [
  'The quick brown fox jumps over the lazy dog.',
  'Pack my box with five dozen liquor jugs.',
  'How vexingly quick daft zebras jump!',
  'The five boxing wizards jump quickly.',
  'Sphinx of black quartz, judge my vow.',
  'Jackdaws love my big sphinx of quartz.',
  'Reading opens doors to worlds unknown.',
  'A book is a dream you hold in your hands.',
  'The more you read, the more you know.',
  'Words have the power to change the world.',
  'Knowledge is the foundation of wisdom.',
  'Every page turned is a step forward.',
  'Libraries are the gardens of the mind.',
  'Stories connect us across time and space.',
  'Imagination is more important than knowledge.',
  'The pen is mightier than the sword indeed.',
  'Writing is thinking on paper, nothing more.',
  'Good readers make great thinkers always.',
  'Literature reveals the human condition.',
  'Each book is a new adventure waiting.',
];

class _TypingTestScreenState extends State<TypingTestScreen> {
  final _ctrl = TextEditingController();
  final _rng = Random();
  String _target = '';
  Timer? _timer;
  int _seconds = 0;
  bool _started = false;
  bool _done = false;
  int _wpm = 0;
  double _accuracy = 0;
  int _testLength = 3; // number of sentences

  @override
  void initState() {
    super.initState();
    _generateTarget();
    _ctrl.addListener(_onType);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.removeListener(_onType);
    _ctrl.dispose();
    super.dispose();
  }

  void _generateTarget() {
    final sentences = List<String>.from(_sentences)..shuffle(_rng);
    _target = sentences.take(_testLength).join(' ');
    setState(() {
      _started = false;
      _done = false;
      _seconds = 0;
      _wpm = 0;
      _accuracy = 0;
    });
    _ctrl.clear();
    _timer?.cancel();
  }

  void _onType() {
    if (_done) return;
    final typed = _ctrl.text;
    if (typed.isNotEmpty && !_started) {
      _started = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    }
    if (typed == _target) {
      _finish();
    }
    setState(() {});
  }

  void _finish() {
    _timer?.cancel();
    final typed = _ctrl.text;
    final mins = _seconds / 60.0;
    final words = typed.trim().split(RegExp(r'\s+')).length;
    _wpm = mins > 0 ? (words / mins).round() : 0;

    // Character-level accuracy
    int correct = 0;
    final len = min(typed.length, _target.length);
    for (var i = 0; i < len; i++) {
      if (typed[i] == _target[i]) correct++;
    }
    _accuracy = typed.isEmpty ? 0 : correct / typed.length * 100;

    setState(() => _done = true);
  }

  Color _charColor(int index, String typed) {
    if (index >= typed.length) return Colors.transparent;
    return typed[index] == _target[index] ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typed = _ctrl.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Typing Speed Test'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Length',
            icon: const Icon(Icons.tune),
            initialValue: _testLength,
            itemBuilder: (_) => [1, 2, 3, 5, 8].map((n) =>
              PopupMenuItem(value: n, child: Text('$n sentence${n > 1 ? 's' : ''}'))
            ).toList(),
            onSelected: (v) {
              setState(() => _testLength = v);
              _generateTarget();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New test',
            onPressed: _generateTarget,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timer and stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatBadge(Icons.timer_outlined, '${_seconds}s', 'Time'),
                const SizedBox(width: 24),
                _StatBadge(Icons.speed, '$_wpm WPM', 'Speed'),
                const SizedBox(width: 24),
                _StatBadge(Icons.check_circle_outline,
                    '${_accuracy.toStringAsFixed(0)}%', 'Accuracy'),
              ],
            ),
            const SizedBox(height: 16),

            // Target text with per-char colouring
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RichText(
                  text: TextSpan(
                    children: [
                      for (var i = 0; i < _target.length; i++)
                        TextSpan(
                          text: _target[i],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            height: 1.6,
                            color: i < typed.length
                                ? (_charColor(i, typed) == Colors.green
                                    ? Colors.green
                                    : Colors.red)
                                : (i == typed.length
                                    ? scheme.primary
                                    : scheme.onSurface),
                            backgroundColor: i < typed.length
                                ? _charColor(i, typed)
                                    .withOpacity(0.12)
                                : (i == typed.length
                                    ? scheme.primary.withOpacity(0.2)
                                    : null),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (!_done) ...[
              TextField(
                controller: _ctrl,
                enabled: !_done,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: _started ? 'Typing…' : 'Start typing to begin',
                  counterText:
                      '${typed.length} / ${_target.length} chars',
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: typed.isEmpty ? 0 : typed.length / _target.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ] else ...[
              // Results
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Test complete!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  color: scheme.onPrimaryContainer)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ResultStat('$_wpm', 'WPM', scheme),
                          _ResultStat(
                              '${_accuracy.toStringAsFixed(1)}%',
                              'Accuracy',
                              scheme),
                          _ResultStat('${_seconds}s', 'Time', scheme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _generateTarget,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

class _ResultStat extends StatelessWidget {
  const _ResultStat(this.value, this.label, this.scheme);
  final String value;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer)),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: scheme.onPrimaryContainer)),
        ],
      );
}
