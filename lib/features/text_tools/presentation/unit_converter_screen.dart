import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unit converter for common measurements found in documents.
///
/// Categories: Length, Weight/Mass, Area, Volume, Temperature, Data Size,
/// Speed, Time.  All conversions use a canonical SI base unit internally.
class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _Unit {
  const _Unit(this.label, this.toBase, this.fromBase);
  final String label;
  final double Function(double) toBase;
  final double Function(double) fromBase;
}

class _Category {
  const _Category(this.name, this.icon, this.units);
  final String name;
  final IconData icon;
  final List<_Unit> units;
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  int _catIndex = 0;
  int _fromIndex = 0;
  int _toIndex = 1;
  final _ctrl = TextEditingController(text: '1');
  String _result = '';

  static final _categories = <_Category>[
    _Category('Length', Icons.straighten, [
      _Unit('Millimetre (mm)', (v) => v / 1000, (v) => v * 1000),
      _Unit('Centimetre (cm)', (v) => v / 100, (v) => v * 100),
      _Unit('Metre (m)', (v) => v, (v) => v),
      _Unit('Kilometre (km)', (v) => v * 1000, (v) => v / 1000),
      _Unit('Inch (in)', (v) => v * 0.0254, (v) => v / 0.0254),
      _Unit('Foot (ft)', (v) => v * 0.3048, (v) => v / 0.3048),
      _Unit('Yard (yd)', (v) => v * 0.9144, (v) => v / 0.9144),
      _Unit('Mile (mi)', (v) => v * 1609.344, (v) => v / 1609.344),
    ]),
    _Category('Weight', Icons.fitness_center, [
      _Unit('Milligram (mg)', (v) => v / 1e6, (v) => v * 1e6),
      _Unit('Gram (g)', (v) => v / 1000, (v) => v * 1000),
      _Unit('Kilogram (kg)', (v) => v, (v) => v),
      _Unit('Tonne (t)', (v) => v * 1000, (v) => v / 1000),
      _Unit('Ounce (oz)', (v) => v * 0.0283495, (v) => v / 0.0283495),
      _Unit('Pound (lb)', (v) => v * 0.453592, (v) => v / 0.453592),
      _Unit('Stone (st)', (v) => v * 6.35029, (v) => v / 6.35029),
    ]),
    _Category('Area', Icons.crop_square, [
      _Unit('mm²', (v) => v / 1e6, (v) => v * 1e6),
      _Unit('cm²', (v) => v / 1e4, (v) => v * 1e4),
      _Unit('m²', (v) => v, (v) => v),
      _Unit('km²', (v) => v * 1e6, (v) => v / 1e6),
      _Unit('Hectare (ha)', (v) => v * 1e4, (v) => v / 1e4),
      _Unit('Acre', (v) => v * 4046.86, (v) => v / 4046.86),
      _Unit('sq ft', (v) => v * 0.092903, (v) => v / 0.092903),
      _Unit('sq mi', (v) => v * 2.59e6, (v) => v / 2.59e6),
    ]),
    _Category('Volume', Icons.water_drop_outlined, [
      _Unit('Millilitre (ml)', (v) => v / 1000, (v) => v * 1000),
      _Unit('Litre (L)', (v) => v, (v) => v),
      _Unit('Cubic metre (m³)', (v) => v * 1000, (v) => v / 1000),
      _Unit('Cup (US)', (v) => v * 0.236588, (v) => v / 0.236588),
      _Unit('Pint (US)', (v) => v * 0.473176, (v) => v / 0.473176),
      _Unit('Gallon (US)', (v) => v * 3.78541, (v) => v / 3.78541),
      _Unit('Gallon (UK)', (v) => v * 4.54609, (v) => v / 4.54609),
    ]),
    _Category('Temperature', Icons.thermostat, [
      _Unit('Celsius (°C)', (v) => v + 273.15, (v) => v - 273.15),
      _Unit('Fahrenheit (°F)', (v) => (v + 459.67) * 5 / 9,
          (v) => v * 9 / 5 - 459.67),
      _Unit('Kelvin (K)', (v) => v, (v) => v),
    ]),
    _Category('Data', Icons.storage_outlined, [
      _Unit('Bit (b)', (v) => v / 8, (v) => v * 8),
      _Unit('Byte (B)', (v) => v, (v) => v),
      _Unit('Kilobyte (KB)', (v) => v * 1024, (v) => v / 1024),
      _Unit('Megabyte (MB)', (v) => v * 1048576, (v) => v / 1048576),
      _Unit('Gigabyte (GB)', (v) => v * 1073741824, (v) => v / 1073741824),
      _Unit('Terabyte (TB)', (v) => v * 1099511627776,
          (v) => v / 1099511627776),
    ]),
    _Category('Speed', Icons.speed_outlined, [
      _Unit('m/s', (v) => v, (v) => v),
      _Unit('km/h', (v) => v / 3.6, (v) => v * 3.6),
      _Unit('mph', (v) => v * 0.44704, (v) => v / 0.44704),
      _Unit('knot', (v) => v * 0.514444, (v) => v / 0.514444),
    ]),
    _Category('Time', Icons.access_time_outlined, [
      _Unit('Second (s)', (v) => v, (v) => v),
      _Unit('Minute (min)', (v) => v * 60, (v) => v / 60),
      _Unit('Hour (h)', (v) => v * 3600, (v) => v / 3600),
      _Unit('Day', (v) => v * 86400, (v) => v / 86400),
      _Unit('Week', (v) => v * 604800, (v) => v / 604800),
      _Unit('Month (30d)', (v) => v * 2592000, (v) => v / 2592000),
      _Unit('Year (365d)', (v) => v * 31536000, (v) => v / 31536000),
    ]),
  ];

