import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Loan/mortgage amortization calculator.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanResult {
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final List<_AmortRow> schedule;

  const _LoanResult({
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.schedule,
  });
}

class _AmortRow {
  final int month;
  final double payment;
  final double principal;
  final double interest;
  final double balance;

  const _AmortRow({
    required this.month,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });
}

_LoanResult _computeLoan(double principal, double annualRate, int years) {
  final n = years * 12;
  final r = annualRate / 100 / 12;

  double monthly;
  if (r == 0) {
    monthly = principal / n;
  } else {
    monthly = principal * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
  }

  final schedule = <_AmortRow>[];
  double balance = principal;
  for (var m = 1; m <= n; m++) {
    final interest = balance * r;
    final p = monthly - interest;
    balance -= p;
    schedule.add(_AmortRow(
      month: m,
      payment: monthly,
      principal: p,
      interest: interest,
      balance: balance < 0 ? 0 : balance,
    ));
  }

  return _LoanResult(
    monthlyPayment: monthly,
    totalPayment: monthly * n,
    totalInterest: monthly * n - principal,
    schedule: schedule,
  );
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _principalCtrl = TextEditingController(text: '100000');
  final _rateCtrl = TextEditingController(text: '5.0');
  final _yearsCtrl = TextEditingController(text: '20');
  _LoanResult? _result;
  bool _showSchedule = false;

  final _fmt = NumberFormat('#,##0.00');

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _doCalculate() {
    final p = double.tryParse(_principalCtrl.text.replaceAll(',', ''));
    final r = double.tryParse(_rateCtrl.text);
    final y = int.tryParse(_yearsCtrl.text);

    if (p == null || r == null || y == null || p <= 0 || r < 0 || y <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid positive values')),
      );
      return;
    }
    setState(() {
      _result = _computeLoan(p, r, y);
      _showSchedule = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _principalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Loan amount',
                prefixText: '£ / \$ / € ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Annual rate (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _yearsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Term (years)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _doCalculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (r != null) ...[
              const SizedBox(height: 20),
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ResultRow('Monthly Payment',
                          _fmt.format(r.monthlyPayment), scheme, bold: true),
                      const Divider(),
                      _ResultRow('Total Payment',
                          _fmt.format(r.totalPayment), scheme),
                      _ResultRow('Total Interest',
                          _fmt.format(r.totalInterest), scheme),
                      _ResultRow(
                          'Interest %',
                          '${(r.totalInterest / r.totalPayment * 100).toStringAsFixed(1)}%',
                          scheme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PieBar(
                principal: double.parse(
                    _principalCtrl.text.replaceAll(',', '')),
                interest: r.totalInterest,
                scheme: scheme,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _showSchedule = !_showSchedule),
                child: Text(_showSchedule
                    ? 'Hide amortisation schedule'
                    : 'Show amortisation schedule'),
              ),
              if (_showSchedule) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 28,
                    columns: const [
                      DataColumn(label: Text('Mo.')),
                      DataColumn(label: Text('Payment'), numeric: true),
                      DataColumn(label: Text('Principal'), numeric: true),
                      DataColumn(label: Text('Interest'), numeric: true),
                      DataColumn(label: Text('Balance'), numeric: true),
                    ],
                    rows: r.schedule.map((row) {
                      final isDec = row.month % 12 == 0 ||
                          row.month == r.schedule.length;
                      return DataRow(
                        color: isDec
                            ? WidgetStateProperty.all(
                                scheme.primaryContainer.withOpacity(0.3))
                            : null,
                        cells: [
                          DataCell(Text('${row.month}',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(row.payment),
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(row.principal),
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(row.interest),
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_fmt.format(row.balance),
                              style: const TextStyle(fontSize: 12))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, this.scheme, {this.bold = false});
  final String label, value;
  final ColorScheme scheme;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: scheme.onPrimaryContainer)),
            Text(value,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 20 : 14,
                    color: scheme.onPrimaryContainer)),
          ],
        ),
      );
}

class _PieBar extends StatelessWidget {
  const _PieBar({
    required this.principal,
    required this.interest,
    required this.scheme,
  });
  final double principal;
  final double interest;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final total = principal + interest;
    final pFrac = total > 0 ? principal / total : 0.5;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                Flexible(
                  flex: (pFrac * 1000).round(),
                  child: Container(color: scheme.primary),
                ),
                Flexible(
                  flex: ((1 - pFrac) * 1000).round(),
                  child: Container(color: scheme.error),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 12, height: 12, color: scheme.primary),
            const SizedBox(width: 4),
            const Text('Principal', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, color: scheme.error),
            const SizedBox(width: 4),
            const Text('Interest', style: TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
