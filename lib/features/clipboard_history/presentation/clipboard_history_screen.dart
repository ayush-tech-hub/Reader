import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMaxItems = 100;
const _kKey = 'clipboard_history_v1';

class ClipboardEntry {
  ClipboardEntry({
    required this.text,
    required this.savedAt,
  });

  final String text;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'text': text,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory ClipboardEntry.fromJson(Map<String, dynamic> json) => ClipboardEntry(
        text: json['text'] as String,
        savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int),
      );
}

/// Service for reading and writing clipboard history.
class ClipboardHistoryService {
  Future<List<ClipboardEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ClipboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(String text) async {
    if (text.trim().isEmpty) return;
    final entries = await load();
    // Deduplicate.
    entries.removeWhere((e) => e.text == text);
    entries.insert(0, ClipboardEntry(text: text, savedAt: DateTime.now()));
    if (entries.length > _kMaxItems) {
      entries.removeRange(_kMaxItems, entries.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> delete(int index) async {
    final entries = await load();
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ClipboardHistoryScreen extends StatefulWidget {
  const ClipboardHistoryScreen({super.key});

  @override
  State<ClipboardHistoryScreen> createState() => _ClipboardHistoryScreenState();
}

class _ClipboardHistoryScreenState extends State<ClipboardHistoryScreen> {
  final _service = ClipboardHistoryService();
  List<ClipboardEntry> _entries = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _service.load();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _capture() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    await _service.add(text);
    await _load();
  }

  List<ClipboardEntry> get _filtered {
    if (_query.trim().isEmpty) return _entries;
    final q = _query.toLowerCase();
    return _entries.where((e) => e.text.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard history'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'Save current clipboard',
            onPressed: _capture,
          ),
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear clipboard history?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) {
                  await _service.clear();
                  await _load();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _entries.isEmpty
                              ? 'No clipboard history.\n'
                                'Copy text and tap the paste icon to save it.'
                              : 'No matches for "$_query"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.outline),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final entry = filtered[i];
                          final globalIdx = _entries.indexOf(entry);
                          return Dismissible(
                            key: ValueKey(
                                '${entry.savedAt.millisecondsSinceEpoch}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: scheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: Icon(Icons.delete_outline,
                                  color: scheme.onError),
                            ),
                            onDismissed: (_) async {
                              await _service.delete(globalIdx);
                              await _load();
                            },
                            child: Card(
                              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: ListTile(
                                title: Text(
                                  entry.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_relative(entry.savedAt)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copy',
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: entry.text),
                                    );
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text('Copied')),
                                      );
                                    }
                                  },
                                ),
                                onTap: () =>
                                    _showFull(context, entry.text),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showFull(BuildContext context, String text) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            AppBar(
              title: const Text('Clipboard entry'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                  },
                ),
              ],
              automaticallyImplyLeading: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                child: SelectableText(text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}
