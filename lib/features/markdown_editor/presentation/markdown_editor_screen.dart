import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
      // Share text directly.
      await Share.share(_ctrl.text, subject: 'Markdown document');
      return;
    }
    await Share.shareXFiles([XFile(src)], subject: p.basename(src));
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
