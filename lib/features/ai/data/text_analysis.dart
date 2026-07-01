import 'dart:math' as math;

/// Pure-Dart, fully offline text analytics: extractive summarization
/// and TF-IDF ranking. No model download required — this is the
/// always-available baseline; a heavier on-device LLM can be plugged
/// in behind [LocalAiBackend] later.
const Set<String> _stopwords = {
  'the',
  'a',
  'an',
  'and',
  'or',
  'but',
  'if',
  'of',
  'at',
  'by',
  'for',
  'with',
  'about',
  'to',
  'from',
  'in',
  'on',
  'is',
  'are',
  'was',
  'were',
  'be',
  'been',
  'it',
  'its',
  'this',
  'that',
  'these',
  'those',
  'as',
  'not',
  'no',
  'so',
  'than',
  'then',
  'there',
  'their',
  'they',
  'them',
  'he',
  'she',
  'his',
  'her',
  'we',
  'you',
  'your',
  'our',
  'i',
  'me',
  'my',
  'have',
  'has',
  'had',
  'do',
  'does',
  'did',
  'will',
  'would',
  'can',
  'could',
  'should',
  'may',
  'might',
  'into',
  'over',
  'under',
  'all',
  'any',
  'each',
  'more',
  'most',
  'other',
  'some',
  'such',
  'only',
  'own',
  'same',
  'too',
  'very',
  'also',
  'which',
  'what',
  'when',
  'where',
  'who',
  'how',
  'why',
  'up',
  'out',
};

final _wordPattern = RegExp(r"[a-zA-ZÀ-ɏ0-9']+");
final _sentencePattern = RegExp(r'(?<=[.!?])\s+');

List<String> tokenize(String text) => _wordPattern
    .allMatches(text.toLowerCase())
    .map((m) => m.group(0)!)
    .where((w) => w.length > 1 && !_stopwords.contains(w))
    .toList();

