import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Encodes plain text to HTML entities and decodes them back.
class HtmlEntitiesScreen extends StatefulWidget {
  const HtmlEntitiesScreen({super.key});

  @override
  State<HtmlEntitiesScreen> createState() => _HtmlEntitiesScreenState();
}

class _HtmlEntitiesScreenState extends State<HtmlEntitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _encCtrl = TextEditingController();
  String _encResult = '';
  bool _encodeAll = false; // false = only mandatory chars (< > & " ')

  final _decCtrl = TextEditingController();
  String _decResult = '';
  String? _decError;

  @override
  void dispose() {
    _tabs.dispose();
    _encCtrl.dispose();
    _decCtrl.dispose();
    super.dispose();
  }

  // Mandatory HTML entities
  static const _mandatory = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  };

  // Extended named entities for encode-all mode
  static const _extended = {
    '©': '&copy;',
    '®': '&reg;',
    '™': '&trade;',
    '€': '&euro;',
    '£': '&pound;',
    '¥': '&yen;',
    '°': '&deg;',
    '±': '&plusmn;',
    '×': '&times;',
    '÷': '&divide;',
    'α': '&alpha;',
    'β': '&beta;',
    'γ': '&gamma;',
    'δ': '&delta;',
    'π': '&pi;',
    'σ': '&sigma;',
    'μ': '&mu;',
    '∞': '&infin;',
    '←': '&larr;',
    '→': '&rarr;',
    '↑': '&uarr;',
    '↓': '&darr;',
    '•': '&bull;',
    '…': '&hellip;',
    '–': '&ndash;',
    '—': '&mdash;',
    ' ': '&nbsp;',
  };

  // Reverse map for decoding (all named + numeric)
  static final _decodeMap = <String, String>{
    for (final e in _mandatory.entries) e.value: e.key,
    for (final e in _extended.entries) e.value: e.key,
  };

  void _encode() {
    var result = _encCtrl.text;
    // Always encode mandatory chars
    for (final e in _mandatory.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    if (_encodeAll) {
      for (final e in _extended.entries) {
        result = result.replaceAll(e.key, e.value);
      }
      // Encode any remaining non-ASCII as &#xxx;
      result = result.replaceAllMapped(RegExp(r'[^\x00-\x7F]'), (m) {
        return '&#${m[0]!.codeUnitAt(0)};';
      });
    }
    setState(() => _encResult = result);
  }

  void _decode() {
    try {
      var result = _decCtrl.text;
      // Named entities
      for (final e in _decodeMap.entries) {
        result = result.replaceAll(e.key, e.value);
      }
      // Numeric decimal &#123;
      result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.parse(m[1]!);
        return String.fromCharCode(code);
      });
      // Numeric hex &#x1F600;
      result = result.replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        final code = int.parse(m[1]!, radix: 16);
        return String.fromCharCode(code);
      });
      setState(() {
        _decResult = result;
        _decError = null;
      });
    } catch (e) {
      setState(() {
        _decResult = '';
        _decError = 'Decode error: $e';
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
        title: const Text('HTML Entities'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Encode'), Tab(text: 'Decode')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Encode
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _encCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter text to encode…',
                  labelText: 'Plain text',
                ),
              ),
              SwitchListTile(
                value: _encodeAll,
                onChanged: (v) => setState(() => _encodeAll = v),
                title: const Text('Encode all special characters'),
                subtitle: const Text(
                    'Off: only mandatory (< > & " \')  •  On: also named + non-ASCII'),
                contentPadding: EdgeInsets.zero,
              ),
              FilledButton.icon(
                onPressed: _encode,
                icon: const Icon(Icons.code),
                label: const Text('Encode'),
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
                          _copy(context, _encResult, 'Encoded HTML'),
                    ),
                  ],
                ),
                SelectableText(_encResult,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13)),
              ],
            ],
          ),

          // Decode
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _decCtrl,
                maxLines: 5,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'Enter HTML entity text… (e.g. &lt;p&gt;&amp;nbsp;&lt;/p&gt;)',
                  labelText: 'HTML entities',
                ),
              ),
              const SizedBox(height: 12),
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
                          _copy(context, _decResult, 'Decoded text'),
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
