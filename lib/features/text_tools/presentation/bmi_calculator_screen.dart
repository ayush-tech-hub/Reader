import 'dart:math';

import 'package:flutter/material.dart';

/// BMI, BMR, and daily calorie estimator using standard formulas.
class BmiCalculatorScreen extends StatefulWidget {
  const BmiCalculatorScreen({super.key});

  @override
  State<BmiCalculatorScreen> createState() => _BmiCalculatorScreenState();
}

class _BmiCalculatorScreenState extends State<BmiCalculatorScreen> {
  double _height = 170; // cm
  double _weight = 70;  // kg
  int _age = 25;
  bool _isMale = true;
  double _activityFactor = 1.375; // moderately active

  double get _bmi => _weight / pow(_height / 100, 2);

  String get _bmiCategory {
    final b = _bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Healthy weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(ColorScheme s) {
    final b = _bmi;
    if (b < 18.5) return Colors.blue;
    if (b < 25.0) return Colors.green;
    if (b < 30.0) return Colors.orange;
    return s.error;
  }

  // Mifflin-St Jeor BMR
  double get _bmr {
    final h = _height;
    final w = _weight;
    final a = _age.toDouble();
    if (_isMale) {
      return 10 * w + 6.25 * h - 5 * a + 5;
    } else {
      return 10 * w + 6.25 * h - 5 * a - 161;
    }
  }

  double get _tdee => _bmr * _activityFactor;

  // Ideal weight (Devine formula)
  double get _idealWeightMin {
    final extraInches = max(0, (_height / 2.54) - 60);
    final base = _isMale ? 50.0 : 45.5;
    return base + 2.3 * extraInches - 5;
  }
  double get _idealWeightMax {
    final extraInches = max(0, (_height / 2.54) - 60);
    final base = _isMale ? 50.0 : 45.5;
    return base + 2.3 * extraInches + 5;
  }

  final _activityOptions = const [
    (1.2, 'Sedentary (desk job, no exercise)'),
    (1.375, 'Lightly active (1–3 days/week)'),
    (1.55, 'Moderately active (3–5 days/week)'),
    (1.725, 'Very active (6–7 days/week)'),
    (1.9, 'Extra active (physical job + exercise)'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bmiColor = _bmiColor(scheme);

    return Scaffold(
      appBar: AppBar(title: const Text('BMI & Health Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sex toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.male), label: Text('Male')),
              ButtonSegment(value: false, icon: Icon(Icons.female), label: Text('Female')),
            ],
            selected: {_isMale},
            onSelectionChanged: (s) => setState(() => _isMale = s.first),
          ),
          const SizedBox(height: 16),

          // Height
          _SliderCard(
            label: 'Height',
            value: _height,
            unit: 'cm',
            min: 100,
            max: 220,
            divisions: 120,
            display: '${_height.round()} cm  (${(_height / 30.48).toStringAsFixed(1)} ft)',
            onChanged: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 8),

          // Weight
          _SliderCard(
            label: 'Weight',
            value: _weight,
            unit: 'kg',
            min: 30,
            max: 200,
            divisions: 170,
            display: '${_weight.round()} kg  (${(_weight * 2.205).toStringAsFixed(1)} lbs)',
            onChanged: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: 8),

          // Age
          _SliderCard(
            label: 'Age',
            value: _age.toDouble(),
            unit: 'yrs',
            min: 15,
            max: 100,
            divisions: 85,
            display: '$_age years',
            onChanged: (v) => setState(() => _age = v.round()),
          ),
          const SizedBox(height: 8),

          // Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<double>(
                value: _activityFactor,
                decoration: const InputDecoration(
                  labelText: 'Activity level',
                  border: InputBorder.none,
                ),
                items: _activityOptions.map((o) =>
                  DropdownMenuItem(value: o.$1, child: Text(o.$2, style: const TextStyle(fontSize: 13)))
                ).toList(),
                onChanged: (v) => setState(() => _activityFactor = v ?? 1.375),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // BMI Result
          Card(
            color: bmiColor.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: bmiColor, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('BMI', style: TextStyle(color: bmiColor, fontWeight: FontWeight.bold)),
                  Text(
                    _bmi.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: bmiColor, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _bmiCategory,
                    style: TextStyle(color: bmiColor, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  // BMI range bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.blue, Colors.green, Colors.orange, Colors.red,
                        ]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('16', style: TextStyle(fontSize: 10)),
                        Text('18.5', style: TextStyle(fontSize: 10)),
                        Text('25', style: TextStyle(fontSize: 10)),
                        Text('30', style: TextStyle(fontSize: 10)),
                        Text('40', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Other stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow('BMR (Basal Metabolic Rate)', '${_bmr.round()} kcal/day'),
                  const Divider(),
                  _StatRow('TDEE (Daily calorie needs)', '${_tdee.round()} kcal/day'),
                  const Divider(),
                  _StatRow('Ideal weight range',
                      '${_idealWeightMin.toStringAsFixed(1)}–${_idealWeightMax.toStringAsFixed(1)} kg'),
                  const Divider(),
                  _StatRow('Weight to lose/gain',
                      '${(_weight - (_idealWeightMin + _idealWeightMax) / 2).abs().toStringAsFixed(1)} kg'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For informational purposes only. Consult a healthcare professional.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });
  final String label, unit, display;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(display, style: const TextStyle(fontSize: 13)),
                ],
              ),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      );
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
