import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Renders a CSV (or TSV) file as a scrollable data table.
class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen> {
  String? _path;
  List<List<String>> _rows = [];
  bool _loading = false;
  String? _error;
  bool _firstRowIsHeader = true;
  String _delimiter = ',';

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _loading = true;
      _path = path;
      _error = null;
    });
    try {
      final content = await File(path).readAsString();
      // Auto-detect delimiter
      final det = _detectDelimiter(content);
      final rows = _parseCsv(content, det);
      setState(() {
        _rows = rows;
        _delimiter = det;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _path = null;
      _error = null;
    });
    try {
      final det = _detectDelimiter(text);
      final rows = _parseCsv(text, det);
      setState(() {
        _rows = rows;
        _delimiter = det;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _detectDelimiter(String content) {
    final firstLine = content.split('\n').first;
    final counts = {
      ',': ','.allMatches(firstLine).length,
      ';': ';'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
      '|': '|'.allMatches(firstLine).length,
    };
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  List<List<String>> _parseCsv(String content, String delimiter) {
    final rows = <List<String>>[];
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      rows.add(_splitLine(line, delimiter));
    }
    return rows;
  }

  List<String> _splitLine(String line, String delimiter) {
    final cells = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == delimiter && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    cells.add(buf.toString());
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headers = _firstRowIsHeader && _rows.isNotEmpty ? _rows.first : null;
    final dataRows = _firstRowIsHeader && _rows.length > 1
        ? _rows.skip(1).toList()
        : _rows;
    final colCount = _rows.isEmpty
        ? 0
        : _rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text(_path != null ? p.basename(_path!) : 'CSV Viewer'),
        actions: [
          if (_rows.isNotEmpty)
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'paste',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.content_paste_outlined),
                        title: Text('Paste from clipboard'))),
                const PopupMenuItem(
                    value: 'header',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.table_rows_outlined),
                        title: Text('Toggle header row'))),
              ],
              onSelected: (v) {
                if (v == 'paste') _pasteFromClipboard();
                if (v == 'header') {
                  setState(() => _firstRowIsHeader = !_firstRowIsHeader);
                }
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_rows.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined,
                        size: 64,
                        color: scheme.onSurfaceVariant.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loading ? null : _pickFile,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Open CSV file'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_outlined),
                      label: const Text('Paste from clipboard'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            )
          else ...[
            // Stats bar
            Container(
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${dataRows.length} row${dataRows.length == 1 ? '' : 's'} × $colCount col${colCount == 1 ? '' : 's'}  •  '
                    'Delimiter: ${_delimiter == '\t' ? 'TAB' : '"$_delimiter"'}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickFile,
                    child: const Text('Open…'),
                  ),
                ],
              ),
            ),

            // Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(
                        scheme.surfaceContainerLow),
                    columns: colCount == 0
                        ? [const DataColumn(label: Text(''))]
                        : List.generate(
                            colCount,
                            (i) => DataColumn(
                              label: Text(
                                headers != null && i < headers.length
                                    ? headers[i]
                                    : 'Col ${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                    rows: dataRows
                        .asMap()
                        .entries
                        .map(
                          (entry) => DataRow(
                            color: WidgetStateProperty.resolveWith((states) =>
                                entry.key.isOdd
                                    ? scheme.surfaceContainerLowest
                                    : null),
                            cells: List.generate(
                              colCount,
                              (ci) => DataCell(
                                Text(
                                  ci < entry.value.length
                                      ? entry.value[ci]
                                      : '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