/// Frequency-based extractive summary: scores sentences by normalized
/// term frequency and returns the top [maxSentences] in document order.
String summarize(String text, {int maxSentences = 5}) {
  final sentences = text
      .split(_sentencePattern)
      .map((s) => s.trim())
      .where((s) => s.length > 20)
      .toList();
  if (sentences.length <= maxSentences) return sentences.join(' ');

  final frequency = <String, int>{};
  for (final word in tokenize(text)) {
    frequency[word] = (frequency[word] ?? 0) + 1;
  }
  final maxFrequency =
      frequency.values.fold(1, (a, b) => a > b ? a : b).toDouble();

  final scored = <(int index, double score)>[];
  for (var i = 0; i < sentences.length; i++) {
    final words = tokenize(sentences[i]);
    if (words.isEmpty) continue;
    final score = words.fold(0.0, (sum, w) => sum + (frequency[w] ?? 0)) /
        maxFrequency /
        math.sqrt(words.length);
    scored.add((i, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final picked = scored.take(maxSentences).map((e) => e.$1).toList()..sort();
  return picked.map((i) => sentences[i]).join(' ');
}

/// TF-IDF cosine ranking of [documents] against [query]. Returns
/// document indices with scores, best first. Used to rerank FTS
/// candidates for semantic-style search and assistant retrieval.
List<(int index, double score)> rankByTfIdf(
  String query,
  List<String> documents,
) {
  final queryTerms = tokenize(query);
  if (queryTerms.isEmpty || documents.isEmpty) return const [];

  final docTokens = [for (final d in documents) tokenize(d)];
  final docFrequency = <String, int>{};
  for (final tokens in docTokens) {
    for (final term in tokens.toSet()) {
      docFrequency[term] = (docFrequency[term] ?? 0) + 1;
    }
  }
  double idf(String term) =>
      math.log((documents.length + 1) / ((docFrequency[term] ?? 0) + 1)) + 1;

  final queryVector = <String, double>{};
  for (final term in queryTerms) {
    queryVector[term] = (queryVector[term] ?? 0) + idf(term);
  }
  final queryNorm = math.sqrt(
    queryVector.values.fold(0.0, (s, v) => s + v * v),
  );

  final results = <(int, double)>[];
  for (var i = 0; i < documents.length; i++) {
    final termFrequency = <String, double>{};
    for (final term in docTokens[i]) {
      termFrequency[term] = (termFrequency[term] ?? 0) + idf(term);
    }
    var dot = 0.0;
    var docNorm = 0.0;
    termFrequency.forEach((term, weight) {
      docNorm += weight * weight;
      dot += weight * (queryVector[term] ?? 0);
    });
    if (dot > 0) {
      results.add((i, dot / (math.sqrt(docNorm) * queryNorm)));
    }
  }
  results.sort((a, b) => b.$2.compareTo(a.$2));
  return results;
}

// ── Keyword extraction ────────────────────────────────────────────────────────

/// Returns the top [maxKeywords] keywords from [text] by term-frequency
/// (unique words, stop-words removed, normalized to lower-case).
List<String> extractKeywords(String text, {int maxKeywords = 10}) {
  final words = tokenize(text);
  final freq = <String, int>{};
  for (final w in words) {
    freq[w] = (freq[w] ?? 0) + 1;
  }
  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(maxKeywords).map((e) => e.key).toList();
}

// ── Extractive bullet points ──────────────────────────────────────────────────

/// Summarizes [text] as a bulleted list with at most [maxPoints] items.
/// Each point is the highest-scoring sentence not yet included.
String extractBulletPoints(String text, {int maxPoints = 7}) {
  final sentences = text
      .split(_sentencePattern)
      .map((s) => s.trim())
      .where((s) => s.length > 20)
      .toList();
  if (sentences.isEmpty) return '';

  final frequency = <String, int>{};
  for (final word in tokenize(text)) {
    frequency[word] = (frequency[word] ?? 0) + 1;
  }
  final maxFrequency =
      frequency.values.fold(1, (a, b) => a > b ? a : b).toDouble();

  final scored = <(int index, double score)>[];
  for (var i = 0; i < sentences.length; i++) {
    final words = tokenize(sentences[i]);
    if (words.isEmpty) continue;
    final score = words.fold(0.0, (sum, w) => sum + (frequency[w] ?? 0)) /
        maxFrequency /
        math.sqrt(words.length);
    scored.add((i, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final picked = scored.take(maxPoints).map((e) => e.$1).toList()..sort();
  return picked.map((i) => '• ${sentences[i]}').join('\n');
}

// ── Text simplification ───────────────────────────────────────────────────────

/// Returns a simplified version of [text] by:
/// - Replacing common complex words with simpler alternatives
/// - Breaking very long sentences at coordinating conjunctions
///
/// This is a heuristic, offline, zero-model approach — not NLU-based.
String simplify(String text) {
  var result = text;

  // Vocabulary substitutions: complex → simple.
  final substitutions = {
    'utilize': 'use',
    'utilise': 'use',
    'demonstrate': 'show',
    'implementation': 'use',
    'approximately': 'about',
    'additionally': 'also',
    'subsequently': 'then',
    'consequently': 'so',
    'notwithstanding': 'despite',
    'facilitate': 'help',
    'endeavour': 'try',
    'endeavor': 'try',
    'commence': 'start',
    'terminate': 'end',
    'sufficient': 'enough',
    'insufficient': 'not enough',
    'obtain': 'get',
    'acquire': 'get',
    'require': 'need',
    'regarding': 'about',
    'concerning': 'about',
    'however': 'but',
    'therefore': 'so',
    'furthermore': 'also',
    'moreover': 'also',
    'nevertheless': 'but',
    'prior to': 'before',
    'in order to': 'to',
    'in the event that': 'if',
    'at the present time': 'now',
    'in the near future': 'soon',
    'due to the fact that': 'because',
    'in spite of the fact that': 'although',
  };
  for (final entry in substitutions.entries) {
    result = result.replaceAll(
      RegExp(r'\b' + entry.key + r'\b', caseSensitive: false),
      entry.value,
    );
  }

  // Break very long sentences (> 40 words) at " and " / " but " / " which ".
  final sentences = result.split(_sentencePattern);
  final simplified = <String>[];
  for (final sent in sentences) {
    final words = sent.split(' ');
    if (words.length <= 30) {
      simplified.add(sent);
    } else {
      // Try to break at conjunctions.
      final breakPoints = [' and ', ' but ', ' which ', ' although ', ' because '];
      var broken = false;
      for (final bp in breakPoints) {
        final idx = sent.toLowerCase().lastIndexOf(bp);
        if (idx > sent.length ~/ 3 && idx < sent.length * 2 ~/ 3) {
          final first = sent.substring(0, idx).trimRight();
          final second = sent.substring(idx + bp.length).trimLeft();
          final conjunction = bp.trim();
          simplified.add(first + '.');
          simplified.add(
            '${conjunction[0].toUpperCase()}${conjunction.substring(1)} $second',
          );
          broken = true;
          break;
        }
      }
      if (!broken) simplified.add(sent);
    }
  }
  return simplified.join(' ').trim();
}

// ── Hook for optional heavier model ──────────────────────────────────────────

/// Hook for an optional heavier on-device model (e.g. a GGUF LLM via a
/// platform channel). When registered, AI screens prefer it and fall
/// back to the extractive baseline.
abstract interface class LocalAiBackend {
  Future<String> summarize(String text);
  Future<String> answer(String question, List<String> contextPassages);
}

LocalAiBackend? registeredAiBackend;
