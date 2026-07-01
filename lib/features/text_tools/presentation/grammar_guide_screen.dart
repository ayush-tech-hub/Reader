import 'package:flutter/material.dart';

/// Quick-reference grammar guide with collapsible sections.
class GrammarGuideScreen extends StatelessWidget {
  const GrammarGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grammar Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section('Parts of Speech', [
            _Rule('Noun', 'Names a person, place, thing, or idea.',
                'The *book* is on the *table*.'),
            _Rule('Pronoun', 'Replaces a noun.',
                '*She* gave *him* the report.'),
            _Rule('Verb', 'Expresses action or state of being.',
                'He *runs* every morning. The sky *is* blue.'),
            _Rule('Adjective', 'Describes a noun or pronoun.',
                'The *tall* woman wore a *red* coat.'),
            _Rule('Adverb', 'Modifies a verb, adjective, or another adverb.',
                'She sings *beautifully*. He is *very* tired.'),
            _Rule('Preposition', 'Shows relationship between a noun and other words.',
                'The cat sat *on* the mat.'),
            _Rule('Conjunction', 'Joins words, phrases, or clauses.',
                'I like coffee *and* tea. She came *but* left early.'),
            _Rule('Interjection', 'Expresses emotion.',
                '*Wow!* That\'s incredible.'),
          ]),
          _Section('Punctuation', [
            _Rule('Period (.)', 'Ends a declarative or imperative sentence.',
                'I enjoy reading.'),
            _Rule('Question Mark (?)', 'Ends a direct question.',
                'Did you finish the book?'),
            _Rule('Exclamation Mark (!)', 'Expresses strong emotion.',
                'What a fantastic story!'),
            _Rule('Comma (,)',
                'Separates list items, clauses, introductory phrases, or appositives.',
                'I bought apples, oranges, and bananas.'),
            _Rule('Semicolon (;)', 'Joins two closely related independent clauses.',
                'The sun set; the stars appeared.'),
            _Rule('Colon (:)',
                'Introduces a list, explanation, or quotation.',
                'She had one goal: to win.'),
            _Rule('Apostrophe (\')',
                'Shows possession or marks a contraction.',
                "John's book. It's raining."),
            _Rule('Quotation Marks ("")',
                'Encloses direct speech or a title.',
                'She said, "I\'ll be there."'),
            _Rule('Dash (—)',
                'Sets off an aside or abrupt change in thought.',
                'He promised—then forgot—to call.'),
            _Rule('Hyphen (-)',
                'Connects compound words or parts of a word.',
                'A well-known author. Twenty-three.'),
          ]),
          _Section('Sentence Structure', [
            _Rule('Simple sentence',
                'One independent clause.',
                'The dog barked.'),
            _Rule('Compound sentence',
                'Two or more independent clauses joined by a conjunction or semicolon.',
                'The dog barked, and the cat hid.'),
            _Rule('Complex sentence',
                'An independent clause plus one or more dependent clauses.',
                'Although it rained, we went for a walk.'),
            _Rule('Compound-complex',
                'Two or more independent clauses and at least one dependent clause.',
                'Although it rained, we went out, and we enjoyed ourselves.'),
          ]),
          _Section('Common Mistakes', [
            _Rule('Its vs It\'s',
                '"Its" = possessive. "It\'s" = it is / it has.',
                "The cat licked its paw. It's a beautiful day."),
            _Rule('Their / There / They\'re',
                '"Their" = possessive. "There" = place. "They\'re" = they are.',
                "Their book is there. They're reading."),
            _Rule('Your / You\'re',
                '"Your" = possessive. "You\'re" = you are.',
                "Your idea is great. You're very creative."),
            _Rule('Affect vs Effect',
                '"Affect" = verb (to influence). "Effect" = noun (result).',
                'Stress can affect health. The effect was immediate.'),
            _Rule('Who vs Whom',
                '"Who" = subject. "Whom" = object.',
                'Who called? To whom did you speak?'),
            _Rule('Fewer vs Less',
                '"Fewer" for countable. "Less" for uncountable.',
                'Fewer people came. Less water was used.'),
            _Rule('Lay vs Lie',
                '"Lay" requires a direct object. "Lie" does not.',
                'Lay the book down. I lie on the bed.'),
          ]),
          _Section('Active vs Passive Voice', [
            _Rule('Active',
                'Subject performs the action. Usually clearer and more direct.',
                'The editor reviewed the manuscript.'),
            _Rule('Passive',
                'Subject receives the action. Useful when the doer is unknown or unimportant.',
                'The manuscript was reviewed by the editor.'),
          ]),
          _Section('Tenses at a Glance', [
            _Rule('Simple present', 'Habitual or general truth.', 'She reads every night.'),
            _Rule('Present continuous', 'Action happening now.', 'She is reading right now.'),
            _Rule('Present perfect', 'Past action with present relevance.', 'She has read five books.'),
            _Rule('Simple past', 'Completed past action.', 'She read the novel yesterday.'),
            _Rule('Past continuous', 'Ongoing past action.', 'She was reading when I called.'),
            _Rule('Past perfect', 'Action before another past action.', 'She had read the book before the film.'),
            _Rule('Simple future', 'Future action.', 'She will read tonight.'),
            _Rule('Future perfect', 'Completed before a future point.', 'She will have read it by Monday.'),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section(this.title, this.rules);
  final String title;
  final List<_Rule> rules;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: widget.rules,
              ),
            ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.term, this.definition, this.example);
  final String term, definition, example;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: scheme.primary)),
          Text(definition,
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'e.g. $example',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
