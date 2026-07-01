import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ── Minimal Markdown → HTML converter ─────────────────────────────────────────
// Handles the most common Markdown elements.  Not a full spec-compliant parser —
// intended for export of typical prose documents.
String _markdownToHtml(String md) {
  final lines = md.split('\n');
  final buf = StringBuffer(
      '<!DOCTYPE html><html><head><meta charset="UTF-8">'
      '<style>body{font-family:sans-serif;max-width:800px;margin:2em auto;'
      'padding:0 1em;line-height:1.6}pre{background:#f4f4f4;padding:1em;'
      'border-radius:4px;overflow-x:auto}code{background:#f4f4f4;padding:.2em .4em}'
      'blockquote{border-left:4px solid #ccc;margin:0;padding-left:1em;color:#666}'
      'hr{border:none;border-top:1px solid #ddd}</style></head><body>\n');

  bool inCode = false;
  bool inUl = false;
  bool inOl = false;

  void closeList() {
    if (inUl) {
      buf.write('</ul>\n');
      inUl = false;
    }
    if (inOl) {
      buf.write('</ol>\n');
      inOl = false;
    }
  }

  String inline(String s) {
    // Escape HTML
    s = s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    // Bold + italic
    s = s.replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*'),
        (m) => '<strong><em>${m[1]}</em></strong>');
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'),
        (m) => '<strong>${m[1]}</strong>');
    s = s.replaceAllMapped(RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
        (m) => '<em>${m[1]}</em>');
    s = s.replaceAllMapped(RegExp(r'__(.+?)__'),
        (m) => '<strong>${m[1]}</strong>');
    s = s.replaceAllMapped(RegExp(r'_(.+?)_'), (m) => '<em>${m[1]}</em>');
    // Inline code
    s = s.replaceAllMapped(RegExp(r'`(.+?)`'), (m) => '<code>${m[1]}</code>');
    // Links
    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
        (m) => '<a href="${m[2]}">${m[1]}</a>');
    // Strikethrough
    s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => '<del>${m[1]}</del>');
    return s;
  }

  for (var line in lines) {
    // Fenced code block
    if (line.startsWith('```')) {
      if (inCode) {
        buf.write('</code></pre>\n');
        inCode = false;
      } else {
        closeList();
        buf.write('<pre><code>');
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      buf.write(
          '${line.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}\n');
      continue;
    }

    // Headings
    final hMatch = RegExp(r'^(#{1,6})\s+(.+)').firstMatch(line);
    if (hMatch != null) {
      closeList();
      final level = hMatch.group(1)!.length;
      buf.write('<h$level>${inline(hMatch.group(2)!)}</h$level>\n');
      continue;
    }

    // Horizontal rule
    if (RegExp(r'^[-*_]{3,}\s*$').hasMatch(line)) {
      closeList();
      buf.write('<hr>\n');
      continue;
    }

    // Blockquote
    if (line.startsWith('> ')) {
      closeList();
      buf.write('<blockquote><p>${inline(line.substring(2))}</p></blockquote>\n');
      continue;
    }

    // Unordered list
    final ulMatch = RegExp(r'^[*\-+]\s+(.+)').firstMatch(line);
    if (ulMatch != null) {
      if (inOl) {
        buf.write('</ol>\n');
        inOl = false;
      }
      if (!inUl) {
        buf.write('<ul>\n');
        inUl = true;
      }
      buf.write('<li>${inline(ulMatch.group(1)!)}</li>\n');
      continue;
    }

    // Ordered list
    final olMatch = RegExp(r'^\d+\.\s+(.+)').firstMatch(line);
    if (olMatch != null) {
      if (inUl) {
        buf.write('</ul>\n');
        inUl = false;
      }
      if (!inOl) {
        buf.write('<ol>\n');
        inOl = true;
      }
      buf.write('<li>${inline(olMatch.group(1)!)}</li>\n');
      continue;
    }

    // Blank line → paragraph break
    if (line.trim().isEmpty) {
      closeList();
      buf.write('\n');
      continue;
    }

    closeList();
    buf.write('<p>${inline(line)}</p>\n');
  }

  closeList();
  if (inCode) buf.write('</code></pre>\n');
  buf.write('</body></html>');
  return buf.toString();
}

enum _EditorMode { edit, split, preview }

