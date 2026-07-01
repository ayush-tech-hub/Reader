import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bill split & tip calculator.
class TipCalculatorScreen extends StatefulWidget {
  const TipCalculatorScreen({super.key});

  @override
  State<TipCalculatorScreen> createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends State<TipCalculatorScreen> {
  double _bill = 0;
  double _tipPercent = 15;
  int _people = 1;

  final _billCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.00');

  @override
  void dispose() {
    _billCtrl.dispose();
    super.dispose();
  }

  double get _tipAmount => _bill * _tipPercent / 100;
  double get _total => _bill + _tipAmount;
  double get _perPerson => _people > 0 ? _total / _people : _total;
  double get _tipPerPerson => _people > 0 ? _tipAmount / _people : _tipAmount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tip Calculator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bill input
            TextField(
              controller: _billCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bill amount',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _bill = double.tryParse(v.replaceAll(',', '')) ?? 0);
              },
            ),
            const SizedBox(height: 20),

            // Tip percent
            Text('Tip: ${_tipPercent.round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Slider(
              value: _tipPercent,
              min: 0,
              max: 50,
              divisions: 50,
              label: '${_tipPercent.round()}%',
              onChanged: (v) => setState(() => _tipPercent = v),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in [5, 10, 15, 18, 20, 25])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$p%'),
                        selected: _tipPercent == p,
                        onSelected: (_) =>
                            setState(() => _tipPercent = p.toDouble()),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // People
            Row(
              children: [
                const Text('Split between:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: _people > 1
                      ? () => setState(() => _people--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$_people person${_people == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => _people++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Results
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Row('Tip', _fmt.format(_tipAmount), scheme, sub: true),
                    _Row('Total', _fmt.format(_total), scheme, bold: true),
                    if (_people > 1) ...[
                      const Divider(),
                      _Row('Per person', _fmt.format(_perPerson), scheme,
                          bold: true),
                      _Row('Tip per person', _fmt.format(_tipPerPerson), scheme,
                          sub: true),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.scheme,
      {this.bold = false, this.sub = false});
  final String label, value;
  final ColorScheme scheme;
  final bool bold, sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: sub ? 13 : 16)),
            Text(value,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 22 : 15,
                    color: scheme.onPrimaryContainer)),
          ],
        ),
      );
}
