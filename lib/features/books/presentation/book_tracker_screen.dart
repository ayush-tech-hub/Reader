import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Track books: want to read, reading, and finished — with ratings and notes.
class BookTrackerScreen extends StatefulWidget {
  const BookTrackerScreen({super.key});

  @override
  State<BookTrackerScreen> createState() => _BookTrackerScreenState();
}

enum _BookStatus { wantToRead, reading, read }

const _statusLabels = {
  _BookStatus.wantToRead: 'Want to Read',
  _BookStatus.reading: 'Reading',
  _BookStatus.read: 'Read',
};

const _statusIcons = {
  _BookStatus.wantToRead: Icons.bookmark_border,
  _BookStatus.reading: Icons.auto_stories,
  _BookStatus.read: Icons.check_circle_outline,
};

class _Book {
  String id;
  String title;
  String author;
  _BookStatus status;
  int rating; // 0-5 stars
  String notes;
  final DateTime added;

  _Book({
    required this.id,
    required this.title,
    required this.author,
    this.status = _BookStatus.wantToRead,
    this.rating = 0,
    this.notes = '',
    required this.added,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'a': author,
        's': status.index,
        'r': rating,
        'n': notes,
        'ts': added.millisecondsSinceEpoch,
      };

  factory _Book.fromJson(Map<String, dynamic> j) => _Book(
        id: j['id'] as String,
        title: j['t'] as String,
        author: j['a'] as String? ?? '',
        status: _BookStatus.values[j['s'] as int? ?? 0],
        rating: j['r'] as int? ?? 0,
        notes: j['n'] as String? ?? '',
        added: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int? ?? 0),
      );
}

const _prefKey = 'book_tracker_v1';

class _BookTrackerScreenState extends State<BookTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<_Book> _books = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _books = list
            .map((e) => _Book.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_books.map((b) => b.toJson()).toList()));
  }

  List<_Book> _forStatus(_BookStatus s) {
    final books = _books.where((b) => b.status == s).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      return books
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.author.toLowerCase().contains(q))
          .toList();
    }
    return books;
  }

  void _addOrEdit([_Book? existing]) {
    showDialog(
      context: context,
      builder: (ctx) => _BookDialog(
        existing: existing,
        onSave: (book) {
          setState(() {
            if (existing != null) {
              final i = _books.indexWhere((b) => b.id == existing.id);
              if (i >= 0) _books[i] = book;
            } else {
              _books.insert(0, book);
            }
          });
          _save();
        },
      ),
    );
  }

  void _delete(_Book book) {
    setState(() => _books.removeWhere((b) => b.id == book.id));
    _save();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Book removed')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Tracker'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final s in _BookStatus.values)
              Tab(
                icon: Icon(_statusIcons[s], size: 18),
                text: _statusLabels[s],
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addOrEdit,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search books…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final s in _BookStatus.values)
                  _BookList(
                    books: _forStatus(s),
                    status: s,
                    onEdit: _addOrEdit,
                    onDelete: _delete,
                    onStatusChange: (book, newStatus) {
                      setState(() => book.status = newStatus);
                      _save();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({
    required this.books,
    required this.status,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  final List<_Book> books;
  final _BookStatus status;
  final void Function(_Book) onEdit;
  final void Function(_Book) onDelete;
  final void Function(_Book, _BookStatus) onStatusChange;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Text(
          'No books in "${_statusLabels[status]}"',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final book = books[i];
        return ListTile(
          leading: const Icon(Icons.book_outlined),
          title: Text(book.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.author.isNotEmpty) Text(book.author),
              if (book.rating > 0)
                Row(
                  children: [
                    for (var j = 0; j < 5; j++)
                      Icon(
                        j < book.rating ? Icons.star : Icons.star_border,
                        size: 14,
                        color: Colors.amber,
                      ),
                  ],
                ),
              if (book.notes.isNotEmpty)
                Text(
                  book.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          isThreeLine: book.notes.isNotEmpty,
          trailing: PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              for (final s in _BookStatus.values)
                if (s != status)
                  PopupMenuItem(
                    value: s.name,
                    child: Row(children: [
                      Icon(_statusIcons[s], size: 16),
                      const SizedBox(width: 6),
                      Text('Move to ${_statusLabels[s]}'),
                    ]),
                  ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (v) {
              if (v == 'edit') onEdit(book);
              if (v == 'delete') onDelete(book);
              for (final s in _BookStatus.values) {
                if (v == s.name) onStatusChange(book, s);
              }
            },
          ),
        );
      },
    );
  }
}

class _BookDialog extends StatefulWidget {
  const _BookDialog({this.existing, required this.onSave});
  final _Book? existing;
  final void Function(_Book) onSave;

  @override
  State<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<_BookDialog> {
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  _BookStatus _status = _BookStatus.wantToRead;
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!.title;
      _authorCtrl.text = widget.existing!.author;
      _notesCtrl.text = widget.existing!.notes;
      _status = widget.existing!.status;
      _rating = widget.existing!.rating;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Book' : 'Edit Book'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _authorCtrl,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<_BookStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: _BookStatus.values.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_statusLabels[s]!),
                  )).toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Rating: '),
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setState(() => _rating = _rating == i ? 0 : i),
                    child: Icon(
                      i <= _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes / Review'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) return;
            widget.onSave(_Book(
              id: widget.existing?.id ??
                  DateTime.now().toIso8601String(),
              title: title,
              author: _authorCtrl.text.trim(),
              status: _status,
              rating: _rating,
              notes: _notesCtrl.text.trim(),
              added: widget.existing?.added ?? DateTime.now(),
            ));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
