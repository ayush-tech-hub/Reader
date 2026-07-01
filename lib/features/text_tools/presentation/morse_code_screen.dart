import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MorseCodeScreen extends StatefulWidget {
  const MorseCodeScreen({super.key});

  @override
  State<MorseCodeScreen> createState() => _MorseCodeScreenState();
}

class _MorseCodeScreenState extends State<MorseCodeScreen> {
  final _inputCtrl = TextEditingController();
  String _result = '';
  bool _encodeMode = true; // true = text→morse, false = morse→text

  static const _encode = <String, String>{
    'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
    'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
    'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
    'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
    'Y': '-.--', 'Z': '--..',
    '0': '-----', '1': '.----', '2': '..---', '3': '...--', '4': '....-',
    '5': '.....', '6': '-....', '7': '--...', '8': '---..', '9': '----.',
    '.': '.-.-.-', ',': '--..--', '?': '..--..', "'": '.----.',
    '!': '-.-.--', '/': '-..-.', '(': '-.--.', ')': '-.--.-',
    '&': '.-...', ':': '---...', ';': '-.-.-.',
    '=': '-...-', '+': '.-.-.', '-': '-....-', '_': '..--.-',
    '"': '.-..-.', '$': '...-..-', '@': '.--.-.',
  };

  static final _decode = {
    for (final e in _encode.entries) e.value: e.key,
  };

  void _convert() {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _result = '');
      return;
    }

    if (_encodeMode) {
      // Text → Morse: each word separated by ' / ', chars by ' '
      final words = input.toUpperCase().split(RegExp(r'\s+'));
      final encoded = words.map((word) {
        return word.split('').map((c) => _encode[c] ?? '?').join(' ');
      }).join(' / ');
      setState(() => _result = encoded);
    } else {
      // Morse → Text: words separated by ' / ' or '  ', chars by ' '
      final wordTokens =
          input.split(RegExp(r'\s*/\s*|\s{2,}'));
      final decoded = wordTokens.map((word) {
        final chars = word.trim().split(RegExp(r'\s+'));
        return chars.map((c) => _decode[c] ?? '?').join();
      }).join(' ');
      setState(() => _result = decoded);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Morse Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode switcher
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Text → Morse'),
                    icon: Icon(Icons.text_fields)),
                ButtonSegment(
                    value: false,
                    label: Text('Morse → Text'),
                    icon: Icon(Icons.abc)),
              ],
              selected: {_encodeMode},
              onSelectionChanged: (s) {
                setState(() {
                  _encodeMode = s.first;
                  _result = '';
                  _inputCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputCtrl,
              maxLines: 4,
              style: _encodeMode
                  ? null
                  : const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _encodeMode
                    ? 'Enter text… (e.g. Hello World)'
                    : 'Enter Morse… (e.g. .... . / .-- --- .-. .-.. -..)',
                labelText: _encodeMode ? 'Text input' : 'Morse input',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _convert,
              icon: const Icon(Icons.compare_arrows),
              label: Text(_encodeMode ? 'Encode' : 'Decode'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Result',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: scheme.primary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_vert, size: 18),
                    tooltip: 'Use as input',
                    onPressed: () {
                      _inputCtrl.text = _result;
                      setState(() {
                        _encodeMode = !_encodeMode;
                        _result = '';
                      });
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: TextStyle(
                      fontFamily: !_encodeMode ? null : 'monospace',
                      fontSize: 13,
                      letterSpacing: !_encodeMode ? null : 1.2,
                    ),
                  ),
                ),
              ),
            ],
            if (_result.isEmpty && !_encodeMode) ...[
              const SizedBox(height: 16),
              Text(
                'Use spaces between symbols, space + / + space between words.\n'
                'Example:  .... . / .-- --- .-. .-.. -..',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
