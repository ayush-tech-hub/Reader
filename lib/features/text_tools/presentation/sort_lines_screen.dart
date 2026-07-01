import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sort, reverse, shuffle, deduplicate, or number lines of text.
class SortLinesScreen extends StatefulWidget {
  const SortLinesScreen({super.key});

  @override
  State<SortLinesScreen> createState() => _SortLinesScreenState();
}

class _SortLinesScreenState extends State<SortLinesScreen> {
  final _inputCtrl = TextEditingController();
  String _result = '';
  String _activeOp = '';

  bool _caseSensitive = true;
  bool _reverse = false;
  bool _trimLines = true;
  bool _removeEmpty = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  List<String> _getLines() {
    var lines = _inputCtrl.text.split('\n');
    if (_trimLines) lines = lines.map((l) => l.trimRight()).toList();
    if (_removeEmpty) lines = lines.where((l) => l.isNotEmpty).toList();
    return lines;
  }

  void _applyOp(String op) {
    var lines = _getLines();
    switch (op) {
      case 'alpha':
        lines.sort((a, b) => _caseSensitive
            ? a.compareTo(b)
            : a.toLowerCase().compareTo(b.toLowerCase()));
      case 'length':
        lines.sort((a, b) => a.length.compareTo(b.length));
      case 'reverse':
        lines = lines.reversed.toList();
      case 'dedupe':
        final seen = <String>{};
        lines = lines
            .where((l) => seen.add(_caseSensitive ? l : l.toLowerCase()))
            .toList();
      case 'shuffle':
        lines.shuffle();
      case 'number':
        lines = lines
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .toList();
      case 'unnumber':
        lines = lines.map((l) => l.replaceFirst(RegExp(r'^\d+\.\s*'), '')).toList();
      case 'upper':
        lines = lines.map((l) => l.toUpperCase()).toList();
      case 'lower':
        lines = lines.map((l) => l.toLowerCase()).toList();
    }
    if (_reverse && op != 'reverse') lines = lines.reversed.toList();
    setState(() {
      _result = lines.join('\n');
      _activeOp = op;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ops = [
      ('alpha', Icons.sort_by_alpha, 'A–Z'),
      ('length', Icons.sort, 'By length'),
      ('reverse', Icons.swap_vert, 'Reverse'),
      ('dedupe', Icons.filter_list, 'Deduplicate'),
      ('shuffle', Icons.shuffle, 'Shuffle'),
      ('number', Icons.format_list_numbered, 'Number'),
      ('unnumber', Icons.format_list_bulleted, 'Remove #'),
      ('upper', Icons.text_fields, 'UPPER'),
      ('lower', Icons.text_fields, 'lower'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sort Lines')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Input (one item per line)',
                hintText: 'Paste lines here…',
              ),
            ),
            const SizedBox(height: 8),

            // Options row
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Case sensitive'),
                  selected: _caseSensitive,
                  onSelected: (v) => setState(() => _caseSensitive = v),
                ),
                FilterChip(
                  label: const Text('Reversed'),
                  selected: _reverse,
                  onSelected: (v) => setState(() => _reverse = v),
                ),
                FilterChip(
                  label: const Text('Trim lines'),
                  selected: _trimLines,
                  onSelected: (v) => setState(() => _trimLines = v),
                ),
                FilterChip(
                  label: const Text('Remove empty'),
                  selected: _removeEmpty,
                  onSelected: (v) => setState(() => _removeEmpty = v),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Operation chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (op, icon, label) in ops)
                  ActionChip(
                    avatar: Icon(icon, size: 16),
                    label: Text(label),
                    backgroundColor: _activeOp == op
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    onPressed: () => _applyOp(op),
                  ),
              ],
            ),

            if (_result.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Text(
                    '${_result.split('\n').length} lines',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    tooltip: 'Use as input',
                    onPressed: () {
                      _inputCtrl.text = _result;
                      setState(() {
                        _result = '';
                        _activeOp = '';
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!')),
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
