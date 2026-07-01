import 'package:flutter/material.dart';

/// Calculates exact age from date of birth, plus various date facts.
class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeResult {
  final int years, months, days;
  final int totalDays, totalWeeks, totalMonths;
  final int totalHours, nextBirthdayDays;
  final String nextBirthdayDate;

  const _AgeResult({
    required this.years,
    required this.months,
    required this.days,
    required this.totalDays,
    required this.totalWeeks,
    required this.totalMonths,
    required this.totalHours,
    required this.nextBirthdayDays,
    required this.nextBirthdayDate,
  });
}

_AgeResult _computeAge(DateTime dob, DateTime now) {
  var years = now.year - dob.year;
  var months = now.month - dob.month;
  var days = now.day - dob.day;

  if (days < 0) {
    months--;
    final prevMonth = DateTime(now.year, now.month, 0);
    days += prevMonth.day;
  }
  if (months < 0) {
    years--;
    months += 12;
  }

  final totalDays = now.difference(dob).inDays;
  final totalWeeks = totalDays ~/ 7;
  final totalMonths = years * 12 + months;
  final totalHours = totalDays * 24;

  // Next birthday
  var next = DateTime(now.year, dob.month, dob.day);
  if (!next.isAfter(now)) {
    next = DateTime(now.year + 1, dob.month, dob.day);
  }
  final nextDays = next.difference(now).inDays + 1;
  final nextStr =
      '${next.day.toString().padLeft(2,'0')}/${next.month.toString().padLeft(2,'0')}/${next.year}';

  return _AgeResult(
    years: years,
    months: months,
    days: days,
    totalDays: totalDays,
    totalWeeks: totalWeeks,
    totalMonths: totalMonths,
    totalHours: totalHours,
    nextBirthdayDays: nextDays,
    nextBirthdayDate: nextStr,
  );
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _dob;
  _AgeResult? _result;

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _result = _computeAge(picked, DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Age Calculator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(_dob == null
                  ? 'Select date of birth'
                  : 'Born: ${_dob!.day.toString().padLeft(2,'0')}/${_dob!.month.toString().padLeft(2,'0')}/${_dob!.year}'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            if (r != null) ...[
              const SizedBox(height: 24),
              // Age hero
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('You are',
                          style: TextStyle(color: scheme.onPrimaryContainer)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _BigNum(r.years, 'years', scheme),
                          const SizedBox(width: 16),
                          _BigNum(r.months, 'months', scheme),
                          const SizedBox(width: 16),
                          _BigNum(r.days, 'days', scheme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StatRow('Total days', _fmt(r.totalDays)),
                      _StatRow('Total weeks', _fmt(r.totalWeeks)),
                      _StatRow('Total months', _fmt(r.totalMonths)),
                      _StatRow('Total hours', _fmt(r.totalHours)),
                      const Divider(),
                      _StatRow(
                        'Next birthday',
                        '${r.nextBirthdayDate} (${r.nextBirthdayDays} day${r.nextBirthdayDays == 1 ? '' : 's'})',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _BigNum extends StatelessWidget {
  const _BigNum(this.value, this.label, this.scheme);
  final int value;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer)),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: scheme.onPrimaryContainer.withOpacity(0.7))),
        ],
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
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