/// A simple Markdown editor with live preview.
///
/// Opens existing .md files or creates a new blank document.
/// Supports split view (editor + rendered preview side by side).
class MarkdownEditorScreen extends StatefulWidget {
  const MarkdownEditorScreen({super.key, this.path});

  /// If provided, loads this file; otherwise creates a blank document.
  final String? path;

  @override
  State<MarkdownEditorScreen> createState() => _MarkdownEditorScreenState();
}

class _MarkdownEditorScreenState extends State<MarkdownEditorScreen> {
  final _ctrl = TextEditingController();
  String? _filePath;
  bool _dirty = false;
  _EditorMode _mode = _EditorMode.split;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    if (widget.path != null) {
      _loadFile(widget.path!);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() => _dirty = true);

  Future<void> _loadFile(String path) async {
    setState(() => _loading = true);
    try {
      final content = await File(path).readAsString();
      _ctrl.text = content;
      setState(() {
        _filePath = path;
        _dirty = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_dirty && !await _confirmDiscard()) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    final path = result?.files.single.path;
    if (path != null) await _loadFile(path);
  }

  Future<void> _save() async {
    if (_filePath == null) {
      await _saveAs();
      return;
    }
    await File(_filePath!).writeAsString(_ctrl.text);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  Future<void> _saveAs() async {
    final dir = await getApplicationDocumentsDirectory();
    final name = _filePath != null
        ? p.basename(_filePath!)
        : 'note_${DateTime.now().millisecondsSinceEpoch}.md';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(_ctrl.text);
    setState(() {
      _filePath = file.path;
      _dirty = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Unsaved changes will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _share() async {
    final src = _filePath;
    if (src == null) {
      await Share.share(_ctrl.text, subject: 'Markdown document');
      return;
    }
    await Share.shareXFiles([XFile(src)], subject: p.basename(src));
  }

  Future<void> _exportHtml() async {
    if (_ctrl.text.trim().isEmpty) return;
    final html = _markdownToHtml(_ctrl.text);
    final dir = await getApplicationDocumentsDirectory();
    final baseName = _filePath != null
        ? p.basenameWithoutExtension(_filePath!)
        : 'document';
    final outPath = p.join(dir.path, '$baseName.html');
    await File(outPath).writeAsString(html);
    if (!mounted) return;
    await Share.shareXFiles([XFile(outPath)], subject: '$baseName.html');
  }

  @override
  Widget build(BuildContext context) {
    final title = _filePath != null
        ? p.basename(_filePath!)
        : 'New document';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _confirmDiscard();
        if (allow && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _dirty ? '$title ●' : title,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Mode toggle
            SegmentedButton<_EditorMode>(
              segments: const [
                ButtonSegment(
                  value: _EditorMode.edit,
                  icon: Icon(Icons.edit, size: 16),
                  tooltip: 'Edit',
                ),
                ButtonSegment(
                  value: _EditorMode.split,
                  icon: Icon(Icons.view_column, size: 16),
                  tooltip: 'Split',
                ),
                ButtonSegment(
                  value: _EditorMode.preview,
                  icon: Icon(Icons.preview, size: 16),
                  tooltip: 'Preview',
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Open file',
              onPressed: _open,
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: _dirty ? _save : null,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'saveAs') _saveAs();
                if (v == 'share') _share();
                if (v == 'exportHtml') _exportHtml();
                if (v == 'new') {
                  if (_dirty) {
                    _confirmDiscard().then((ok) {
                      if (ok) {
                        _ctrl.text = '';
                        setState(() {
                          _filePath = null;
                          _dirty = false;
                        });
                      }
                    });
                  } else {
                    _ctrl.text = '';
                    setState(() {
                      _filePath = null;
                      _dirty = false;
                    });
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('New')),
                const PopupMenuItem(value: 'saveAs', child: Text('Save as…')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(
                    value: 'exportHtml', child: Text('Export as HTML')),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final editor = _Editor(controller: _ctrl);
    final preview = _Preview(text: _ctrl.text);

    switch (_mode) {
      case _EditorMode.edit:
        return editor;
      case _EditorMode.preview:
        return preview;
      case _EditorMode.split:
        return Row(
          children: [
            Expanded(child: editor),
            const VerticalDivider(width: 1),
            Expanded(child: preview),
          ],
        );
    }
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.6),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
        hintText: '# Start writing Markdown…\n\nType here.',
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          'Preview will appear here.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return Markdown(
      data: text,
      selectable: true,
      padding: const EdgeInsets.all(16),
    );
  }
}
