import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personal budget tracker: income / expense entries with category totals.
class BudgetTrackerScreen extends StatefulWidget {
  const BudgetTrackerScreen({super.key});

  @override
  State<BudgetTrackerScreen> createState() => _BudgetTrackerScreenState();
}

enum _Type { income, expense }

const _incomeCategories = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'];
const _expenseCategories = [
  'Food', 'Transport', 'Rent', 'Utilities', 'Healthcare',
  'Entertainment', 'Clothing', 'Education', 'Savings', 'Other',
];

class _Entry {
  String id;
  String title;
  double amount;
  _Type type;
  String category;
  DateTime date;
  String note;

  _Entry({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'a': amount,
        'tp': type.index,
        'c': category,
        'dt': date.toIso8601String(),
        'n': note,
      };

  factory _Entry.fromJson(Map<String, dynamic> j) => _Entry(
        id: j['id'] as String,
        title: j['t'] as String,
        amount: (j['a'] as num).toDouble(),
        type: _Type.values[j['tp'] as int? ?? 1],
        category: j['c'] as String? ?? 'Other',
        date: DateTime.parse(j['dt'] as String),
        note: j['n'] as String? ?? '',
      );
}

const _prefKey = 'budget_v1';

class _BudgetTrackerScreenState extends State<BudgetTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _entries =
            list.map((e) => _Entry.fromJson(e as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  double get _totalIncome => _entries
      .where((e) => e.type == _Type.income)
      .fold(0.0, (s, e) => s + e.amount);

  double get _totalExpense => _entries
      .where((e) => e.type == _Type.expense)
      .fold(0.0, (s, e) => s + e.amount);

  double get _balance => _totalIncome - _totalExpense;

  void _addEntry() => _showDialog(null);

  void _showDialog(_Entry? existing) {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final amountCtrl =
        TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    _Type type = existing?.type ?? _Type.expense;
    String category = existing?.category ?? 'Other';
    DateTime date = existing?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLS) {
          final cats =
              type == _Type.income ? _incomeCategories : _expenseCategories;
          if (!cats.contains(category)) category = cats.first;

          return AlertDialog(
            title: Text(existing == null ? 'New Entry' : 'Edit Entry'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<_Type>(
                    segments: const [
                      ButtonSegment(value: _Type.income, label: Text('Income')),
                      ButtonSegment(value: _Type.expense, label: Text('Expense')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) =>
                        setLS(() { type = s.first; category = 'Other'; }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount *', prefixText: '\$ '),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setLS(() => category = v ?? category),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Date: ${date.day}/${date.month}/${date.year}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setLS(() => date = d);
                      },
                      child: const Text('Change'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  final amount = double.tryParse(amountCtrl.text);
                  if (title.isEmpty || amount == null || amount <= 0) return;
                  setState(() {
                    if (existing != null) {
                      existing.title = title;
                      existing.amount = amount;
                      existing.type = type;
                      existing.category = category;
                      existing.date = date;
                      existing.note = noteCtrl.text.trim();
                    } else {
                      _entries.add(_Entry(
                        id: DateTime.now().toIso8601String(),
                        title: title,
                        amount: amount,
                        type: type,
                        category: category,
                        date: date,
                        note: noteCtrl.text.trim(),
                      ));
                    }
                  });
                  _save();
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balance = _balance;
    final balanceColor = balance >= 0 ? Colors.green : scheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Tracker'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Summary'),
            Tab(text: 'By Category'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Balance banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: scheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BannerItem('Income', _totalIncome, Colors.green),
                _BannerItem('Balance', balance, balanceColor, bold: true),
                _BannerItem('Expenses', _totalExpense, scheme.error),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _TransactionList(
                  entries: [..._entries]..sort((a, b) => b.date.compareTo(a.date)),
                  onEdit: _showDialog,
                  onDelete: (e) {
                    setState(() => _entries.remove(e));
                    _save();
                  },
                ),
                _SummaryTab(
                  income: _totalIncome,
                  expense: _totalExpense,
                  balance: _balance,
                  count: _entries.length,
                ),
                _CategoryTab(entries: _entries),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem(this.label, this.amount, this.color, {this.bold = false});
  final String label;
  final double amount;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            '\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 18 : 15,
            ),
          ),
        ],
      );
}

class _TransactionList extends StatelessWidget {
  const _TransactionList(
      {required this.entries, required this.onEdit, required this.onDelete});
  final List<_Entry> entries;
  final void Function(_Entry) onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No transactions yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = entries[i];
        final isIncome = e.type == _Type.income;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                (isIncome ? Colors.green : Colors.red).withOpacity(0.15),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(e.title),
          subtitle: Text('${e.category}  •  ${e.date.day}/${e.date.month}/${e.date.year}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '${isIncome ? '+' : '-'}\$${e.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit(e);
                if (v == 'delete') onDelete(e);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        );
      },
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.income,
    required this.expense,
    required this.balance,
    required this.count,
  });
  final double income, expense, balance;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = income + expense;
    final incomeRatio = total == 0 ? 0.5 : income / total;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow('Total Income', '+\$${income.toStringAsFixed(2)}',
                      Colors.green),
                  _SummaryRow('Total Expenses', '-\$${expense.toStringAsFixed(2)}',
                      scheme.error),
                  const Divider(),
                  _SummaryRow(
                    'Balance',
                    '${balance >= 0 ? '+' : '-'}\$${balance.abs().toStringAsFixed(2)}',
                    balance >= 0 ? Colors.green : scheme.error,
                    bold: true,
                  ),
                  _SummaryRow('Transactions', count.toString(), scheme.onSurface),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (total > 0) ...[
            const Text('Income vs Expenses',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [
                Flexible(
                  flex: (incomeRatio * 100).round(),
                  child: Container(height: 28, color: Colors.green),
                ),
                Flexible(
                  flex: ((1 - incomeRatio) * 100).round(),
                  child: Container(height: 28, color: Colors.red),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Income ${(incomeRatio * 100).round()}%',
                    style: const TextStyle(color: Colors.green, fontSize: 12)),
                Text('Expenses ${((1 - incomeRatio) * 100).round()}%',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, this.color, {this.bold = false});
  final String label, value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.entries});
  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    final expMap = <String, double>{};
    final incMap = <String, double>{};
    for (final e in entries) {
      if (e.type == _Type.expense) {
        expMap[e.category] = (expMap[e.category] ?? 0) + e.amount;
      } else {
        incMap[e.category] = (incMap[e.category] ?? 0) + e.amount;
      }
    }
    final expList = expMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final incList = incMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalExp =
        expList.fold(0.0, (s, e) => s + e.value);

    if (entries.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (expList.isNotEmpty) ...[
          const Text('Expenses by Category',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in expList)
            _CategoryBar(
                e.key, e.value, totalExp == 0 ? 0 : e.value / totalExp,
                Colors.red),
          const SizedBox(height: 16),
        ],
        if (incList.isNotEmpty) ...[
          const Text('Income by Category',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in incList)
            _CategoryBar(e.key, e.value, 1.0, Colors.green),
        ],
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar(this.label, this.amount, this.ratio, this.color);
  final String label;
  final double amount, ratio;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                Text('\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              backgroundColor: color.withOpacity(0.15),
              minHeight: 6,
            ),
          ],
        ),
      );
}
