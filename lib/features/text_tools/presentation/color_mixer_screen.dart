import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Interactive color mixer: blend two or more colours and explore palettes.
class ColorMixerScreen extends StatefulWidget {
  const ColorMixerScreen({super.key});

  @override
  State<ColorMixerScreen> createState() => _ColorMixerScreenState();
}

class _ColorMixerScreenState extends State<ColorMixerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Mixer tab state
  Color _colorA = Colors.red;
  Color _colorB = Colors.blue;
  double _blend = 0.5;

  // RGB builder tab state
  double _r = 128, _g = 64, _b = 200;

  // Palette tab state
  Color _baseColor = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Color get _mixed => Color.lerp(_colorA, _colorB, _blend)!;
  Color get _rgbColor => Color.fromARGB(255, _r.round(), _g.round(), _b.round());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Mixer'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Mix'),
            Tab(text: 'RGB Builder'),
            Tab(text: 'Palette'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MixerTab(
            colorA: _colorA,
            colorB: _colorB,
            blend: _blend,
            mixed: _mixed,
            onColorAChanged: (c) => setState(() => _colorA = c),
            onColorBChanged: (c) => setState(() => _colorB = c),
            onBlendChanged: (v) => setState(() => _blend = v),
          ),
          _RgbBuilderTab(
            r: _r, g: _g, b: _b, color: _rgbColor,
            onRChanged: (v) => setState(() => _r = v),
            onGChanged: (v) => setState(() => _g = v),
            onBChanged: (v) => setState(() => _b = v),
          ),
          _PaletteTab(
            base: _baseColor,
            onBaseChanged: (c) => setState(() => _baseColor = c),
          ),
        ],
      ),
    );
  }
}

// ─── Mixer Tab ───────────────────────────────────────────────────────────────

class _MixerTab extends StatelessWidget {
  const _MixerTab({
    required this.colorA,
    required this.colorB,
    required this.blend,
    required this.mixed,
    required this.onColorAChanged,
    required this.onColorBChanged,
    required this.onBlendChanged,
  });

  final Color colorA, colorB, mixed;
  final double blend;
  final ValueChanged<Color> onColorAChanged, onColorBChanged;
  final ValueChanged<double> onBlendChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _ColorSwatch('Color A', colorA, onColorAChanged)),
            const SizedBox(width: 12),
            Expanded(child: _ColorSwatch('Color B', colorB, onColorBChanged)),
          ]),
          const SizedBox(height: 16),
          Text('Mix ratio: ${(blend * 100).round()}% B',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: blend,
            onChanged: onBlendChanged,
            divisions: 20,
            label: '${(blend * 100).round()}%',
          ),
          const SizedBox(height: 12),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: mixed,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(blurRadius: 8, color: mixed.withOpacity(0.4))],
            ),
          ),
          const SizedBox(height: 12),
          _HexDisplay(mixed),
          const SizedBox(height: 20),
          // Gradient preview
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: [colorA, colorB]),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Gradient A → B', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          // Blended steps
          Row(children: [
            for (int i = 0; i <= 10; i++)
              Expanded(
                child: Container(
                  height: 32,
                  color: Color.lerp(colorA, colorB, i / 10),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          const Text('10-step blend', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── RGB Builder Tab ─────────────────────────────────────────────────────────

class _RgbBuilderTab extends StatelessWidget {
  const _RgbBuilderTab({
    required this.r, required this.g, required this.b,
    required this.color,
    required this.onRChanged, required this.onGChanged, required this.onBChanged,
  });

  final double r, g, b;
  final Color color;
  final ValueChanged<double> onRChanged, onGChanged, onBChanged;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(blurRadius: 12, color: color.withOpacity(0.5))],
            ),
          ),
          const SizedBox(height: 12),
          _HexDisplay(color),
          const SizedBox(height: 8),
          Text(
            'rgb(${r.round()}, ${g.round()}, ${b.round()})',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          Text(
            'hsl(${(hsl.hue).round()}°, ${(hsl.saturation * 100).round()}%, ${(hsl.lightness * 100).round()}%)',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _RgbSlider('R', r, Colors.red, onRChanged),
          _RgbSlider('G', g, Colors.green, onGChanged),
          _RgbSlider('B', b, Colors.blue, onBChanged),
        ],
      ),
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider(this.label, this.value, this.color, this.onChanged);
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(label, style: TextStyle(
                fontWeight: FontWeight.bold, color: color)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: color),
              child: Slider(
                value: value,
                max: 255,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(value.round().toString(), textAlign: TextAlign.right),
          ),
        ],
      );
}

