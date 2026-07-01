import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WCAG 2.1 colour contrast checker.
///
/// Calculates the contrast ratio between foreground and background colours
/// and reports whether it passes WCAG AA and AAA at normal and large text sizes.
class ColorContrastScreen extends StatefulWidget {
  const ColorContrastScreen({super.key});

  @override
  State<ColorContrastScreen> createState() => _ColorContrastScreenState();
}

class _ColorContrastScreenState extends State<ColorContrastScreen> {
  Color _fg = Colors.black;
  Color _bg = Colors.white;

  final _fgCtrl = TextEditingController(text: '000000');
  final _bgCtrl = TextEditingController(text: 'FFFFFF');

  @override
  void dispose() {
    _fgCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _relativeLuminance(Color c) {
    double channel(int v) {
      final s = v / 255.0;
      return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
    }
    return 0.2126 * channel(c.red) +
        0.7152 * channel(c.green) +
        0.0722 * channel(c.blue);
  }

  double _contrastRatio(Color c1, Color c2) {
    final l1 = _relativeLuminance(c1);
    final l2 = _relativeLuminance(c2);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color? _parseHex(String hex) {
    hex = hex.replaceAll('#', '').trim();
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length != 6) return null;
    final val = int.tryParse(hex, radix: 16);
    if (val == null) return null;
    return Color(0xFF000000 | val);
  }

  void _fromHex(String hex, bool isFg) {
    final c = _parseHex(hex);
    if (c == null) return;
    setState(() {
      if (isFg) {
        _fg = c;
      } else {
        _bg = c;
      }
    });
  }

  String _hexOf(Color c) =>
      c.red.toRadixString(16).padLeft(2, '0') +
      c.green.toRadixString(16).padLeft(2, '0') +
      c.blue.toRadixString(16).padLeft(2, '0');

  void _swap() {
    setState(() {
      final tmp = _fg;
      _fg = _bg;
      _bg = tmp;
      _fgCtrl.text = _hexOf(_fg).toUpperCase();
      _bgCtrl.text = _hexOf(_bg).toUpperCase();
    });
  }

  void _pickColor(bool isFg) async {
    final initial = isFg ? _fg : _bg;
    Color picked = initial;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pick ${isFg ? "foreground" : "background"}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              for (final preset in [
                Colors.black, Colors.white, Colors.red, Colors.green,
                Colors.blue, Colors.yellow, Colors.orange, Colors.purple,
                Colors.teal, Colors.pink, Colors.brown, Colors.grey,
              ])
                ListTile(
                  dense: true,
                  leading: CircleAvatar(backgroundColor: preset),
                  title: Text('#${_hexOf(preset).toUpperCase()}'),
                  onTap: () {
                    picked = preset;
                    Navigator.pop(ctx, true);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      if (isFg) {
        _fg = picked;
        _fgCtrl.text = _hexOf(_fg).toUpperCase();
      } else {
        _bg = picked;
        _bgCtrl.text = _hexOf(_bg).toUpperCase();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _contrastRatio(_fg, _bg);
    final ratioStr = ratio.toStringAsFixed(2);

    final aaSmall = ratio >= 4.5;
    final aaaSmall = ratio >= 7.0;
    final aaLarge = ratio >= 3.0;
    final aaaLarge = ratio >= 4.5;

    Color ratioColor() {
      if (ratio >= 7.0) return Colors.green;
      if (ratio >= 4.5) return Colors.lightGreen;
      if (ratio >= 3.0) return Colors.orange;
      return Colors.red;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Colour Contrast Checker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview card
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).dividerColor),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sample Text',
                  style: TextStyle(
                      color: _fg,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'Normal size text',
                  style: TextStyle(color: _fg, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Colour pickers
          Row(
            children: [
              Expanded(child: _ColorInput(
                label: 'Foreground',
                color: _fg,
                ctrl: _fgCtrl,
                onHexChanged: (h) => _fromHex(h, true),
                onPick: () => _pickColor(true),
              )),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Swap',
                onPressed: _swap,
              ),
              Expanded(child: _ColorInput(
                label: 'Background',
                color: _bg,
                ctrl: _bgCtrl,
                onHexChanged: (h) => _fromHex(h, false),
                onPick: () => _pickColor(false),
              )),
            ],
          ),
          const SizedBox(height: 20),

          // Contrast ratio
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Contrast ratio',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '$ratioStr : 1',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ratioColor()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$ratioStr:1'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ratio copied!')));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // WCAG results
          Table(
            border: TableBorder.all(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(8)),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              _tableHeader(),
              _tableRow('Normal text (< 18pt)', aaSmall, aaaSmall,
                  'AA ≥ 4.5', 'AAA ≥ 7.0'),
              _tableRow('Large text (≥ 18pt / bold 14pt)', aaLarge,
                  aaaLarge, 'AA ≥ 3.0', 'AAA ≥ 4.5'),
            ],
          ),
          const SizedBox(height: 16),

          // Info
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'WCAG 2.1 defines four conformance levels:\n'
                '• AA (minimum) — 4.5:1 for normal, 3:1 for large text\n'
                '• AAA (enhanced) — 7:1 for normal, 4.5:1 for large text\n\n'
                'Large text = ≥18pt regular or ≥14pt bold (≈24px / 19px).',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _tableHeader() => TableRow(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        children: const [
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('AA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('AAA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );

  TableRow _tableRow(String label, bool aa, bool aaa, String aaReq,
      String aaaReq) =>
      TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child:
                Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Icon(aa ? Icons.check_circle : Icons.cancel,
                  color: aa ? Colors.green : Colors.red, size: 18),
              const SizedBox(width: 4),
              Text(aaReq,
                  style:
                      const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Icon(aaa ? Icons.check_circle : Icons.cancel,
                  color: aaa ? Colors.green : Colors.red, size: 18),
              const SizedBox(width: 4),
              Text(aaaReq,
                  style:
                      const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ],
      );
}

class _ColorInput extends StatelessWidget {
  const _ColorInput({
    required this.label,
    required this.color,
    required this.ctrl,
    required this.onHexChanged,
    required this.onPick,
  });

  final String label;
  final Color color;
  final TextEditingController ctrl;
  final ValueChanged<String> onHexChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            GestureDetector(
              onTap: onPick,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Theme.of(context).dividerColor),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: ctrl,
                onChanged: onHexChanged,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  prefixText: '#',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
