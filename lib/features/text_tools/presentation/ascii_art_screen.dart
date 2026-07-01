import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Converts text to ASCII art using block-character fonts.
class AsciiArtScreen extends StatefulWidget {
  const AsciiArtScreen({super.key});

  @override
  State<AsciiArtScreen> createState() => _AsciiArtScreenState();
}

// Each character is 5 rows of 5 chars (space separated).
// 0-indexed: 0–9 digits, then A-Z letters.
const _block5 = {
  ' ': ['     ', '     ', '     ', '     ', '     '],
  'A': [' ███ ', '█   █', '█████', '█   █', '█   █'],
  'B': ['████ ', '█   █', '████ ', '█   █', '████ '],
  'C': [' ████', '█    ', '█    ', '█    ', ' ████'],
  'D': ['████ ', '█   █', '█   █', '█   █', '████ '],
  'E': ['█████', '█    ', '████ ', '█    ', '█████'],
  'F': ['█████', '█    ', '████ ', '█    ', '█    '],
  'G': [' ████', '█    ', '█  ██', '█   █', ' ████'],
  'H': ['█   █', '█   █', '█████', '█   █', '█   █'],
  'I': ['█████', '  █  ', '  █  ', '  █  ', '█████'],
  'J': ['█████', '    █', '    █', '█   █', ' ███ '],
  'K': ['█   █', '█  █ ', '███  ', '█  █ ', '█   █'],
  'L': ['█    ', '█    ', '█    ', '█    ', '█████'],
  'M': ['█   █', '██ ██', '█ █ █', '█   █', '█   █'],
  'N': ['█   █', '██  █', '█ █ █', '█  ██', '█   █'],
  'O': [' ███ ', '█   █', '█   █', '█   █', ' ███ '],
  'P': ['████ ', '█   █', '████ ', '█    ', '█    '],
  'Q': [' ███ ', '█   █', '█ █ █', '█  ██', ' ████'],
  'R': ['████ ', '█   █', '████ ', '█  █ ', '█   █'],
  'S': [' ████', '█    ', ' ███ ', '    █', '████ '],
  'T': ['█████', '  █  ', '  █  ', '  █  ', '  █  '],
  'U': ['█   █', '█   █', '█   █', '█   █', ' ███ '],
  'V': ['█   █', '█   █', '█   █', ' █ █ ', '  █  '],
  'W': ['█   █', '█   █', '█ █ █', '██ ██', '█   █'],
  'X': ['█   █', ' █ █ ', '  █  ', ' █ █ ', '█   █'],
  'Y': ['█   █', ' █ █ ', '  █  ', '  █  ', '  █  '],
  'Z': ['█████', '   █ ', '  █  ', ' █   ', '█████'],
  '0': [' ███ ', '█  ██', '█ █ █', '██  █', ' ███ '],
  '1': ['  █  ', ' ██  ', '  █  ', '  █  ', '█████'],
  '2': [' ███ ', '█   █', '  ██ ', ' █   ', '█████'],
  '3': ['████ ', '    █', ' ███ ', '    █', '████ '],
  '4': ['█   █', '█   █', '█████', '    █', '    █'],
  '5': ['█████', '█    ', '████ ', '    █', '████ '],
  '6': [' ███ ', '█    ', '████ ', '█   █', ' ███ '],
  '7': ['█████', '    █', '   █ ', '  █  ', ' █   '],
  '8': [' ███ ', '█   █', ' ███ ', '█   █', ' ███ '],
  '9': [' ███ ', '█   █', ' ████', '    █', ' ███ '],
  '!': ['  █  ', '  █  ', '  █  ', '     ', '  █  '],
  '?': [' ███ ', '    █', '  ██ ', '     ', '  █  '],
  '.': ['     ', '     ', '     ', '     ', '  █  '],
  ',': ['     ', '     ', '     ', '  █  ', ' █   '],
  '-': ['     ', '     ', '█████', '     ', '     '],
  '_': ['     ', '     ', '     ', '     ', '█████'],
  '+': ['     ', '  █  ', '█████', '  █  ', '     '],
  '*': ['█ █ █', ' ███ ', '█████', ' ███ ', '█ █ █'],
  '/': ['    █', '   █ ', '  █  ', ' █   ', '█    '],
  '\\': ['█    ', ' █   ', '  █  ', '   █ ', '    █'],
  '(': ['  █  ', ' █   ', ' █   ', ' █   ', '  █  '],
  ')': ['  █  ', '   █ ', '   █ ', '   █ ', '  █  '],
  '#': [' █ █ ', '█████', ' █ █ ', '█████', ' █ █ '],
  '@': [' ███ ', '█ ███', '█ █ █', '█ ███', ' ███ '],
  '&': [' ██  ', '█  █ ', ' ██  ', '█  ██', ' ██ █'],
  '%': ['█  █ ', '   █ ', '  █  ', ' █   ', ' █  █'],
  '$': [' ████', '█ █  ', ' ███ ', '  █ █', '████ '],
};

// Fallback for unknown chars: 5 rows of 5 spaces
const _fallback = ['     ', '     ', '     ', '     ', '     '];

String _toAsciiArt(String text, {String fill = '█', bool wide = false}) {
  final chars = text.toUpperCase().split('');
  final gap = wide ? '  ' : ' ';
  final rows = List.generate(5, (row) {
    return chars.map((c) {
      final glyph = (_block5[c] ?? _fallback)[row];
      return wide ? glyph.split('').join(' ') : glyph;
    }).join(gap);
  });
  return rows.join('\n');
}

class _StyleOption {
  const _StyleOption(this.label, this.fill, this.wide);
  final String label;
  final String fill;
  final bool wide;
}

const _styles = [
  _StyleOption('Block (█)', '█', false),
  _StyleOption('Dots (•)', '•', false),
  _StyleOption('Hash (#)', '#', false),
  _StyleOption('Wide (█ )', '█', true),
];

class _AsciiArtScreenState extends State<AsciiArtScreen> {
  final _ctrl = TextEditingController();
  String _output = '';
  int _styleIndex = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _generate() {
    final style = _styles[_styleIndex];
    var art = _toAsciiArt(_ctrl.text, fill: style.fill, wide: style.wide);
    if (style.fill != '█') {
      art = art.replaceAll('█', style.fill);
    }
    setState(() => _output = art);
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _output));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ASCII art copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASCII Art Generator'),
        actions: [
          if (_output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: _copy,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              maxLength: 12,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Text (max 12 chars)',
                hintText: 'Hello',
              ),
              onSubmitted: (_) => _generate(),
            ),
            const SizedBox(height: 8),
            // Style selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _styles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_styles[i].label),
                        selected: _styleIndex == i,
                        onSelected: (_) => setState(() => _styleIndex = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.text_fields),
              label: const Text('Generate'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            if (_output.isNotEmpty) ...[
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  color: scheme.surfaceContainerHighest,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy to Clipboard'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
