import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Multi-mode percentage calculator.
class PercentageScreen extends StatelessWidget {
  const PercentageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Percentage Calculator'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'X% of Y'),
              Tab(text: 'X is ?% of Y'),
              Tab(text: '% Change'),
              Tab(text: 'Add/Remove %'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PercentOfTab(),
            _WhatPercentTab(),
            _PercentChangeTab(),
            _AddRemoveTab(),
          ],
        ),
      ),
    );
  }
}

// ─── X% of Y ────────────────────────────────────────────────────────────────

class _PercentOfTab extends StatefulWidget {
  const _PercentOfTab();

  @override
  State<_PercentOfTab> createState() => _PercentOfTabState();
}

class _PercentOfTabState extends State<_PercentOfTab> {
  final _pctCtrl = TextEditingController();
  final _ofCtrl = TextEditingController();
  String _result = '';

  @override
  void dispose() {
    _pctCtrl.dispose();
    _ofCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    final p = double.tryParse(_pctCtrl.text);
    final v = double.tryParse(_ofCtrl.text);
    if (p == null || v == null) return;
    final r = p / 100 * v;
    setState(() => _result = _fmt(r));
  }

  @override
  Widget build(BuildContext context) => _CalcLayout(
        question: 'What is X% of Y?',
        inputs: [
          _NumField(_pctCtrl, 'X (%)'),
          _NumField(_ofCtrl, 'Y (value)'),
        ],
        onCalc: _calc,
        result: _result,
        resultLabel: '${_pctCtrl.text}% of ${_ofCtrl.text} =',
      );
}

// ─── X is ?% of Y ───────────────────────────────────────────────────────────

class _WhatPercentTab extends StatefulWidget {
  const _WhatPercentTab();

  @override
  State<_WhatPercentTab> createState() => _WhatPercentTabState();
}

class _WhatPercentTabState extends State<_WhatPercentTab> {
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  String _result = '';

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    final x = double.tryParse(_xCtrl.text);
    final y = double.tryParse(_yCtrl.text);
    if (x == null || y == null || y == 0) return;
    setState(() => _result = '${_fmt(x / y * 100)}%');
  }

  @override
  Widget build(BuildContext context) => _CalcLayout(
        question: 'X is what % of Y?',
        inputs: [
          _NumField(_xCtrl, 'X (part)'),
          _NumField(_yCtrl, 'Y (total)'),
        ],
        onCalc: _calc,
        result: _result,
        resultLabel: '${_xCtrl.text} is ___% of ${_yCtrl.text}',
      );
}

// ─── % Change ────────────────────────────────────────────────────────────────

class _PercentChangeTab extends StatefulWidget {
  const _PercentChangeTab();

  @override
  State<_PercentChangeTab> createState() => _PercentChangeTabState();
}

class _PercentChangeTabState extends State<_PercentChangeTab> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  String _result = '';

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    final from = double.tryParse(_fromCtrl.text);
    final to = double.tryParse(_toCtrl.text);
    if (from == null || to == null || from == 0) return;
    final change = (to - from) / from * 100;
    final sign = change >= 0 ? '+' : '';
    setState(() => _result = '$sign${_fmt(change)}%');
  }

  @override
  Widget build(BuildContext context) => _CalcLayout(
        question: '% change from A to B',
        inputs: [
          _NumField(_fromCtrl, 'From (original)'),
          _NumField(_toCtrl, 'To (new)'),
        ],
        onCalc: _calc,
        result: _result,
        resultLabel: 'Change =',
      );
}

// ─── Add / Remove % ──────────────────────────────────────────────────────────

class _AddRemoveTab extends StatefulWidget {
  const _AddRemoveTab();

  @override
  State<_AddRemoveTab> createState() => _AddRemoveTabState();
}

class _AddRemoveTabState extends State<_AddRemoveTab> {
  final _valCtrl = TextEditingController();
  final _pctCtrl = TextEditingController();
  String _addResult = '';
  String _removeResult = '';

  @override
  void dispose() {
    _valCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  void _calc() {
    final v = double.tryParse(_valCtrl.text);
    final p = double.tryParse(_pctCtrl.text);
    if (v == null || p == null) return;
    setState(() {
      _addResult = _fmt(v + v * p / 100);
      _removeResult = _fmt(v - v * p / 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Add or remove % from a value',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          _NumField(_valCtrl, 'Value'),
          const SizedBox(height: 12),
          _NumField(_pctCtrl, 'Percentage (%)'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _calc,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (_addResult.isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResRow('Add ${_pctCtrl.text}%', _addResult, scheme),
                    const Divider(),
                    _ResRow('Remove ${_pctCtrl.text}%', _removeResult, scheme),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResRow extends StatelessWidget {
  const _ResRow(this.label, this.value, this.scheme);
  final String label, value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: scheme.onPrimaryContainer)),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied')));
              },
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: scheme.onPrimaryContainer)),
            ),
          ],
        ),
      );
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
}

class _NumField extends StatelessWidget {
  const _NumField(this.ctrl, this.label);
  final TextEditingController ctrl;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}

class _CalcLayout extends StatelessWidget {
  const _CalcLayout({
    required this.question,
    required this.inputs,
    required this.onCalc,
    required this.result,
    required this.resultLabel,
  });

  final String question, result, resultLabel;
  final List<Widget> inputs;
  final VoidCallback onCalc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          for (final w in inputs) ...[w, const SizedBox(height: 12)],
          FilledButton.icon(
            onPressed: onCalc,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (result.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(resultLabel,
                        style: TextStyle(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')));
                      },
                      child: Text(result,
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
