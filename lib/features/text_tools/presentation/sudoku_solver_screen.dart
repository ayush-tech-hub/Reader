import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 9×9 Sudoku solver using backtracking.
class SudokuSolverScreen extends StatefulWidget {
  const SudokuSolverScreen({super.key});

  @override
  State<SudokuSolverScreen> createState() => _SudokuSolverScreenState();
}

class _SudokuSolverScreenState extends State<SudokuSolverScreen> {
  // 9×9 grid; 0 = empty
  final _grid = List.generate(9, (_) => List.filled(9, 0));
  final _given = List.generate(9, (_) => List.filled(9, false));
  final _ctrls = List.generate(9, (_) =>
      List.generate(9, (_) => TextEditingController()));
  bool _solved = false;
  String? _error;

  @override
  void dispose() {
    for (final row in _ctrls) {
      for (final c in row) c.dispose();
    }
    super.dispose();
  }

  void _readGrid() {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final v = int.tryParse(_ctrls[r][c].text) ?? 0;
        _grid[r][c] = v;
        _given[r][c] = v != 0;
      }
    }
  }

  bool _isValid(List<List<int>> g, int row, int col, int num) {
    for (var i = 0; i < 9; i++) {
      if (g[row][i] == num && i != col) return false;
      if (g[i][col] == num && i != row) return false;
    }
    final br = (row ~/ 3) * 3;
    final bc = (col ~/ 3) * 3;
    for (var r = br; r < br + 3; r++) {
      for (var c = bc; c < bc + 3; c++) {
        if (g[r][c] == num && (r != row || c != col)) return false;
      }
    }
    return true;
  }

  bool _solve(List<List<int>> g) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (g[r][c] == 0) {
          for (var num = 1; num <= 9; num++) {
            if (_isValid(g, r, c, num)) {
              g[r][c] = num;
              if (_solve(g)) return true;
              g[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  void _doSolve() {
    _readGrid();

    // Validate current input
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final v = _grid[r][c];
        if (v != 0 && !_isValid(_grid, r, c, v)) {
          setState(() => _error = 'Invalid puzzle: conflict at (${r + 1},${c + 1})');
          return;
        }
      }
    }

    final copy = List.generate(9, (r) => List.from(_grid[r]));
    if (_solve(copy)) {
      setState(() {
        _error = null;
        _solved = true;
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            _grid[r][c] = copy[r][c];
            if (!_given[r][c]) {
              _ctrls[r][c].text = '${copy[r][c]}';
            }
          }
        }
      });
    } else {
      setState(() => _error = 'No solution found for this puzzle.');
    }
  }

  void _clear() {
    setState(() {
      _solved = false;
      _error = null;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          _grid[r][c] = 0;
          _given[r][c] = false;
          _ctrls[r][c].clear();
        }
      }
    });
  }

  void _clearSolution() {
    setState(() {
      _solved = false;
      _error = null;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (!_given[r][c]) {
            _grid[r][c] = 0;
            _ctrls[r][c].clear();
          }
        }
      }
    });
  }

  static const _examplePuzzle = [
    [5, 3, 0, 0, 7, 0, 0, 0, 0],
    [6, 0, 0, 1, 9, 5, 0, 0, 0],
    [0, 9, 8, 0, 0, 0, 0, 6, 0],
    [8, 0, 0, 0, 6, 0, 0, 0, 3],
    [4, 0, 0, 8, 0, 3, 0, 0, 1],
    [7, 0, 0, 0, 2, 0, 0, 0, 6],
    [0, 6, 0, 0, 0, 0, 2, 8, 0],
    [0, 0, 0, 4, 1, 9, 0, 0, 5],
    [0, 0, 0, 0, 8, 0, 0, 7, 9],
  ];

  void _loadExample() {
    setState(() {
      _solved = false;
      _error = null;
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          final v = _examplePuzzle[r][c];
          _grid[r][c] = v;
          _given[r][c] = v != 0;
          _ctrls[r][c].text = v == 0 ? '' : '$v';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku Solver'),
        actions: [
          TextButton(
            onPressed: _loadExample,
            child: const Text('Example'),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all',
            onPressed: _clear,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Grid
            AspectRatio(
              aspectRatio: 1,
              child: Table(
                border: TableBorder.all(
                  color: scheme.outline,
                  width: 1.5,
                ),
                children: [
                  for (var r = 0; r < 9; r++)
                    TableRow(
                      children: [
                        for (var c = 0; c < 9; c++)
                          _SudokuCell(
                            controller: _ctrls[r][c],
                            isGiven: _given[r][c],
                            isSolved: _solved && !_given[r][c],
                            isBold: (r % 3 == 0 && r != 0) || (c % 3 == 0 && c != 0),
                            thickTop: r % 3 == 0,
                            thickLeft: c % 3 == 0,
                            scheme: scheme,
                            onChanged: (v) {
                              setState(() {
                                _solved = false;
                                _error = null;
                              });
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: scheme.error),
                    textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _doSolve,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Solve'),
                  ),
                ),
                if (_solved) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _clearSolution,
                    child: const Text('Reset'),
                  ),
                ],
              ],
            ),
            if (_solved)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Solved!',
                    style: TextStyle(color: Colors.green[700],
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    required this.controller,
    required this.isGiven,
    required this.isSolved,
    required this.isBold,
    required this.thickTop,
    required this.thickLeft,
    required this.scheme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isGiven, isSolved, isBold, thickTop, thickLeft;
  final ColorScheme scheme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isGiven
            ? scheme.surfaceContainerHighest
            : (isSolved ? scheme.primaryContainer.withOpacity(0.3) : null),
        border: Border(
          top: thickTop ? BorderSide(color: scheme.onSurface, width: 2) : BorderSide.none,
          left: thickLeft ? BorderSide(color: scheme.onSurface, width: 2) : BorderSide.none,
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: !isGiven,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: isGiven
              ? scheme.onSurface
              : (isSolved ? scheme.primary : scheme.onSurface),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _SingleDigitFormatter(),
        ],
        maxLength: 1,
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SingleDigitFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue nw) {
    final text = nw.text.replaceAll(RegExp(r'[^1-9]'), '');
    final clamped = text.isEmpty ? '' : text[text.length - 1];
    return nw.copyWith(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
  }
}
