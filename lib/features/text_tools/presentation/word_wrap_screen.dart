import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formats text by wrapping at a configurable column width and
/// optionally left-pads each line for indentation.
class WordWrapScreen extends StatefulWidget {
  const WordWrapScreen({super.key});

  @override
  State<WordWrapScreen> createState() => _WordWrapScreenState();
}

class _WordWrapScreenState extends State<WordWrapScreen> {
  final _inputCtrl = TextEditingController();
  String _result = '';

  double _lineWidth = 72;
  int _indent = 0;
  bool _preserveBlankLines = true;
  bool _joinParagraphLines = false; // join within a paragraph before re-wrapping

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  String _wrap() {
    final text = _inputCtrl.text;
    if (text.isEmpty) return '';
    final indentStr = ' ' * _indent;
    final width = _lineWidth.toInt();
    final effectiveWidth = (width - _indent).clamp(1, width);

    // Split into paragraphs (blank line delimiters)
    final rawParagraphs = text.split(RegExp(r'\n\s*\n'));

    final output = StringBuffer();
    for (var pi = 0; pi < rawParagraphs.length; pi++) {
      if (pi > 0 && _preserveBlankLines) {
        output.write('\n\n');
      } else if (pi > 0) {
        output.write('\n');
      }

      var para = rawParagraphs[pi].trim();
      if (para.isEmpty) continue;

      if (_joinParagraphLines) {
        para = para.replaceAll('\n', ' ').replaceAll(RegExp(r' +'), ' ');
      }

      // Wrap words
      final words = para.split(RegExp(r'\s+'));
      var lineLen = 0;
      final lineBuf = StringBuffer();

      for (final word in words) {
        if (word.isEmpty) continue;
        if (lineLen == 0) {
          lineBuf.write(indentStr + word);
          lineLen = _indent + word.length;
        } else if (lineLen + 1 + word.length <= effectiveWidth + _indent) {
          lineBuf.write(' $word');
          lineLen += 1 + word.length;
        } else {
          output.writeln(lineBuf.toString());
          lineBuf.clear();
          lineBuf.write(indentStr + word);
          lineLen = _indent + word.length;
        }
      }
      if (lineBuf.isNotEmpty) {
        output.write(lineBuf.toString());
      }
    }
    return output.toString();
  }

  void _process() {
    setState(() => _result = _wrap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Word Wrap Formatter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Input text',
                hintText: 'Paste text to reformat…',
              ),
            ),
            const SizedBox(height: 12),

            // Line width slider
            Row(
              children: [
                const Text('Line width:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${_lineWidth.toInt()} chars'),
                Expanded(
                  child: Slider(
                    value: _lineWidth,
                    min: 20,
                    max: 120,
                    divisions: 20,
                    label: _lineWidth.toInt().toString(),
                    onChanged: (v) => setState(() => _lineWidth = v),
                  ),
                ),
              ],
            ),

            // Indent slider
            Row(
              children: [
                const Text('Indent:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('$_indent spaces'),
                Expanded(
                  child: Slider(
                    value: _indent.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    label: _indent.toString(),
                    onChanged: (v) => setState(() => _indent = v.toInt()),
                  ),
                ),
              ],
            ),

            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _joinParagraphLines,
              onChanged: (v) => setState(() => _joinParagraphLines = v),
              title: const Text('Join paragraph lines before re-wrapping'),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _preserveBlankLines,
              onChanged: (v) => setState(() => _preserveBlankLines = v),
              title: const Text('Preserve blank lines between paragraphs'),
            ),

            FilledButton.icon(
              onPressed: _process,
              icon: const Icon(Icons.wrap_text),
              label: const Text('Format'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),

            if (_result.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  const Text('Result',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
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
