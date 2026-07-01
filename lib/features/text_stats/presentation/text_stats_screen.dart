import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Analyzes any text for readability, word/sentence/syllable counts,
/// and Flesch-Kincaid reading ease & grade level scores.
class TextStatsScreen extends StatefulWidget {
  const TextStatsScreen({super.key, this.initialText});

  final String? initialText;

  @override
  State<TextStatsScreen> createState() => _TextStatsScreenState();
}

class _TextStatsScreenState extends State<TextStatsScreen> {
  final _ctrl = TextEditingController();
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _ctrl.text = widget.initialText!;
      _analyze(widget.initialText!);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _analyze(String text) {
    if (text.trim().isEmpty) {
      setState(() => _stats = null);
      return;
    }
    setState(() => _stats = _Stats.compute(text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text statistics'),
        actions: [
          if (_stats != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy report',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _stats!.report()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report copied')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Paste or type text here…',
                border: OutlineInputBorder(),
              ),
              onChanged: _analyze,
            ),
          ),
          if (_stats != null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _StatsCard(stats: _stats!),
                  const SizedBox(height: 12),
                  _ReadabilityCard(stats: _stats!),
                  const SizedBox(height: 12),
                  _FreqCard(stats: _stats!),
                ],
              ),
            ),
          if (_stats == null)
            const Expanded(
              child: Center(
                child: Text('Type or paste text above to see statistics.'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stats model ───────────────────────────────────────────────────────────────

class _Stats {
  const _Stats({
    required this.charCount,
    required this.charNoSpaces,
    required this.wordCount,
    required this.sentenceCount,
    required this.paragraphCount,
    required this.syllableCount,
    required this.avgWordsPerSentence,
    required this.avgSyllablesPerWord,
    required this.fleschEase,
    required this.fleschKincaidGrade,
    required this.topWords,
    required this.estimatedReadingMins,
  });

  final int charCount;
  final int charNoSpaces;
  final int wordCount;
  final int sentenceCount;
  final int paragraphCount;
  final int syllableCount;
  final double avgWordsPerSentence;
  final double avgSyllablesPerWord;
  final double fleschEase;
  final double fleschKincaidGrade;
  final List<(String word, int count)> topWords;
  final double estimatedReadingMins;

  factory _Stats.compute(String text) {
    final charCount = text.length;
    final charNoSpaces = text.replaceAll(' ', '').length;

    final words = text
        .toLowerCase()
        .split(RegExp(r"[^a-zA-Z']+"))
        .where((w) => w.length > 1)
        .toList();
    final wordCount = words.length;

    final sentences = text
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .length;
    final sentenceCount = sentences.clamp(1, 999999);

    final paragraphs = text
        .split(RegExp(r'\n\n+'))
        .where((p) => p.trim().isNotEmpty)
        .length;

    int syllables = 0;
    for (final word in words) {
      syllables += _countSyllables(word);
    }

    final wps =
        wordCount / sentenceCount.toDouble();
    final spw = wordCount > 0 ? syllables / wordCount.toDouble() : 0.0;

    // Flesch Reading Ease = 206.835 − 1.015(wps) − 84.6(spw)
    final ease = 206.835 - 1.015 * wps - 84.6 * spw;
    // Flesch-Kincaid Grade = 0.39(wps) + 11.8(spw) - 15.59
    final grade = 0.39 * wps + 11.8 * spw - 15.59;

    // Top 10 words (excluding common stop words).
    final freq = <String, int>{};
    for (final w in words) {
      if (!_kStop.contains(w)) freq[w] = (freq[w] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWords =
        sorted.take(10).map((e) => (e.key, e.value)).toList();

    return _Stats(
      charCount: charCount,
      charNoSpaces: charNoSpaces,
      wordCount: wordCount,
      sentenceCount: sentenceCount,
      paragraphCount: paragraphs,
      syllableCount: syllables,
      avgWordsPerSentence: double.parse(wps.toStringAsFixed(1)),
      avgSyllablesPerWord: double.parse(spw.toStringAsFixed(2)),
      fleschEase: ease.clamp(0, 100),
      fleschKincaidGrade: grade.clamp(0, 20),
      topWords: topWords,
      estimatedReadingMins: wordCount / 200,
    );
  }

  static int _countSyllables(String word) {
    if (word.isEmpty) return 0;
    word = word.toLowerCase();
    if (word.length <= 3) return 1;
    word = word.replaceAll(RegExp(r'e$'), '');
    final vowels = RegExp(r'[aeiouy]+');
    final count = vowels.allMatches(word).length;
    return count.clamp(1, 999);
  }

  String fleschLabel() {
    if (fleschEase >= 90) return 'Very easy (5th grade)';
    if (fleschEase >= 80) return 'Easy (6th grade)';
    if (fleschEase >= 70) return 'Fairly easy (7th grade)';
    if (fleschEase >= 60) return 'Standard (8th–9th grade)';
    if (fleschEase >= 50) return 'Fairly difficult (10th–12th grade)';
    if (fleschEase >= 30) return 'Difficult (college)';
    return 'Very difficult (professional)';
  }

  String report() => [
        'Text Statistics',
        '═══════════════',
        'Characters: $charCount ($charNoSpaces without spaces)',
        'Words: $wordCount',
        'Sentences: $sentenceCount',
        'Paragraphs: $paragraphCount',
        'Avg words/sentence: $avgWordsPerSentence',
        '',
        'Readability',
        '───────────',
        'Flesch Reading Ease: ${fleschEase.toStringAsFixed(1)} (${fleschLabel()})',
        'Flesch-Kincaid Grade: ${fleschKincaidGrade.toStringAsFixed(1)}',
        'Estimated reading time: ${estimatedReadingMins.toStringAsFixed(1)} min',
        '',
        'Top words: ${topWords.map((t) => '${t.$1}(${t.$2})').join(', ')}',
      ].join('\n');

  static const _kStop = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to',
    'for', 'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were',
    'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
    'would', 'could', 'should', 'may', 'might', 'it', 'its', 'this',
    'that', 'these', 'those', 'i', 'you', 'he', 'she', 'we', 'they',
    'as', 'if', 'not', 'so', 'up', 'out', 'about', 'into', 'than',
    'then', 'when', 'which', 'who', 'what', 'how', 'all', 'more',
    'also', 'can', 'his', 'her', 'their', 'our', 'your', 'my',
  };
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Counts', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _Metric('Characters', stats.charCount.toString()),
                _Metric('No spaces', stats.charNoSpaces.toString()),
                _Metric('Words', stats.wordCount.toString()),
                _Metric('Sentences', stats.sentenceCount.toString()),
                _Metric('Paragraphs', stats.paragraphCount.toString()),
                _Metric('Syllables', stats.syllableCount.toString()),
                _Metric('Words/sentence',
                    stats.avgWordsPerSentence.toString()),
                _Metric('Syllables/word',
                    stats.avgSyllablesPerWord.toString()),
                _Metric('Read time',
                    '~${stats.estimatedReadingMins.toStringAsFixed(1)} min'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadabilityCard extends StatelessWidget {
  const _ReadabilityCard({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ease = stats.fleschEase;
    final easeColor = ease >= 60
        ? Colors.green
        : ease >= 40
            ? Colors.orange
            : scheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Readability',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flesch Reading Ease',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              )),
                      Text(
                        ease.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: easeColor,
                        ),
                      ),
                      Text(stats.fleschLabel(),
                          style: TextStyle(color: easeColor, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grade Level',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                              )),
                      Text(
                        stats.fleschKincaidGrade.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Flesch-Kincaid',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: ease / 100,
              backgroundColor: scheme.surfaceContainerHighest,
              color: easeColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreqCard extends StatelessWidget {
  const _FreqCard({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.topWords.isEmpty) return const SizedBox.shrink();
    final max = stats.topWords.first.$2.toDouble();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top words',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final (word, count) in stats.topWords)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(word,
                          style: const TextStyle(fontFamily: 'monospace')),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: count / max,
                        backgroundColor: scheme.surfaceContainerHighest,
                        minHeight: 14,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  )),
        ],
      ),
    );
  }
}
