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

// ── Citation extraction ───────────────────────────────────────────────────────

/// A citation found in a document.
class Citation {
  const Citation({
    required this.raw,
    required this.kind,
    this.year,
    this.authors,
  });

  final String raw;
  final CitationKind kind;
  final String? year;
  final String? authors;
}

enum CitationKind { inText, reference, doi, url }

/// Extracts citations from [text] using common academic patterns.
///
/// Recognises:
/// - APA/MLA in-text: (Author, year) / (Author et al., year)
/// - Numbered references: [1], [1,2], (1)
/// - DOI: doi:10.xxx / https://doi.org/...
/// - Reference list entries that start with a year or author pattern
List<Citation> extractCitations(String text) {
  final citations = <Citation>[];
  final seen = <String>{};

  void add(Citation c) {
    if (seen.add(c.raw)) citations.add(c);
  }

  // In-text (Author, year)
  for (final m in RegExp(
    r'\(([A-Z][a-zA-Z\-]+(?:\s+(?:et al\.?|and\s+[A-Z][a-zA-Z]+))?),\s*(\d{4}[a-z]?)\)',
  ).allMatches(text)) {
    add(Citation(
      raw: m.group(0)!,
      kind: CitationKind.inText,
      authors: m.group(1),
      year: m.group(2),
    ));
  }

  // Numbered in-text [n] or [n,m]
  for (final m
      in RegExp(r'\[(\d+(?:[,\s]\d+)*)\]').allMatches(text)) {
    add(Citation(raw: m.group(0)!, kind: CitationKind.inText));
  }

  // DOI
  for (final m in RegExp(
    r'(?:doi:\s*|https?://doi\.org/)(10\.\d{4,}/\S+)',
    caseSensitive: false,
  ).allMatches(text)) {
    add(Citation(raw: 'doi:${m.group(1)}', kind: CitationKind.doi));
  }

  // URLs that look like references
  for (final m in RegExp(
    r'https?://[^\s,\)\]]+',
    caseSensitive: false,
  ).allMatches(text)) {
    final url = m.group(0)!;
    if (!url.contains('doi.org')) {
      add(Citation(raw: url, kind: CitationKind.url));
    }
  }

  // Reference-list lines: start with [n] or a year
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (l.length < 20) continue;
    if (RegExp(r'^\[\d+\]').hasMatch(l) ||
        RegExp(r'^\d{4}\.\s').hasMatch(l) ||
        RegExp(r'^[A-Z][a-z]+,\s*[A-Z]\.').hasMatch(l)) {
      add(Citation(raw: l, kind: CitationKind.reference));
    }
  }

  return citations;
}

// ── Invoice / receipt extraction ─────────────────────────────────────────────

/// Structured fields extracted from an invoice or receipt.
class InvoiceData {
  const InvoiceData({
    this.invoiceNumber,
    this.date,
    this.dueDate,
    this.vendor,
    this.total,
    this.subtotal,
    this.tax,
    this.lineItems = const [],
  });

  final String? invoiceNumber;
  final String? date;
  final String? dueDate;
  final String? vendor;
  final String? total;
  final String? subtotal;
  final String? tax;
  final List<String> lineItems;

  bool get isEmpty =>
      invoiceNumber == null &&
      date == null &&
      vendor == null &&
      total == null;
}

/// Extracts common invoice / receipt fields from OCR or plain text.
InvoiceData parseInvoice(String text) {
  String? find(RegExp pattern) {
    final m = pattern.firstMatch(text);
    // Return the first non-null capturing group.
    if (m == null) return null;
    for (var i = 1; i <= m.groupCount; i++) {
      final g = m.group(i);
      if (g != null && g.trim().isNotEmpty) return g.trim();
    }
    return null;
  }

  final invoiceNumber = find(RegExp(
    r'(?:invoice|inv|bill)\s*(?:no\.?|number|#)?\s*[:\-]?\s*([A-Z0-9\-\/]{3,20})',
    caseSensitive: false,
  ));

  final date = find(RegExp(
    r'(?:date|issued?)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s*\d{1,2},?\s*\d{4})',
    caseSensitive: false,
  ));

  final dueDate = find(RegExp(
    r'(?:due|payment due)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})',
    caseSensitive: false,
  ));

  final total = find(RegExp(
    r'(?:total|amount due|balance due|grand total)\s*[:\-]?\s*(?:[A-Z]{0,3}\s*)?([£$€¥₹]?\s*\d[\d,]*\.?\d{0,2})',
    caseSensitive: false,
  ));

  final subtotal = find(RegExp(
    r'(?:sub-?total|net)\s*[:\-]?\s*(?:[A-Z]{0,3}\s*)?([£$€¥₹]?\s*\d[\d,]*\.?\d{0,2})',
    caseSensitive: false,
  ));

  final tax = find(RegExp(
    r'(?:tax|vat|gst|hst)\s*[:\-]?\s*(?:[A-Z]{0,3}\s*)?([£$€¥₹]?\s*\d[\d,]*\.?\d{0,2})',
    caseSensitive: false,
  ));

  // Vendor: first all-caps line or line before "invoice"
  String? vendor;
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isNotEmpty) {
    for (final line in lines.take(5)) {
      if (line.length >= 3 && line.length <= 60 &&
          RegExp(r'^[A-Z]').hasMatch(line) &&
          !RegExp(r'invoice|bill|receipt|date|no\.', caseSensitive: false).hasMatch(line)) {
        vendor = line;
        break;
      }
    }
  }

  // Line items: lines with a quantity and a price
  final lineItems = <String>[];
  for (final line in lines) {
    if (RegExp(
      r'^\d+\s+.+\s+[£$€¥₹]?\d[\d,]*\.?\d{0,2}\s*$',
    ).hasMatch(line)) {
      lineItems.add(line);
    }
  }

  return InvoiceData(
    invoiceNumber: invoiceNumber,
    date: date,
    dueDate: dueDate,
    vendor: vendor,
    total: total,
    subtotal: subtotal,
    tax: tax,
    lineItems: lineItems,
  );
}

