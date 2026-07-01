import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cleans and normalises pasted or OCR-extracted text.
///
/// Operations applied (each can be toggled):
///   • Remove extra blank lines (collapse 3+ newlines → 2)
///   • Trim leading/trailing whitespace per line
///   • Remove soft hyphens (­ U+00AD) and line-break hyphens at EOL
///   • Fix common OCR ligature artifacts (ﬁ → fi, ﬂ → fl, etc.)
///   • Collapse multiple spaces into one
///   • Remove non-printable / control characters
class TextCleanerScreen extends StatefulWidget {
  const TextCleanerScreen({super.key});

  @override
  State<TextCleanerScreen> createState() => _TextCleanerScreenState();
}

class _TextCleanerScreenState extends State<TextCleanerScreen> {
  final _inputCtrl = TextEditingController();
  String _cleaned = '';
  bool _didClean = false;

  // Options
  bool _collapseBlankLines = true;
  bool _trimLines = true;
  bool _fixHyphens = true;
  bool _fixLigatures = true;
  bool _collapseSpaces = true;
  bool _removeControlChars = true;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _clean() {
    var text = _inputCtrl.text;
    if (text.isEmpty) return;

    if (_removeControlChars) {
      // Keep standard whitespace (space, tab, newline, CR)
      text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
      // Remove soft hyphen
      text = text.replaceAll('­', '');
      // Remove zero-width chars
      text = text.replaceAll(RegExp(r'[​-‍﻿]'), '');
    }

    if (_fixLigatures) {
      text = text
          .replaceAll('ﬀ', 'ff')
          .replaceAll('ﬁ', 'fi')
          .replaceAll('ﬂ', 'fl')
          .replaceAll('ﬃ', 'ffi')
          .replaceAll('ﬄ', 'ffl')
          .replaceAll('ﬅ', 'st')
          .replaceAll('ﬆ', 'st');
    }

    if (_fixHyphens) {
      // OCR often splits words at line end with a hyphen; re-join them.
      text = text.replaceAllMapped(
        RegExp(r'(\w)-\n(\w)'),
        (m) => '${m[1]}${m[2]}',
      );
    }

    if (_trimLines) {
      text = text
          .split('\n')
          .map((l) => l.trimRight())
          .join('\n');
    }

    if (_collapseSpaces) {
      // Replace multiple spaces/tabs (not newlines) with a single space.
      text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    }

    if (_collapseBlankLines) {
      // Collapse 3+ consecutive newlines to 2 (i.e., one blank line).
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }

    setState(() {
      _cleaned = text.trim();
      _didClean = true;
    });
  }

  int get _charDiff => _inputCtrl.text.length - _cleaned.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Cleaner'),
        actions: [
          if (_didClean)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy cleaned text',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _cleaned));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Options
          Container(
            color: scheme.surfaceContainerHighest.withOpacity(0.4),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _ToggleChip(
                  label: 'Blank lines',
                  value: _collapseBlankLines,
                  onChanged: (v) =>
                      setState(() => _collapseBlankLines = v),
                ),
                _ToggleChip(
                  label: 'Trim lines',
                  value: _trimLines,
                  onChanged: (v) => setState(() => _trimLines = v),
                ),
                _ToggleChip(
                  label: 'Fix hyphens',
                  value: _fixHyphens,
                  onChanged: (v) => setState(() => _fixHyphens = v),
                ),
                _ToggleChip(
                  label: 'Ligatures',
                  value: _fixLigatures,
                  onChanged: (v) => setState(() => _fixLigatures = v),
                ),
                _ToggleChip(
                  label: 'Spaces',
                  value: _collapseSpaces,
                  onChanged: (v) => setState(() => _collapseSpaces = v),
                ),
                _ToggleChip(
                  label: 'Control chars',
                  value: _removeControlChars,
                  onChanged: (v) =>
                      setState(() => _removeControlChars = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _didClean
                ? _ResultView(
                    cleaned: _cleaned,
                    charDiff: _charDiff,
                    onEdit: () => setState(() => _didClean = false),
                  )
                : _InputView(
                    controller: _inputCtrl,
                    onClean: _clean,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _InputView extends StatelessWidget {
  const _InputView({required this.controller, required this.onClean});
  final TextEditingController controller;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Paste your text here…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.paste_outlined),
                label: const Text('Paste'),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    controller.text = data!.text!;
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Clean Text'),
                  onPressed: controller.text.isNotEmpty ? onClean : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.cleaned,
    required this.charDiff,
    required this.onEdit,
  });
  final String cleaned;
  final int charDiff;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text(
                charDiff > 0
                    ? 'Removed $charDiff character${charDiff == 1 ? '' : 's'}'
                    : 'No changes needed',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${cleaned.length} chars',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  cleaned,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit input'),
                onPressed: onEdit,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to clipboard'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cleaned));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
