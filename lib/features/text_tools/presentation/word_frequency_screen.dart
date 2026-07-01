import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Analyses word frequency in pasted text.
///
/// Shows top-N most frequent words, excludes common stop words by default,
/// and displays a simple bar chart of the top 10 words.
class WordFrequencyScreen extends StatefulWidget {
  const WordFrequencyScreen({super.key});

  @override
  State<WordFrequencyScreen> createState() => _WordFrequencyScreenState();
}

class _WordFrequencyScreenState extends State<WordFrequencyScreen> {
  final _ctrl = TextEditingController();
  List<MapEntry<String, int>> _top = [];
  bool _excludeStopWords = true;
  bool _analysed = false;

  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to',
    'for', 'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through',
    'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has',
    'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should',
    'may', 'might', 'shall', 'can', 'not', 'no', 'if', 'as', 'it',
    'its', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she',
    'we', 'they', 'my', 'your', 'his', 'her', 'our', 'their', 'me',
    'him', 'us', 'them', 'what', 'which', 'who', 'when', 'where', 'how',
    'all', 'also', 'so', 'just', 'than', 'then', 'more', 'very', 'well',
  };

  void _analyse() {
    final text = _ctrl.text.toLowerCase();
    final words = RegExp(r"[a-z']+").allMatches(text)
        .map((m) => m.group(0)!)
        .where((w) => w.length > 1)
        .where((w) => !_excludeStopWords || !_stopWords.contains(w))
        .toList();

    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _top = sorted.take(50).toList();
      _analysed = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = _top.isEmpty ? 1 : _top.first.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Frequency'),
        actions: [
          if (_top.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy as CSV',
              onPressed: () {
                final csv = _top
                    .map((e) => '${e.key},${e.value}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: 'word,count\n$csv'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Options & input area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Exclude common stop words'),
                  value: _excludeStopWords,
                  onChanged: (v) => setState(() => _excludeStopWords = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Paste text to analyse…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.paste_outlined),
                      label: const Text('Paste'),
                      onPressed: () async {
                        final d = await Clipboard.getData('text/plain');
                        if (d?.text != null) _ctrl.text = d!.text!;
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Analyse'),
                        onPressed: _ctrl.text.isNotEmpty ? _analyse : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_analysed && _top.isEmpty)
            const Expanded(
              child: Center(child: Text('No words found.')),
            )
          else if (_top.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('${_top.length} unique words',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _top.length,
                itemBuilder: (context, i) {
                  final entry = _top[i];
                  final fraction = entry.value / maxCount;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: LinearProgressIndicator(
                            value: fraction,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: i < 3
                                ? scheme.primary
                                : scheme.primary.withOpacity(0.55),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${entry.value}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
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
