import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "To Be Read" reading list — add titles with optional author and notes.
class ReadingListScreen extends StatefulWidget {
  const ReadingListScreen({super.key});

  @override
  State<ReadingListScreen> createState() => _ReadingListScreenState();
}

enum _ReadStatus { unread, reading, done }

class _ReadingItem {
  _ReadingItem({
    required this.title,
    this.author = '',
    this.notes = '',
    this.status = _ReadStatus.unread,
  });

  factory _ReadingItem.fromJson(Map<String, dynamic> j) => _ReadingItem(
        title: j['title'] as String,
        author: j['author'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        status: _ReadStatus.values[j['status'] as int? ?? 0],
      );

  String title;
  String author;
  String notes;
  _ReadStatus status;

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'notes': notes,
        'status': status.index,
      };
}

class _ReadingListScreenState extends State<ReadingListScreen> {
  static const _key = 'reading_list_v1';
  List<_ReadingItem> _items = [];
  bool _loaded = false;

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
        _items = list
            .map((e) => _ReadingItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  void _delete(int i) {
    setState(() => _items.removeAt(i));
    _save();
  }

  Future<void> _openAddDialog([int? editIndex]) async {
    final item =
        editIndex != null ? _items[editIndex] : _ReadingItem(title: '');
    final titleCtrl = TextEditingController(text: item.title);
    final authorCtrl = TextEditingController(text: item.author);
    final notesCtrl = TextEditingController(text: item.notes);
    var status = item.status;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title:
              Text(editIndex == null ? 'Add to Reading List' : 'Edit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: authorCtrl,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_ReadStatus>(
                  value: status,
                  items: [
                    DropdownMenuItem(
                        value: _ReadStatus.unread, child: const Text('Unread')),
                    DropdownMenuItem(
                        value: _ReadStatus.reading,
                        child: const Text('Currently reading')),
                    DropdownMenuItem(
                        value: _ReadStatus.done, child: const Text('Done')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => status = v);
                  },
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final newTitle = titleCtrl.text.trim();
    if (newTitle.isEmpty) return;

    final newItem = _ReadingItem(
      title: newTitle,
      author: authorCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      status: status,
    );

    setState(() {
      if (editIndex != null) {
        _items[editIndex] = newItem;
      } else {
        _items.add(newItem);
      }
    });
    _save();
  }

  Color _statusColor(_ReadStatus s) => switch (s) {
        _ReadStatus.unread => Colors.grey,
        _ReadStatus.reading => Colors.orange,
        _ReadStatus.done => Colors.green,
      };

  IconData _statusIcon(_ReadStatus s) => switch (s) {
        _ReadStatus.unread => Icons.bookmark_border,
        _ReadStatus.reading => Icons.auto_stories,
        _ReadStatus.done => Icons.check_circle_outline,
      };

  String _statusLabel(_ReadStatus s) => switch (s) {
        _ReadStatus.unread => 'Unread',
        _ReadStatus.reading => 'Reading',
        _ReadStatus.done => 'Done',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final unread = _items.where((i) => i.status == _ReadStatus.unread).length;
    final reading =
        _items.where((i) => i.status == _ReadStatus.reading).length;
    final done = _items.where((i) => i.status == _ReadStatus.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading List'),
        actions: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatChip(unread, Colors.grey, 'unread'),
                  const SizedBox(width: 4),
                  _StatChip(reading, Colors.orange, 'reading'),
                  const SizedBox(width: 4),
                  _StatChip(done, Colors.green, 'done'),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        tooltip: 'Add book',
        child: const Icon(Icons.add),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 64,
                          color:
                              scheme.onSurfaceVariant.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('Your reading list is empty.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return Dismissible(
                      key: ValueKey('$i-${item.title}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(i),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red,
                        child: const Icon(Icons.delete,
                            color: Colors.white),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            _statusIcon(item.status),
                            color: _statusColor(item.status),
                          ),
                          title: Text(item.title,
                              style: TextStyle(
                                decoration: item.status == _ReadStatus.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                          subtitle: Text([
                            if (item.author.isNotEmpty) item.author,
                            _statusLabel(item.status),
                          ].join(' · ')),
                          trailing: PopupMenuButton<String>(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                      dense: true,
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Edit'))),
                              for (final s in _ReadStatus.values)
                                if (s != item.status)
                                  PopupMenuItem(
                                    value: 'status-${s.index}',
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(_statusIcon(s),
                                          color: _statusColor(s)),
                                      title: Text('Mark as ${_statusLabel(s)}'),
                                    ),
                                  ),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                      dense: true,
                                      leading: Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      title: Text('Delete',
                                          style: TextStyle(
                                              color: Colors.red)))),
                            ],
                            onSelected: (v) {
                              if (v == 'edit') {
                                _openAddDialog(i);
                              } else if (v.startsWith('status-')) {
                                final idx = int.parse(v.split('-')[1]);
                                setState(() =>
                                    _items[i].status =
                                        _ReadStatus.values[idx]);
                                _save();
                              } else if (v == 'delete') {
                                _delete(i);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.count, this.color, this.label);
  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$count $label',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.3)),
      );
}
