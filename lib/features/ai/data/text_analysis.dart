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
  final maxFrequency = frequency.values
      .fold(1, (a, b) => a > b ? a : b)
      .toDouble();

  final scored = <(int index, double score)>[];
  for (var i = 0; i < sentences.length; i++) {
    final words = tokenize(sentences[i]);
    if (words.isEmpty) continue;
    final score =
        words.fold(0.0, (sum, w) => sum + (frequency[w] ?? 0)) /
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

/// Hook for an optional heavier on-device model (e.g. a GGUF LLM via a
/// platform channel). When registered, AI screens prefer it and fall
/// back to the extractive baseline.
abstract interface class LocalAiBackend {
  Future<String> summarize(String text);
  Future<String> answer(String question, List<String> contextPassages);
}

LocalAiBackend? registeredAiBackend;
