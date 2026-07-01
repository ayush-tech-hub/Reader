import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Encode and decode Base64 strings.
///
/// Supports standard Base64 (RFC 4648) and URL-safe Base64 variants.
/// Useful for decoding data URIs, JWT payloads, embedded assets, or
/// any base64-encoded content found in documents / config files.
class Base64Screen extends StatefulWidget {
  const Base64Screen({super.key});

  @override
  State<Base64Screen> createState() => _Base64ScreenState();
}

class _Base64ScreenState extends State<Base64Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _encodeCtrl = TextEditingController();
  final _decodeCtrl = TextEditingController();
  String _encodeResult = '';
  String _decodeResult = '';
  String? _encodeError;
  String? _decodeError;
  bool _urlSafe = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _encodeCtrl.dispose();
    _decodeCtrl.dispose();
    super.dispose();
  }

  void _encode() {
    final text = _encodeCtrl.text;
    if (text.isEmpty) return;
    try {
      final bytes = utf8.encode(text);
      final result = _urlSafe
          ? base64Url.encode(bytes)
          : base64.encode(bytes);
      setState(() {
        _encodeResult = result;
        _encodeError = null;
      });
    } catch (e) {
      setState(() => _encodeError = e.toString());
    }
  }

  void _decode() {
    var text = _decodeCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      // Normalise — accept both variants
      final normalised = text.replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if missing
      final padded = normalised.padRight(
          (normalised.length + 3) ~/ 4 * 4, '=');
      final bytes = base64.decode(padded);
      // Try UTF-8; fall back to latin-1
      String decoded;
      try {
        decoded = utf8.decode(bytes);
      } catch (_) {
        decoded = latin1.decode(bytes);
      }
      setState(() {
        _decodeResult = decoded;
        _decodeError = null;
      });
    } catch (e) {
      setState(() => _decodeError = 'Invalid Base64: $e');
    }
  }

  Widget _copyButton(String text) => IconButton(
        icon: const Icon(Icons.copy, size: 20),
        tooltip: 'Copy',
        onPressed: text.isEmpty
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Base64 Tool'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Encode'),
            Tab(text: 'Decode'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Encode tab ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('URL-safe (- instead of +, _ instead of /)'),
                  value: _urlSafe,
                  onChanged: (v) => setState(() => _urlSafe = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _encodeCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Plain text to encode',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) {
                    if (_encodeResult.isNotEmpty) {
                      setState(() {
                        _encodeResult = '';
                        _encodeError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.paste_outlined),
                      label: const Text('Paste'),
                      onPressed: () async {
                        final d =
                            await Clipboard.getData('text/plain');
                        if (d?.text != null) _encodeCtrl.text = d!.text!;
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.lock_outlined),
                        label: const Text('Encode'),
                        onPressed: _encode,
                      ),
                    ),
                  ],
                ),
                if (_encodeError != null) ...[
                  const SizedBox(height: 8),
                  Text(_encodeError!,
                      style: const TextStyle(color: Colors.red)),
                ],
                if (_encodeResult.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Result',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary)),
                      const Spacer(),
                      _copyButton(_encodeResult),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.primary.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.primaryContainer.withOpacity(0.2),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _encodeResult,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Decode tab ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _decodeCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Base64 string to decode',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                  onChanged: (_) {
                    if (_decodeResult.isNotEmpty) {
                      setState(() {
                        _decodeResult = '';
                        _decodeError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.paste_outlined),
                      label: const Text('Paste'),
                      onPressed: () async {
                        final d =
                            await Clipboard.getData('text/plain');
                        if (d?.text != null) _decodeCtrl.text = d!.text!;
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.lock_open_outlined),
                        label: const Text('Decode'),
                        onPressed: _decode,
                      ),
                    ),
                  ],
                ),
                if (_decodeError != null) ...[
                  const SizedBox(height: 8),
                  Text(_decodeError!,
                      style: const TextStyle(color: Colors.red)),
                ],
                if (_decodeResult.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Result',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary)),
                      const Spacer(),
                      _copyButton(_decodeResult),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.primary.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.primaryContainer.withOpacity(0.2),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _decodeResult,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
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
