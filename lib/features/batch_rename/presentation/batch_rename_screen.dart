import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

enum _RenamePattern { numbered, prefix, suffix, replace, regexReplace }

/// Renames multiple files at once using a chosen pattern.
class BatchRenameScreen extends StatefulWidget {
  const BatchRenameScreen({super.key});

  @override
  State<BatchRenameScreen> createState() => _BatchRenameScreenState();
}

class _BatchRenameScreenState extends State<BatchRenameScreen> {
  final List<String> _files = [];
  _RenamePattern _pattern = _RenamePattern.numbered;
  final _param1 = TextEditingController(text: 'file_');
  final _param2 = TextEditingController();
  int _startNumber = 1;
  bool _preserveExtension = true;
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _param1.dispose();
    _param2.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() {
      _files.clear();
      _files.addAll(
        result.files.map((f) => f.path).whereType<String>(),
      );
      _result = null;
    });
  }

  String _preview(String originalPath, int index) {
    final dir = p.dirname(originalPath);
    final base = p.basenameWithoutExtension(originalPath);
    final ext = _preserveExtension ? p.extension(originalPath) : '';

    String newBase;
    switch (_pattern) {
      case _RenamePattern.numbered:
        final prefix = _param1.text;
        final pad = (_files.length + _startNumber).toString().length;
        newBase =
            '$prefix${(_startNumber + index).toString().padLeft(pad, '0')}';
      case _RenamePattern.prefix:
        newBase = '${_param1.text}$base';
      case _RenamePattern.suffix:
        newBase = '$base${_param1.text}';
      case _RenamePattern.replace:
        final from = _param1.text;
        final to = _param2.text;
        newBase = base.replaceAll(from, to);
      case _RenamePattern.regexReplace:
        try {
          final re = RegExp(_param1.text);
          newBase = base.replaceAll(re, _param2.text);
        } catch (_) {
          newBase = base;
        }
    }
    return p.join(dir, '$newBase$ext');
  }

  Future<void> _apply() async {
    if (_files.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });

    int done = 0;
    final errors = <String>[];

    for (int i = 0; i < _files.length; i++) {
      final src = _files[i];
      final dst = _preview(src, i);
      if (src == dst) {
        done++;
        continue;
      }
      try {
        await File(src).rename(dst);
        _files[i] = dst;
        done++;
      } catch (e) {
        errors.add('${p.basename(src)}: $e');
      }
    }

    setState(() {
      _busy = false;
      _result = errors.isEmpty
          ? '$done file${done != 1 ? 's' : ''} renamed successfully.'
          : '$done renamed. Errors:\n${errors.join('\n')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch rename'),
        actions: [
          if (_files.isNotEmpty)
            FilledButton(
              onPressed: _busy ? null : _apply,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Rename'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // File picker
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_files.isEmpty
                ? 'Pick files'
                : 'Pick files (${_files.length} selected)'),
            onPressed: _pickFiles,
          ),
          const SizedBox(height: 16),

          // Pattern selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rename pattern',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final pat in _RenamePattern.values)
                        ChoiceChip(
                          label: Text(_patLabel(pat)),
                          selected: _pattern == pat,
                          onSelected: (_) =>
                              setState(() => _pattern = pat),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPatternFields(),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Preserve extension'),
                    value: _preserveExtension,
                    onChanged: (v) =>
                        setState(() => _preserveExtension = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preview
          if (_files.isNotEmpty) ...[
            Text('Preview', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (int i = 0; i < _files.length && i < 10; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.basename(_files[i]),
                        style: TextStyle(color: scheme.outline, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 14),
                    Expanded(
                      child: Text(
                        p.basename(_preview(_files[i], i)),
                        style:
                            TextStyle(color: scheme.primary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (_files.length > 10)
              Text('… and ${_files.length - 10} more',
                  style: TextStyle(color: scheme.outline)),
          ],
          const SizedBox(height: 16),

          // Result
          if (_result != null)
            Card(
              color: _result!.contains('Error')
                  ? scheme.errorContainer
                  : scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _result!,
                  style: TextStyle(
                    color: _result!.contains('Error')
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatternFields() {
    switch (_pattern) {
      case _RenamePattern.numbered:
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _param1,
                decoration: const InputDecoration(
                  labelText: 'Prefix',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextField(
                controller: TextEditingController(
                    text: _startNumber.toString()),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Start #',
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() => _startNumber = int.tryParse(v) ?? 1);
                },
              ),
            ),
          ],
        );
      case _RenamePattern.prefix:
        return TextField(
          controller: _param1,
          decoration: const InputDecoration(
            labelText: 'Prefix to add',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        );
      case _RenamePattern.suffix:
        return TextField(
          controller: _param1,
          decoration: const InputDecoration(
            labelText: 'Suffix to add',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        );
      case _RenamePattern.replace:
      case _RenamePattern.regexReplace:
        return Column(
          children: [
            TextField(
              controller: _param1,
              decoration: InputDecoration(
                labelText: _pattern == _RenamePattern.regexReplace
                    ? 'Regex pattern'
                    : 'Find text',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _param2,
              decoration: const InputDecoration(
                labelText: 'Replace with',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
    }
  }

  static String _patLabel(_RenamePattern p) {
    switch (p) {
      case _RenamePattern.numbered:
        return 'Numbered';
      case _RenamePattern.prefix:
        return 'Add prefix';
      case _RenamePattern.suffix:
        return 'Add suffix';
      case _RenamePattern.replace:
        return 'Find & replace';
      case _RenamePattern.regexReplace:
        return 'Regex';
    }
  }
}
