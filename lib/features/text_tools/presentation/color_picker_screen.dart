import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour picker and HEX ↔ RGB ↔ HSL converter.
///
/// Useful when working with document colours, CSS values, or design specs.
/// Allows entering a hex code, RGB values, or HSL values; all three
/// update in sync.  Shows the current and recently-picked colours.
class ColorPickerScreen extends StatefulWidget {
  const ColorPickerScreen({super.key});

  @override
  State<ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<ColorPickerScreen> {
  final _hexCtrl = TextEditingController(text: 'FF5733');
  final _rCtrl = TextEditingController(text: '255');
  final _gCtrl = TextEditingController(text: '87');
  final _bCtrl = TextEditingController(text: '51');

  Color _color = const Color(0xFFFF5733);
  bool _updating = false;
  List<Color> _history = [];

  @override
  void initState() {
    super.initState();
    _hexCtrl.addListener(_fromHex);
    _rCtrl.addListener(_fromRgb);
    _gCtrl.addListener(_fromRgb);
    _bCtrl.addListener(_fromRgb);
    _updateHsl();
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  void _setColor(Color c) {
    _color = c;
    _updating = true;
    _hexCtrl.text =
        c.red.toRadixString(16).padLeft(2, '0').toUpperCase() +
        c.green.toRadixString(16).padLeft(2, '0').toUpperCase() +
        c.blue.toRadixString(16).padLeft(2, '0').toUpperCase();
    _rCtrl.text = '${c.red}';
    _gCtrl.text = '${c.green}';
    _bCtrl.text = '${c.blue}';
    _updating = false;
    _updateHsl();
  }

  // HSL as string for display only (no editable fields)
  String _hslString = '';

  void _updateHsl() {
    final r = _color.red / 255;
    final g = _color.green / 255;
    final b = _color.blue / 255;
    final max = [r, g, b].reduce((a, c) => a > c ? a : c);
    final min = [r, g, b].reduce((a, c) => a < c ? a : c);
    final l = (max + min) / 2;
    double h = 0, s = 0;
    if (max != min) {
      final d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max == r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
      else if (max == g) h = ((b - r) / d + 2) / 6;
      else h = ((r - g) / d + 4) / 6;
    }
    final hDeg = (h * 360).round();
    final sPct = (s * 100).round();
    final lPct = (l * 100).round();
    _hslString = 'hsl($hDeg, $sPct%, $lPct%)';
  }

  void _fromHex() {
    if (_updating) return;
    final hex = _hexCtrl.text.replaceAll('#', '').trim();
    if (hex.length != 6) return;
    try {
      final v = int.parse(hex, radix: 16);
      final c = Color(0xFF000000 | v);
      _color = c;
      _updating = true;
      _rCtrl.text = '${c.red}';
      _gCtrl.text = '${c.green}';
      _bCtrl.text = '${c.blue}';
      _updating = false;
      setState(_updateHsl);
    } catch (_) {}
  }

  void _fromRgb() {
    if (_updating) return;
    final r = int.tryParse(_rCtrl.text) ?? -1;
    final g = int.tryParse(_gCtrl.text) ?? -1;
    final b = int.tryParse(_bCtrl.text) ?? -1;
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255) return;
    final c = Color.fromARGB(255, r, g, b);
    _color = c;
    _updating = true;
    _hexCtrl.text =
        r.toRadixString(16).padLeft(2, '0').toUpperCase() +
        g.toRadixString(16).padLeft(2, '0').toUpperCase() +
        b.toRadixString(16).padLeft(2, '0').toUpperCase();
    _updating = false;
    setState(_updateHsl);
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied: $text')));
  }

  @override
  Widget build(BuildContext context) {
    final luminance = _color.computeLuminance();
    final onColor = luminance > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('Colour Picker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Colour preview
          GestureDetector(
            onTap: () {
              setState(() {
                if (!_history.contains(_color)) {
                  _history = [_color, ..._history].take(12).toList();
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 120,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${_hexCtrl.text}',
                    style: TextStyle(
                        color: onColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace'),
                  ),
                  Text(
                    'rgb(${_color.red}, ${_color.green}, ${_color.blue})',
                    style: TextStyle(color: onColor.withOpacity(0.8)),
                  ),
                  Text(
                    _hslString,
                    style: TextStyle(color: onColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // HEX input
          TextField(
            controller: _hexCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'HEX',
              prefixText: '#  ',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copy('#${_hexCtrl.text}'),
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
          ),
          const SizedBox(height: 12),

          // RGB inputs
          Row(
            children: [
              Expanded(child: _rgbField('R', _rCtrl, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _rgbField('G', _gCtrl, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _rgbField('B', _bCtrl, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),

          // HSL display (read-only)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_hslString,
                      style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copy(_hslString),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Copy buttons row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('HEX'),
                onPressed: () => _copy('#${_hexCtrl.text}'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('RGB'),
                onPressed: () => _copy(
                    'rgb(${_color.red}, ${_color.green}, ${_color.blue})'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('HSL'),
                onPressed: () => _copy(_hslString),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Palette – Material colours
          const Text('Named colours',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, c) in _namedColors)
                GestureDetector(
                  onTap: () => setState(() => _setColor(c)),
                  child: Tooltip(
                    message: name,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color.value == c.value
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // History
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Saved colours',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _history)
                  GestureDetector(
                    onTap: () => setState(() => _setColor(c)),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rgbField(
      String label, TextEditingController ctrl, Color indicatorColor) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Container(
          width: 12,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  static const _namedColors = [
    ('Red', Color(0xFFF44336)),
    ('Pink', Color(0xFFE91E63)),
    ('Purple', Color(0xFF9C27B0)),
    ('Deep Purple', Color(0xFF673AB7)),
    ('Indigo', Color(0xFF3F51B5)),
    ('Blue', Color(0xFF2196F3)),
    ('Light Blue', Color(0xFF03A9F4)),
    ('Cyan', Color(0xFF00BCD4)),
    ('Teal', Color(0xFF009688)),
    ('Green', Color(0xFF4CAF50)),
    ('Light Green', Color(0xFF8BC34A)),
    ('Lime', Color(0xFFCDDC39)),
    ('Yellow', Color(0xFFFFEB3B)),
    ('Amber', Color(0xFFFFC107)),
    ('Orange', Color(0xFFFF9800)),
    ('Deep Orange', Color(0xFFFF5722)),
    ('Brown', Color(0xFF795548)),
    ('Grey', Color(0xFF9E9E9E)),
    ('Blue Grey', Color(0xFF607D8B)),
    ('Black', Color(0xFF000000)),
    ('White', Color(0xFFFFFFFF)),
  ];
}
