import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Format, minify, and validate JSON.
///
/// - Formats with configurable indent (2 or 4 spaces, or tab)
/// - Minifies by removing all non-significant whitespace
/// - Shows a clear error message when the JSON is invalid
/// - Displays key count and nesting depth in the stats bar
class JsonFormatterScreen extends StatefulWidget {
  const JsonFormatterScreen({super.key});

  @override
  State<JsonFormatterScreen> createState() => _JsonFormatterScreenState();
}

class _JsonFormatterScreenState extends State<JsonFormatterScreen> {
  final _inputCtrl = TextEditingController();
  String _output = '';
  String? _error;
  int _indent = 2; // 0 = tab, 2 = two spaces, 4 = four spaces

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _format() => _process(minify: false);
  void _minify() => _process(minify: true);

  void _process({required bool minify}) {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) return;
    try {
      final obj = jsonDecode(raw);
      String result;
      if (minify) {
        result = jsonEncode(obj);
      } else {
        final indentStr = _indent == 0 ? '\t' : ' ' * _indent;
        result = const JsonEncoder.withIndent('').convert(obj);
        // Re-encode with proper indent
        result = JsonEncoder.withIndent(indentStr).convert(obj);
      }
      setState(() {
        _output = result;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _output = '';
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(FormatException e) {
    final msg = e.message;
    final src = e.source;
    if (src is String && e.offset != null) {
      final offset = e.offset!;
      final before = src.substring(0, offset.clamp(0, src.length));
      final line = '\n'.allMatches(before).length + 1;
      final col = offset - (before.lastIndexOf('\n') + 1) + 1;
      return '$msg (line $line, col $col)';
    }
    return msg;
  }

  int _countKeys(dynamic obj) {
    if (obj is Map) {
      return obj.length +
          obj.values.fold<int>(0, (sum, v) => sum + _countKeys(v));
    }
    if (obj is List) {
      return obj.fold<int>(0, (sum, v) => sum + _countKeys(v));
    }
    return 0;
  }

  int _maxDepth(dynamic obj, [int depth = 0]) {
    if (obj is Map) {
      if (obj.isEmpty) return depth;
      return obj.values
          .map((v) => _maxDepth(v, depth + 1))
          .reduce((a, b) => a > b ? a : b);
    }
    if (obj is List) {
      if (obj.isEmpty) return depth;
      return obj
          .map((v) => _maxDepth(v, depth + 1))
          .reduce((a, b) => a > b ? a : b);
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON Formatter'),
        actions: [
          if (_output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy output',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _output));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Options bar
          Container(
            color: scheme.surfaceContainerHighest.withOpacity(0.4),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Indent:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                for (final (val, lbl) in [
                  (2, '2'),
                  (4, '4'),
                  (0, 'Tab'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(lbl, style: const TextStyle(fontSize: 12)),
                      selected: _indent == val,
                      onSelected: (_) => setState(() => _indent = val),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          // Input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Paste JSON here…',
                        border: const OutlineInputBorder(),
                        suffixIcon: _inputCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _inputCtrl.clear();
                                  setState(() {
                                    _output = '';
                                    _error = null;
                                                              });
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        if (_output.isNotEmpty || _error != null) {
                          setState(() {
                            _output = '';
                            _error = null;
                                              });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.paste_outlined),
                        label: const Text('Paste'),
                        onPressed: () async {
                          final d =
                              await Clipboard.getData('text/plain');
                          if (d?.text != null) {
                            _inputCtrl.text = d!.text!;
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.format_align_left),
                          label: const Text('Format'),
                          onPressed: _format,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _minify,
                        child: const Text('Minify'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_output.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildStats(),
                    const SizedBox(height: 4),
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.green.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.green.withOpacity(0.04),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _output,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    try {
      final obj = jsonDecode(_output);
      final keys = _countKeys(obj);
      final depth = _maxDepth(obj);
      final scheme = Theme.of(context).colorScheme;
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 14),
          const SizedBox(width: 4),
          Text('Valid JSON',
              style: const TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Text('$keys key${keys == 1 ? '' : 's'} · depth $depth',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Text('${_output.length} chars',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
