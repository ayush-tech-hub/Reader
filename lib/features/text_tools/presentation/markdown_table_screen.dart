import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates Markdown tables by specifying rows, columns, and content.
class MarkdownTableScreen extends StatefulWidget {
  const MarkdownTableScreen({super.key});

  @override
  State<MarkdownTableScreen> createState() => _MarkdownTableScreenState();
}

class _MarkdownTableScreenState extends State<MarkdownTableScreen> {
  int _rows = 3;
  int _cols = 3;
  late List<List<TextEditingController>> _cells;
  String _result = '';

  // Alignment per column: left, center, right
  late List<String> _alignments;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _cells = List.generate(
        _rows + 1, // +1 for header row
        (_) => List.generate(_cols, (_) => TextEditingController()));
    _alignments = List.filled(_cols, 'left');
  }

  @override
  void dispose() {
    for (final row in _cells) {
      for (final ctrl in row) ctrl.dispose();
    }
    super.dispose();
  }

  void _resizeGrid(int newRows, int newCols) {
    final old = _cells;
    final oldAlignments = List<String>.from(_alignments);

    _cells = List.generate(
      newRows + 1,
      (r) => List.generate(
        newCols,
        (c) {
          if (r < old.length && c < old[r].length) return old[r][c];
          return TextEditingController();
        },
      ),
    );
    _alignments = List.generate(
        newCols, (c) => c < oldAlignments.length ? oldAlignments[c] : 'left');
    _rows = newRows;
    _cols = newCols;
  }

  String _alignSep(String a) {
    switch (a) {
      case 'center': return ':---:';
      case 'right': return '---:';
      default: return '---';
    }
  }

  void _generate() {
    final sb = StringBuffer();
    // Header row
    final header = _cells[0].map((c) => ' ${c.text.isEmpty ? ' ' : c.text} ').join('|');
    sb.writeln('|$header|');
    // Separator
    final sep = _alignments.map(_alignSep).map((s) => ' $s ').join('|');
    sb.writeln('|$sep|');
    // Data rows
    for (var r = 1; r <= _rows; r++) {
      final row = _cells[r].map((c) => ' ${c.text.isEmpty ? ' ' : c.text} ').join('|');
      sb.writeln('|$row|');
    }
    setState(() => _result = sb.toString().trimRight());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alignIcons = {
      'left': Icons.format_align_left,
      'center': Icons.format_align_center,
      'right': Icons.format_align_right,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Markdown Table Generator')),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Rows:'),
                const SizedBox(width: 8),
                _Stepper(
                  value: _rows,
                  min: 1, max: 20,
                  onChanged: (v) => setState(() => _resizeGrid(v, _cols)),
                ),
                const SizedBox(width: 16),
                const Text('Cols:'),
                const SizedBox(width: 8),
                _Stepper(
                  value: _cols,
                  min: 1, max: 10,
                  onChanged: (v) => setState(() => _resizeGrid(_rows, v)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('Generate'),
                ),
              ],
            ),
          ),

          // Column alignment
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Align: ', style: TextStyle(fontSize: 12)),
                for (var c = 0; c < _cols; c++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ToggleButtons(
                      isSelected: ['left', 'center', 'right']
                          .map((a) => _alignments[c] == a)
                          .toList(),
                      onPressed: (i) {
                        setState(() => _alignments[c] =
                            ['left', 'center', 'right'][i]);
                      },
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      borderRadius: BorderRadius.circular(6),
                      children: [
                        for (final a in ['left', 'center', 'right'])
                          Tooltip(
                            message: a,
                            child: Icon(alignIcons[a], size: 14),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Cell grid
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    border: TableBorder.all(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4)),
                    defaultColumnWidth: const FixedColumnWidth(120),
                    children: [
                      // Header row (index 0)
                      TableRow(
                        decoration: BoxDecoration(
                            color: scheme.primaryContainer.withOpacity(0.3)),
                        children: List.generate(
                          _cols,
                          (c) => _Cell(
                              ctrl: _cells[0][c],
                              hint: 'Header ${c + 1}',
                              bold: true),
                        ),
                      ),
                      // Data rows
                      for (var r = 1; r <= _rows; r++)
                        TableRow(
                          children: List.generate(
                            _cols,
                            (c) => _Cell(
                                ctrl: _cells[r][c],
                                hint: 'R${r}C${c + 1}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Result
          if (_result.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Markdown output',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _result));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Markdown table copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                  SelectableText(
                    _result,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.ctrl, required this.hint, this.bold = false});
  final TextEditingController ctrl;
  final String hint;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(2),
        child: TextField(
          controller: ctrl,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.all(4),
          ),
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          Text('$value',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
}
