import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech screen with speed, pitch, and volume controls.
class TextToSpeechScreen extends StatefulWidget {
  const TextToSpeechScreen({super.key});

  @override
  State<TextToSpeechScreen> createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  final _tts = FlutterTts();
  final _ctrl = TextEditingController();
  double _rate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  bool _speaking = false;
  bool _paused = false;
  List<String> _voices = [];
  String? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);

    _tts.setStartHandler(() => setState(() { _speaking = true; _paused = false; }));
    _tts.setCompletionHandler(() => setState(() { _speaking = false; _paused = false; }));
    _tts.setCancelHandler(() => setState(() { _speaking = false; _paused = false; }));
    _tts.setPauseHandler(() => setState(() => _paused = true));
    _tts.setContinueHandler(() => setState(() => _paused = false));

    final voices = await _tts.getVoices;
    if (voices is List) {
      final names = voices
          .whereType<Map>()
          .where((v) => (v['locale'] as String? ?? '').startsWith('en'))
          .map((v) => v['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (mounted) setState(() => _voices = names);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(_volume);
    if (_selectedVoice != null) {
      await _tts.setVoice({'name': _selectedVoice!, 'locale': 'en-US'});
    }
    await _tts.speak(text);
  }

  Future<void> _pauseResume() async {
    if (_paused) {
      await _tts.continueSpeak();
    } else {
      await _tts.pause();
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() { _speaking = false; _paused = false; });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wordCount = _ctrl.text.trim().isEmpty
        ? 0
        : _ctrl.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Text to Speech')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Text to speak',
                  alignLabelWithHint: true,
                  suffixText: '$wordCount words',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // Voice selector
            if (_voices.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedVoice,
                decoration: const InputDecoration(
                  labelText: 'Voice',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default')),
                  ..._voices.map((v) =>
                      DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _selectedVoice = v),
              ),

            const SizedBox(height: 8),
            _SliderRow('Rate', _rate, 0.1, 1.0, (v) => setState(() => _rate = v)),
            _SliderRow('Pitch', _pitch, 0.5, 2.0, (v) => setState(() => _pitch = v)),
            _SliderRow('Volume', _volume, 0.0, 1.0, (v) => setState(() => _volume = v)),
            const SizedBox(height: 12),

            // Controls
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _speaking ? null : _speak,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Speak'),
                  ),
                ),
                const SizedBox(width: 8),
                if (_speaking) ...[
                  FilledButton.tonal(
                    onPressed: _pauseResume,
                    child: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _stop,
                    style: FilledButton.styleFrom(
                        backgroundColor: scheme.errorContainer),
                    child: Icon(Icons.stop, color: scheme.onErrorContainer),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow(this.label, this.value, this.min, this.max, this.onChanged);
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      );
}
