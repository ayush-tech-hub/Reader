import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StringHasherScreen extends StatefulWidget {
  const StringHasherScreen({super.key});

  @override
  State<StringHasherScreen> createState() => _StringHasherScreenState();
}

class _StringHasherScreenState extends State<StringHasherScreen> {
  final _inputCtrl = TextEditingController();
  bool _uppercase = false;

  Map<String, String> _hashes = {};

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _compute() {
    final bytes = utf8.encode(_inputCtrl.text);
    String fmt(Digest d) {
      final s = d.toString();
      return _uppercase ? s.toUpperCase() : s;
    }

    setState(() {
      _hashes = {
        'MD5': fmt(md5.convert(bytes)),
        'SHA-1': fmt(sha1.convert(bytes)),
        'SHA-224': fmt(sha224.convert(bytes)),
        'SHA-256': fmt(sha256.convert(bytes)),
        'SHA-384': fmt(sha384.convert(bytes)),
        'SHA-512': fmt(sha512.convert(bytes)),
        'SHA-512/224': fmt(sha512224.convert(bytes)),
        'SHA-512/256': fmt(sha512256.convert(bytes)),
        'HMAC-SHA256 (key=key)':
            fmt(Hmac(sha256, utf8.encode('key')).convert(bytes)),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('String Hasher')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter text to hash…',
                labelText: 'Input',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: _uppercase,
                  onChanged: (v) {
                    setState(() => _uppercase = v);
                    if (_hashes.isNotEmpty) _compute();
                  },
                ),
                const Text('Uppercase output'),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _compute,
                  icon: const Icon(Icons.tag),
                  label: const Text('Hash'),
                ),
              ],
            ),
            if (_hashes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in _hashes.entries)
                      _HashRow(
                        algorithm: entry.key,
                        value: entry.value,
                        scheme: scheme,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  const _HashRow({
    required this.algorithm,
    required this.value,
    required this.scheme,
  });

  final String algorithm;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(algorithm,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary)),
                  const SizedBox(height: 2),
                  SelectableText(
                    value,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$algorithm hash copied!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
