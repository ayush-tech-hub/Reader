import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scientific calculator with a simple expression evaluator.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expr = '';
  String _display = '0';
  bool _hasResult = false;
  bool _inDegrees = true;
  final List<String> _history = [];

  void _append(String s) {
    if (_hasResult && RegExp(r'^[\d.]$').hasMatch(s)) {
      // Start fresh when typing a number after result
      _expr = s;
      _display = s;
    } else {
      if (_hasResult) _hasResult = false;
      _expr += s;
      _display = _expr;
    }
    setState(() {});
  }

  void _clear() => setState(() {
        _expr = '';
        _display = '0';
        _hasResult = false;
      });

  void _backspace() {
    if (_hasResult) return;
    if (_expr.isNotEmpty) {
      _expr = _expr.substring(0, _expr.length - 1);
      _display = _expr.isEmpty ? '0' : _expr;
      setState(() {});
    }
  }

  void _toggleDeg() => setState(() => _inDegrees = !_inDegrees);

  double _toRad(double d) => _inDegrees ? d * pi / 180 : d;
  double _fromRad(double r) => _inDegrees ? r * 180 / pi : r;

  void _calculate() {
    if (_expr.isEmpty) return;
    try {
      final result = _eval(_expr);
      final resultStr = result == result.toInt().toDouble() &&
              result.abs() < 1e15
          ? result.toInt().toString()
          : result.toStringAsPrecision(10)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
      _history.insert(0, '$_expr = $resultStr');
      if (_history.length > 20) _history.removeLast();
      setState(() {
        _display = resultStr;
        _expr = resultStr;
        _hasResult = true;
      });
    } catch (e) {
      setState(() {
        _display = 'Error';
        _hasResult = true;
      });
    }
  }

  // ── Tokeniser + recursive descent parser ─────────────────────────────────

  static final _tokenRe = RegExp(
      r'(\d+\.?\d*|\.\d+)'
      r'|([+\-*/^%()])'
      r'|(sin|cos|tan|asin|acos|atan|sqrt|ln|log|abs|floor|ceil|round)'
      r'|([eπ])');

  List<String> _tokenize(String expr) {
    // normalise multiplication × and minus −
    expr = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', 'π')
        .replaceAll('^', '^')
        .trim();
    final tokens = <String>[];
    for (final m in _tokenRe.allMatches(expr)) {
      tokens.add(m[0]!);
    }
    return tokens;
  }

  int _pos = 0;
  List<String> _tokens = [];

  double _eval(String expr) {
    _tokens = _tokenize(expr);
    _pos = 0;
    final result = _parseExpr();
    if (_pos < _tokens.length) throw FormatException('Unexpected token');
    return result;
  }

  double _parseExpr() {
    var left = _parseTerm();
    while (_pos < _tokens.length &&
        (_tokens[_pos] == '+' || _tokens[_pos] == '-')) {
      final op = _tokens[_pos++];
      final right = _parseTerm();
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double _parseTerm() {
    var left = _parsePower();
    while (_pos < _tokens.length &&
        (_tokens[_pos] == '*' ||
            _tokens[_pos] == '/' ||
            _tokens[_pos] == '%')) {
      final op = _tokens[_pos++];
      final right = _parsePower();
      if (op == '*') left *= right;
      else if (op == '/') left /= right;
      else left %= right;
    }
    return left;
  }

  double _parsePower() {
    var base = _parseUnary();
    if (_pos < _tokens.length && _tokens[_pos] == '^') {
      _pos++;
      final exp = _parsePower(); // right associative
      base = pow(base, exp).toDouble();
    }
    return base;
  }

  double _parseUnary() {
    if (_pos < _tokens.length && _tokens[_pos] == '-') {
      _pos++;
      return -_parsePrimary();
    }
    if (_pos < _tokens.length && _tokens[_pos] == '+') {
      _pos++;
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    if (_pos >= _tokens.length) throw FormatException('Unexpected end');
    final tok = _tokens[_pos];

    // Constants
    if (tok == 'π') { _pos++; return pi; }
    if (tok == 'e') { _pos++; return e; }

    // Functions
    if (['sin','cos','tan','asin','acos','atan','sqrt','ln','log',
         'abs','floor','ceil','round'].contains(tok)) {
      _pos++;
      if (_pos >= _tokens.length || _tokens[_pos] != '(') {
        throw FormatException('Expected (');
      }
      _pos++;
      final arg = _parseExpr();
      if (_pos >= _tokens.length || _tokens[_pos] != ')') {
        throw FormatException('Expected )');
      }
      _pos++;
      return switch (tok) {
        'sin'   => sin(_toRad(arg)),
        'cos'   => cos(_toRad(arg)),
        'tan'   => tan(_toRad(arg)),
        'asin'  => _fromRad(asin(arg)),
        'acos'  => _fromRad(acos(arg)),
        'atan'  => _fromRad(atan(arg)),
        'sqrt'  => sqrt(arg),
        'ln'    => log(arg),
        'log'   => log(arg) / log(10),
        'abs'   => arg.abs(),
        'floor' => arg.floorToDouble(),
        'ceil'  => arg.ceilToDouble(),
        'round' => arg.roundToDouble(),
        _       => arg,
      };
    }

    // Grouping
    if (tok == '(') {
      _pos++;
      final val = _parseExpr();
      if (_pos >= _tokens.length || _tokens[_pos] != ')') {
        throw FormatException('Expected )');
      }
      _pos++;
      return val;
    }

    // Number
    final num = double.tryParse(tok);
    if (num != null) { _pos++; return num; }

    throw FormatException('Unexpected: $tok');
  }

  // ── Build UI ──────────────────────────────────────────────────────────────

  Widget _btn(String label, {Color? color, VoidCallback? action, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: action ?? () => _append(label),
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: Column(
        children: [
          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: scheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_expr.isNotEmpty && !_hasResult)
                  Text(_expr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: scheme.onSurfaceVariant)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: SelectableText(
                        _display,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: _display.length > 12 ? 24 : 36,
                            fontWeight: FontWeight.bold,
                            color: _hasResult ? scheme.primary : null),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _display));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!')));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mode / deg toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                TextButton(
                  onPressed: _toggleDeg,
                  child: Text(_inDegrees ? 'DEG' : 'RAD',
                      style: TextStyle(color: scheme.primary)),
                ),
                const Spacer(),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History'),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _history.length,
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(_history[i],
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 13)),
                          onTap: () {
                            final parts = _history[i].split(' = ');
                            if (parts.length == 2) {
                              setState(() {
                                _expr = parts[1];
                                _display = parts[1];
                                _hasResult = true;
                              });
                            }
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Keypad
          Expanded(
            child: Column(
              children: [
                Row(children: [
                  _btn('sin()', action: () => _append('sin(')),
                  _btn('cos()', action: () => _append('cos(')),
                  _btn('tan()', action: () => _append('tan(')),
                  _btn('⌫', action: _backspace,
                      color: scheme.errorContainer),
                ]),
                Row(children: [
                  _btn('√(', action: () => _append('sqrt(')),
                  _btn('ln(', action: () => _append('ln(')),
                  _btn('log(', action: () => _append('log(')),
                  _btn('xⁿ', action: () => _append('^'),
                      color: scheme.secondaryContainer),
                ]),
                Row(children: [
                  _btn('π', action: () => _append('π')),
                  _btn('e', action: () => _append('e')),
                  _btn('('),
                  _btn(')'),
                ]),
                Row(children: [
                  _btn('7'), _btn('8'), _btn('9'),
                  _btn('÷', action: () => _append('/'),
                      color: scheme.primaryContainer),
                ]),
                Row(children: [
                  _btn('4'), _btn('5'), _btn('6'),
                  _btn('×', action: () => _append('*'),
                      color: scheme.primaryContainer),
                ]),
                Row(children: [
                  _btn('1'), _btn('2'), _btn('3'),
                  _btn('−', action: () => _append('-'),
                      color: scheme.primaryContainer),
                ]),
                Row(children: [
                  _btn('0', flex: 2),
                  _btn('.'),
                  _btn('+', color: scheme.primaryContainer),
                ]),
                Row(children: [
                  _btn('AC', action: _clear,
                      color: scheme.errorContainer, flex: 2),
                  _btn('%'),
                  _btn('=', action: _calculate,
                      color: scheme.primary, flex: 1),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
