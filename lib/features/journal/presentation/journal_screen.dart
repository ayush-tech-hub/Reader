import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily journaling with mood tracking and date navigation.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

const _moods = ['😢', '😕', '😐', '😊', '😄'];
const _moodLabels = ['Sad', 'Meh', 'Neutral', 'Good', 'Great'];
const _prefKey = 'journal_entries_v1';

class _Entry {
  String text;
  int mood; // 0–4
  final String dateKey; // 'YYYY-MM-DD'

  _Entry({required this.text, required this.mood, required this.dateKey});

  Map<String, dynamic> toJson() => {'t': text, 'm': mood, 'd': dateKey};
  factory _Entry.fromJson(Map<String, dynamic> j) => _Entry(
        text: j['t'] as String,
        mood: j['m'] as int? ?? 2,
        dateKey: j['d'] as String,
      );
}

String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

String _fmtDate(DateTime dt) {
  const months = ['January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class _JournalScreenState extends State<JournalScreen> {
  final Map<String, _Entry> _entries = {};
  DateTime _current = DateTime.now();
  bool _editing = false;
  late TextEditingController _ctrl;
  int _mood = 2;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final map = jsonDecode(raw) as Map;
      setState(() {
        for (final kv in map.entries) {
          _entries[kv.key] =
              _Entry.fromJson(kv.value as Map<String, dynamic>);
        }
        _syncToDate();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey,
        jsonEncode(Map.fromEntries(
            _entries.entries.map((e) => MapEntry(e.key, e.value.toJson())))));
  }

  void _syncToDate() {
    final key = _dateKey(_current);
    final entry = _entries[key];
    if (entry != null) {
      _ctrl.text = entry.text;
      _mood = entry.mood;
    } else {
      _ctrl.clear();
      _mood = 2;
    }
  }

  void _goBack() {
    if (_editing) _saveEntry();
    setState(() {
      _current = _current.subtract(const Duration(days: 1));
      _editing = false;
      _syncToDate();
    });
  }

  void _goForward() {
    if (_editing) _saveEntry();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_current.isBefore(tomorrow)) {
      setState(() {
        _current = _current.add(const Duration(days: 1));
        _editing = false;
        _syncToDate();
      });
    }
  }

  void _saveEntry() {
    final key = _dateKey(_current);
    final text = _ctrl.text.trim();
    if (text.isNotEmpty) {
      _entries[key] = _Entry(text: text, mood: _mood, dateKey: key);
    } else {
      _entries.remove(key);
    }
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = _dateKey(_current);
    final entry = _entries[key];
    final isToday = _dateKey(_current) == _dateKey(DateTime.now());
    final isFuture = _current.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'All entries',
            onPressed: _showList,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    onPressed: _goBack, icon: const Icon(Icons.chevron_left)),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _current,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      if (_editing) _saveEntry();
                      setState(() {
                        _current = picked;
                        _editing = false;
                        _syncToDate();
                      });
                    }
                  },
                  child: Column(
                    children: [
                      Text(_fmtDate(_current),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (isToday)
                        Text('Today',
                            style: TextStyle(
                                color: scheme.primary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isFuture ? null : _goForward,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const Divider(),
            if (isFuture)
              const Expanded(
                child: Center(child: Text("Can't journal in the future.")),
              )
            else if (_editing) ...[
              // Mood selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _moods.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _mood = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _moods[i],
                          style: TextStyle(
                              fontSize: _mood == i ? 32 : 22,
                              opacity: _mood == i ? 1 : 0.4),
                        ),
                      ),
                    ),
                ],
              ),
              Text(_moodLabels[_mood],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Write about your day…',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  _saveEntry();
                  setState(() => _editing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry saved')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Entry'),
              ),
            ] else ...[
              Expanded(
                child: entry == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note,
                                size: 48,
                                color: scheme.onSurface.withOpacity(0.3)),
                            const SizedBox(height: 8),
                            Text(
                              isToday
                                  ? 'No entry yet today'
                                  : 'No entry for this day',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(_moods[entry.mood],
                                  style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 8),
                              Text(_moodLabels[entry.mood],
                                  style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                entry.text,
                                style: const TextStyle(fontSize: 16, height: 1.7),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              FilledButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: Icon(entry == null ? Icons.edit : Icons.edit),
                label: Text(entry == null ? 'Write entry' : 'Edit entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) {
          final sorted = _entries.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('All Entries (${sorted.length})',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = sorted[i];
                    return ListTile(
                      leading: Text(_moods[e.value.mood],
                          style: const TextStyle(fontSize: 22)),
                      title: Text(e.key),
                      subtitle: Text(
                        e.value.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        final dt = DateTime.parse(e.key);
                        setState(() {
                          _current = dt;
                          _editing = false;
                          _syncToDate();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
