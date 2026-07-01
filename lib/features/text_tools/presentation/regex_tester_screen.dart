import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive regex tester with match highlighting.
///
/// - Global (find all) and first-match modes
/// - Case-insensitive and multiline flags
/// - Highlights each match in a different accent colour
/// - Shows captured groups per match in an expandable tile
class RegexTesterScreen extends StatefulWidget {
  const RegexTesterScreen({super.key});

  @override
  State<RegexTesterScreen> createState() => _RegexTesterScreenState();
}

class _RegexTesterScreenState extends State<RegexTesterScreen> {
  final _patternCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  List<RegExpMatch> _matches = [];
  String? _error;
  bool _caseInsensitive = false;
  bool _multiLine = false;
  bool _dotAll = false;
  bool _globalMode = true;

  static const _matchColors = [
    Color(0xFFFFD700),
    Color(0xFF90EE90),
    Color(0xFFADD8E6),
    Color(0xFFFFB6C1),
    Color(0xFFDDA0DD),
  ];

  void _run() {
    final pattern = _patternCtrl.text;
    final text = _textCtrl.text;
    if (pattern.isEmpty) {
      setState(() {
        _matches = [];
        _error = null;
      });
      return;
    }
    try {
      final rx = RegExp(
        pattern,
        caseSensitive: !_caseInsensitive,
        multiLine: _multiLine,
        dotAll: _dotAll,
      );
      final matches = _globalMode
          ? rx.allMatches(text).toList()
          : [if (rx.firstMatch(text) case final m when m != null) m];
      setState(() {
        _matches = matches;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _matches = [];
        _error = e.message;
      });
    }
  }

  List<TextSpan> _buildSpans(String text) {
    if (_matches.isEmpty) return [TextSpan(text: text)];

    final spans = <TextSpan>[];
    int cursor = 0;
    for (var i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      final color = _matchColors[i % _matchColors.length];
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: TextStyle(
          backgroundColor: color.withOpacity(0.5),
          fontWeight: FontWeight.bold,
        ),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _textCtrl.text;

    return Scaffold(
      appBar: AppBar(title: const Text('Regex Tester')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pattern bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                const Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
                Expanded(
                  child: TextField(
                    controller: _patternCtrl,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'pattern',
                      border: InputBorder.none,
                      errorText: _error,
                    ),
                    onChanged: (_) => _run(),
                  ),
                ),
                Text(
                  '/${[
                    if (_caseInsensitive) 'i',
                    if (_multiLine) 'm',
                    if (_dotAll) 's',
                    if (_globalMode) 'g',
                  ].join()}',
                  style: const TextStyle(
                      fontSize: 20, color: Colors.grey, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

          // Flags
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: const Text('i – case insensitive'),
                  selected: _caseInsensitive,
                  onSelected: (v) {
                    setState(() => _caseInsensitive = v);
                    _run();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('m – multiline'),
                  selected: _multiLine,
                  onSelected: (v) {
                    setState(() => _multiLine = v);
                    _run();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('s – dot-all'),
                  selected: _dotAll,
                  onSelected: (v) {
                    setState(() => _dotAll = v);
                    _run();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                FilterChip(
                  label: const Text('g – global'),
                  selected: _globalMode,
                  onSelected: (v) {
                    setState(() => _globalMode = v);
                    _run();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Test text input
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Test string',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary)),
                      const Spacer(),
                      if (_matches.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_matches.length} match${_matches.length == 1 ? '' : 'es'}',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Enter text to test against…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _run(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Highlighted result
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matches highlighted',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.outline.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                        color: scheme.surfaceContainerLowest,
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText.rich(
                          TextSpan(
                            children: _buildSpans(text),
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Match details
          if (_matches.isNotEmpty) ...[
            const Divider(height: 1),
            SizedBox(
              height: 120,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _matches.length,
                itemBuilder: (context, i) {
                  final m = _matches[i];
                  final color =
                      _matchColors[i % _matchColors.length].withOpacity(0.4);
                  final groups = List.generate(
                      m.groupCount, (g) => m.group(g + 1) ?? '(null)');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '#${i + 1} [${m.start}–${m.end}]  ',
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            '"${text.substring(m.start, m.end)}"'
                            '${groups.isNotEmpty ? '  groups: ${groups.join(', ')}' : ''}',
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: text.substring(m.start, m.end)));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
