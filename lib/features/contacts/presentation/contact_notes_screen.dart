import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight contact notes / mini-CRM: store people with tags, notes, last contact.
class ContactNotesScreen extends StatefulWidget {
  const ContactNotesScreen({super.key});

  @override
  State<ContactNotesScreen> createState() => _ContactNotesScreenState();
}

class _Contact {
  String id;
  String name;
  String phone;
  String email;
  String company;
  List<String> tags;
  String notes;
  DateTime? lastContact;
  int followUpDays; // 0 = no follow-up

  _Contact({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.company = '',
    List<String>? tags,
    this.notes = '',
    this.lastContact,
    this.followUpDays = 0,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        'ph': phone,
        'em': email,
        'co': company,
        'tg': tags,
        'nt': notes,
        'lc': lastContact?.toIso8601String(),
        'fu': followUpDays,
      };

  factory _Contact.fromJson(Map<String, dynamic> j) => _Contact(
        id: j['id'] as String,
        name: j['n'] as String,
        phone: j['ph'] as String? ?? '',
        email: j['em'] as String? ?? '',
        company: j['co'] as String? ?? '',
        tags: (j['tg'] as List?)?.cast<String>() ?? [],
        notes: j['nt'] as String? ?? '',
        lastContact:
            j['lc'] != null ? DateTime.parse(j['lc'] as String) : null,
        followUpDays: j['fu'] as int? ?? 0,
      );

  bool get needsFollowUp {
    if (followUpDays <= 0 || lastContact == null) return false;
    final due = lastContact!.add(Duration(days: followUpDays));
    return due.isBefore(DateTime.now());
  }
}

const _prefKey = 'contacts_v1';

class _ContactNotesScreenState extends State<ContactNotesScreen> {
  List<_Contact> _contacts = [];
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
        _contacts =
            list.map((e) => _Contact.fromJson(e as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_contacts.map((c) => c.toJson()).toList()));
  }

  List<_Contact> get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.company.toLowerCase().contains(q) ||
        c.tags.any((t) => t.toLowerCase().contains(q))).toList();
  }

  void _showDetail(_Contact? existing) {
    final namCtrl = TextEditingController(text: existing?.name ?? '');
    final phCtrl = TextEditingController(text: existing?.phone ?? '');
    final emCtrl = TextEditingController(text: existing?.email ?? '');
    final coCtrl = TextEditingController(text: existing?.company ?? '');
    final ntCtrl = TextEditingController(text: existing?.notes ?? '');
    final tgCtrl = TextEditingController(text: existing?.tags.join(', ') ?? '');
    int followUp = existing?.followUpDays ?? 0;
    DateTime? lastContact = existing?.lastContact;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'New Contact' : 'Edit Contact',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: namCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *', border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: coCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. client, friend, mentor',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ntCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lastContact == null
                      ? 'Last contact: never'
                      : 'Last: ${lastContact!.day}/${lastContact!.month}/${lastContact!.year}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: lastContact ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setLS(() => lastContact = d);
                    },
                    child: const Text('Set'),
                  ),
                ),
                Row(children: [
                  const Text('Follow-up in:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: followUp,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('None')),
                      DropdownMenuItem(value: 7, child: Text('1 week')),
                      DropdownMenuItem(value: 14, child: Text('2 weeks')),
                      DropdownMenuItem(value: 30, child: Text('1 month')),
                      DropdownMenuItem(value: 90, child: Text('3 months')),
                    ],
                    onChanged: (v) => setLS(() => followUp = v ?? 0),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  if (existing != null)
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _contacts.remove(existing));
                        _save();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error),
                      child: const Text('Delete'),
                    ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = namCtrl.text.trim();
                      if (name.isEmpty) return;
                      final tags = tgCtrl.text
                          .split(',')
                          .map((t) => t.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();
                      setState(() {
                        if (existing != null) {
                          existing.name = name;
                          existing.phone = phCtrl.text.trim();
                          existing.email = emCtrl.text.trim();
                          existing.company = coCtrl.text.trim();
                          existing.notes = ntCtrl.text.trim();
                          existing.tags = tags;
                          existing.lastContact = lastContact;
                          existing.followUpDays = followUp;
                        } else {
                          _contacts.add(_Contact(
                            id: DateTime.now().toIso8601String(),
                            name: name,
                            phone: phCtrl.text.trim(),
                            email: emCtrl.text.trim(),
                            company: coCtrl.text.trim(),
                            notes: ntCtrl.text.trim(),
                            tags: tags,
                            lastContact: lastContact,
                            followUpDays: followUp,
                          ));
                        }
                      });
                      _save();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final followUps = _contacts.where((c) => c.needsFollowUp).length;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts${followUps > 0 ? ' ($followUps follow-up)' : ''}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDetail(null),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, company or tag…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _contacts.isEmpty ? 'No contacts yet' : 'No matches',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(c.name[0].toUpperCase()),
                        ),
                        title: Row(children: [
                          Text(c.name),
                          if (c.needsFollowUp) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.notifications_active,
                                size: 14, color: scheme.error),
                          ],
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (c.company.isNotEmpty) Text(c.company),
                            if (c.tags.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                children: c.tags
                                    .map((t) => Chip(
                                          label: Text(t),
                                          visualDensity:
                                              VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ))
                                    .toList(),
                              ),
                          ],
                        ),
                        onTap: () => _showDetail(c),
                        isThreeLine: c.company.isNotEmpty || c.tags.isNotEmpty,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
