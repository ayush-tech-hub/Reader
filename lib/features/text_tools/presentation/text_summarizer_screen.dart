import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Extractive text summariser: ranks sentences by keyword frequency
/// and returns the top N as a summary.
class TextSummarizerScreen extends StatefulWidget {
  const TextSummarizerScreen({super.key});

  @override
  State<TextSummarizerScreen> createState() => _TextSummarizerScreenState();
}

// Common English stop-words to ignore in scoring
const _stopWords = {
  'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
  'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been',
  'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
  'could', 'should', 'may', 'might', 'shall', 'that', 'this', 'it', 'its',
  'as', 'if', 'not', 'no', 'nor', 'so', 'yet', 'both', 'either', 'neither',
  'each', 'every', 'all', 'any', 'such', 'more', 'most', 'other', 'than',
  'then', 'when', 'where', 'who', 'which', 'how', 'what', 'there', 'their',
  'they', 'we', 'he', 'she', 'you', 'i', 'me', 'my', 'our', 'your', 'his',
  'her', 'us', 'up', 'out', 'can', 'also', 'into', 'about', 'after', 'only',
};

List<String> _summarize(String text, int maxSentences) {
  // Split into sentences
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.length > 20)
      .toList();

  if (sentences.isEmpty) return [];
  if (sentences.length <= maxSentences) return sentences;

  // Build word frequency map (excluding stop-words)
  final freq = <String, int>{};
  for (final sent in sentences) {
    for (final word in sent
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))) {
      if (word.length > 2 && !_stopWords.contains(word)) {
        freq[word] = (freq[word] ?? 0) + 1;
      }
    }
  }

  if (freq.isEmpty) return sentences.take(maxSentences).toList();

  // Normalize frequencies
  final maxFreq = freq.values.reduce(max).toDouble();

  // Score each sentence
  final scores = sentences.map((sent) {
    final words = sent
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'));
    final score = words.fold<double>(
        0, (s, w) => s + (freq[w] ?? 0) / maxFreq);
    return score / max(1, words.length);
  }).toList();

  // Pick top sentences, preserve original order
  final indexed =
      List.generate(sentences.length, (i) => MapEntry(i, scores[i]));
  indexed.sort((a, b) => b.value.compareTo(a.value));
  final top = indexed.take(maxSentences).map((e) => e.key).toList()..sort();
  return top.map((i) => sentences[i]).toList();
}

class _TextSummarizerScreenState extends State<TextSummarizerScreen> {
  final _inputCtrl = TextEditingController();
  String _summary = '';
  int _sentenceCount = 3;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _run() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final result = _summarize(text, _sentenceCount);
    setState(() => _summary = result.join(' '));
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wordCount = _inputCtrl.text.trim().isEmpty
        ? 0
        : _inputCtrl.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Summariser'),
        actions: [
          if (_summary.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy summary',
                onPressed: _copy),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input
            Expanded(
              flex: 3,
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Paste text to summarise',
                  alignLabelWithHint: true,
                  suffixText: '$wordCount words',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Sentences in summary:'),
                Expanded(
                  child: Slider(
                    value: _sentenceCount.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_sentenceCount',
                    onChanged: (v) => setState(() => _sentenceCount = v.round()),
                  ),
                ),
                Text('$_sentenceCount'),
              ],
            ),
            FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.summarize),
              label: const Text('Summarise'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            if (_summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                flex: 2,
                child: Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Summary',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onPrimaryContainer)),
                            IconButton(
                              icon: Icon(Icons.copy,
                                  color: scheme.onPrimaryContainer),
                              iconSize: 18,
                              onPressed: _copy,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _summary,
                              style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  height: 1.6),
                            ),
                          ),
                        ),
                      ],
                    ),
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
