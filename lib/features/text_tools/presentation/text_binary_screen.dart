import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Converts text to various binary/byte representations and back.
class TextBinaryScreen extends StatefulWidget {
  const TextBinaryScreen({super.key});

  @override
  State<TextBinaryScreen> createState() => _TextBinaryScreenState();
}

enum _Format { binary, octal, decimal, hex }

class _TextBinaryScreenState extends State<TextBinaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _encCtrl = TextEditingController();
  _Format _encFormat = _Format.binary;
  bool _addSpaces = true;
  String _encResult = '';

  final _decCtrl = TextEditingController();
  _Format _decFormat = _Format.binary;
  String _decResult = '';
  String? _decError;

  @override
  void dispose() {
    _tabs.dispose();
    _encCtrl.dispose();
    _decCtrl.dispose();
    super.dispose();
  }

  void _encode() {
    final bytes = utf8.encode(_encCtrl.text);
    String convert(int b) {
      switch (_encFormat) {
        case _Format.binary:
          return b.toRadixString(2).padLeft(8, '0');
        case _Format.octal:
          return b.toRadixString(8).padLeft(3, '0');
        case _Format.decimal:
          return b.toString().padLeft(3, '0');
        case _Format.hex:
          return b.toRadixString(16).toUpperCase().padLeft(2, '0');
      }
    }

    final sep = _addSpaces ? ' ' : '';
    setState(() => _encResult = bytes.map(convert).join(sep));
  }

  void _decode() {
    try {
      final parts = _decCtrl.text.trim().split(RegExp(r'[\s,]+'));
      final bytes = parts.map((p) {
        if (p.isEmpty) return null;
        int radix;
        switch (_decFormat) {
          case _Format.binary:
            radix = 2;
          case _Format.octal:
            radix = 8;
          case _Format.decimal:
            radix = 10;
          case _Format.hex:
            radix = 16;
        }
        final v = int.tryParse(p, radix: radix);
        if (v == null || v < 0 || v > 255) {
          throw FormatException('Invalid byte value: $p');
        }
        return v;
      }).whereType<int>().toList();

      final result = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _decResult = result;
        _decError = null;
      });
    } catch (e) {
      setState(() {
        _decResult = '';
        _decError = e.toString();
      });
    }
  }

  void _copy(BuildContext ctx, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text('$label copied!')));
  }

  Widget _formatSelector(
      _Format current, ValueChanged<_Format?> onChanged) {
    return SegmentedButton<_Format>(
      segments: const [
        ButtonSegment(value: _Format.binary, label: Text('Bin')),
        ButtonSegment(value: _Format.octal, label: Text('Oct')),
        ButtonSegment(value: _Format.decimal, label: Text('Dec')),
        ButtonSegment(value: _Format.hex, label: Text('Hex')),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.firstOrNull),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text ↔ Binary'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Text → Bytes'), Tab(text: 'Bytes → Text')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Encode tab ───────────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _encCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Text input',
                  hintText: 'Enter text to convert…',
                ),
              ),
              const SizedBox(height: 8),
              _formatSelector(
                  _encFormat, (f) => setState(() => _encFormat = f!)),
              SwitchListTile(
                value: _addSpaces,
                onChanged: (v) => setState(() => _addSpaces = v),
                title: const Text('Add spaces between bytes'),
                contentPadding: EdgeInsets.zero,
              ),
              FilledButton.icon(
                onPressed: _encode,
                icon: const Icon(Icons.transform),
                label: const Text('Convert'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
              if (_encResult.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  children: [
                    const Text('Result',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          _copy(context, _encResult, 'Bytes'),
                    ),
                  ],
                ),
                SelectableText(_encResult,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12,
                        letterSpacing: 0.5)),
              ],
            ],
          ),

          // ── Decode tab ───────────────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _decCtrl,
                maxLines: 4,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Byte values (space or comma separated)',
                  hintText: '01001000 01100101 01101100 01101100 01101111',
                ),
              ),
              const SizedBox(height: 8),
              _formatSelector(
                  _decFormat, (f) => setState(() => _decFormat = f!)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _decode,
                icon: const Icon(Icons.text_fields),
                label: const Text('Decode'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
              if (_decError != null) ...[
                const SizedBox(height: 8),
                Text(_decError!,
                    style: const TextStyle(color: Colors.red)),
              ],
              if (_decResult.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  children: [
                    const Text('Result',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          _copy(context, _decResult, 'Text'),
                    ),
                  ],
                ),
                SelectableText(_decResult,
                    style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
