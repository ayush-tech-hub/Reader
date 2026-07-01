import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DateCalculatorScreen extends StatefulWidget {
  const DateCalculatorScreen({super.key});

  @override
  State<DateCalculatorScreen> createState() => _DateCalculatorScreenState();
}

class _DateCalculatorScreenState extends State<DateCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // ── Tab 1: diff between two dates ────────────────────────────────────────
  DateTime _date1 = DateTime.now();
  DateTime _date2 = DateTime.now().add(const Duration(days: 30));
  _DiffResult? _diff;

  // ── Tab 2: add/subtract duration ─────────────────────────────────────────
  DateTime _baseDate = DateTime.now();
  final _daysCtrl = TextEditingController(text: '0');
  final _monthsCtrl = TextEditingController(text: '0');
  final _yearsCtrl = TextEditingController(text: '0');
  bool _addMode = true;
  DateTime? _calcResult;

  // ── Tab 3: what day of week? ─────────────────────────────────────────────
  DateTime _dowDate = DateTime.now();

  static final _fmt = DateFormat('EEE, d MMM y');
  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void dispose() {
    _tabs.dispose();
    _daysCtrl.dispose();
    _monthsCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
      BuildContext context, DateTime initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1000),
      lastDate: DateTime(9999),
    );
    if (picked != null) onPicked(picked);
  }

  void _computeDiff() {
    final d1 = _date1.isBefore(_date2) ? _date1 : _date2;
    final d2 = _date1.isBefore(_date2) ? _date2 : _date1;
    final diff = d2.difference(d1);

    int years = d2.year - d1.year;
    int months = d2.month - d1.month;
    int days = d2.day - d1.day;
    if (days < 0) {
      months--;
      final prevMonth =
          DateTime(d2.year, d2.month, 0); // last day of prev month
      days += prevMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    setState(() {
      _diff = _DiffResult(
        totalDays: diff.inDays,
        years: years,
        months: months,
        days: days,
        weeks: diff.inDays ~/ 7,
        hours: diff.inHours,
        minutes: diff.inMinutes,
      );
    });
  }

  void _computeAdd() {
    final y = int.tryParse(_yearsCtrl.text) ?? 0;
    final m = int.tryParse(_monthsCtrl.text) ?? 0;
    final d = int.tryParse(_daysCtrl.text) ?? 0;

    final sign = _addMode ? 1 : -1;
    var result = DateTime(
      _baseDate.year + sign * y,
      _baseDate.month + sign * m,
      _baseDate.day + sign * d,
    );
    setState(() => _calcResult = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Date Calculator'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Difference'),
            Tab(text: 'Add / Subtract'),
            Tab(text: 'Day of Week'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildDiffTab(context),
          _buildAddTab(context),
          _buildDowTab(context),
        ],
      ),
    );
  }

  // ── Diff tab ──────────────────────────────────────────────────────────────

  Widget _buildDiffTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DatePickerTile(
          label: 'Start date',
          date: _date1,
          fmt: _fmt,
          onTap: () => _pickDate(context, _date1,
              (d) => setState(() => _date1 = d)),
        ),
        const SizedBox(height: 8),
        _DatePickerTile(
          label: 'End date',
          date: _date2,
          fmt: _fmt,
          onTap: () => _pickDate(context, _date2,
              (d) => setState(() => _date2 = d)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _computeDiff,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calculate Difference'),
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        if (_diff != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_diff!.years}y  ${_diff!.months}m  ${_diff!.days}d',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20),
                  _DiffRow('Total days', '${_diff!.totalDays}', scheme),
                  _DiffRow('Total weeks', '${_diff!.weeks}', scheme),
                  _DiffRow('Total hours', '${_diff!.hours}', scheme),
                  _DiffRow('Total minutes', '${_diff!.minutes}', scheme),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Add/Sub tab ───────────────────────────────────────────────────────────

  Widget _buildAddTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DatePickerTile(
          label: 'Base date',
          date: _baseDate,
          fmt: _fmt,
          onTap: () => _pickDate(context, _baseDate,
              (d) => setState(() => _baseDate = d)),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Add'), icon: Icon(Icons.add)),
            ButtonSegment(
                value: false, label: Text('Subtract'), icon: Icon(Icons.remove)),
          ],
          selected: {_addMode},
          onSelectionChanged: (s) => setState(() => _addMode = s.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NumField(label: 'Years', ctrl: _yearsCtrl),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumField(label: 'Months', ctrl: _monthsCtrl),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumField(label: 'Days', ctrl: _daysCtrl),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _computeAdd,
          icon: const Icon(Icons.event_outlined),
          label: const Text('Calculate'),
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        if (_calcResult != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading:
                  Icon(Icons.event, color: scheme.primary),
              title: Text(
                _fmt.format(_calcResult!),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle:
                  Text('${_days[_calcResult!.weekday - 1]}'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _fmt.format(_calcResult!)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Date copied!')),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Day-of-week tab ───────────────────────────────────────────────────────

  Widget _buildDowTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dow = _days[_dowDate.weekday - 1];
    final isWeekend = _dowDate.weekday >= 6;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DatePickerTile(
          label: 'Select date',
          date: _dowDate,
          fmt: _fmt,
          onTap: () => _pickDate(context, _dowDate,
              (d) => setState(() => _dowDate = d)),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  dow,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isWeekend ? Colors.red : scheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(_fmt.format(_dowDate),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Chip(
                  label: Text(isWeekend ? 'Weekend' : 'Weekday'),
                  backgroundColor: isWeekend
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Day number info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _DiffRow('Day of year',
                    _dowDate.difference(DateTime(_dowDate.year, 1, 1)).inDays + 1,
                    scheme),
                _DiffRow('Week of year',
                    (_dowDate.difference(DateTime(_dowDate.year, 1, 1)).inDays / 7).ceil() + 1,
                    scheme),
                _DiffRow('Days until end of year',
                    DateTime(_dowDate.year + 1, 1, 1).difference(_dowDate).inDays,
                    scheme),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiffResult {
  const _DiffResult({
    required this.totalDays,
    required this.years,
    required this.months,
    required this.days,
    required this.weeks,
    required this.hours,
    required this.minutes,
  });

  final int totalDays;
  final int years;
  final int months;
  final int days;
  final int weeks;
  final int hours;
  final int minutes;
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.fmt,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final DateFormat fmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(fmt.format(date)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.ctrl});
  final String label;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          isDense: true,
        ),
      );
}

class _DiffRow extends StatelessWidget {
  const _DiffRow(this.label, this.value, this.scheme);
  final String label;
  final Object value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            Text(value.toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
