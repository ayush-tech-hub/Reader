import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Template-based poem generator: pick a form, fill blanks, generate.
class PoemGeneratorScreen extends StatefulWidget {
  const PoemGeneratorScreen({super.key});

  @override
  State<PoemGeneratorScreen> createState() => _PoemGeneratorScreenState();
}

// ─── Poem Forms ───────────────────────────────────────────────────────────────

class _PoemForm {
  final String name;
  final String description;
  final List<String> fieldLabels; // blanks the user fills
  final String Function(List<String> values, Random rng) generate;

  const _PoemForm({
    required this.name,
    required this.description,
    required this.fieldLabels,
    required this.generate,
  });
}

final _forms = [
  _PoemForm(
    name: 'Haiku',
    description: '5-7-5 syllable structure',
    fieldLabels: ['Season / setting', 'Action / event', 'Feeling / insight'],
    generate: (v, rng) {
      final setting = v[0].isEmpty ? 'autumn wind' : v[0];
      final action = v[1].isEmpty ? 'leaves fall gently' : v[1];
      final feeling = v[2].isEmpty ? 'silence returns' : v[2];
      return '$setting—\n$action\n$feeling.';
    },
  ),
  _PoemForm(
    name: 'Acrostic',
    description: 'First letters spell a word',
    fieldLabels: ['Word to spell out (e.g. LOVE)', 'Theme / topic'],
    generate: (v, rng) {
      final word = v[0].isEmpty ? 'HOPE' : v[0].toUpperCase();
      final theme = v[1].isEmpty ? 'life' : v[1];
      final phrases = {
        'H': ['Hearts open wide', 'Hope lights the way', 'High above clouds'],
        'O': ['Over mountains tall', 'Opening like a flower', 'On silent wings'],
        'P': ['Peace fills the air', 'Petals fall like snow', 'Paths yet untrod'],
        'E': ['Each new dawn brings', 'Echoes of laughter', 'Endless horizons'],
        'L': ['Light breaking through', 'Laughter on the breeze', 'Longing fulfilled'],
        'O': ['Open sky calls', 'Onward ever on', 'Oceans deep and wide'],
        'V': ['Voices in the dark', 'Vast and endless blue', 'Visions of tomorrow'],
        'E': ['Every star above', 'Evermore and ever', 'Eternity waits'],
        'S': ['Silence speaks', 'Stars align at night', 'Soft the morning light'],
        'U': ['Underneath the moon', 'Unbound we are free', 'Upon the rising tide'],
        'N': ['Night gives way to day', 'Never-ending song', 'Nature calls us home'],
        'D': ['Dreams take flight', 'Distance fades away', 'Dawn paints the sky'],
        'A': ['All things bright', 'Across the ancient sea', 'Arising from the deep'],
        'Y': ['Years roll gently by', 'Yesterday is done', 'Yet we press ahead'],
      };
      final lines = word.split('').map((ch) {
        final opts = phrases[ch] ?? ['$ch stands for $theme'];
        return '$ch — ${opts[rng.nextInt(opts.length)]}';
      });
      return lines.join('\n');
    },
  ),
  _PoemForm(
    name: 'Limerick',
    description: 'AABBA rhyme scheme, humorous',
    fieldLabels: ['Main character (a name)', 'Place', 'Quirky trait or problem'],
    generate: (v, rng) {
      final name = v[0].isEmpty ? 'Jack' : v[0];
      final place = v[1].isEmpty ? 'Nantucket' : v[1];
      final trait = v[2].isEmpty ? 'couldn\'t stop singing' : v[2];
      final starters = [
        'There once was a fellow named $name',
        'A curious person named $name',
        'There lived in $place a ${name.toLowerCase()}',
      ];
      final ends = [
        'whose $trait brought everyone fame.',
        'who $trait and never felt shame.',
        'for whom $trait was a game.',
      ];
      final mid = [
        'Who $trait all day,',
        'Who just couldn\'t stay,',
        'In the most alarming way,',
      ];
      final last = [
        'And so life in $place never stayed the same.',
        'They say $place was never quite the same.',
        'And $place was never the same.',
      ];
      final i = rng.nextInt(starters.length);
      final j = rng.nextInt(mid.length);
      return '${starters[i]}\n'
          '${ends[i]}\n'
          '${mid[j]}\n'
          '${mid[j]}\n'
          '${last[rng.nextInt(last.length)]}';
    },
  ),
  _PoemForm(
    name: 'Sonnet (14-line)',
    description: '3 quatrains + couplet',
    fieldLabels: ['Subject / person', 'Central emotion', 'A contrasting image'],
    generate: (v, rng) {
      final subj = v[0].isEmpty ? 'the sea' : v[0];
      final emotion = v[1].isEmpty ? 'longing' : v[1];
      final contrast = v[2].isEmpty ? 'a winter storm' : v[2];
      return 'When I behold $subj in morning light,\n'
          'And feel the pull of $emotion in my chest,\n'
          'I know that nothing stirs my soul more right,\n'
          'Than $subj among all things I love the best.\n'
          '\n'
          'Yet $contrast rises, dark upon the hill,\n'
          'And all my $emotion turns to quiet dread;\n'
          'The world grows cold, and time itself stands still,\n'
          'As shadows lengthen, deep and cold as lead.\n'
          '\n'
          'But still $subj endures through darkest night,\n'
          'And $emotion flowers in the barren ground;\n'
          'For every shadow frames a brighter light,\n'
          'And in the quiet, hope is always found.\n'
          '\n'
          '  So let me hold this truth until the end:\n'
          '  On $subj, my $emotion will never bend.';
    },
  ),
  _PoemForm(
    name: 'Free Verse',
    description: 'No rhyme or meter constraints',
    fieldLabels: ['Subject', 'Colour or texture', 'Memory or place'],
    generate: (v, rng) {
      final subj = v[0].isEmpty ? 'rain' : v[0];
      final colour = v[1].isEmpty ? 'silver' : v[1];
      final memory = v[2].isEmpty ? 'childhood' : v[2];
      return 'There is something about $subj—\n'
          'the way it catches $colour light\n'
          'and turns the world translucent.\n'
          '\n'
          'I have held $subj before,\n'
          'in a $memory I can barely name,\n'
          'where the air was softer\n'
          'and the hours longer.\n'
          '\n'
          'Now I return to $subj\n'
          'and find it unchanged,\n'
          'patient as ever,\n'
          '$colour and quiet and real.';
    },
  ),
  _PoemForm(
    name: 'Ode',
    description: 'Formal praise of a subject',
    fieldLabels: ['Thing to celebrate', 'Quality you admire', 'How it makes you feel'],
    generate: (v, rng) {
      final thing = v[0].isEmpty ? 'coffee' : v[0];
      final quality = v[1].isEmpty ? 'warmth' : v[1];
      final feel = v[2].isEmpty ? 'alive' : v[2];
      return 'O $thing, praise beyond all measure!\n'
          'You bring the world your gift of $quality;\n'
          'Each moment near you is a treasure,\n'
          'A balm for all that we have been through.\n'
          '\n'
          'No storm can dim your gentle power,\n'
          'No winter chill your radiance quell;\n'
          'You turn the plainest ordinary hour\n'
          'Into a story worth the telling.\n'
          '\n'
          'And I, who sought you first in wonder,\n'
          'Return again as to a faithful friend;\n'
          'For when the world is torn asunder,\n'
          'You make me feel $feel again.';
    },
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class _PoemGeneratorScreenState extends State<PoemGeneratorScreen> {
  int _formIndex = 0;
  List<TextEditingController> _ctrls = [];
  String _poem = '';
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _resetControllers();
  }

  void _resetControllers() {
    for (final c in _ctrls) {
      c.dispose();
    }
    final form = _forms[_formIndex];
    _ctrls = List.generate(form.fieldLabels.length, (_) => TextEditingController());
    _poem = '';
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _generate() {
    final values = _ctrls.map((c) => c.text.trim()).toList();
    setState(() {
      _poem = _forms[_formIndex].generate(values, _rng);
    });
  }

  void _randomize() {
    for (final c in _ctrls) {
      c.clear();
    }
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = _forms[_formIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Poem Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form selector
            const Text('Select form:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: List.generate(_forms.length, (i) => ChoiceChip(
                label: Text(_forms[i].name),
                selected: _formIndex == i,
                onSelected: (_) => setState(() {
                  _formIndex = i;
                  _resetControllers();
                }),
              )),
            ),
            const SizedBox(height: 4),
            Text(form.description,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            // Input fields
            for (int i = 0; i < form.fieldLabels.length; i++) ...[
              TextField(
                controller: _ctrls[i],
                decoration: InputDecoration(
                  labelText: form.fieldLabels[i],
                  border: const OutlineInputBorder(),
                  hintText: 'Optional — leave blank for random',
                  hintStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Generate'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _randomize,
                icon: const Icon(Icons.shuffle),
                label: const Text('Random'),
              ),
            ]),
            if (_poem.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _poem,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          fontStyle: FontStyle.italic,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _poem));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Poem copied')));
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
