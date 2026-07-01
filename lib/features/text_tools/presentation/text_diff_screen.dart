import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Side-by-side or unified text diff for two pasted texts.
///
/// Uses a simple LCS-based line diff (no external package).  Lines unique
/// to the left text are shown in red; lines unique to the right are in green;
/// common lines are shown in the default colour.
class TextDiffScreen extends StatefulWidget {
  const TextDiffScreen({super.key});

  @override
  State<TextDiffScreen> createState() => _TextDiffScreenState();
}

// ── Minimal LCS line diff ─────────────────────────────────────────────────────

enum _DiffOp { equal, insert, delete }

class _DiffChunk {
  const _DiffChunk(this.op, this.lines);
  final _DiffOp op;
  final List<String> lines;
}

List<_DiffChunk> _diff(List<String> a, List<String> b) {
  // Build LCS table
  final m = a.length, n = b.length;
  // Use a map to save memory for large inputs
  final lcs = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      lcs[i][j] =
          a[i - 1] == b[j - 1] ? lcs[i - 1][j - 1] + 1 : lcs[i - 1][j] > lcs[i][j - 1] ? lcs[i - 1][j] : lcs[i][j - 1];
    }
  }

  // Backtrack
  final chunks = <_DiffChunk>[];
  var i = m, j = n;
  final raw = <({_DiffOp op, String line})>[];
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
      raw.add((op: _DiffOp.equal, line: a[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j])) {
      raw.add((op: _DiffOp.insert, line: b[j - 1]));
      j--;
    } else {
      raw.add((op: _DiffOp.delete, line: a[i - 1]));
      i--;
    }
  }

  // Reverse and merge consecutive same-op lines into chunks
  var cur = raw.reversed.toList();
  var idx = 0;
  while (idx < cur.length) {
    final op = cur[idx].op;
    final lines = <String>[];
    while (idx < cur.length && cur[idx].op == op) {
      lines.add(cur[idx].line);
      idx++;
    }
    chunks.add(_DiffChunk(op, lines));
  }
  return chunks;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class _TextDiffScreenState extends State<TextDiffScreen> {
  final _leftCtrl = TextEditingController();
  final _rightCtrl = TextEditingController();
  List<_DiffChunk>? _chunks;
  int _adds = 0, _dels = 0;

  void _compare() {
    final left = _leftCtrl.text.split('\n');
    final right = _rightCtrl.text.split('\n');
    if (left.isEmpty && right.isEmpty) return;
    final chunks = _diff(left, right);
    int adds = 0, dels = 0;
    for (final c in chunks) {
      if (c.op == _DiffOp.insert) adds += c.lines.length;
      if (c.op == _DiffOp.delete) dels += c.lines.length;
    }
    setState(() {
      _chunks = chunks;
      _adds = adds;
      _dels = dels;
    });
  }

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  Color _opColor(_DiffOp op, bool isDark) {
    switch (op) {
      case _DiffOp.insert:
        return isDark
            ? Colors.green.withOpacity(0.25)
            : Colors.green.withOpacity(0.12);
      case _DiffOp.delete:
        return isDark
            ? Colors.red.withOpacity(0.25)
            : Colors.red.withOpacity(0.12);
      case _DiffOp.equal:
        return Colors.transparent;
    }
  }

  String _prefix(_DiffOp op) {
    switch (op) {
      case _DiffOp.insert:
        return '+ ';
      case _DiffOp.delete:
        return '- ';
      case _DiffOp.equal:
        return '  ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Diff'),
        actions: [
          if (_chunks != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Text('+$_adds',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('-$_dels',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Input panels
          Expanded(
            flex: _chunks == null ? 2 : 1,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                                child: Text('Original',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600))),
                            IconButton(
                              icon: const Icon(Icons.paste_outlined, size: 18),
                              tooltip: 'Paste',
                              onPressed: () async {
                                final d = await Clipboard.getData('text/plain');
                                if (d?.text != null) _leftCtrl.text = d!.text!;
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: TextField(
                            controller: _leftCtrl,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Original text…',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                                child: Text('Modified',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600))),
                            IconButton(
                              icon: const Icon(Icons.paste_outlined, size: 18),
                              tooltip: 'Paste',
                              onPressed: () async {
                                final d = await Clipboard.getData('text/plain');
                                if (d?.text != null) _rightCtrl.text = d!.text!;
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: TextField(
                            controller: _rightCtrl,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Modified text…',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: FilledButton.icon(
              onPressed: _compare,
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),
          ),

          if (_chunks != null) ...[
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _chunks!.length,
                itemBuilder: (context, i) {
                  final chunk = _chunks![i];
                  return Container(
                    color: _opColor(chunk.op, isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in chunk.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 1),
                            child: Text(
                              '${_prefix(chunk.op)}$line',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: chunk.op == _DiffOp.insert
                                    ? Colors.green.shade700
                                    : chunk.op == _DiffOp.delete
                                        ? Colors.red.shade700
                                        : scheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
