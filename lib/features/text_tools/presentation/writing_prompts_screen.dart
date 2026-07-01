import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Random creative writing prompt generator with category filters.
class WritingPromptsScreen extends StatefulWidget {
  const WritingPromptsScreen({super.key});

  @override
  State<WritingPromptsScreen> createState() => _WritingPromptsScreenState();
}

const _promptsByCategory = <String, List<String>>{
  'Fiction': [
    'A letter arrives addressed to your protagonist — but the sender died twenty years ago.',
    'Two strangers discover they share the exact same recurring dream.',
    'A librarian finds a book that updates itself with real events as they happen.',
    'An AI develops a phobia no one knows how to treat.',
    'The last lighthouse keeper on Earth receives a signal from the sea.',
    'A cartographer discovers their maps are changing overnight.',
    'A musician finds that every song they play predicts the near future.',
    'The protagonist wakes to find their shadow moving independently.',
    'In a world without sleep, people pay to borrow memories of dreams.',
    'A detective investigates crimes that haven\'t happened yet.',
    'An archaeologist unearths an artifact that seems to be from a century in the future.',
    'The town clock stopped at 3:17 — and so did time for everyone except one person.',
    'A translator is hired to decode messages found inside meteorites.',
    'Every mirror in the city suddenly shows a different world.',
    'A chef discovers that the meals they cook cause people to confess their secrets.',
  ],
  'Non-fiction': [
    'Describe the earliest memory you can access with as much sensory detail as possible.',
    'Write about a moment when a stranger\'s kindness changed your day — or your life.',
    'Document a skill you\'ve forgotten how to do and why you stopped.',
    'Reflect on a belief you held strongly at 16 that you\'ve completely reversed.',
    'Describe a place that no longer exists exactly as it was when you knew it.',
    'Write about an object in your home with an unexpected history.',
    'Explore a conversation you wish you could have again and do differently.',
    'Describe what it feels like to be good at something no one else seems to notice.',
    'Write about a book that surprised you by changing how you see something mundane.',
    'Reflect on the last time you felt genuinely lost — geographically or otherwise.',
  ],
  'Poetry': [
    'Write a poem using only words that describe sounds.',
    'Describe a colour to someone who has never seen it, in verse.',
    'Write a poem from the perspective of a discarded library book.',
    'Compose a love letter between two seasons of the year.',
    'Write about silence as if it were a physical object you could hold.',
    'Describe the feeling of almost remembering something.',
    'Write a poem that begins and ends with the same line, but means something different by the end.',
    'Compose a poem made entirely of questions.',
    'Write a lament for something small that the world has forgotten.',
    'Describe a city at 4 a.m. from the viewpoint of the city itself.',
  ],
  'Mystery': [
    'A detective is called to a locked-room murder — and the suspect is themselves.',
    'The only witness to a crime is a parrot who can\'t stop repeating what it heard.',
    'A series of thefts targets only items that have no monetary value.',
    'Every resident of a village claims they were somewhere else at the same time.',
    'A cold case reopens when the victim\'s grave is found — empty.',
    'A renowned forger dies and their lawyer announces that all the evidence in a famous trial was fake.',
    'Someone is leaving historical facts folded into origami and mailed anonymously to journalists.',
    'A missing person reappears with no memory but speaks a language that hasn\'t been spoken in 300 years.',
  ],
  'Sci-Fi': [
    'Humanity makes first contact — but the aliens are asking for asylum.',
    'A colony ship\'s AI quietly rewrites history to keep morale high across five generations.',
    'A physicist discovers that free will is real — but only on Tuesdays.',
    'Earth receives a message: "Do not respond to this transmission."',
    'Consciousness is now uploadable, but only the wealthy can afford storage.',
    'The first person to live to 200 years old gives an interview.',
    'A programmer discovers the simulation they\'re in has a memory limit — almost reached.',
    'Time travel is invented but immediately made illegal as a public health measure.',
    'An asteroid mining crew finds something that was clearly placed there intentionally.',
    'The cure for all disease is discovered — and outlawed within a year.',
  ],
  'Fantasy': [
    'A dragon applies for a job at a prestigious library.',
    'Magic is real but requires a licence, and the bureaucracy is infuriating.',
    'A prophecy predicts the chosen one — and three thousand people fit the description.',
    'A kingdom is threatened not by war but by an epidemic of forgetting.',
    'A young wizard discovers that their spell book has a chapter written in their own future handwriting.',
    'The villain wins at the end of chapter one. The rest of the story belongs to someone else.',
    'An enchanted sword refuses to let its wielder die — making the bearer increasingly reckless.',
    'A necromancer raises the dead only to discover one of them doesn\'t want to go back.',
    'In a world of elemental magic, one person can only control paperwork.',
    'Every wish granted by the genie is technically fulfilled but always misinterpreted.',
  ],
};

class _WritingPromptsScreenState extends State<WritingPromptsScreen> {
  final _rng = Random();
  String _category = 'Fiction';
  String _currentPrompt = '';
  final List<String> _saved = [];

  @override
  void initState() {
    super.initState();
    _newPrompt();
  }

  void _newPrompt() {
    final list = _promptsByCategory[_category]!;
    setState(() => _currentPrompt = list[_rng.nextInt(list.length)]);
  }

  void _save() {
    if (_currentPrompt.isNotEmpty && !_saved.contains(_currentPrompt)) {
      setState(() => _saved.add(_currentPrompt));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prompt saved')),
      );
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = _promptsByCategory.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Writing Prompts'),
        actions: [
          if (_saved.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_saved.length}'),
                child: const Icon(Icons.bookmark_outlined),
              ),
              tooltip: 'Saved prompts',
              onPressed: _showSaved,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _category == cat,
                        onSelected: (_) {
                          setState(() => _category = cat);
                          _newPrompt();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Prompt card
            Expanded(
              child: Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note,
                          size: 40, color: scheme.onPrimaryContainer.withOpacity(0.5)),
                      const SizedBox(height: 20),
                      Text(
                        _currentPrompt,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              height: 1.6,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copy(_currentPrompt),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onPrimaryContainer,
                              side: BorderSide(color: scheme.onPrimaryContainer.withOpacity(0.4)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                            label: const Text('Save'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onPrimaryContainer,
                              side: BorderSide(color: scheme.onPrimaryContainer.withOpacity(0.4)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _newPrompt,
              icon: const Icon(Icons.shuffle),
              label: const Text('New Prompt'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaved() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Saved Prompts (${_saved.length})',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  TextButton(
                    onPressed: () {
                      _copy(_saved.join('\n\n'));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Copy All'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: _saved.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  title: Text(_saved[i], maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copy(_saved[i]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => setState(() => _saved.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
