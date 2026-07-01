import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Computes MD5, SHA-1, SHA-256, and SHA-512 checksums for any file.
///
/// Useful for verifying download integrity and detecting accidental
/// corruption or tampering.
class FileHashScreen extends StatefulWidget {
  const FileHashScreen({super.key});

  @override
  State<FileHashScreen> createState() => _FileHashScreenState();
}

class _FileHashScreenState extends State<FileHashScreen> {
  String? _path;
  bool _computing = false;
  Map<String, String>? _hashes;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    await _compute(path);
  }

  Future<void> _compute(String path) async {
    setState(() {
      _path = path;
      _computing = true;
      _hashes = null;
      _error = null;
    });
    try {
      final bytes = await File(path).readAsBytes();
      final hashes = <String, String>{
        'MD5': md5.convert(bytes).toString(),
        'SHA-1': sha1.convert(bytes).toString(),
        'SHA-256': sha256.convert(bytes).toString(),
        'SHA-512': sha512.convert(bytes).toString(),
      };
      if (mounted) setState(() => _hashes = hashes);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('File Hash Checker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Select a file to compute its cryptographic checksums.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _computing ? null : _pickFile,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Choose file…'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_path != null) ...[
            const SizedBox(height: 12),
            Text(
              _path!.split('/').last,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          if (_computing)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_hashes != null) ...[
            for (final entry in _hashes!.entries) ...[
              _HashRow(algorithm: entry.key, hash: entry.value),
              const SizedBox(height: 10),
            ],
            const Divider(height: 32),
            // Verify against known hash
            _VerifySection(hashes: _hashes!),
          ],
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  const _HashRow({required this.algorithm, required this.hash});
  final String algorithm;
  final String hash;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(algorithm,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$algorithm hash copied')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              hash,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifySection extends StatefulWidget {
  const _VerifySection({required this.hashes});
  final Map<String, String> hashes;

  @override
  State<_VerifySection> createState() => _VerifySectionState();
}

class _VerifySectionState extends State<_VerifySection> {
  final _ctrl = TextEditingController();
  bool? _match;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _verify() {
    final input = _ctrl.text.trim().toLowerCase();
    if (input.isEmpty) return;
    final found = widget.hashes.values
        .any((h) => h.toLowerCase() == input);
    setState(() => _match = found);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify a known checksum',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Paste expected hash here…',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Verify',
              onPressed: _verify,
            ),
          ),
          onSubmitted: (_) => _verify(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        if (_match != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _match! ? Icons.check_circle : Icons.cancel,
                color: _match! ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                _match!
                    ? 'Hash matches — file is intact'
                    : 'Hash does not match — file may be corrupt or modified',
                style: TextStyle(
                    color: _match! ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
