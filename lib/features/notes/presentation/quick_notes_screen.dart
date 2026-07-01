import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight quick-notes with colour tagging and search.
class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _Note {
  _Note({
    required this.id,
    required this.content,
    this.color = 0,
    required this.createdAt,
  });

  final String id;
  String content;
  int color; // index into _noteColors
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'c': content,
        'col': color,
        'ts': createdAt.millisecondsSinceEpoch,
      };

  factory _Note.fromJson(Map<String, dynamic> j) => _Note(
        id: j['id'] as String,
        content: j['c'] as String,
        color: j['col'] as int? ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );
}

const _noteColors = [
  Colors.transparent,
  Color(0xFFFFF9C4), // yellow
  Color(0xFFCCFF90), // green
  Color(0xFF80DEEA), // cyan
  Color(0xFFCF94DA), // purple
  Color(0xFFFFAB91), // orange
];
const _noteColorLabels = ['Default', 'Yellow', 'Green', 'Cyan', 'Purple', 'Orange'];
const _prefKey = 'quick_notes_v1';

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  List<_Note> _notes = [];
  String _search = '';

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
        _notes = list
            .map((e) => _Note.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  List<_Note> get _filtered {
    if (_search.isEmpty) return _notes;
    final q = _search.toLowerCase();
    return _notes.where((n) => n.content.toLowerCase().contains(q)).toList();
  }

  void _add() {
    _editNote(null);
  }

  void _editNote(_Note? note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NoteEditor(
        note: note,
        onSave: (content, color) {
          setState(() {
            if (note == null) {
              _notes.insert(0, _Note(
                id: DateTime.now().toIso8601String(),
                content: content,
                color: color,
                createdAt: DateTime.now(),
              ));
            } else {
              note.content = content;
              note.color = color;
            }
          });
          _save();
        },
      ),
    );
  }

  void _delete(_Note note) {
    setState(() => _notes.remove(note));
    _save();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Notes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search notes…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Text(
                _notes.isEmpty
                    ? 'No notes yet.\nTap + to create one.'
                    : 'No matching notes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final note = filtered[i];
                final bgColor = _noteColors[note.color.clamp(0, _noteColors.length - 1)];
                return Card(
                  color: bgColor == Colors.transparent ? null : bgColor,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _editNote(note),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.content,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(note.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: note.content));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Copied')));
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _delete(note),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.note, required this.onSave});
  final _Note? note;
  final void Function(String, int) onSave;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _ctrl;
  late int _color;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.note?.content ?? '');
    _color = widget.note?.color ?? 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.note == null ? 'New Note' : 'Edit Note',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 8,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Write your note…',
            ),
          ),
          const SizedBox(height: 10),
          // Color picker
          Row(
            children: [
              const Text('Colour: ', style: TextStyle(fontSize: 12)),
              for (var i = 0; i < _noteColors.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _noteColors[i] == Colors.transparent
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : _noteColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final text = _ctrl.text.trim();
              if (text.isEmpty) return;
              widget.onSave(text, _color);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