// ─── Palette Tab ─────────────────────────────────────────────────────────────

class _PaletteTab extends StatelessWidget {
  const _PaletteTab({required this.base, required this.onBaseChanged});
  final Color base;
  final ValueChanged<Color> onBaseChanged;

  List<Color> get _complementary => [base, _rotateHue(base, 180)];
  List<Color> get _analogous => [
        _rotateHue(base, -30), base, _rotateHue(base, 30),
      ];
  List<Color> get _triadic => [
        base, _rotateHue(base, 120), _rotateHue(base, 240),
      ];
  List<Color> get _shades => [
        for (int i = 1; i <= 9; i++)
          HSLColor.fromColor(base).withLightness(i * 0.1).toColor()
      ];

  static Color _rotateHue(Color c, double deg) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withHue((hsl.hue + deg) % 360).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ColorSwatch('Base Color', base, onBaseChanged),
          const SizedBox(height: 16),
          _PaletteRow('Complementary', _complementary),
          _PaletteRow('Analogous', _analogous),
          _PaletteRow('Triadic', _triadic),
          const Text('Shades', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: _shades.map((c) => Expanded(
              child: GestureDetector(
                onTap: () => _copyHex(context, c),
                child: Container(
                  height: 48,
                  color: c,
                  child: Center(
                    child: Text(
                      _hexStr(c),
                      style: TextStyle(
                        fontSize: 8,
                        color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ))).toList()),
        ],
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow(this.label, this.colors);
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: colors.map((c) => Expanded(
              child: GestureDetector(
                onTap: () => _copyHex(context, c),
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      _hexStr(c),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ))).toList()),
          const SizedBox(height: 12),
        ],
      );
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch(this.label, this.color, this.onChanged);
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showColorPicker(context, color, onChanged),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  _hexStr(color),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Tap to change', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

class _HexDisplay extends StatelessWidget {
  const _HexDisplay(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _copyHex(context, color),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.copy, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            _hexStr(color),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                fontFamily: 'monospace'),
          ),
        ]),
      );
}

String _hexStr(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}'
    '${c.green.toRadixString(16).padLeft(2, '0')}'
    '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

void _copyHex(BuildContext context, Color c) {
  Clipboard.setData(ClipboardData(text: _hexStr(c)));
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Copied ${_hexStr(c)}')));
}

void _showColorPicker(BuildContext context, Color initial,
    ValueChanged<Color> onChanged) {
  double r = initial.red.toDouble();
  double g = initial.green.toDouble();
  double b = initial.blue.toDouble();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLS) {
        final c = Color.fromARGB(255, r.round(), g.round(), b.round());
        return AlertDialog(
          title: const Text('Pick Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 60, decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(8),
              )),
              const SizedBox(height: 12),
              _RgbSlider('R', r, Colors.red, (v) => setLS(() => r = v)),
              _RgbSlider('G', g, Colors.green, (v) => setLS(() => g = v)),
              _RgbSlider('B', b, Colors.blue, (v) => setLS(() => b = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                onChanged(c);
                Navigator.pop(ctx);
              },
              child: const Text('Use'),
            ),
          ],
        );
      },
    ),
  );
}
