import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bulk find-and-replace on pasted text with regex and case options.
class FindReplaceScreen extends StatefulWidget {
  const FindReplaceScreen({super.key});

  @override
  State<FindReplaceScreen> createState() => _FindReplaceScreenState();
}

class _FindReplaceScreenState extends State<FindReplaceScreen> {
  final _inputCtrl = TextEditingController();
  final _findCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();

  bool _useRegex = false;
  bool _caseSensitive = true;
  bool _wholeWord = false;

  String _result = '';
  int _count = 0;
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    super.dispose();
  }

  void _replace() {
    final input = _inputCtrl.text;
    final findStr = _findCtrl.text;
    if (findStr.isEmpty) return;

    try {
      RegExp pattern;
      if (_useRegex) {
        pattern = RegExp(
          _wholeWord ? r'\b' + findStr + r'\b' : findStr,
          caseSensitive: _caseSensitive,
          multiLine: true,
        );
      } else {
        pattern = RegExp(
          _wholeWord
              ? r'\b' + RegExp.escape(findStr) + r'\b'
              : RegExp.escape(findStr),
          caseSensitive: _caseSensitive,
          multiLine: true,
        );
      }

      int count = 0;
      final result = input.replaceAllMapped(pattern, (m) {
        count++;
        return _replaceCtrl.text;
      });

      setState(() {
        _result = result;
        _count = count;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _result = '';
        _count = 0;
        _error = 'Regex error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Find & Replace')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Text',
                hintText: 'Paste your text here…',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _findCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: _useRegex ? 'Find (regex)' : 'Find',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replaceCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText:
                    _useRegex ? 'Replace (use \$1, \$2 for groups)' : 'Replace with',
                isDense: true,
                prefixIcon: const Icon(Icons.find_replace, size: 18),
              ),
            ),
            const SizedBox(height: 8),

            // Option chips
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Regex'),
                  selected: _useRegex,
                  onSelected: (v) => setState(() => _useRegex = v),
                ),
                FilterChip(
                  label: const Text('Case sensitive'),
                  selected: _caseSensitive,
                  onSelected: (v) => setState(() => _caseSensitive = v),
                ),
                FilterChip(
                  label: const Text('Whole word'),
                  selected: _wholeWord,
                  onSelected: (v) => setState(() => _wholeWord = v),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _replace,
              icon: const Icon(Icons.find_replace),
              label: const Text('Replace All'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),

            if (_result.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _count > 0
                          ? Colors.green.withOpacity(0.1)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_count replacement${_count == 1 ? '' : 's'} made',
                      style: TextStyle(
                          fontSize: 12,
                          color: _count > 0 ? Colors.green : null),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    tooltip: 'Use as input',
                    onPressed: () {
                      _inputCtrl.text = _result;
                      setState(() {
                        _result = '';
                        _count = 0;
                      });
                    },
                  ),
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
                  child: SelectableText(_result,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
