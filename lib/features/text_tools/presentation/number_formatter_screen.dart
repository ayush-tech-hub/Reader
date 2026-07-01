import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats numbers in various ways: locale separators, scientific,
/// currency, byte sizes, ordinals, etc.
class NumberFormatterScreen extends StatefulWidget {
  const NumberFormatterScreen({super.key});

  @override
  State<NumberFormatterScreen> createState() => _NumberFormatterScreenState();
}

class _NumberFormatterScreenState extends State<NumberFormatterScreen> {
  final _inputCtrl = TextEditingController();
  List<_Row> _rows = [];
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  String _fmtBytes(double bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var v = bytes;
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(2)} ${units[i]}';
  }

  String _words(int n) {
    if (n == 0) return 'zero';
    final ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
        'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
        'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
    final tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty',
        'seventy', 'eighty', 'ninety'];
    String below1000(int n) {
      if (n < 20) return ones[n];
      if (n < 100) {
        return tens[n ~/ 10] + (n % 10 != 0 ? '-${ones[n % 10]}' : '');
      }
      return '${ones[n ~/ 100]} hundred' +
          (n % 100 != 0 ? ' and ${below1000(n % 100)}' : '');
    }
    final parts = <String>[];
    final billions = n ~/ 1000000000;
    final millions = (n % 1000000000) ~/ 1000000;
    final thousands = (n % 1000000) ~/ 1000;
    final rem = n % 1000;
    if (billions > 0) parts.add('${below1000(billions)} billion');
    if (millions > 0) parts.add('${below1000(millions)} million');
    if (thousands > 0) parts.add('${below1000(thousands)} thousand');
    if (rem > 0) parts.add(below1000(rem));
    return parts.join(', ');
  }

  void _format() {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) return;
    final num = double.tryParse(raw.replaceAll(',', ''));
    if (num == null) {
      setState(() {
        _rows = [];
        _error = 'Not a valid number';
      });
      return;
    }

    final intNum = num.toInt();
    final absNum = num.abs();
    final rows = <_Row>[];

    // Standard with commas
    rows.add(_Row('Comma separated', NumberFormat('#,##0.######').format(num)));

    // Without decimals
    if (num == num.roundToDouble()) {
      rows.add(_Row('Integer', NumberFormat('#,##0').format(num)));
    }

    // Fixed decimals
    rows.add(_Row('2 decimal places', NumberFormat('#,##0.00').format(num)));

    // Percent
    rows.add(_Row('Percentage', '${(num * 100).toStringAsFixed(2)}%'));

    // Scientific notation
    rows.add(_Row('Scientific', num.toStringAsExponential(4)));

    // Engineering (exponent multiple of 3)
    final exp = num == 0 ? 0 : (log(absNum) / ln10).floor();
    final engExp = (exp / 3).floor() * 3;
    final engCoeff = absNum / pow(10, engExp);
    rows.add(_Row('Engineering',
        '${(num < 0 ? -engCoeff : engCoeff).toStringAsFixed(3)} × 10^$engExp'));

    // Currency (USD, EUR, GBP)
    rows.add(_Row('USD', NumberFormat.currency(symbol: '\$').format(num)));
    rows.add(_Row('EUR', NumberFormat.currency(symbol: '€').format(num)));
    rows.add(_Row('GBP', NumberFormat.currency(symbol: '£').format(num)));

    // Bytes
    if (absNum >= 0 && absNum < 1e18) {
      rows.add(_Row('File size', _fmtBytes(absNum)));
    }

    // Ordinal (integers only)
    if (num == intNum.toDouble() && intNum >= 0 && intNum < 1000000) {
      rows.add(_Row('Ordinal', _ordinal(intNum)));
    }

    // Words (integers, reasonable range)
    if (num == intNum.toDouble() && intNum.abs() < 1000000000) {
      rows.add(_Row('In words', _words(intNum.abs())));
    }

    // Roman (1–3999)
    if (num == intNum.toDouble() && intNum >= 1 && intNum <= 3999) {
      rows.add(_Row('Roman numerals', _toRoman(intNum)));
    }

    // Binary/Hex/Octal (integers up to 2^32)
    if (num == intNum.toDouble() && intNum >= 0 && intNum < 4294967296) {
      rows.add(_Row('Binary', '0b${intNum.toRadixString(2)}'));
      rows.add(_Row('Octal', '0o${intNum.toRadixString(8)}'));
      rows.add(_Row('Hex', '0x${intNum.toRadixString(16).toUpperCase()}'));
    }

    setState(() {
      _rows = rows;
      _error = null;
    });
  }

  static const _romanVals = [
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'),
    (100, 'C'),  (90, 'XC'),  (50, 'L'),  (40, 'XL'),
    (10, 'X'),   (9, 'IX'),   (5, 'V'),   (4, 'IV'),
    (1, 'I'),
  ];

  String _toRoman(int n) {
    final buf = StringBuffer();
    for (final (val, sym) in _romanVals) {
      while (n >= val) { buf.write(sym); n -= val; }
    }
    return buf.toString();
  }

  void _copy(BuildContext ctx, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text('$label copied!')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Number Formatter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              onSubmitted: (_) => _format(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Number',
                hintText: 'Enter any number…',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _format,
              icon: const Icon(Icons.format_list_numbered),
              label: const Text('Format'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final row = _rows[i];
                    return ListTile(
                      dense: true,
                      title: Text(row.label,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      subtitle: SelectableText(row.value,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copy(context, row.value, row.label),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}
