import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple flashcard study tool.
///
/// Users create decks of term → definition cards and quiz themselves
/// with a flip animation. Decks are stored in SharedPreferences.
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _Card {
  _Card({required this.front, required this.back});

  factory _Card.fromJson(Map<String, dynamic> j) =>
      _Card(front: j['front'] as String, back: j['back'] as String);

  String front;
  String back;

  Map<String, dynamic> toJson() => {'front': front, 'back': back};
}

class _Deck {
  _Deck({required this.name, List<_Card>? cards})
      : cards = cards ?? [];

  factory _Deck.fromJson(Map<String, dynamic> j) => _Deck(
        name: j['name'] as String,
        cards: (j['cards'] as List<dynamic>)
            .map((c) => _Card.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  String name;
  List<_Card> cards;

  Map<String, dynamic> toJson() =>
      {'name': name, 'cards': cards.map((c) => c.toJson()).toList()};
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  static const _key = 'flashcard_decks_v1';
  List<_Deck> _decks = [];
  bool _loaded = false;
  int? _selectedDeck;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _decks =
            list.map((e) => _Deck.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_decks.map((d) => d.toJson()).toList()));
  }

  Future<void> _addDeck() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Deck'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Deck name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _decks.add(_Deck(name: ctrl.text.trim())));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_selectedDeck != null) {
      final deck = _decks[_selectedDeck!];
      return _DeckView(
        deck: deck,
        onBack: () => setState(() => _selectedDeck = null),
        onSave: () { _save(); setState(() {}); },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDeck,
        icon: const Icon(Icons.add),
        label: const Text('New Deck'),
      ),
      body: _decks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.style_outlined,
                      size: 64,
                      color: scheme.onSurfaceVariant.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No decks yet.\nTap + to create your first deck.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _decks.length,
              itemBuilder: (context, i) {
                final deck = _decks[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text(deck.cards.length.toString(),
                          style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(deck.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${deck.cards.length} card${deck.cards.length == 1 ? "" : "s"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (deck.cards.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Study',
                            onPressed: () =>
                                setState(() => _selectedDeck = i),
                          ),
                        PopupMenuButton<String>(
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'open',
                                child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Edit cards'))),
                            const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    title: Text('Delete deck',
                                        style: TextStyle(
                                            color: Colors.red)))),
                          ],
                          onSelected: (v) {
                            if (v == 'open') {
                              setState(() => _selectedDeck = i);
                            } else if (v == 'delete') {
                              setState(() => _decks.removeAt(i));
                              _save();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Deck view (edit + study) ──────────────────────────────────────────────────

class _DeckView extends StatefulWidget {
  const _DeckView({
    required this.deck,
    required this.onBack,
    required this.onSave,
  });

  final _Deck deck;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  State<_DeckView> createState() => _DeckViewState();
}

class _DeckViewState extends State<_DeckView> {
  bool _studyMode = false;

  void _addCard() async {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: frontCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Front (term)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: backCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Back (definition)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || frontCtrl.text.trim().isEmpty) return;
    setState(() => widget.deck.cards.add(
          _Card(front: frontCtrl.text.trim(), back: backCtrl.text.trim()),
        ));
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    if (_studyMode) {
      return _StudyMode(
        deck: widget.deck,
        onExit: () => setState(() => _studyMode = false),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        leading: BackButton(onPressed: widget.onBack),
        actions: [
          if (widget.deck.cards.isNotEmpty)
            FilledButton.icon(
              onPressed: () => setState(() => _studyMode = true),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Study'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        tooltip: 'Add card',
        child: const Icon(Icons.add),
      ),
      body: widget.deck.cards.isEmpty
          ? const Center(child: Text('No cards yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: widget.deck.cards.length,
              itemBuilder: (context, i) {
                final card = widget.deck.cards[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(card.front,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(card.back),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () {
                        setState(() => widget.deck.cards.removeAt(i));
                        widget.onSave();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Study mode ────────────────────────────────────────────────────────────────

class _StudyMode extends StatefulWidget {
  const _StudyMode({required this.deck, required this.onExit});

  final _Deck deck;
  final VoidCallback onExit;

  @override
  State<_StudyMode> createState() => _StudyModeState();
}

class _StudyModeState extends State<_StudyMode>
    with SingleTickerProviderStateMixin {
  late List<_Card> _shuffled;
  int _index = 0;
  bool _flipped = false;
  int _known = 0;
  late final AnimationController _ctrl;
  late final Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _shuffled = List.of(widget.deck.cards)..shuffle(Random());
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _flip = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flipCard() async {
    if (!_flipped) {
      await _ctrl.forward();
    } else {
      await _ctrl.reverse();
    }
    setState(() => _flipped = !_flipped);
  }

  void _next({required bool knew}) {
    if (knew) _known++;
    _ctrl.reset();
    setState(() {
      _flipped = false;
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = _index >= _shuffled.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        leading: BackButton(onPressed: widget.onExit),
        actions: [
          if (!isDone)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1} / ${_shuffled.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: isDone
          ? _buildSummary(scheme)
          : _buildCard(scheme),
    );
  }

  Widget _buildCard(ColorScheme scheme) {
    final card = _shuffled[_index];
    return Column(
      children: [
        LinearProgressIndicator(
          value: _index / _shuffled.length,
          minHeight: 4,
        ),
        Expanded(
          child: GestureDetector(
            onTap: _flipCard,
            child: AnimatedBuilder(
              animation: _flip,
              builder: (_, child) {
                final angle = _flip.value * pi;
                final isFront = _flip.value < 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      elevation: 4,
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(32),
                        child: isFront
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('TERM',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              scheme.onSurfaceVariant)),
                                  const SizedBox(height: 12),
                                  Text(card.front,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  const Text('Tap to reveal',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                ],
                              )
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..rotateY(pi),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('DEFINITION',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: scheme
                                                .onSurfaceVariant)),
                                    const SizedBox(height: 12),
                                    Text(card.back,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 18)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_flipped)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _next(knew: false),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Didn\'t know',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _next(knew: true),
                    icon: const Icon(Icons.check),
                    label: const Text('Got it!'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSummary(ColorScheme scheme) {
    final total = _shuffled.length;
    final pct = total == 0 ? 0.0 : _known / total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct >= 0.8
                  ? Icons.star
                  : pct >= 0.5
                      ? Icons.thumb_up_outlined
                      : Icons.replay,
              size: 64,
              color: pct >= 0.8
                  ? Colors.amber
                  : pct >= 0.5
                      ? Colors.green
                      : scheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Round complete!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('$_known / $total cards known (${(pct * 100).round()}%)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _shuffled.shuffle(Random());
                  _index = 0;
                  _known = 0;
                  _flipped = false;
                  _ctrl.reset();
                });
              },
              icon: const Icon(Icons.replay),
              label: const Text('Study again'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: widget.onExit,
              child: const Text('Back to deck'),
            ),
          ],
        ),
      ),
    );
  }
}
