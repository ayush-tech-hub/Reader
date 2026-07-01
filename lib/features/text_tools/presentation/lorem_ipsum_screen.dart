import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates Lorem Ipsum placeholder text.
///
/// The classic Cicero-based corpus is used verbatim (no randomisation) so
/// every generation with the same settings produces the same text — predictable
/// for layout work.  Users can request 1–20 paragraphs.
class LoremIpsumScreen extends StatefulWidget {
  const LoremIpsumScreen({super.key});

  @override
  State<LoremIpsumScreen> createState() => _LoremIpsumScreenState();
}

class _LoremIpsumScreenState extends State<LoremIpsumScreen> {
  int _paragraphs = 3;
  bool _startWithClassic = true;
  String _generated = '';

  // Classic Lorem Ipsum paragraphs (Cicero, De Finibus, 45 BC)
  static const _corpus = [
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
        'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim '
        'veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
        'commodo consequat. Duis aute irure dolor in reprehenderit in voluptate '
        'velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint '
        'occaecat cupidatat non proident, sunt in culpa qui officia deserunt '
        'mollit anim id est laborum.',
    'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium '
        'doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo '
        'inventore veritatis et quasi architecto beatae vitae dicta sunt '
        'explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur '
        'aut odit aut fugit, sed quia consequuntur magni dolores eos qui '
        'ratione voluptatem sequi nesciunt.',
    'At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis '
        'praesentium voluptatum deleniti atque corrupti quos dolores et quas '
        'molestias excepturi sint occaecati cupiditate non provident, similique '
        'sunt in culpa qui officia deserunt mollitia animi, id est laborum et '
        'dolorum fuga.',
    'Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil '
        'impedit quo minus id quod maxime placeat facere possimus, omnis '
        'voluptas assumenda est, omnis dolor repellendus. Temporibus autem '
        'quibusdam et aut officiis debitis aut rerum necessitatibus saepe '
        'eveniet ut et voluptates repudiandae sint et molestiae non recusandae.',
    'Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis '
        'voluptatibus maiores alias consequatur aut perferendis doloribus '
        'asperiores repellat. Quis autem vel eum iure reprehenderit qui in ea '
        'voluptate velit esse quam nihil molestiae consequatur, vel illum qui '
        'dolorem eum fugiat quo voluptas nulla pariatur.',
    'Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, '
        'consectetur, adipisci velit, sed quia non numquam eius modi tempora '
        'incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut '
        'enim ad minima veniam, quis nostrum exercitationem ullam corporis '
        'suscipit laboriosam.',
    'Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam '
        'nihil molestiae consequatur, vel illum qui dolorem eum fugiat, quo '
        'voluptas nulla pariatur? Temporibus autem quibusdam et aut officiis '
        'debitis aut rerum necessitatibus saepe eveniet.',
  ];

  void _generate() {
    final buf = StringBuffer();
    for (var i = 0; i < _paragraphs; i++) {
      if (i == 0 && _startWithClassic) {
        buf.write(_corpus[0]);
      } else {
        buf.write(_corpus[i % _corpus.length]);
      }
      if (i < _paragraphs - 1) buf.write('\n\n');
    }
    setState(() => _generated = buf.toString());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lorem Ipsum Generator'),
        actions: [
          if (_generated.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generated));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Paragraph count
                    Row(
                      children: [
                        const Text('Paragraphs:',
                            style:
                                TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Slider(
                            value: _paragraphs.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: '$_paragraphs',
                            onChanged: (v) =>
                                setState(() => _paragraphs = v.round()),
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('$_paragraphs',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.end),
                        ),
                      ],
                    ),

                    // Classic start toggle
                    SwitchListTile(
                      title: const Text('Start with "Lorem ipsum…"'),
                      value: _startWithClassic,
                      onChanged: (v) =>
                          setState(() => _startWithClassic = v),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),

                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Generate'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_generated.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    '${_generated.split(' ').length} words · '
                    '${_generated.length} characters',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: scheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.surfaceContainerLowest,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _generated,
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.text_snippet_outlined,
                          size: 64,
                          color: scheme.onSurfaceVariant.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Adjust the settings above and tap Generate',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
