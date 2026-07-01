import 'package:flutter/material.dart';

import '../../data/text_analysis.dart' as ai;

/// Multiple-choice quiz generated from document text.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.text});
  final String text;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<ai.QuizQuestion> _questions;
  int _index = 0;
  int? _selected;
  bool _submitted = false;
  int _score = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _questions = ai.generateQuiz(widget.text, maxQuestions: 8);
  }

  void _select(int option) {
    if (_submitted) return;
    setState(() => _selected = option);
  }

  void _submit() {
    if (_selected == null) return;
    final correct = _selected == _questions[_index].correctIndex;
    setState(() {
      _submitted = true;
      if (correct) _score++;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _submitted = false;
      });
    } else {
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(
          child: Text('Not enough content to generate a quiz.'),
        ),
      );
    }

    if (_done) return _ResultScreen(score: _score, total: _questions.length);

    final q = _questions[_index];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz  ${_index + 1} / ${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _questions.length,
              minHeight: 4,
            ),
            const SizedBox(height: 20),
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  q.question,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < q.options.length; i++)
              _OptionTile(
                label: q.options[i],
                index: i,
                selected: _selected == i,
                submitted: _submitted,
                isCorrect: i == q.correctIndex,
                onTap: () => _select(i),
              ),
            const Spacer(),
            if (!_submitted)
              FilledButton(
                onPressed: _selected == null ? null : _submit,
                child: const Text('Check answer'),
              )
            else ...[
              Card(
                color: _selected == q.correctIndex
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    _selected == q.correctIndex
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: _selected == q.correctIndex
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
                  ),
                  title: Text(
                    _selected == q.correctIndex ? 'Correct!' : 'Incorrect',
                    style: TextStyle(
                      color: _selected == q.correctIndex
                          ? scheme.onPrimaryContainer
                          : scheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: _selected != q.correctIndex
                      ? Text(
                          'Correct answer: ${q.options[q.correctIndex]}',
                          style:
                              TextStyle(color: scheme.onErrorContainer),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _next,
                child: Text(
                  _index < _questions.length - 1 ? 'Next question' : 'See results',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.index,
    required this.selected,
    required this.submitted,
    required this.isCorrect,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? bg;
    Color? fg;
    if (submitted) {
      if (isCorrect) {
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
      } else if (selected) {
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
      }
    } else if (selected) {
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
    }

    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: selected && !submitted
              ? scheme.primary
              : scheme.outlineVariant,
          child: Text(
            String.fromCharCode(65 + index),
            style: TextStyle(
              color: selected && !submitted
                  ? scheme.onPrimary
                  : scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(label, style: fg != null ? TextStyle(color: fg) : null),
        onTap: submitted ? null : onTap,
      ),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({required this.score, required this.total});
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (score / total * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz results')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pct >= 70 ? Icons.emoji_events : Icons.school_outlined,
                size: 72,
                color: pct >= 70 ? scheme.primary : scheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '$score / $total',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$pct% correct',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                pct >= 80
                    ? 'Excellent!'
                    : pct >= 60
                        ? 'Good job — keep reviewing!'
                        : 'Keep studying — you\'ve got this!',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
