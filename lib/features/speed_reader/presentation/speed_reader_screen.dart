import 'dart:async';

import 'package:flutter/material.dart';

/// RSVP (Rapid Serial Visual Presentation) speed reader.
///
/// Shows one word at a time at a configurable WPM rate.
/// The user pastes text or it is passed in via [text].
class SpeedReaderScreen extends StatefulWidget {
  const SpeedReaderScreen({super.key, this.text});

  final String? text;

  @override
  State<SpeedReaderScreen> createState() => _SpeedReaderScreenState();
}

class _SpeedReaderScreenState extends State<SpeedReaderScreen> {
  final _textCtrl = TextEditingController();
  List<String> _words = [];
  int _index = 0;
  int _wpm = 300;
  bool _playing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.text != null) {
      _textCtrl.text = widget.text!;
      _words = _tokenize(widget.text!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  List<String> _tokenize(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  void _load() {
    setState(() {
      _words = _tokenize(_textCtrl.text);
      _index = 0;
      _playing = false;
      _timer?.cancel();
    });
  }

  void _play() {
    if (_words.isEmpty) return;
    if (_index >= _words.length) _index = 0;
    setState(() => _playing = true);
    final interval =
        Duration(milliseconds: (60000 / _wpm).round());
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {
        if (_index < _words.length - 1) {
          _index++;
        } else {
          _playing = false;
          _timer?.cancel();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _index = 0;
      _playing = false;
    });
  }

  // Returns (left, pivot, right) parts of the word for ORP alignment.
  (String, String, String) _orp(String word) {
    if (word.isEmpty) return ('', '', '');
    // Pivot = ~30% into the word (Spritz-style).
    final pivotIdx = ((word.length - 1) * 0.3).round();
    final left = word.substring(0, pivotIdx);
    final pivot = word[pivotIdx];
    final right = pivotIdx + 1 < word.length
        ? word.substring(pivotIdx + 1)
        : '';
    return (left, pivot, right);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentWord =
        _words.isNotEmpty ? _words[_index.clamp(0, _words.length - 1)] : '';
    final (left, pivot, right) = _orp(currentWord);
    final progress =
        _words.isEmpty ? 0.0 : (_index + 1) / _words.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Speed reader')),
      body: Column(
        children: [
          // Text input area (collapsed when playing)
          if (!_playing && _words.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _textCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Paste text to read',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Load & start'),
                    onPressed: () {
                      _load();
                      _play();
                    },
                  ),
                ],
              ),
            ),

          // RSVP display
          if (_words.isNotEmpty)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_index + 1} / ${_words.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                  ),
                  const Spacer(),

                  // Word display with ORP pivot
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          left,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          pivot,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          right,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // WPM control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text('$_wpm wpm',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Expanded(
                          child: Slider(
                            value: _wpm.toDouble(),
                            min: 60,
                            max: 1000,
                            divisions: 94,
                            onChanged: (v) {
                              final wasPlaying = _playing;
                              _pause();
                              setState(() => _wpm = v.round());
                              if (wasPlaying) _play();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.outlined(
                        icon: const Icon(Icons.restart_alt),
                        tooltip: 'Restart',
                        onPressed: _reset,
                      ),
                      const SizedBox(width: 12),
                      IconButton.outlined(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: '−10 words',
                        onPressed: () {
                          setState(() => _index = (_index - 10).clamp(0, _words.length - 1));
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        label: Text(_playing ? 'Pause' : 'Play'),
                        onPressed: _playing ? _pause : _play,
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        icon: const Icon(Icons.skip_next),
                        tooltip: '+10 words',
                        onPressed: () {
                          setState(() => _index = (_index + 10).clamp(0, _words.length - 1));
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton.outlined(
                        icon: const Icon(Icons.edit),
                        tooltip: 'New text',
                        onPressed: () {
                          _pause();
                          setState(() {
                            _words = [];
                            _index = 0;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