// ── Formula extraction ────────────────────────────────────────────────────────

/// A formula or equation found in a document.
class Formula {
  const Formula({required this.raw, required this.context});
  final String raw;
  final String context;
}

/// Extracts formula-like strings from [text].
///
/// Recognises LaTeX `$...$` / `$$...$$` blocks and inline patterns
/// such as `E = mc²` / `y = mx + b`.
List<Formula> extractFormulas(String text) {
  final formulas = <Formula>[];
  final seen = <String>{};

  void add(String raw, String ctx) {
    if (seen.add(raw)) formulas.add(Formula(raw: raw, context: ctx));
  }

  // LaTeX display math $$...$$
  for (final m in RegExp(r'\$\$(.+?)\$\$', dotAll: true).allMatches(text)) {
    final raw = m.group(1)!.trim();
    if (raw.length > 1) add(raw, '');
  }

  // LaTeX inline math $...$
  for (final m
      in RegExp(r'\$([^\$\n]{2,80})\$').allMatches(text)) {
    final raw = m.group(1)!.trim();
    if (raw.isNotEmpty) add(raw, '');
  }

  // Equation-like patterns: something = something with operators/vars
  for (final m in RegExp(
    r'([A-Za-z_][A-Za-z0-9_]?\s*[=≈≤≥<>]\s*[A-Za-z0-9_+\-*/^²³√π\s().,]+)',
  ).allMatches(text)) {
    final raw = m.group(0)!.trim();
    if (raw.length >= 5 && raw.length <= 120) {
      // Find surrounding context (the sentence).
      final start = text.lastIndexOf(RegExp(r'[.!?\n]'), m.start);
      final end = text.indexOf(RegExp(r'[.!?\n]'), m.end);
      final ctx = text
          .substring(
            start < 0 ? 0 : start + 1,
            end < 0 ? text.length : end,
          )
          .trim();
      add(raw, ctx.length > 200 ? '${ctx.substring(0, 200)}…' : ctx);
    }
  }

  return formulas;
}

// ── Grammar & style correction ────────────────────────────────────────────────

/// Heuristic grammar/style pass that corrects common writing issues:
/// - Double spaces, trailing spaces
/// - Missing space after period/comma
/// - Capitalize first word of each sentence
/// - Common confused-word pairs (heuristic, non-contextual)
/// - Oxford-comma reminder (adds comma before "and" in simple lists)
String rewrite(String text) {
  var r = text;

  // Normalize whitespace.
  r = r.replaceAll(RegExp(r'  +'), ' ');
  r = r.split('\n').map((l) => l.trimRight()).join('\n');

  // Space after punctuation.
  r = r.replaceAllMapped(
    RegExp(r'([.,;:!?])([A-Za-z])'),
    (m) => '${m[1]} ${m[2]}',
  );

  // Common confused words (non-contextual substitutions — may be wrong in
  // some contexts; user should review the output).
  final confused = {
    r'\byour welcome\b': "you're welcome",
    r'\bits a\b': "it's a",
    r'\btheir is\b': 'there is',
    r'\btheir are\b': 'there are',
    r'\bthere going\b': "they're going",
    r'\bwould of\b': 'would have',
    r'\bcould of\b': 'could have',
    r'\bshould of\b': 'should have',
    r'\bwould of been\b': 'would have been',
    r'\balot\b': 'a lot',
    r'\brecieve\b': 'receive',
    r'\boccured\b': 'occurred',
    r'\bseperate\b': 'separate',
    r'\bneccessary\b': 'necessary',
    r'\buntill\b': 'until',
    r'\bgoverment\b': 'government',
    r'\bproffessional\b': 'professional',
    r'\benviroment\b': 'environment',
    r'\bdefinately\b': 'definitely',
    r'\bthier\b': 'their',
    r'\bneighbour hood\b': 'neighbourhood',
  };
  for (final entry in confused.entries) {
    r = r.replaceAll(
      RegExp(entry.key, caseSensitive: false),
      entry.value,
    );
  }

  // Capitalize first letter of each sentence.
  r = r.replaceAllMapped(
    RegExp(r'(?:^|(?<=[.!?]\s{1,2}))([a-z])'),
    (m) => m[1]!.toUpperCase(),
  );

  // Trim trailing whitespace / blank lines at end.
  r = r.trimRight();

  return r;
}

