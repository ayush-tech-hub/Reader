import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personal vocabulary builder: add words, definitions, examples; quiz yourself.
class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabEntry {
  _VocabEntry({
    required this.word,
    required this.definition,
    this.example = '',
    this.partOfSpeech = '',
  });

  String word;
  String definition;
  String example;
  String partOfSpeech;

  Map<String, dynamic> toJson() => {
        'w': word,
        'd': definition,
        'e': example,
        'p': partOfSpeech,
      };

  factory _VocabEntry.fromJson(Map<String, dynamic> j) => _VocabEntry(
        word: j['w'] as String,
        definition: j['d'] as String,
        example: j['e'] as String? ?? '',
        partOfSpeech: j['p'] as String? ?? '',
      );
}

const _posOptions = ['noun', 'verb', 'adjective', 'adverb', 'phrase', 'other'];
const _prefKey = 'vocab_entries_v1';

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<_VocabEntry> _entries = [];
  String _search = '';
  bool _quizMode = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _entries = list
            .map((e) => _VocabEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  List<_VocabEntry> get _filtered {
    if (_search.isEmpty) return _entries;
    final q = _search.toLowerCase();
    return _entries
        .where((e) =>
            e.word.toLowerCase().contains(q) ||
            e.definition.toLowerCase().contains(q))
        .toList();
  }

  void _addOrEdit([_VocabEntry? existing]) {
    showDialog(
      context: context,
      builder: (ctx) => _VocabDialog(
        existing: existing,
        onSave: (entry) {
          setState(() {
            if (existing != null) {
              final i = _entries.indexOf(existing);
              if (i >= 0) _entries[i] = entry;
            } else {
              _entries.add(entry);
            }
          });
          _save();
        },
      ),
    );
  }

  void _delete(_VocabEntry entry) {
    setState(() => _entries.remove(entry));
    _save();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Word deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Builder'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Words'), Tab(text: 'Quiz')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add word',
            onPressed: _addOrEdit,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_WordListTab(this), _QuizTab(this)],
      ),
    );
  }
}

// ─── Word List Tab ──────────────────────────────────────────────────────────

class _WordListTab extends StatelessWidget {
  const _WordListTab(this.state);
  final _VocabularyScreenState state;

  @override
  Widget build(BuildContext context) {
    final filtered = state._filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search words…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => state.setState(() => state._search = v),
          ),
        ),
        if (state._entries.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No words yet. Tap + to add your first word.'),
            ),
          )
        else if (filtered.isEmpty)
          const Expanded(child: Center(child: Text('No matches')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final entry = filtered[i];
                return ListTile(
                  title: Text(entry.word,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.partOfSpeech.isNotEmpty)
                        Text(entry.partOfSpeech,
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.primary)),
                      Text(entry.definition),
                      if (entry.example.isNotEmpty)
                        Text('"${entry.example}"',
                            style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') state._addOrEdit(entry);
                      if (v == 'delete') state._delete(entry);
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Quiz Tab ───────────────────────────────────────────────────────────────

class _QuizTab extends StatefulWidget {
  const _QuizTab(this.parentState);
  final _VocabularyScreenState parentState;

  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  int _index = 0;
  bool _revealed = false;
  late List<_VocabEntry> _shuffled;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    _shuffled = [...widget.parentState._entries]..shuffle();
    _index = 0;
    _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = widget.parentState._entries;

    if (entries.isEmpty) {
      return const Center(child: Text('Add words first to use the quiz.'));
    }

    if (_shuffled.isEmpty || _index >= _shuffled.length) {
      _shuffle();
    }

    final entry = _shuffled[_index];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('${_index + 1} / ${_shuffled.length}',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(entry.word,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          )),
                  if (entry.partOfSpeech.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(entry.partOfSpeech,
                        style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: scheme.onPrimaryContainer.withOpacity(0.7))),
                  ],
                  const SizedBox(height: 24),
                  if (_revealed) ...[
                    Text(entry.definition,
                        style: TextStyle(
                            fontSize: 16, color: scheme.onPrimaryContainer),
                        textAlign: TextAlign.center),
                    if (entry.example.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('"${entry.example}"',
                          style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: scheme.onPrimaryContainer.withOpacity(0.8)),
                          textAlign: TextAlign.center),
                    ],
                  ] else
                    Text('Tap to reveal definition',
                        style: TextStyle(
                            color: scheme.onPrimaryContainer.withOpacity(0.5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_revealed)
            FilledButton(
              onPressed: () => setState(() => _revealed = true),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              child: const Text('Reveal'),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _index = (_index + 1) % _shuffled.length;
                    _revealed = false;
                  }),
                  child: const Text('Next'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => setState(_shuffle),
                  child: const Text('Shuffle'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Add/Edit Dialog ────────────────────────────────────────────────────────

class _VocabDialog extends StatefulWidget {
  const _VocabDialog({this.existing, required this.onSave});
  final _VocabEntry? existing;
  final void Function(_VocabEntry) onSave;

  @override
  State<_VocabDialog> createState() => _VocabDialogState();
}

class _VocabDialogState extends State<_VocabDialog> {
  final _wordCtrl = TextEditingController();
  final _defCtrl = TextEditingController();
  final _exCtrl = TextEditingController();
  String _pos = '';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _wordCtrl.text = widget.existing!.word;
      _defCtrl.text = widget.existing!.definition;
      _exCtrl.text = widget.existing!.example;
      _pos = widget.existing!.partOfSpeech;
    }
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _defCtrl.dispose();
    _exCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Word' : 'Edit Word'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _wordCtrl,
              decoration: const InputDecoration(labelText: 'Word *'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _pos.isEmpty ? null : _pos,
              decoration: const InputDecoration(labelText: 'Part of speech'),
              items: _posOptions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _pos = v ?? ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _defCtrl,
              decoration: const InputDecoration(labelText: 'Definition *'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _exCtrl,
              decoration:
                  const InputDecoration(labelText: 'Example sentence (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final word = _wordCtrl.text.trim();
            final def = _defCtrl.text.trim();
            if (word.isEmpty || def.isEmpty) return;
            widget.onSave(_VocabEntry(
              word: word,
              definition: def,
              example: _exCtrl.text.trim(),
              partOfSpeech: _pos,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
