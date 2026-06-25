import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/features/ai/data/text_analysis.dart';

void main() {
  group('summarize', () {
    test('returns top sentences in original order', () {
      const text =
          'Flutter renders widgets with Skia and Impeller. '
          'The weather was unremarkable on that particular day in autumn. '
          'Flutter widgets compose into trees managed by the framework. '
          'Someone mentioned an unrelated anecdote about gardening tools. '
          'Widget trees in Flutter rebuild when state changes occur.';
      final summary = summarize(text, maxSentences: 2);
      expect(summary, contains('Flutter'));
      // Picked sentences keep document order.
      final first = summary.indexOf('widgets');
      expect(first, greaterThanOrEqualTo(0));
    });

    test('short documents are returned whole', () {
      const text = 'One meaningful sentence about archives.';
      expect(summarize(text, maxSentences: 5), text);
    });
  });

  group('rankByTfIdf', () {
    test('ranks the on-topic document first', () {
      final ranked = rankByTfIdf('zip archive compression', [
        'Bananas are rich in potassium and grow in tropical climates.',
        'ZIP archive compression reduces file size using deflate.',
        'The compression of springs follows the elastic Hooke law.',
      ]);
      expect(ranked.first.$1, 1);
    });

    test('empty query yields no results', () {
      expect(rankByTfIdf('', ['anything']), isEmpty);
    });
  });

  test('tokenize strips stopwords and short tokens', () {
    final tokens = tokenize('The quick brown fox is in the box');
    expect(tokens, isNot(contains('the')));
    expect(tokens, contains('quick'));
  });
}