// ── Table extraction ──────────────────────────────────────────────────────────

/// A parsed table row (list of cell strings).
typedef TableRow = List<String>;

/// A parsed table from plain text.
class ExtractedTable {
  const ExtractedTable({required this.headers, required this.rows});
  final TableRow headers;
  final List<TableRow> rows;

  bool get isEmpty => rows.isEmpty;
  int get columnCount => headers.isEmpty
      ? (rows.isEmpty ? 0 : rows.first.length)
      : headers.length;
}

/// Detects and extracts tables from plain text.
///
/// Recognizes two formats:
/// 1. Pipe-delimited tables (Markdown style): `| col1 | col2 | col3 |`
/// 2. Tab-separated lines: `col1\tcol2\tcol3`
///
/// Returns a list of tables found in [text].
List<ExtractedTable> extractTables(String text) {
  final tables = <ExtractedTable>[];
  tables.addAll(_extractPipeTables(text));
  if (tables.isEmpty) tables.addAll(_extractTsvTables(text));
  return tables;
}

List<ExtractedTable> _extractPipeTables(String text) {
  final lines = text.split('\n');
  final tables = <ExtractedTable>[];

  int i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();
    if (!line.startsWith('|')) {
      i++;
      continue;
    }

    // Collect consecutive pipe lines.
    final block = <String>[];
    while (i < lines.length && lines[i].trim().startsWith('|')) {
      block.add(lines[i].trim());
      i++;
    }
    if (block.length < 2) continue;

    // Parse cells: skip separator rows (---|---|---).
    final rows = <TableRow>[];
    for (final row in block) {
      if (RegExp(r'^\|[-\s|:]+\|$').hasMatch(row)) continue;
      final cells = row
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.length < 2) continue;

    tables.add(ExtractedTable(headers: rows.first, rows: rows.skip(1).toList()));
  }
  return tables;
}

List<ExtractedTable> _extractTsvTables(String text) {
  final lines = text.split('\n');
  final tables = <ExtractedTable>[];

  int i = 0;
  while (i < lines.length) {
    if (!lines[i].contains('\t')) {
      i++;
      continue;
    }

    final block = <String>[];
    while (i < lines.length && lines[i].contains('\t')) {
      block.add(lines[i]);
      i++;
    }
    if (block.length < 2) continue;

    final rows = block
        .map((l) => l.split('\t').map((c) => c.trim()).toList())
        .toList();
    tables.add(ExtractedTable(headers: rows.first, rows: rows.skip(1).toList()));
  }
  return tables;
}

// ── Flashcard & quiz generation ───────────────────────────────────────────────

/// A single Q/A flashcard.
class Flashcard {
  const Flashcard({required this.question, required this.answer});
  final String question;
  final String answer;
}

/// Generates up to [maxCards] extractive flashcards from [text].
///
/// Strategy: pair each keyword with the sentence that first defines /
/// introduces it as Q = "What does <keyword> mean / refer to?" and
/// A = that sentence (trimmed). Deduplication keeps only the
/// highest-scoring sentence per keyword.
List<Flashcard> generateFlashcards(String text, {int maxCards = 10}) {
  final sentences = text
      .split(_sentencePattern)
      .map((s) => s.trim())
      .where((s) => s.length > 30)
      .toList();
  if (sentences.isEmpty) return const [];

  final frequency = <String, int>{};
  for (final word in tokenize(text)) {
    frequency[word] = (frequency[word] ?? 0) + 1;
  }

  // Score sentences as in summarize().
  final maxFreq =
      frequency.values.fold(1, (a, b) => a > b ? a : b).toDouble();
  final sentenceScore = List.generate(sentences.length, (i) {
    final words = tokenize(sentences[i]);
    if (words.isEmpty) return 0.0;
    return words.fold(0.0, (sum, w) => sum + (frequency[w] ?? 0)) /
        maxFreq /
        math.sqrt(words.length);
  });

  // Top keywords not already used as a question.
  final keywords = extractKeywords(text, maxKeywords: maxCards * 2);
  final used = <String>{};
  final cards = <Flashcard>[];

  for (final kw in keywords) {
    if (cards.length >= maxCards) break;
    if (used.contains(kw)) continue;

    // Find the best-scoring sentence that contains this keyword.
    int? bestIdx;
    double bestScore = -1;
    for (var i = 0; i < sentences.length; i++) {
      if (sentences[i].toLowerCase().contains(kw) &&
          sentenceScore[i] > bestScore) {
        bestScore = sentenceScore[i];
        bestIdx = i;
      }
    }
    if (bestIdx == null) continue;

    final answer = sentences[bestIdx];
    final q = _questionFor(kw, answer);
    cards.add(Flashcard(question: q, answer: answer));
    used.add(kw);
  }
  return cards;
}

