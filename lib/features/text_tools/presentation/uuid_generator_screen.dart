import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates UUIDs in v4 (random) format.
class UuidGeneratorScreen extends StatefulWidget {
  const UuidGeneratorScreen({super.key});

  @override
  State<UuidGeneratorScreen> createState() => _UuidGeneratorScreenState();
}

class _UuidGeneratorScreenState extends State<UuidGeneratorScreen> {
  final _random = Random.secure();
  List<String> _uuids = [];
  int _count = 5;
  bool _uppercase = false;
  bool _noDashes = false;

  String _generateV4() {
    // Generate 16 random bytes
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Set version 4 bits (bits 12-15 of time_hi_and_version)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant bits (bits 6-7 of clock_seq_hi_and_reserved)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final s = bytes.map(hex).join();
    final uuid =
        '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
    var result = uuid;
    if (_uppercase) result = result.toUpperCase();
    if (_noDashes) result = result.replaceAll('-', '');
    return result;
  }

  void _generate() {
    setState(() => _uuids = List.generate(_count, (_) => _generateV4()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('UUID Generator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Options
            Row(
              children: [
                const Text('Count:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _count,
                  items: [1, 5, 10, 20, 50]
                      .map((n) => DropdownMenuItem(
                          value: n, child: Text(n.toString())))
                      .toList(),
                  onChanged: (v) => setState(() => _count = v!),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('UPPERCASE'),
                  selected: _uppercase,
                  onSelected: (v) => setState(() => _uppercase = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('No dashes'),
                  selected: _noDashes,
                  onSelected: (v) => setState(() => _noDashes = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Generate'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            if (_uuids.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${_uuids.length} UUID(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: const Text('Copy all'),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _uuids.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All UUIDs copied!')),
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _uuids.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final uuid = _uuids[i];
                    return ListTile(
                      dense: true,
                      title: SelectableText(uuid,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: uuid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UUID copied!')),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'UUID v4 uses 122 random bits,\n'
                        'giving 5.3×10³⁶ possible values.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
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
