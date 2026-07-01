import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple task manager with priorities, due dates, and categories.
class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

enum _Priority { low, medium, high, urgent }

const _priorityColors = {
  _Priority.low: Colors.grey,
  _Priority.medium: Colors.blue,
  _Priority.high: Colors.orange,
  _Priority.urgent: Colors.red,
};

const _priorityLabels = {
  _Priority.low: 'Low',
  _Priority.medium: 'Medium',
  _Priority.high: 'High',
  _Priority.urgent: 'Urgent',
};

class _Task {
  String id;
  String title;
  String notes;
  _Priority priority;
  bool done;
  DateTime? dueDate;
  String category;

  _Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.priority = _Priority.medium,
    this.done = false,
    this.dueDate,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'n': notes,
        'p': priority.index,
        'd': done,
        'due': dueDate?.toIso8601String(),
        'c': category,
      };

  factory _Task.fromJson(Map<String, dynamic> j) => _Task(
        id: j['id'] as String,
        title: j['t'] as String,
        notes: j['n'] as String? ?? '',
        priority: _Priority.values[j['p'] as int? ?? 1],
        done: j['d'] as bool? ?? false,
        dueDate: j['due'] != null ? DateTime.parse(j['due'] as String) : null,
        category: j['c'] as String? ?? 'General',
      );
}

const _prefKey = 'tasks_v1';
const _defaultCategories = [
  'General', 'Work', 'Personal', 'Shopping', 'Health', 'Finance', 'Study',
];

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  List<_Task> _tasks = [];
  String _filter = 'all'; // 'all' | 'active' | 'done'
  String _sortBy = 'priority'; // 'priority' | 'due' | 'name'

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
        _tasks = list
            .map((e) => _Task.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  List<_Task> get _displayed {
    var tasks = _tasks.where((t) {
      if (_filter == 'active') return !t.done;
      if (_filter == 'done') return t.done;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'priority':
        tasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case 'due':
        tasks.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case 'name':
        tasks.sort((a, b) => a.title.compareTo(b.title));
    }
    return tasks;
  }

  void _addTask() => _showDialog(null);

  void _showDialog(_Task? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    _Priority priority = existing?.priority ?? _Priority.medium;
    String category = existing?.category ?? 'General';
    DateTime? due = existing?.dueDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) => AlertDialog(
          title: Text(existing == null ? 'New Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task *'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_Priority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _Priority.values.map((p) => DropdownMenuItem(
                    value: p,
                    child: Row(children: [
                      Icon(Icons.circle, size: 10, color: _priorityColors[p]),
                      const SizedBox(width: 6),
                      Text(_priorityLabels[p]!),
                    ]),
                  )).toList(),
                  onChanged: (v) => setLS(() => priority = v ?? priority),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _defaultCategories.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setLS(() => category = v ?? category),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(due == null
                      ? 'No due date'
                      : 'Due: ${due!.day}/${due!.month}/${due!.year}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (due != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setLS(() => due = null),
                      ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: due ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (d != null) setLS(() => due = d);
                      },
                      child: const Text('Pick'),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                setState(() {
                  if (existing != null) {
                    existing.title = title;
                    existing.notes = notesCtrl.text.trim();
                    existing.priority = priority;
                    existing.category = category;
                    existing.dueDate = due;
                  } else {
                    _tasks.add(_Task(
                      id: DateTime.now().toIso8601String(),
                      title: title,
                      notes: notesCtrl.text.trim(),
                      priority: priority,
                      category: category,
                      dueDate: due,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayed = _displayed;
    final doneCount = _tasks.where((t) => t.done).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks (${_tasks.length - doneCount} active)'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'priority', child: Text('Sort by priority')),
              PopupMenuItem(value: 'due', child: Text('Sort by due date')),
              PopupMenuItem(value: 'name', child: Text('Sort by name')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'done', label: Text('Done')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
      body: displayed.isEmpty
          ? Center(
              child: Text(
                _tasks.isEmpty ? 'No tasks yet' : 'No tasks in this filter',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
              itemCount: displayed.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final task = displayed[i];
                final color = _priorityColors[task.priority] ?? Colors.grey;
                final isOverdue = task.dueDate != null &&
                    task.dueDate!.isBefore(DateTime.now()) &&
                    !task.done;

                return ListTile(
                  leading: Checkbox(
                    value: task.done,
                    onChanged: (v) {
                      setState(() => task.done = v ?? false);
                      _save();
                    },
                    activeColor: color,
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      color: task.done ? scheme.onSurface.withOpacity(0.4) : null,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _priorityLabels[task.priority]!,
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(task.category,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (task.dueDate != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${task.dueDate!.day}/${task.dueDate!.month}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue ? scheme.error : Colors.grey,
                            fontWeight: isOverdue ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (v) {
                      if (v == 'edit') _showDialog(task);
                      if (v == 'delete') {
                        setState(() => _tasks.remove(task));
                        _save();
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