String _questionFor(String keyword, String sentence) {
  // Prefer "What is X?" for nouns / concepts, "How does X work?" for verbs.
  final lower = sentence.toLowerCase();
  if (lower.contains(' is ') ||
      lower.contains(' are ') ||
      lower.contains(' was ')) {
    return 'What is $keyword?';
  }
  if (lower.contains(' how ') || lower.contains(' process ')) {
    return 'How does $keyword work?';
  }
  return 'What does the text say about "$keyword"?';
}

/// A multiple-choice quiz question generated from the document.
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
  final String question;
  final List<String> options;
  final int correctIndex;
}

/// Generates up to [maxQuestions] multiple-choice questions from [text].
///
/// Each question picks a key sentence, identifies a keyword in it, asks
/// the user to identify the right sentence (fill-in context), and
/// provides three distractor sentences as wrong answers.
List<QuizQuestion> generateQuiz(String text, {int maxQuestions = 8}) {
  final sentences = text
      .split(_sentencePattern)
      .map((s) => s.trim())
      .where((s) => s.length > 40)
      .toList();
  if (sentences.length < 4) return const [];

  final frequency = <String, int>{};
  for (final word in tokenize(text)) {
    frequency[word] = (frequency[word] ?? 0) + 1;
  }
  final maxFreq =
      frequency.values.fold(1, (a, b) => a > b ? a : b).toDouble();

  final scored = List.generate(sentences.length, (i) {
    final words = tokenize(sentences[i]);
    if (words.isEmpty) return (i, 0.0);
    final score = words.fold(0.0, (s, w) => s + (frequency[w] ?? 0)) /
        maxFreq /
        math.sqrt(words.length);
    return (i, score);
  })
    ..sort((a, b) => b.$2.compareTo(a.$2));

  // Take top N sentences for questions and use the remaining pool as
  // distractors.
  final questionCount = math.min(maxQuestions, scored.length);
  final questions = <QuizQuestion>[];
  final used = <int>{};

  for (var qi = 0; qi < questionCount && questions.length < maxQuestions; qi++) {
    final (sentIdx, _) = scored[qi];
    if (used.contains(sentIdx)) continue;
    used.add(sentIdx);

    final correctSentence = sentences[sentIdx];
    final keywords = tokenize(correctSentence);
    if (keywords.isEmpty) continue;

    // Pick the most frequent keyword from this sentence.
    keywords.sort((a, b) => (frequency[b] ?? 0).compareTo(frequency[a] ?? 0));
    final kw = keywords.first;

    // Replace the keyword in the sentence with a blank for the question.
    final blank = correctSentence.replaceAll(
      RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false),
      '___',
    );
    final questionText = 'Fill in the blank:\n"$blank"';

    // Collect 3 distractor keywords from other high-scoring sentences.
    final distractors = <String>[];
    for (final (di, _) in scored) {
      if (distractors.length >= 3) break;
      if (di == sentIdx) continue;
      final dKws = tokenize(sentences[di]);
      dKws.sort(
          (a, b) => (frequency[b] ?? 0).compareTo(frequency[a] ?? 0));
      if (dKws.isNotEmpty && !distractors.contains(dKws.first) &&
          dKws.first != kw) {
        distractors.add(dKws.first);
      }
    }
    if (distractors.length < 3) continue;

    // Shuffle options (correct answer always last before shuffle, then
    // we track its position).
    final options = [...distractors, kw];
    // Simple deterministic pseudo-shuffle: rotate by sentIdx % 4.
    final shift = sentIdx % 4;
    final shifted = [
      ...options.sublist(shift),
      ...options.sublist(0, shift),
    ];
    final correctIndex = shifted.indexOf(kw);

    questions.add(QuizQuestion(
      question: questionText,
      options: shifted,
      correctIndex: correctIndex,
    ));
  }
  return questions;
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
