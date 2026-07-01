import 'dart:math';

import 'package:flutter/material.dart';

/// Random decision-maker: enter items, spin to pick one.
class RandomPickerScreen extends StatefulWidget {
  const RandomPickerScreen({super.key});

  @override
  State<RandomPickerScreen> createState() => _RandomPickerScreenState();
}

class _RandomPickerScreenState extends State<RandomPickerScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final List<String> _items = [];
  String? _picked;
  final _rng = Random();
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    // Allow multiple lines/commas as separate items
    final parts = text
        .split(RegExp(r'[,\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    setState(() => _items.addAll(parts));
    _inputCtrl.clear();
  }

  void _pick() {
    if (_items.isEmpty) return;
    setState(() => _picked = _items[_rng.nextInt(_items.length)]);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Picker'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all',
              onPressed: () => setState(() {
                _items.clear();
                _picked = null;
              }),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Add items (comma or newline separated)',
                      hintText: 'Pizza, Sushi, Tacos',
                    ),
                    maxLines: 2,
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addItem,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_items.isNotEmpty) ...[
              Text('${_items.length} item${_items.length == 1 ? '' : 's'}:',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _items
                    .asMap()
                    .entries
                    .map((e) => Chip(
                          label: Text(e.value),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _items.removeAt(e.key)),
                        ))
                    .toList(),
              ),
            ],
            const Spacer(),
            if (_picked != null) ...[
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: Card(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text('🎲',
                              style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            _picked!,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimaryContainer,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            FilledButton.icon(
              onPressed: _items.isEmpty ? null : _pick,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Pick One!'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
            const SizedBox(height: 8),
            // Number picker variant
            if (_items.isEmpty)
              OutlinedButton.icon(
                onPressed: () => _showNumberPicker(),
                icon: const Icon(Icons.numbers),
                label: const Text('Random Number'),
              ),
          ],
        ),
      ),
    );
  }

  void _showNumberPicker() {
    final minCtrl = TextEditingController(text: '1');
    final maxCtrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Random Number'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('–'),
            ),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lo = int.tryParse(minCtrl.text) ?? 1;
              final hi = int.tryParse(maxCtrl.text) ?? 100;
              if (lo >= hi) return;
              final result = lo + _rng.nextInt(hi - lo + 1);
              Navigator.pop(ctx);
              setState(() => _picked = '$result');
              _anim.forward(from: 0);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
