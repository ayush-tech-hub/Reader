import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UrlEncoderScreen extends StatefulWidget {
  const UrlEncoderScreen({super.key});

  @override
  State<UrlEncoderScreen> createState() => _UrlEncoderScreenState();
}

class _UrlEncoderScreenState extends State<UrlEncoderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  // Encode tab
  final _encInputCtrl = TextEditingController();
  String _encResult = '';
  bool _encodeComponent = true;

  // Decode tab
  final _decInputCtrl = TextEditingController();
  String _decResult = '';
  String? _decError;

  @override
  void dispose() {
    _tabs.dispose();
    _encInputCtrl.dispose();
    _decInputCtrl.dispose();
    super.dispose();
  }

  void _encode() {
    final raw = _encInputCtrl.text;
    if (_encodeComponent) {
      setState(() => _encResult = Uri.encodeComponent(raw));
    } else {
      setState(() => _encResult = Uri.encodeFull(raw));
    }
  }

  void _decode() {
    final raw = _decInputCtrl.text.trim();
    try {
      // Try URI decode first, then HTML entity decode
      String decoded = Uri.decodeFull(raw.replaceAll('+', ' '));
      setState(() {
        _decResult = decoded;
        _decError = null;
      });
    } catch (_) {
      setState(() {
        _decResult = '';
        _decError = 'Invalid URL-encoded string';
      });
    }
  }

  void _copy(BuildContext ctx, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text('$label copied!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Encoder / Decoder'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Encode'), Tab(text: 'Decode')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Encode ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _encInputCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter text to encode…',
                    labelText: 'Input',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _encodeComponent,
                  onChanged: (v) => setState(() => _encodeComponent = v),
                  title: const Text('Encode component'),
                  subtitle: const Text(
                      'On: encodes ?, &, =, # too  •  Off: encodes spaces and non-ASCII only'),
                  contentPadding: EdgeInsets.zero,
                ),
                FilledButton.icon(
                  onPressed: _encode,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Encode'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                ),
                if (_encResult.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Result',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () =>
                            _copy(context, _encResult, 'Encoded URL'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(_encResult,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Decode ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _decInputCtrl,
                  maxLines: 5,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter URL-encoded text…',
                    labelText: 'Encoded input',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _decode,
                  icon: const Icon(Icons.lock_open_outlined),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Result',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () =>
                            _copy(context, _decResult, 'Decoded text'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(_decResult,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
