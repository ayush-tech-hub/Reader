import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates secure random passwords.
///
/// Options: length (8–64), uppercase, lowercase, digits, symbols,
/// and exclude ambiguous characters (0/O, 1/I/l).
/// Generates up to 5 passwords at once for comparison.
class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  int _length = 16;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = true;
  bool _excludeAmbiguous = false;
  List<String> _passwords = [];

  static const _charsUpper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _charsUpperNoAmb = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // no I, O
  static const _charsLower = 'abcdefghijklmnopqrstuvwxyz';
  static const _charsLowerNoAmb = 'abcdefghjkmnpqrstuvwxyz'; // no i, l, o
  static const _charsDigits = '0123456789';
  static const _charsDigitsNoAmb = '23456789'; // no 0, 1
  static const _charsSymbols = r'!@#$%^&*()-_=+[]{}|;:,.<>?';

  void _generate() {
    final chars = StringBuffer();
    final required = <String>[];

    if (_upper) {
      final pool = _excludeAmbiguous ? _charsUpperNoAmb : _charsUpper;
      chars.write(pool);
      required.add(pool);
    }
    if (_lower) {
      final pool = _excludeAmbiguous ? _charsLowerNoAmb : _charsLower;
      chars.write(pool);
      required.add(pool);
    }
    if (_digits) {
      final pool = _excludeAmbiguous ? _charsDigitsNoAmb : _charsDigits;
      chars.write(pool);
      required.add(pool);
    }
    if (_symbols) {
      chars.write(_charsSymbols);
      required.add(_charsSymbols);
    }

    if (chars.isEmpty) return;
    final pool = chars.toString();
    final rng = Random.secure();

    List<String> genBatch(int count) => List.generate(count, (_) {
          while (true) {
            final pw = List.generate(
                _length, (_) => pool[rng.nextInt(pool.length)]).join();
            // Ensure at least one character from each required set
            if (required.every((set) => pw.split('').any(set.contains))) {
              return pw;
            }
          }
        });

    setState(() => _passwords = genBatch(5));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anyEnabled = _upper || _lower || _digits || _symbols;

    return Scaffold(
      appBar: AppBar(title: const Text('Password Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Length
                  Row(
                    children: [
                      const Text('Length:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: _length.toDouble(),
                          min: 8,
                          max: 64,
                          divisions: 56,
                          label: '$_length',
                          onChanged: (v) =>
                              setState(() => _length = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text('$_length',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end),
                      ),
                    ],
                  ),

                  // Character sets
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('A–Z'),
                        selected: _upper,
                        onSelected: (v) => setState(() => _upper = v),
                      ),
                      FilterChip(
                        label: const Text('a–z'),
                        selected: _lower,
                        onSelected: (v) => setState(() => _lower = v),
                      ),
                      FilterChip(
                        label: const Text('0–9'),
                        selected: _digits,
                        onSelected: (v) => setState(() => _digits = v),
                      ),
                      FilterChip(
                        label: const Text('!@#…'),
                        selected: _symbols,
                        onSelected: (v) => setState(() => _symbols = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text(
                        'Exclude ambiguous characters (0/O, 1/I/l)'),
                    value: _excludeAmbiguous,
                    onChanged: (v) => setState(() => _excludeAmbiguous = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: anyEnabled ? _generate : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate Passwords'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_passwords.isNotEmpty) ...[
            for (final pw in _passwords)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pw));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password copied')),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pw,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy, size: 18,
                            color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (_passwords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tap a password to copy it.  '
              'These are generated locally — nothing is sent over the network.',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
