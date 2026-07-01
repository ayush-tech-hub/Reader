import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Computes several standard readability metrics on pasted text.
class ReadabilityScreen extends StatefulWidget {
  const ReadabilityScreen({super.key});

  @override
  State<ReadabilityScreen> createState() => _ReadabilityScreenState();
}

class _ReadabilityScreenState extends State<ReadabilityScreen> {
  final _ctrl = TextEditingController();
  _Metrics? _metrics;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _metrics = _Metrics.compute(text));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Readability Analyzer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste your text here…',
                labelText: 'Text',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analyze'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
            if (_metrics != null) ...[
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _CountRow(
                      'Characters', _metrics!.chars.toString(),
                      icon: Icons.abc, scheme: scheme),
                    _CountRow(
                      'Words', _metrics!.words.toString(),
                      icon: Icons.text_fields, scheme: scheme),
                    _CountRow(
                      'Sentences', _metrics!.sentences.toString(),
                      icon: Icons.short_text, scheme: scheme),
                    _CountRow(
                      'Syllables', _metrics!.syllables.toString(),
                      icon: Icons.record_voice_over_outlined, scheme: scheme),
                    _CountRow(
                      'Avg words / sentence',
                      _metrics!.avgWordsPerSentence.toStringAsFixed(1),
                      icon: Icons.straighten, scheme: scheme),
                    _CountRow(
                      'Avg syllables / word',
                      _metrics!.avgSyllablesPerWord.toStringAsFixed(2),
                      icon: Icons.speaker_notes_outlined, scheme: scheme),
                    const Divider(),
                    _ScoreCard(
                      title: 'Flesch Reading Ease',
                      score: _metrics!.fleschEase,
                      description: _metrics!.fleschEaseLabel,
                      low: 0, high: 100,
                      higherIsBetter: true,
                      scheme: scheme,
                    ),
                    _ScoreCard(
                      title: 'Flesch-Kincaid Grade',
                      score: _metrics!.fleschKincaidGrade,
                      description:
                          'Approx. US school grade level needed to understand',
                      low: 0, high: 20,
                      higherIsBetter: false,
                      scheme: scheme,
                    ),
                    _ScoreCard(
                      title: 'Gunning Fog Index',
                      score: _metrics!.gunningFog,
                      description:
                          'Years of formal education needed to read on first pass',
                      low: 0, high: 20,
                      higherIsBetter: false,
                      scheme: scheme,
                    ),
                    _ScoreCard(
                      title: 'SMOG Grade',
                      score: _metrics!.smog,
                      description:
                          'Years of education required to comprehend',
                      low: 0, high: 20,
                      higherIsBetter: false,
                      scheme: scheme,
                    ),
                    _ScoreCard(
                      title: 'Automated Readability Index',
                      score: _metrics!.ari,
                      description: 'Character-based grade-level estimate',
                      low: 0, high: 20,
                      higherIsBetter: false,
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

// ── Metrics ───────────────────────────────────────────────────────────────────

class _Metrics {
  const _Metrics._({
    required this.chars,
    required this.words,
    required this.sentences,
    required this.syllables,
    required this.fleschEase,
    required this.fleschKincaidGrade,
    required this.gunningFog,
    required this.smog,
    required this.ari,
  });

  final int chars;
  final int words;
  final int sentences;
  final int syllables;
  final double fleschEase;
  final double fleschKincaidGrade;
  final double gunningFog;
  final double smog;
  final double ari;

  double get avgWordsPerSentence =>
      sentences == 0 ? 0 : words / sentences;
  double get avgSyllablesPerWord =>
      words == 0 ? 0 : syllables / words;

  String get fleschEaseLabel {
    if (fleschEase >= 90) return 'Very easy (5th grade)';
    if (fleschEase >= 80) return 'Easy (6th grade)';
    if (fleschEase >= 70) return 'Fairly easy (7th grade)';
    if (fleschEase >= 60) return 'Standard (8th–9th grade)';
    if (fleschEase >= 50) return 'Fairly difficult (10th–12th grade)';
    if (fleschEase >= 30) return 'Difficult (college level)';
    return 'Very confusing (college graduate)';
  }

  factory _Metrics.compute(String text) {
    // chars (no spaces)
    final chars = text.replaceAll(' ', '').length;

    // sentences: end with . ! ?
    final sentenceMatches =
        RegExp(r'[.!?]+').allMatches(text).length;
    final sentences = max(1, sentenceMatches);

    // words
    final wordList =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final words = max(1, wordList.length);

    // syllables (English heuristic)
    int totalSyllables = 0;
    int complexWords = 0; // >=3 syllables for Gunning Fog
    for (final w in wordList) {
      final s = _countSyllables(w);
      totalSyllables += s;
      if (s >= 3) complexWords++;
    }
    final syllables = max(1, totalSyllables);

    final wps = words / sentences;
    final spw = syllables / words;

    final fke = 206.835 - 1.015 * wps - 84.6 * spw;
    final fkg = 0.39 * wps + 11.8 * spw - 15.59;
    final fog = 0.4 * (wps + 100 * complexWords / words);
    final smog = sentences >= 30
        ? 3 + sqrt(complexWords * 30 / sentences)
        : 3 + sqrt(complexWords.toDouble());
    final ari = 4.71 * (chars / words) + 0.5 * wps - 21.43;

    return _Metrics._(
      chars: chars,
      words: words,
      sentences: sentences,
      syllables: syllables,
      fleschEase: fke.clamp(0, 100),
      fleschKincaidGrade: fkg.clamp(0, 20),
      gunningFog: fog.clamp(0, 20),
      smog: smog.clamp(0, 20),
      ari: ari.clamp(0, 20),
    );
  }

  static int _countSyllables(String word) {
    word = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (word.isEmpty) return 0;
    if (word.length <= 3) return 1;
    word = word.replaceAll(RegExp(r'e$'), '');
    final matches = RegExp(r'[aeiouy]+').allMatches(word).length;
    return max(1, matches);
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _CountRow extends StatelessWidget {
  const _CountRow(this.label, this.value,
      {required this.icon, required this.scheme});

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: scheme.primary),
        title: Text(label),
        trailing: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.title,
    required this.score,
    required this.description,
    required this.low,
    required this.high,
    required this.higherIsBetter,
    required this.scheme,
  });

  final String title;
  final double score;
  final String description;
  final double low;
  final double high;
  final bool higherIsBetter;
  final ColorScheme scheme;

  Color _color() {
    final fraction = (score - low) / (high - low);
    if (higherIsBetter) {
      if (fraction >= 0.7) return Colors.green;
      if (fraction >= 0.4) return Colors.orange;
      return Colors.red;
    } else {
      if (fraction <= 0.3) return Colors.green;
      if (fraction <= 0.6) return Colors.orange;
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction = ((score - low) / (high - low)).clamp(0.0, 1.0);
    final color = _color();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(score.toStringAsFixed(1),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: higherIsBetter ? fraction : 1 - fraction,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(description,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
