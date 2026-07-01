import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Count down to (or since) custom named events.
class EventCountdownScreen extends StatefulWidget {
  const EventCountdownScreen({super.key});

  @override
  State<EventCountdownScreen> createState() => _EventCountdownScreenState();
}

class _CountdownEvent {
  String name;
  DateTime date;
  String emoji;

  _CountdownEvent({required this.name, required this.date, this.emoji = '🎉'});

  Map<String, dynamic> toJson() => {
        'n': name,
        'd': date.toIso8601String(),
        'e': emoji,
      };

  factory _CountdownEvent.fromJson(Map<String, dynamic> j) => _CountdownEvent(
        name: j['n'] as String,
        date: DateTime.parse(j['d'] as String),
        emoji: j['e'] as String? ?? '🎉',
      );
}

const _emojis = ['🎉', '🎂', '🏖️', '💼', '🎓', '💍', '✈️', '🎄', '🎵', '🏆', '❤️', '🌟'];
const _prefKey = 'events_v1';

class _EventCountdownScreenState extends State<EventCountdownScreen> {
  List<_CountdownEvent> _events = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _events = list
            .map((e) => _CountdownEvent.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  void _addEvent() {
    _showDialog(null);
  }

  void _showDialog(_CountdownEvent? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now().add(const Duration(days: 7));
    String selectedEmoji = existing?.emoji ?? '🎉';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) => AlertDialog(
          title: Text(existing == null ? 'Add Event' : 'Edit Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Event name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Text(selectedEmoji, style: const TextStyle(fontSize: 24)),
                title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                subtitle: const Text('Tap to change date'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setLS(() => selectedDate = d);
                },
              ),
              Wrap(
                spacing: 4,
                children: _emojis.map((e) => GestureDetector(
                  onTap: () => setLS(() => selectedEmoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: e == selectedEmoji
                          ? Border.all(
                              color: Theme.of(ctx).colorScheme.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                )).toList(),
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
                    existing.date = selectedDate;
                    existing.emoji = selectedEmoji;
                  } else {
                    _events.add(_CountdownEvent(
                        name: name, date: selectedDate, emoji: selectedEmoji));
                    _events.sort((a, b) => a.date.compareTo(b.date));
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

  String _fmtDiff(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    final abs = diff.abs();
    final past = diff.isNegative;
    final d = abs.inDays;
    final h = abs.inHours % 24;
    final m = abs.inMinutes % 60;
    final s = abs.inSeconds % 60;
    String txt;
    if (d > 0) {
      txt = '$d day${d == 1 ? '' : 's'}, $h h';
    } else if (h > 0) {
      txt = '$h h $m min';
    } else if (m > 0) {
      txt = '$m min $s sec';
    } else {
      txt = '$s seconds';
    }
    return past ? '$txt ago' : 'In $txt';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Event Countdown')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        child: const Icon(Icons.add),
      ),
      body: _events.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 56,
                      color: scheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Text('No events yet',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  const Text('Tap + to add your first event'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _events.length,
              itemBuilder: (_, i) {
                final ev = _events[i];
                final isPast = ev.date.isBefore(now);
                final diff = ev.date.difference(now).abs();
                final totalDays = diff.inDays + 1;

                return Card(
                  color: isPast
                      ? scheme.surfaceContainerHighest
                      : scheme.primaryContainer,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(ev.emoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ev.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isPast
                                          ? scheme.onSurfaceVariant
                                          : scheme.onPrimaryContainer)),
                              Text(
                                '${ev.date.day}/${ev.date.month}/${ev.date.year}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isPast
                                        ? scheme.onSurfaceVariant
                                        : scheme.onPrimaryContainer.withOpacity(0.7)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fmtDiff(ev.date),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: isPast
                                        ? scheme.onSurfaceVariant
                                        : scheme.primary),
                              ),
                              if (!isPast)
                                Text(
                                  '$totalDays days total',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onPrimaryContainer
                                          .withOpacity(0.6)),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (v) {
                            if (v == 'edit') _showDialog(ev);
                            if (v == 'delete') {
                              setState(() => _events.remove(ev));
                              _save();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
