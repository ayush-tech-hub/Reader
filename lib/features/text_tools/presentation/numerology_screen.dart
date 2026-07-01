import 'package:flutter/material.dart';

/// Numerology calculator: life path, expression, soul urge, personality numbers.
class NumerologyScreen extends StatefulWidget {
  const NumerologyScreen({super.key});

  @override
  State<NumerologyScreen> createState() => _NumerologyScreenState();
}

class _NumerologyScreenState extends State<NumerologyScreen> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  DateTime? _dob;
  _NumerologyResult? _result;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _dob == null) return;
    setState(() {
      _result = _NumerologyResult.compute(name, _dob!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Numerology')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name (as given at birth)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dobCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date of birth',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: _dob == null
                    ? 'Tap to select'
                    : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime(1990),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() {
                    _dob = d;
                    _dobCtrl.text = '${d.day}/${d.month}/${d.year}';
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultCard('Life Path Number', _result!.lifePath,
                  _result!.lifePathMeaning, scheme),
              const SizedBox(height: 10),
              _ResultCard('Expression Number', _result!.expression,
                  _result!.expressionMeaning, scheme),
              const SizedBox(height: 10),
              _ResultCard('Soul Urge Number', _result!.soulUrge,
                  _result!.soulUrgeMeaning, scheme),
              const SizedBox(height: 10),
              _ResultCard('Personality Number', _result!.personality,
                  _result!.personalityMeaning, scheme),
              const SizedBox(height: 16),
              Text(
                'Numerology is for entertainment only.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.label, this.number, this.meaning, this.scheme);
  final String label;
  final int number;
  final String meaning;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary,
                child: Text('$number',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(meaning,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Numerology Logic ─────────────────────────────────────────────────────────

class _NumerologyResult {
  final int lifePath;
  final int expression;
  final int soulUrge;
  final int personality;

  const _NumerologyResult({
    required this.lifePath,
    required this.expression,
    required this.soulUrge,
    required this.personality,
  });

  factory _NumerologyResult.compute(String name, DateTime dob) {
    final lp = _lifePath(dob);
    final exp = _nameNumber(name, _full);
    final su = _nameNumber(name, _vowels);
    final per = _nameNumber(name, _consonants);
    return _NumerologyResult(
      lifePath: lp,
      expression: exp,
      soulUrge: su,
      personality: per,
    );
  }

  static int _lifePath(DateTime dob) {
    final digits = '${dob.day}${dob.month}${dob.year}'
        .split('')
        .map(int.parse)
        .reduce((a, b) => a + b);
    return _reduce(digits);
  }

  static int _nameNumber(String name, bool Function(String) filter) {
    final chars = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final sum = chars
        .split('')
        .where(filter)
        .map(_letterValue)
        .fold(0, (a, b) => a + b);
    return _reduce(sum);
  }

  static int _letterValue(String ch) {
    const map = {
      'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5, 'f': 6, 'g': 7, 'h': 8,
      'i': 9, 'j': 1, 'k': 2, 'l': 3, 'm': 4, 'n': 5, 'o': 6, 'p': 7,
      'q': 8, 'r': 9, 's': 1, 't': 2, 'u': 3, 'v': 4, 'w': 5, 'x': 6,
      'y': 7, 'z': 8,
    };
    return map[ch] ?? 0;
  }

  static bool _full(String _) => true;
  static bool _vowels(String c) => 'aeiou'.contains(c);
  static bool _consonants(String c) => !'aeiou'.contains(c);

  static int _reduce(int n) {
    // Master numbers 11 and 22 are not reduced in classic numerology
    if (n == 11 || n == 22) return n;
    while (n > 9) {
      n = n.toString().split('').map(int.parse).reduce((a, b) => a + b);
      if (n == 11 || n == 22) return n;
    }
    return n;
  }

  String get lifePathMeaning => _meanings[lifePath] ?? '';
  String get expressionMeaning => _meanings[expression] ?? '';
  String get soulUrgeMeaning => _meanings[soulUrge] ?? '';
  String get personalityMeaning => _meanings[personality] ?? '';
}

const _meanings = <int, String>{
  1: 'Leadership, independence, ambition. You are a pioneer and original thinker.',
  2: 'Cooperation, balance, diplomacy. You work best in partnership.',
  3: 'Creativity, self-expression, optimism. Communication is your gift.',
  4: 'Stability, discipline, hard work. You build lasting foundations.',
  5: 'Freedom, adaptability, adventure. Change energises you.',
  6: 'Responsibility, nurturing, harmony. Family and community matter deeply.',
  7: 'Introspection, spirituality, analysis. You seek deeper truths.',
  8: 'Power, abundance, authority. Material success is within your reach.',
  9: 'Compassion, idealism, completion. You are here to serve humanity.',
  11: 'Master number: spiritual insight and illumination. High intuition.',
  22: 'Master number: master builder. Grand visions made reality.',
};