  void _convert() {
    final cat = _categories[_catIndex];
    final input = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (input == null) {
      setState(() => _result = '—');
      return;
    }
    final base = cat.units[_fromIndex].toBase(input);
    final out = cat.units[_toIndex].fromBase(base);

    String fmt;
    if (out.abs() >= 1e9 || (out.abs() < 1e-4 && out != 0)) {
      fmt = out.toStringAsExponential(6);
    } else {
      // Up to 8 significant digits, strip trailing zeros
      fmt = out.toStringAsPrecision(8).replaceAll(RegExp(r'\.?0+$'), '');
    }
    setState(() => _result = fmt);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cat = _categories[_catIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Unit Converter')),
      body: Column(
        children: [
          // Category tabs (horizontal scroll)
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final c = _categories[i];
                final selected = i == _catIndex;
                return ChoiceChip(
                  avatar: Icon(c.icon, size: 16),
                  label: Text(c.name),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _catIndex = i;
                    _fromIndex = 0;
                    _toIndex = 1.clamp(0, _categories[i].units.length - 1);
                    _result = '';
                  }),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // From / To dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('From',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              value: _fromIndex,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true),
                              items: [
                                for (var i = 0;
                                    i < cat.units.length;
                                    i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(cat.units[i].label,
                                        style:
                                            const TextStyle(fontSize: 13)),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _fromIndex = v;
                                    _result = '';
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                        child: IconButton.filled(
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () => setState(() {
                            final tmp = _fromIndex;
                            _fromIndex = _toIndex;
                            _toIndex = tmp;
                            _result = '';
                          }),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('To',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              value: _toIndex,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true),
                              items: [
                                for (var i = 0;
                                    i < cat.units.length;
                                    i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(cat.units[i].label,
                                        style:
                                            const TextStyle(fontSize: 13)),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _toIndex = v;
                                    _result = '';
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Input
                  TextField(
                    controller: _ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: 'Value',
                      border: const OutlineInputBorder(),
                      suffixText: cat.units[_fromIndex].label,
                    ),
                    onChanged: (_) => _convert(),
                    onSubmitted: (_) => _convert(),
                  ),
                  const SizedBox(height: 20),

                  // Convert button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Convert'),
                      onPressed: _convert,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),

                  if (_result.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _result,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.units[_toIndex].label,
                            style: TextStyle(
                                color: scheme.onPrimaryContainer
                                    .withOpacity(0.7)),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy result'),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
