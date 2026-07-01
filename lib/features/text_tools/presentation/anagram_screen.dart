import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Checks if two words/phrases are anagrams and finds sub-anagrams.
class AnagramScreen extends StatefulWidget {
  const AnagramScreen({super.key});

  @override
  State<AnagramScreen> createState() => _AnagramScreenState();
}

// Basic English word list (curated common words for demo)
const _wordBank = [
  'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her',
  'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how',
  'man', 'new', 'now', 'old', 'see', 'two', 'way', 'who', 'boy', 'did',
  'its', 'let', 'put', 'say', 'she', 'too', 'use', 'cat', 'dog', 'ear',
  'eat', 'far', 'god', 'got', 'had', 'hat', 'hot', 'job', 'map', 'met',
  'net', 'nod', 'nor', 'odd', 'ore', 'own', 'pan', 'par', 'pat', 'pen',
  'pet', 'pie', 'pig', 'pin', 'pit', 'pot', 'raw', 'red', 'rod', 'row',
  'run', 'sat', 'set', 'sit', 'six', 'sky', 'son', 'sun', 'tap', 'tar',
  'tax', 'ten', 'tie', 'tip', 'ton', 'top', 'try', 'tub', 'van', 'war',
  'win', 'won', 'wood', 'word', 'work', 'year', 'able', 'also', 'area',
  'back', 'ball', 'band', 'bank', 'base', 'bath', 'bear', 'beat', 'been',
  'bell', 'belt', 'best', 'bill', 'bird', 'blow', 'blue', 'boat', 'body',
  'bone', 'book', 'bore', 'born', 'boss', 'both', 'bull', 'burn', 'busy',
  'call', 'calm', 'came', 'card', 'care', 'case', 'cash', 'cast', 'cave',
  'cell', 'chat', 'chip', 'city', 'clap', 'clay', 'clip', 'club', 'clue',
  'coal', 'coat', 'code', 'coil', 'coin', 'cold', 'cole', 'come', 'cook',
  'cool', 'cope', 'copy', 'core', 'cost', 'coup', 'crew', 'crop', 'cure',
  'curl', 'cute', 'dale', 'dame', 'dare', 'dark', 'date', 'dawn', 'dead',
  'dear', 'deed', 'deep', 'deer', 'deft', 'deny', 'desk', 'diet', 'dime',
  'dine', 'dire', 'dirt', 'dish', 'disk', 'dive', 'dock', 'done', 'door',
  'dope', 'dose', 'dove', 'down', 'drag', 'draw', 'drip', 'drop', 'drum',
  'dual', 'dull', 'dump', 'dune', 'dusk', 'dust', 'duty', 'dwell', 'each',
  'earl', 'earn', 'ease', 'east', 'edge', 'else', 'emit', 'epic', 'even',
  'ever', 'evil', 'exam', 'exit', 'face', 'fact', 'fair', 'fake', 'fall',
  'fame', 'farm', 'fast', 'fate', 'fear', 'feat', 'feed', 'feel', 'feet',
  'fell', 'felt', 'fill', 'film', 'find', 'fine', 'fire', 'firm', 'fish',
  'fist', 'flag', 'flat', 'flew', 'flip', 'flow', 'foam', 'fold', 'folk',
  'fond', 'font', 'fool', 'ford', 'fore', 'fork', 'form', 'fort', 'foul',
  'four', 'free', 'from', 'fuel', 'full', 'fund', 'fury', 'fuse', 'gain',
  'gale', 'game', 'gate', 'gave', 'gaze', 'gear', 'gene', 'gist', 'give',
  'glad', 'glow', 'glue', 'goal', 'goes', 'gold', 'golf', 'gone', 'good',
  'gore', 'gown', 'grab', 'gray', 'grew', 'grid', 'grip', 'grit', 'grow',
  'gulf', 'gust', 'hack', 'hail', 'half', 'hall', 'halt', 'hand', 'hang',
  'hard', 'hare', 'harm', 'hate', 'have', 'head', 'heal', 'heap', 'hear',
  'heat', 'heel', 'held', 'help', 'hero', 'hide', 'high', 'hill', 'hint',
  'hire', 'hold', 'hole', 'home', 'hood', 'hook', 'hope', 'horn', 'hour',
  'huge', 'hunt', 'icon', 'idea', 'idle', 'inch', 'into', 'iron', 'isle',
  'item', 'join', 'joke', 'jump', 'just', 'keen', 'keep', 'kick', 'kind',
  'king', 'kiss', 'knit', 'know', 'lack', 'lake', 'lamp', 'land', 'lane',
  'late', 'lead', 'leaf', 'leak', 'lean', 'leap', 'left', 'lend', 'lens',
  'life', 'lift', 'like', 'lime', 'line', 'link', 'lion', 'list', 'live',
  'load', 'loan', 'lock', 'loft', 'logo', 'lone', 'long', 'look', 'loop',
  'lord', 'lore', 'lose', 'loss', 'lost', 'loud', 'love', 'luck', 'lung',
  'lure', 'lust', 'made', 'mail', 'main', 'make', 'male', 'mall', 'malt',
  'mare', 'mark', 'mars', 'mast', 'mate', 'math', 'maze', 'meal', 'mean',
  'meat', 'melt', 'memo', 'menu', 'mere', 'mesh', 'mile', 'milk', 'mill',
  'mind', 'mine', 'mint', 'miss', 'mist', 'mode', 'mood', 'moon', 'more',
  'most', 'move', 'much', 'muse', 'must', 'mute', 'myth', 'nail', 'name',
  'near', 'neck', 'need', 'nest', 'news', 'next', 'nice', 'nine', 'node',
  'nose', 'note', 'null', 'nurse', 'oath', 'once', 'only', 'open', 'oral',
  'oval', 'over', 'oven', 'pace', 'pack', 'page', 'paid', 'pain', 'pair',
  'pale', 'palm', 'pave', 'peak', 'pear', 'peer', 'pick', 'pile', 'pipe',
  'plan', 'play', 'plot', 'plow', 'plum', 'plus', 'poem', 'poet', 'poke',
  'pole', 'poll', 'pond', 'pool', 'poor', 'pork', 'port', 'pose', 'post',
  'pour', 'pray', 'prey', 'prod', 'prop', 'pull', 'pump', 'pure', 'push',
  'race', 'raid', 'rail', 'rain', 'rake', 'ramp', 'rang', 'rank', 'rape',
  'rare', 'rate', 'read', 'real', 'reap', 'rear', 'reed', 'reef', 'reel',
  'rein', 'rely', 'rent', 'rest', 'rice', 'rich', 'ride', 'ring', 'riot',
  'rise', 'risk', 'road', 'roam', 'roar', 'robe', 'rock', 'rode', 'role',
  'roll', 'roof', 'root', 'rope', 'rose', 'ruin', 'rule', 'rush', 'rust',
  'safe', 'sage', 'sail', 'sake', 'sale', 'salt', 'same', 'sand', 'sane',
  'sang', 'sank', 'save', 'scan', 'scar', 'seal', 'seam', 'seat', 'seed',
  'seek', 'seem', 'self', 'sell', 'send', 'sent', 'shed', 'shin', 'ship',
  'shoe', 'shop', 'shot', 'show', 'shut', 'sick', 'sign', 'silk', 'sill',
  'sing', 'sink', 'size', 'skin', 'skip', 'slab', 'slam', 'slap', 'slid',
  'slim', 'slip', 'slot', 'slow', 'slug', 'snap', 'snow', 'soak', 'soap',
  'sock', 'soil', 'sold', 'sole', 'soma', 'song', 'soon', 'sore', 'sort',
  'soup', 'sour', 'span', 'spar', 'spin', 'spit', 'spot', 'spur', 'star',
  'stay', 'stem', 'step', 'stop', 'stub', 'such', 'suit', 'sure', 'surf',
  'swan', 'swap', 'swim', 'tale', 'talk', 'tall', 'tank', 'tape', 'task',
  'team', 'tear', 'tend', 'tent', 'term', 'test', 'text', 'than', 'that',
  'them', 'then', 'they', 'thin', 'this', 'thus', 'tide', 'till', 'time',
  'tire', 'title', 'toad', 'told', 'toll', 'tomb', 'tome', 'tone', 'tool',
  'tore', 'torn', 'tour', 'town', 'toys', 'trap', 'tree', 'trim', 'trio',
  'trip', 'true', 'tube', 'tune', 'turf', 'turn', 'twin', 'type', 'unit',
  'upon', 'urge', 'used', 'vale', 'vast', 'veil', 'vein', 'vest', 'view',
  'vine', 'void', 'volt', 'vow', 'wade', 'wage', 'wake', 'walk', 'wall',
  'wand', 'want', 'ward', 'warm', 'warn', 'wart', 'wave', 'weak', 'weal',
  'wean', 'wear', 'weed', 'well', 'went', 'were', 'west', 'what', 'when',
  'whip', 'wide', 'wild', 'will', 'wind', 'wine', 'wing', 'wink', 'wire',
  'wise', 'wish', 'with', 'wolf', 'womb', 'wont', 'wore', 'worn', 'wove',
  'wrap', 'wren', 'writ', 'yard', 'yell', 'your', 'zone',
];

