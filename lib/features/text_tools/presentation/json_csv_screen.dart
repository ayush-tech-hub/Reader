import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Convert between JSON (array of objects) and CSV format.
class JsonCsvScreen extends StatefulWidget {
  const JsonCsvScreen({super.key});

  @override
  State<JsonCsvScreen> createState() => _JsonCsvScreenState();
}

// ── JSON → CSV ──────────────────────────────────────────────────────────────

String _jsonToCsv(String jsonStr) {
  final decoded = jsonDecode(jsonStr);
  if (decoded is! List) throw FormatException('Expected a JSON array');
  if (decoded.isEmpty) return '';

  final objects = decoded.cast<Map<String, dynamic>>();
  final keys = objects.expand((o) => o.keys).toSet().toList();

  final buf = StringBuffer();
  // Header
  buf.writeln(keys.map(_csvCell).join(','));
  // Rows
  for (final obj in objects) {
    buf.writeln(keys.map((k) => _csvCell('${obj[k] ?? ''}')).join(','));
  }
  return buf.toString().trim();
}

String _csvCell(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

// ── CSV → JSON ──────────────────────────────────────────────────────────────

List<List<String>> _parseCsv(String csv) {
  final result = <List<String>>[];
  for (final rawLine in csv.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final cells = <String>[];
    var i = 0;
    while (i < line.length) {
      if (line[i] == '"') {
        final start = i + 1;
        var end = start;
        while (end < line.length) {
          if (line[end] == '"') {
            if (end + 1 < line.length && line[end + 1] == '"') {
              end += 2;
            } else {
              break;
            }
          } else {
            end++;
          }
        }
        cells.add(line.substring(start, end).replaceAll('""', '"'));
        i = end + 1;
        if (i < line.length && line[i] == ',') i++;
      } else {
        final end = line.indexOf(',', i);
        if (end == -1) {
          cells.add(line.substring(i));
          break;
        } else {
          cells.add(line.substring(i, end));
          i = end + 1;
        }
      }
    }
    result.add(cells);
  }
  return result;
}

String _csvToJson(String csv) {
  final rows = _parseCsv(csv);
  if (rows.isEmpty) return '[]';
  final headers = rows.first;
  final objects = rows.skip(1).map((row) {
    final obj = <String, dynamic>{};
    for (var i = 0; i < headers.length; i++) {
      final val = i < row.length ? row[i] : '';
      // Auto-detect numbers/booleans
      if (val == 'true') {
        obj[headers[i]] = true;
      } else if (val == 'false') {
        obj[headers[i]] = false;
      } else if (val == 'null' || val.isEmpty) {
        obj[headers[i]] = null;
      } else {
        final n = num.tryParse(val);
        obj[headers[i]] = n ?? val;
      }
    }
    return obj;
  }).toList();
  return const JsonEncoder.withIndent('  ').convert(objects);
}

class _JsonCsvScreenState extends State<JsonCsvScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _inputCtrl = TextEditingController();
  String _output = '';
  String? _error;

  static const _sampleJson = '''[
  {"name": "Alice", "age": 30, "city": "London"},
  {"name": "Bob", "age": 25, "city": "Paris"},
  {"name": "Carol", "age": 35, "city": "Tokyo"}
]''';

  static const _sampleCsv =
      'name,age,city\nAlice,30,London\nBob,25,Paris\nCarol,35,Tokyo';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      _inputCtrl.clear();
      setState(() { _output = ''; _error = null; });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _convert() {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      try {
        if (_tabs.index == 0) {
          _output = _jsonToCsv(input);
        } else {
          _output = _csvToJson(input);
        }
        _error = null;
      } catch (e) {
        _output = '';
        _error = e.toString();
      }
    });
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _output));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _tabs.index == 0 ? 'JSON' : 'CSV';
    final outputLabel = _tabs.index == 0 ? 'CSV' : 'JSON';

    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON ↔ CSV'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'JSON → CSV'), Tab(text: 'CSV → JSON')],
        ),
        actions: [
          if (_output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy output',
              onPressed: _copy,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _build(scheme, 'JSON', 'CSV', _sampleJson),
          _build(scheme, 'CSV', 'JSON', _sampleCsv),
        ],
      ),
    );
  }

  Widget _build(ColorScheme scheme, String inLabel, String outLabel,
      String sample) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Paste $inLabel here',
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.insert_drive_file_outlined),
                  tooltip: 'Load sample',
                  onPressed: () {
                    _inputCtrl.text = sample;
                    setState(() { _output = ''; _error = null; });
                  },
                ),
              ),
              onChanged: (_) => setState(() { _output = ''; _error = null; }),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _convert,
            icon: const Icon(Icons.swap_horiz),
            label: Text('Convert to $outLabel'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
          if (_output.isNotEmpty) ...[
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _output,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12, height: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy, size: 16),
              label: Text('Copy $outLabel'),
            ),
          ],
        ],
      ),
    );
  }
}
