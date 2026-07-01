import 'package:flutter/material.dart';

import '../../data/text_analysis.dart' as ai;

/// Displays extractive flashcards for a document.
/// Pass the document's full text; cards are generated on first build.
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key, required this.text});
  final String text;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late final List<ai.Flashcard> _cards;
  int _index = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _cards = ai.generateFlashcards(widget.text, maxCards: 12);
  }

  void _next() => setState(() {
        _index = (_index + 1) % _cards.length;
        _showAnswer = false;
      });

  void _previous() => setState(() {
        _index = (_index - 1 + _cards.length) % _cards.length;
        _showAnswer = false;
      });

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(
          child: Text('Not enough content to generate flashcards.'),
        ),
      );
    }

    final card = _cards[_index];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards  ${_index + 1} / ${_cards.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _cards.length,
              minHeight: 4,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _FlashcardFace(
                    key: ValueKey('$_index-$_showAnswer'),
                    label: _showAnswer ? 'Answer' : 'Question',
                    text: _showAnswer ? card.answer : card.question,
                    color: _showAnswer
                        ? scheme.primaryContainer
                        : scheme.secondaryContainer,
                    textColor: _showAnswer
                        ? scheme.onPrimaryContainer
                        : scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _showAnswer ? 'Tap card to flip back' : 'Tap card to reveal answer',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  onPressed: _cards.length > 1 ? _previous : null,
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  onPressed: _cards.length > 1 ? _next : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardFace extends StatelessWidget {
  const _FlashcardFace({
    super.key,
    required this.label,
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 4,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