String _sorted(String s) {
  final chars = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').split('');
  chars.sort();
  return chars.join();
}

List<String> _findAnagrams(String input) {
  final key = _sorted(input);
  if (key.isEmpty) return [];
  return _wordBank.where((w) => _sorted(w) == key && w != input.toLowerCase()).toList();
}

class _AnagramScreenState extends State<AnagramScreen> {
  final _w1Ctrl = TextEditingController();
  final _w2Ctrl = TextEditingController();
  bool? _isAnagram;
  List<String> _found = [];
  bool _searched = false;

  @override
  void dispose() {
    _w1Ctrl.dispose();
    _w2Ctrl.dispose();
    super.dispose();
  }

  void _check() {
    final a = _w1Ctrl.text.trim();
    final b = _w2Ctrl.text.trim();
    if (a.isEmpty || b.isEmpty) return;
    setState(() => _isAnagram = _sorted(a) == _sorted(b));
  }

  void _find() {
    final q = _w1Ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _found = _findAnagrams(q);
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Anagram Finder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _w1Ctrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Word or phrase',
                hintText: 'e.g. listen',
              ),
              onChanged: (_) => setState(() { _isAnagram = null; _searched = false; }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _find,
                    icon: const Icon(Icons.search),
                    label: const Text('Find Anagrams'),
                  ),
                ),
              ],
            ),
            if (_searched) ...[
              const SizedBox(height: 12),
              if (_found.isEmpty)
                Center(
                  child: Text('No anagrams found in word bank',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              else ...[
                Text('Anagrams (${_found.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _found.map((w) => ActionChip(
                    label: Text(w),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: w));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"$w" copied')),
                      );
                    },
                  )).toList(),
                ),
              ],
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text('Check two words/phrases:',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _w1Ctrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Word 1',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _isAnagram = null),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('vs'),
                ),
                Expanded(
                  child: TextField(
                    controller: _w2Ctrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Word 2',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _isAnagram = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.compare),
              label: const Text('Check'),
            ),
            if (_isAnagram != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isAnagram! ? Icons.check_circle : Icons.cancel,
                      color: _isAnagram! ? Colors.green : scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAnagram!
                          ? '"${_w1Ctrl.text.trim()}" and "${_w2Ctrl.text.trim()}" ARE anagrams!'
                          : 'Not anagrams.',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isAnagram! ? Colors.green : scheme.error),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
