import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates colour palettes from a base colour using colour theory.
class ColorPaletteScreen extends StatefulWidget {
  const ColorPaletteScreen({super.key});

  @override
  State<ColorPaletteScreen> createState() => _ColorPaletteScreenState();
}

class _ColorPaletteScreenState extends State<ColorPaletteScreen> {
  Color _base = const Color(0xFF2196F3); // Material Blue
  final _hexCtrl = TextEditingController(text: '2196F3');

  // ── Colour math ────────────────────────────────────────────────────────────

  List<double> _toHsl(Color c) {
    final r = c.red / 255, g = c.green / 255, b = c.blue / 255;
    final mx = max(r, max(g, b));
    final mn = min(r, min(g, b));
    final l = (mx + mn) / 2;
    if (mx == mn) return [0, 0, l];
    final d = mx - mn;
    final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    double h;
    if (mx == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return [h / 6, s, l];
  }

  Color _fromHsl(double h, double s, double l) {
    h = h % 1.0;
    if (h < 0) h += 1;
    if (s == 0) {
      final v = (l * 255).round();
      return Color.fromARGB(255, v, v, v);
    }
    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final r = (hue2rgb(p, q, h + 1 / 3) * 255).round().clamp(0, 255);
    final g = (hue2rgb(p, q, h) * 255).round().clamp(0, 255);
    final b = (hue2rgb(p, q, h - 1 / 3) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  String _hex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  List<Color> _complementary() {
    final hsl = _toHsl(_base);
    return [_base, _fromHsl(hsl[0] + 0.5, hsl[1], hsl[2])];
  }

  List<Color> _analogous() {
    final hsl = _toHsl(_base);
    return [
      _fromHsl(hsl[0] - 1 / 12, hsl[1], hsl[2]),
      _base,
      _fromHsl(hsl[0] + 1 / 12, hsl[1], hsl[2]),
    ];
  }

  List<Color> _triadic() {
    final hsl = _toHsl(_base);
    return [
      _base,
      _fromHsl(hsl[0] + 1 / 3, hsl[1], hsl[2]),
      _fromHsl(hsl[0] + 2 / 3, hsl[1], hsl[2]),
    ];
  }

  List<Color> _splitComplementary() {
    final hsl = _toHsl(_base);
    return [
      _base,
      _fromHsl(hsl[0] + 5 / 12, hsl[1], hsl[2]),
      _fromHsl(hsl[0] + 7 / 12, hsl[1], hsl[2]),
    ];
  }

  List<Color> _monochromatic() {
    final hsl = _toHsl(_base);
    return [
      _fromHsl(hsl[0], hsl[1], (hsl[2] * 0.4).clamp(0, 1)),
      _fromHsl(hsl[0], hsl[1], (hsl[2] * 0.7).clamp(0, 1)),
      _base,
      _fromHsl(hsl[0], hsl[1] * 0.6, min(1, hsl[2] * 1.3 + 0.1)),
      _fromHsl(hsl[0], hsl[1] * 0.3, min(1, hsl[2] * 1.6 + 0.2)),
    ];
  }

  List<Color> _shades() {
    final hsl = _toHsl(_base);
    return [
      for (var i = 9; i >= 1; i--)
        _fromHsl(hsl[0], hsl[1], i * 0.1),
    ];
  }

  void _fromHex(String hex) {
    hex = hex.replaceAll('#', '').trim();
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) setState(() => _base = Color(0xFF000000 | val));
    }
  }

  void _copy(BuildContext ctx, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text('$text copied!')));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palettes = [
      ('Monochromatic', _monochromatic()),
      ('Complementary', _complementary()),
      ('Analogous', _analogous()),
      ('Triadic', _triadic()),
      ('Split-Complementary', _splitComplementary()),
      ('Shades', _shades()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Colour Palette Generator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Base colour input
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  // Cycle through some preset colours on tap
                  final presets = [
                    0xFF2196F3, 0xFFE91E63, 0xFF4CAF50,
                    0xFFFF9800, 0xFF9C27B0, 0xFF00BCD4,
                    0xFFF44336, 0xFF795548,
                  ];
                  final cur = presets.indexOf(_base.value);
                  final next = presets[(cur + 1) % presets.length];
                  setState(() {
                    _base = Color(next);
                    _hexCtrl.text =
                        _hex(_base).replaceAll('#', '');
                  });
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _base,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: _base.withOpacity(0.4),
                          blurRadius: 8)
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _hexCtrl,
                  onChanged: _fromHex,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    prefixText: '#',
                    border: OutlineInputBorder(),
                    labelText: 'Base colour (hex)',
                    isDense: true,
                  ),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Tap the swatch to cycle presets',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),

          for (final (name, colours) in palettes) ...[
            Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  for (final c in colours)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _copy(context, _hex(c)),
                        child: Container(
                          color: c,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2),
                                color: Colors.black.withOpacity(0.25),
                                child: Text(
                                  _hex(c),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in colours)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(_hex(c),
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace')),
                        onPressed: () => _copy(context, _hex(c)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.copy_all, size: 14),
                    label: const Text('All', style: TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _copy(context, colours.map(_hex).join('\n')),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
