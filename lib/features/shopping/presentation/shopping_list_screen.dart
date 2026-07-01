import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Categorised shopping list with check-off, quantity, and persistent storage.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _Item {
  String name;
  String quantity;
  String category;
  bool checked;
  final String id;

  _Item({
    required this.id,
    required this.name,
    this.quantity = '',
    this.category = 'Other',
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        'q': quantity,
        'c': category,
        'ch': checked,
      };

  factory _Item.fromJson(Map<String, dynamic> j) => _Item(
        id: j['id'] as String,
        name: j['n'] as String,
        quantity: j['q'] as String? ?? '',
        category: j['c'] as String? ?? 'Other',
        checked: j['ch'] as bool? ?? false,
      );
}

const _categories = [
  'Fruit & Veg',
  'Dairy',
  'Meat & Fish',
  'Bakery',
  'Frozen',
  'Drinks',
  'Snacks',
  'Household',
  'Personal Care',
  'Other',
];

const _prefKey = 'shopping_list_v1';

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<_Item> _items = [];
  String _filterCat = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _items = list
            .map((e) => _Item.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  List<_Item> get _filtered {
    if (_filterCat == 'All') return _items;
    return _items.where((i) => i.category == _filterCat).toList();
  }

  void _add() {
    _showItemDialog(null);
  }

  void _showItemDialog(_Item? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(text: existing?.quantity ?? '');
    String cat = existing?.category ?? 'Other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) => AlertDialog(
          title: Text(existing == null ? 'Add Item' : 'Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item name *'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                    labelText: 'Quantity', hintText: 'e.g. 2, 500g, 1 bunch'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: cat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setLS(() => cat = v ?? 'Other'),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  if (existing != null) {
                    existing.name = name;
                    existing.quantity = qtyCtrl.text.trim();
                    existing.category = cat;
                  } else {
                    _items.add(_Item(
                      id: DateTime.now().toIso8601String(),
                      name: name,
                      quantity: qtyCtrl.text.trim(),
                      category: cat,
                    ));
                  }
                });
                _save();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearChecked() {
    setState(() => _items.removeWhere((i) => i.checked));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    final checkedCount = _items.where((i) => i.checked).length;

    // Group by category
    final grouped = <String, List<_Item>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping List (${_items.length})'),
        actions: [
          if (checkedCount > 0)
            TextButton(
              onPressed: _clearChecked,
              child: Text('Clear $checkedCount ✓'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final cat in ['All', ..._categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _filterCat == cat,
                      onSelected: (_) =>
                          setState(() => _filterCat = cat),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          if (_items.isEmpty)
            const Expanded(
              child: Center(child: Text('Tap + to add items')),
            )
          else if (filtered.isEmpty)
            const Expanded(
              child: Center(child: Text('No items in this category')),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                children: [
                  for (final cat in sortedKeys) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        cat,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                            fontSize: 13),
                      ),
                    ),
                    for (final item in grouped[cat]!)
                      Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          setState(() => _items.remove(item));
                          _save();
                        },
                        background: Container(
                          color: scheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(Icons.delete, color: scheme.onError),
                        ),
                        child: CheckboxListTile(
                          value: item.checked,
                          onChanged: (v) {
                            setState(() => item.checked = v ?? false);
                            _save();
                          },
                          title: Text(
                            item.name,
                            style: TextStyle(
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.checked
                                  ? scheme.onSurface.withOpacity(0.4)
                                  : null,
                            ),
                          ),
                          subtitle: item.quantity.isNotEmpty
                              ? Text(item.quantity)
                              : null,
                          secondary: IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () => _showItemDialog(item),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
