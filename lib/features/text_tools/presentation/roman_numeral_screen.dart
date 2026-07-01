import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RomanNumeralScreen extends StatefulWidget {
  const RomanNumeralScreen({super.key});

  @override
  State<RomanNumeralScreen> createState() => _RomanNumeralScreenState();
}

class _RomanNumeralScreenState extends State<RomanNumeralScreen> {
  final _inputCtrl = TextEditingController();
  String _result = '';
  String? _error;
  bool _toRoman = true;

  static const _vals = [
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'),
    (100, 'C'),  (90, 'XC'),  (50, 'L'),  (40, 'XL'),
    (10, 'X'),   (9, 'IX'),   (5, 'V'),   (4, 'IV'),
    (1, 'I'),
  ];

  String _intToRoman(int n) {
    if (n < 1 || n > 3999) throw RangeError('Must be 1–3999');
    final buf = StringBuffer();
    for (final (val, sym) in _vals) {
      while (n >= val) {
        buf.write(sym);
        n -= val;
      }
    }
    return buf.toString();
  }

  int _romanToInt(String s) {
    const map = {
      'I': 1, 'V': 5, 'X': 10, 'L': 50,
      'C': 100, 'D': 500, 'M': 1000,
    };
    s = s.toUpperCase().trim();
    if (s.isEmpty) throw FormatException('Empty input');
    int total = 0;
    for (var i = 0; i < s.length; i++) {
      final cur = map[s[i]];
      if (cur == null) throw FormatException('Invalid character: ${s[i]}');
      final next = i + 1 < s.length ? map[s[i + 1]] : null;
      if (next != null && next > cur) {
        total -= cur;
      } else {
        total += cur;
      }
    }
    if (total < 1 || total > 3999) throw RangeError('Result out of range');
    return total;
  }

  void _convert() {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    try {
      if (_toRoman) {
        final n = int.parse(input);
        setState(() {
          _result = _intToRoman(n);
          _error = null;
        });
      } else {
        final n = _romanToInt(input);
        setState(() {
          _result = n.toString();
          _error = null;
        });
      }
    } on FormatException {
      setState(() {
        _result = '';
        _error = 'Invalid Roman numeral';
      });
    } on RangeError catch (e) {
      setState(() {
        _result = '';
        _error = e.message.toString();
      });
    } catch (_) {
      setState(() {
        _result = '';
        _error = 'Invalid input';
      });
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
      appBar: AppBar(title: const Text('Roman Numerals')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Number → Roman'),
                    icon: Icon(Icons.tag)),
                ButtonSegment(
                    value: false,
                    label: Text('Roman → Number'),
                    icon: Icon(Icons.abc)),
              ],
              selected: {_toRoman},
              onSelectionChanged: (s) {
                setState(() {
                  _toRoman = s.first;
                  _result = '';
                  _error = null;
                  _inputCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputCtrl,
              keyboardType:
                  _toRoman ? TextInputType.number : TextInputType.text,
              textCapitalization: _toRoman
                  ? TextCapitalization.none
                  : TextCapitalization.characters,
              onSubmitted: (_) => _convert(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _toRoman
                    ? 'Enter integer (1–3999)…'
                    : 'Enter Roman numeral (e.g. XLII)…',
                labelText: _toRoman ? 'Integer' : 'Roman',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _convert,
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Convert'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _toRoman ? 'Roman Numeral' : 'Integer',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _result,
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Quick reference table
            Text('Quick reference',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (val, sym) in _vals)
                  Chip(
                    label: Text('$sym = $val',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
