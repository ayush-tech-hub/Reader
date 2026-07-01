import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Converts integers between binary, octal, decimal, and hexadecimal.
///
/// Any of the four fields can be the input — type in one and the others
/// update instantly.  Useful when working with hex colour codes, binary
/// data in documents, or memory addresses in technical writing.
class NumberBaseScreen extends StatefulWidget {
  const NumberBaseScreen({super.key});

  @override
  State<NumberBaseScreen> createState() => _NumberBaseScreenState();
}

class _NumberBaseScreenState extends State<NumberBaseScreen> {
  final _binCtrl = TextEditingController();
  final _octCtrl = TextEditingController();
  final _decCtrl = TextEditingController();
  final _hexCtrl = TextEditingController();
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _binCtrl.addListener(() => _update(_binCtrl, 2));
    _octCtrl.addListener(() => _update(_octCtrl, 8));
    _decCtrl.addListener(() => _update(_decCtrl, 10));
    _hexCtrl.addListener(() => _update(_hexCtrl, 16));
  }

  @override
  void dispose() {
    _binCtrl.dispose();
    _octCtrl.dispose();
    _decCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  void _update(TextEditingController source, int radix) {
    if (_updating) return;
    final text = source.text.trim();
    if (text.isEmpty) {
      _setAll('', '', '', '');
      setState(() => _error = null);
      return;
    }
    try {
      final value = BigInt.parse(text, radix: radix);
      _updating = true;
      if (source != _binCtrl)
        _binCtrl.text = value.toRadixString(2).toUpperCase();
      if (source != _octCtrl)
        _octCtrl.text = value.toRadixString(8);
      if (source != _decCtrl) _decCtrl.text = value.toString();
      if (source != _hexCtrl)
        _hexCtrl.text = value.toRadixString(16).toUpperCase();
      _updating = false;
      setState(() => _error = null);
    } catch (_) {
      _updating = false;
      setState(() => _error = 'Invalid ${_radixName(radix)} number');
    }
  }

  void _setAll(String bin, String oct, String dec, String hex) {
    _updating = true;
    _binCtrl.text = bin;
    _octCtrl.text = oct;
    _decCtrl.text = dec;
    _hexCtrl.text = hex;
    _updating = false;
  }

  String _radixName(int r) =>
      {2: 'binary', 8: 'octal', 10: 'decimal', 16: 'hexadecimal'}[r] ?? '';

  Widget _field(String label, String prefix, TextEditingController ctrl,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          prefixText: '$prefix  ',
          prefixStyle: const TextStyle(
              fontFamily: 'monospace', color: Colors.grey, fontSize: 13),
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ctrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Number Base Converter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear',
            onPressed: () {
              _setAll('', '', '', '');
              setState(() => _error = null);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field('Binary (base 2)', 'BIN', _binCtrl, hint: '1010'),
            _field('Octal (base 8)', 'OCT', _octCtrl, hint: '12'),
            _field('Decimal (base 10)', 'DEC', _decCtrl, hint: '10'),
            _field('Hexadecimal (base 16)', 'HEX', _hexCtrl, hint: 'A'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            // Quick presets
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick presets',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (label, dec) in [
                  ('0xFF', 255),
                  ('0x80', 128),
                  ('256', 256),
                  ('1024', 1024),
                  ('65535', 65535),
                  ('Max uint8', 255),
                  ('Max uint16', 65535),
                  ('Max uint32', 4294967295),
                ])
                  ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _updating = true;
                      _decCtrl.text = dec.toString();
                      _updating = false;
                      _update(_decCtrl, 10);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
