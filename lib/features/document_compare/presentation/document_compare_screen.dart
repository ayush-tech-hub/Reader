// ignore_for_file: unawaited_futures

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';

/// Side-by-side or unified diff view for two documents.
class DocumentCompareScreen extends ConsumerStatefulWidget {
  const DocumentCompareScreen({super.key});

  @override
  ConsumerState<DocumentCompareScreen> createState() =>
      _DocumentCompareScreenState();
}

class _DocumentCompareScreenState
    extends ConsumerState<DocumentCompareScreen> {
  String? _pathA;
  String? _pathB;
  List<_DiffChunk>? _diff;
  bool _busy = false;
  String? _error;

  Future<void> _pick(bool isA) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      if (isA) {
        _pathA = path;
      } else {
        _pathB = path;
      }
      _diff = null;
    });
  }

  Future<void> _compare() async {
    final a = _pathA;
    final b = _pathB;
    if (a == null || b == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _diff = null;
    });
    try {
      final index = ref.read(documentIndexServiceProvider);
      var textA = await index.documentText(a);
      if (textA.trim().isEmpty) {
        await index.indexFile(a);
        textA = await index.documentText(a);
      }
      var textB = await index.documentText(b);
      if (textB.trim().isEmpty) {
        await index.indexFile(b);
        textB = await index.documentText(b);
      }
      final diff = _computeDiff(textA, textB);
      if (mounted) setState(() => _diff = diff);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Document comparison')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── File pickers ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _FilePicker(
                  label: 'Document A',
                  path: _pathA,
                  onTap: () => _pick(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilePicker(
                  label: 'Document B',
                  path: _pathB,
                  onTap: () => _pick(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Compare'),
            onPressed:
                (_pathA != null && _pathB != null && !_busy) ? _compare : null,
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          if (_diff != null) ...[
            _DiffSummary(chunks: _diff!),
            const SizedBox(height: 8),
            for (final chunk in _diff!) _ChunkTile(chunk: chunk),
          ],
        ],
      ),
    );
  }
}

// ── Diff engine ───────────────────────────────────────────────────────────────

enum _DiffKind { equal, added, removed }

class _DiffChunk {
  const _DiffChunk(this.kind, this.text);
  final _DiffKind kind;
  final String text;
}

/// Line-level LCS diff.
List<_DiffChunk> _computeDiff(String a, String b) {
  final linesA = a.split('\n').where((l) => l.trim().isNotEmpty).toList();
  final linesB = b.split('\n').where((l) => l.trim().isNotEmpty).toList();

  // Limit for performance: compare at most 500 lines each.
  final aSlice = linesA.take(500).toList();
  final bSlice = linesB.take(500).toList();

  final m = aSlice.length;
  final n = bSlice.length;

  // Build LCS table.
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (aSlice[i - 1].trim() == bSlice[j - 1].trim()) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  // Backtrack.
  final chunks = <_DiffChunk>[];
  var i = m;
  var j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && aSlice[i - 1].trim() == bSlice[j - 1].trim()) {
      chunks.add(_DiffChunk(_DiffKind.equal, aSlice[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      chunks.add(_DiffChunk(_DiffKind.added, bSlice[j - 1]));
      j--;
    } else {
      chunks.add(_DiffChunk(_DiffKind.removed, aSlice[i - 1]));
      i--;
    }
  }

  // Collapse consecutive equal chunks to save screen space.
  final result = chunks.reversed.toList();
  return _collapse(result);
}

List<_DiffChunk> _collapse(List<_DiffChunk> raw) {
  const maxContext = 2;
  final out = <_DiffChunk>[];
  var equalsRun = <String>[];

  void flush() {
    if (equalsRun.isEmpty) return;
    if (equalsRun.length <= maxContext * 2) {
      out.add(_DiffChunk(_DiffKind.equal, equalsRun.join('\n')));
    } else {
      out.add(_DiffChunk(
          _DiffKind.equal, equalsRun.take(maxContext).join('\n')));
      out.add(const _DiffChunk(_DiffKind.equal, '…'));
      out.add(_DiffChunk(
          _DiffKind.equal, equalsRun.skip(equalsRun.length - maxContext).join('\n')));
    }
    equalsRun = [];
  }

  for (final c in raw) {
    if (c.kind == _DiffKind.equal && c.text != '…') {
      equalsRun.addAll(c.text.split('\n'));
    } else {
      flush();
      out.add(c);
    }
  }
  flush();
  return out;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _FilePicker extends StatelessWidget {
  const _FilePicker({
    required this.label,
    required this.path,
    required this.onTap,
  });
  final String label;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(path == null ? label : p.basename(path!),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: path == null ? const Text('Tap to pick') : null,
        trailing: const Icon(Icons.folder_open, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _DiffSummary extends StatelessWidget {
  const _DiffSummary({required this.chunks});
  final List<_DiffChunk> chunks;

  @override
  Widget build(BuildContext context) {
    final added = chunks.where((c) => c.kind == _DiffKind.added).length;
    final removed = chunks.where((c) => c.kind == _DiffKind.removed).length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline,
                color: Colors.green.shade700, size: 18),
            const SizedBox(width: 4),
            Text('$added added',
                style:
                    TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Icon(Icons.remove_circle_outline,
                color: scheme.error, size: 18),
            const SizedBox(width: 4),
            Text('$removed removed',
                style: TextStyle(
                    color: scheme.error, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ChunkTile extends StatelessWidget {
  const _ChunkTile({required this.chunk});
  final _DiffChunk chunk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (chunk.text == '…') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '  ···',
          style: TextStyle(color: scheme.outline, fontSize: 12),
        ),
      );
    }

    Color bg;
    Color fg;
    String prefix;
    switch (chunk.kind) {
      case _DiffKind.added:
        bg = Colors.green.shade50;
        fg = Colors.green.shade900;
        prefix = '+ ';
      case _DiffKind.removed:
        bg = scheme.errorContainer.withOpacity(0.4);
        fg = scheme.onErrorContainer;
        prefix = '− ';
      case _DiffKind.equal:
        bg = Colors.transparent;
        fg = scheme.onSurface.withOpacity(0.6);
        prefix = '  ';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SelectableText(
          '$prefix${chunk.text}',
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
