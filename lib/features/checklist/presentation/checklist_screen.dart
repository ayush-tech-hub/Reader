import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple persistent checklist / to-do screen.
///
/// Items are stored in SharedPreferences as JSON so they survive app restarts.
/// Useful for tracking reading tasks, research steps, or document review
/// items without leaving the app.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistItem {
  _ChecklistItem({required this.text, this.done = false});

  factory _ChecklistItem.fromJson(Map<String, dynamic> j) =>
      _ChecklistItem(text: j['text'] as String, done: j['done'] as bool);

  String text;
  bool done;

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  static const _prefsKey = 'checklist_items_v1';
  List<_ChecklistItem> _items = [];
  bool _loaded = false;
  final _addCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _items = list
            .map((e) => _ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  void _add() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _items.add(_ChecklistItem(text: text)));
    _addCtrl.clear();
    _focusNode.requestFocus();
    _save();
  }

  void _toggle(int index) {
    setState(() => _items[index].done = !_items[index].done);
    _save();
  }

  void _delete(int index) {
    setState(() => _items.removeAt(index));
    _save();
  }

  void _clearDone() {
    setState(() => _items.removeWhere((i) => i.done));
    _save();
  }

  int get _doneCount => _items.where((i) => i.done).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist'),
        actions: [
          if (_doneCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18),
              label: Text('Clear $_doneCount done'),
              onPressed: _clearDone,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: LinearProgressIndicator(
                      value: _items.isEmpty ? 0 : _doneCount / _items.length,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$_doneCount / ${_items.length} done',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.checklist_outlined,
                                  size: 64,
                                  color: scheme.onSurfaceVariant.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'No items yet.\nType a task below to add it.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _items.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                            });
                            _save();
                          },
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return Dismissible(
                              key: ValueKey('$i-${item.text}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _delete(i),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.red,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              child: ListTile(
                                key: ValueKey('tile-$i'),
                                leading: Checkbox(
                                  value: item.done,
                                  onChanged: (_) => _toggle(i),
                                ),
                                title: Text(
                                  item.text,
                                  style: TextStyle(
                                    decoration: item.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.done
                                        ? scheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                trailing: const Icon(Icons.drag_handle,
                                    color: Colors.grey),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      8 + MediaQuery.of(context).viewInsets.bottom),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addCtrl,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: 'New task…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _add,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(52, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
