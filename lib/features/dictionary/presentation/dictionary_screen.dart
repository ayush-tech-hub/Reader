import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../ai/data/text_analysis.dart' as ai;
import '../data/dictionary_service.dart';

/// Offline dictionary screen.
///
/// Lookup order:
/// 1. The document index (concordance — shows sentences that contain the
///    word, giving context-specific "definitions").
/// 2. The bundled basic English vocabulary list.
class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  final _ctrl = TextEditingController();
  List<_DictResult> _results = [];
  bool _busy = false;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final word = _ctrl.text.trim().toLowerCase();
    if (word.isEmpty) return;
    setState(() {
      _busy = true;
      _searched = false;
    });

    final results = <_DictResult>[];

    // 1. Built-in word list lookup.
    final definition = DictionaryService.lookup(word);
    if (definition != null) {
      results.add(_DictResult(
        heading: 'Definition',
        content: definition,
        kind: _ResultKind.definition,
      ));
    }

    // 2. Concordance: search document index for context sentences.
    final index = ref.read(documentIndexServiceProvider);
    final hits = await index.search(word);
    if (hits.isNotEmpty) {
      final ranked = ai.rankByTfIdf(word, [for (final h in hits) h.content]);
      final top = ranked.take(5);
      for (final (i, _) in top) {
        final hit = hits[i];
        results.add(_DictResult(
          heading: '${hit.name} (p.${hit.page})',
          content: hit.snippet.isNotEmpty ? hit.snippet : hit.content,
          kind: _ResultKind.context,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _results = results;
        _busy = false;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: 'Look up a word',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _busy ? null : _lookup,
                ),
              ),
              onSubmitted: (_) => _lookup(),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: _searched
                        ? const Text('No results found.')
                        : Text(
                            'Type a word and press Enter.',
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.outline,
                            ),
                          ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      final scheme = Theme.of(context).colorScheme;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: r.kind == _ResultKind.definition
                            ? scheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    r.kind == _ResultKind.definition
                                        ? Icons.menu_book_outlined
                                        : Icons.article_outlined,
                                    size: 16,
                                    color: r.kind == _ResultKind.definition
                                        ? scheme.onPrimaryContainer
                                        : scheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    r.heading,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: r.kind ==
                                                  _ResultKind.definition
                                              ? scheme.onPrimaryContainer
                                              : scheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                r.content,
                                style: TextStyle(
                                  color: r.kind == _ResultKind.definition
                                      ? scheme.onPrimaryContainer
                                          .withOpacity(0.9)
                                      : null,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

enum _ResultKind { definition, context }

class _DictResult {
  const _DictResult({
    required this.heading,
    required this.content,
    required this.kind,
  });
  final String heading;
  final String content;
  final _ResultKind kind;
}
