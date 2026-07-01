import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple classical cipher tools: ROT13, Caesar, Atbash, Vigenère.
class TextEncryptionScreen extends StatefulWidget {
  const TextEncryptionScreen({super.key});

  @override
  State<TextEncryptionScreen> createState() => _TextEncryptionScreenState();
}

class _TextEncryptionScreenState extends State<TextEncryptionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  // ROT13 / Caesar
  final _caesarInputCtrl = TextEditingController();
  final _caesarKeyCtrl = TextEditingController(text: '13');
  bool _caesarEncrypt = true;
  String _caesarResult = '';

  // Atbash
  final _atbashCtrl = TextEditingController();
  String _atbashResult = '';

  // Vigenère
  final _vigInputCtrl = TextEditingController();
  final _vigKeyCtrl = TextEditingController();
  bool _vigEncrypt = true;
  String _vigResult = '';
  String? _vigError;

  @override
  void dispose() {
    _tabs.dispose();
    _caesarInputCtrl.dispose();
    _caesarKeyCtrl.dispose();
    _atbashCtrl.dispose();
    _vigInputCtrl.dispose();
    _vigKeyCtrl.dispose();
    super.dispose();
  }

  // ── Caesar ───────────────────────────────────────────────────────────────

  String _caesarCipher(String text, int shift, bool encrypt) {
    shift = shift % 26;
    if (!encrypt) shift = (26 - shift) % 26;
    return text.split('').map((c) {
      if (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) {
        return String.fromCharCode((c.codeUnitAt(0) - 65 + shift) % 26 + 65);
      } else if (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) {
        return String.fromCharCode((c.codeUnitAt(0) - 97 + shift) % 26 + 97);
      }
      return c;
    }).join();
  }

  void _computeCaesar() {
    final shift = int.tryParse(_caesarKeyCtrl.text) ?? 13;
    setState(() => _caesarResult =
        _caesarCipher(_caesarInputCtrl.text, shift, _caesarEncrypt));
  }

  // ── Atbash ───────────────────────────────────────────────────────────────

  String _atbash(String text) => text.split('').map((c) {
        final code = c.codeUnitAt(0);
        if (code >= 65 && code <= 90) {
          return String.fromCharCode(90 - (code - 65));
        } else if (code >= 97 && code <= 122) {
          return String.fromCharCode(122 - (code - 97));
        }
        return c;
      }).join();

  void _computeAtbash() =>
      setState(() => _atbashResult = _atbash(_atbashCtrl.text));

  // ── Vigenère ─────────────────────────────────────────────────────────────

  void _computeVigenere() {
    final key = _vigKeyCtrl.text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (key.isEmpty) {
      setState(() {
        _vigResult = '';
        _vigError = 'Key must contain at least one letter';
      });
      return;
    }
    final text = _vigInputCtrl.text;
    final buf = StringBuffer();
    int ki = 0;
    for (final c in text.split('')) {
      final code = c.codeUnitAt(0);
      if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
        final upper = code < 97;
        final base = upper ? 65 : 97;
        final shift = key.codeUnitAt(ki % key.length) - 65;
        final adjusted = _vigEncrypt
            ? (code - base + shift) % 26 + base
            : (code - base - shift + 26) % 26 + base;
        buf.write(String.fromCharCode(adjusted));
        ki++;
      } else {
        buf.write(c);
      }
    }
    setState(() {
      _vigResult = buf.toString();
      _vigError = null;
    });
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
        title: const Text('Text Encryption'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'ROT13 / Caesar'),
            Tab(text: 'Atbash'),
            Tab(text: 'Vigenère'),
            Tab(text: 'Info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _caesarTab(context),
          _atbashTab(context),
          _vigenereTab(context),
          _infoTab(context),
        ],
      ),
    );
  }

  Widget _caesarTab(BuildContext ctx) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _caesarInputCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Input text',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _caesarKeyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Shift (0–25; 13 = ROT13)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Encrypt')),
                ButtonSegment(value: false, label: Text('Decrypt')),
              ],
              selected: {_caesarEncrypt},
              onSelectionChanged: (s) =>
                  setState(() => _caesarEncrypt = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _computeCaesar,
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('Apply'),
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        if (_caesarResult.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          Row(
            children: [
              const Text('Result',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copy(ctx, _caesarResult, 'Result'),
              ),
            ],
          ),
          SelectableText(_caesarResult,
              style: const TextStyle(fontFamily: 'monospace')),
        ],
      ],
    );
  }

  Widget _atbashTab(BuildContext ctx) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _atbashCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Input text',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _computeAtbash,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Apply Atbash'),
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        if (_atbashResult.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          Row(
            children: [
              const Text('Result',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copy(ctx, _atbashResult, 'Result'),
              ),
            ],
          ),
          SelectableText(_atbashResult,
              style: const TextStyle(fontFamily: 'monospace')),
        ],
        const SizedBox(height: 12),
        const Text(
          'Atbash replaces each letter with its reverse-alphabet counterpart '
          '(A↔Z, B↔Y, …). It is its own inverse.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _vigenereTab(BuildContext ctx) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _vigInputCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Input text',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _vigKeyCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Key (letters only)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Encrypt')),
                ButtonSegment(value: false, label: Text('Decrypt')),
              ],
              selected: {_vigEncrypt},
              onSelectionChanged: (s) =>
                  setState(() => _vigEncrypt = s.first),
            ),
          ],
        ),
        if (_vigError != null) ...[
          const SizedBox(height: 4),
          Text(_vigError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _computeVigenere,
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('Apply'),
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        if (_vigResult.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          Row(
            children: [
              const Text('Result',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copy(ctx, _vigResult, 'Result'),
              ),
            ],
          ),
          SelectableText(_vigResult,
              style: const TextStyle(fontFamily: 'monospace')),
        ],
      ],
    );
  }

  Widget _infoTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ciphers = [
      (
        'ROT13',
        'A special case of the Caesar cipher with a shift of 13. '
            'Because 26/2 = 13, encoding and decoding are the same operation.'
      ),
      (
        'Caesar Cipher',
        'Each letter is shifted by a fixed number of positions in the alphabet. '
            'Easy to break with frequency analysis (26 possible keys).'
      ),
      (
        'Atbash',
        'A simple substitution cipher originally for the Hebrew alphabet. '
            'Maps A↔Z, B↔Y, and so on. Self-inverse: applying it twice gives the original.'
      ),
      (
        'Vigenère',
        'Uses a repeating keyword as the key. Each letter of the plaintext is '
            'shifted by the corresponding letter of the key. Stronger than Caesar '
            'but still vulnerable to the Kasiski attack for short keys.'
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (name, desc) in ciphers)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary)),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        Card(
          color: Colors.orange.withOpacity(0.1),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These are classical ciphers for educational purposes only. '
                    'Do NOT use them to protect sensitive data — they are easily broken. '
                    'Use AES or ChaCha20 for real encryption.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
