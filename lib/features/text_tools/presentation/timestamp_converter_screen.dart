import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Converts Unix timestamps ↔ human-readable date-times.
///
/// Accepts epoch seconds or milliseconds as input and outputs multiple
/// formatted representations (ISO 8601, local, UTC, relative).
/// Also shows the current timestamp for copy-pasting into documents.
class TimestampConverterScreen extends StatefulWidget {
  const TimestampConverterScreen({super.key});

  @override
  State<TimestampConverterScreen> createState() =>
      _TimestampConverterScreenState();
}

class _TimestampConverterScreenState extends State<TimestampConverterScreen> {
  final _tsCtrl = TextEditingController();
  final _dtCtrl = TextEditingController();
  DateTime? _result;
  String? _tsError;
  String? _dtError;

  @override
  void dispose() {
    _tsCtrl.dispose();
    _dtCtrl.dispose();
    super.dispose();
  }

  void _fromTimestamp() {
    final raw = _tsCtrl.text.trim();
    if (raw.isEmpty) return;
    final n = int.tryParse(raw);
    if (n == null) {
      setState(() => _tsError = 'Not a valid integer');
      return;
    }
    // Auto-detect ms vs seconds: > 1e10 is almost certainly milliseconds
    final dt = n > 9999999999
        ? DateTime.fromMillisecondsSinceEpoch(n, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
    setState(() {
      _result = dt;
      _tsError = null;
      _dtCtrl.text = _isoLocal(dt.toLocal());
    });
  }

  void _fromDateTime() {
    final raw = _dtCtrl.text.trim();
    if (raw.isEmpty) return;
    try {
      final dt = DateTime.parse(raw);
      setState(() {
        _result = dt;
        _dtError = null;
        _tsCtrl.text = '${dt.millisecondsSinceEpoch ~/ 1000}';
      });
    } catch (_) {
      setState(() => _dtError = 'Use ISO 8601: 2024-06-15T14:30:00');
    }
  }

  String _isoLocal(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}T'
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    final abs = diff.abs();
    if (abs.inSeconds < 60) return '${abs.inSeconds} seconds ago';
    if (abs.inMinutes < 60) return '${abs.inMinutes} minutes ago';
    if (abs.inHours < 24) return '${abs.inHours} hours ago';
    if (abs.inDays < 7) return '${abs.inDays} days ago';
    if (abs.inDays < 30) return '${(abs.inDays / 7).round()} weeks ago';
    if (abs.inDays < 365) return '${(abs.inDays / 30).round()} months ago';
    return '${(abs.inDays / 365).round()} years ago';
  }

  Widget _row(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();

    return Scaffold(
      appBar: AppBar(title: const Text('Timestamp Converter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current time card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Now',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${now.millisecondsSinceEpoch ~/ 1000}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  '${now.millisecondsSinceEpoch ~/ 1000}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        tooltip: 'Use now',
                        onPressed: () {
                          _tsCtrl.text =
                              '${now.millisecondsSinceEpoch ~/ 1000}';
                          _fromTimestamp();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Epoch → DateTime
          const Text('Unix timestamp → Date/time',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _tsCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Epoch seconds (or milliseconds)',
              border: const OutlineInputBorder(),
              errorText: _tsError,
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'Convert',
                onPressed: _fromTimestamp,
              ),
            ),
            onSubmitted: (_) => _fromTimestamp(),
          ),
          const SizedBox(height: 16),

          // DateTime → Epoch
          const Text('Date/time → Unix timestamp',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _dtCtrl,
            decoration: InputDecoration(
              labelText: 'ISO 8601  (e.g. 2024-06-15T14:30:00)',
              border: const OutlineInputBorder(),
              errorText: _dtError,
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Convert',
                onPressed: _fromDateTime,
              ),
            ),
            onSubmitted: (_) => _fromDateTime(),
          ),

          if (_result != null) ...[
            const SizedBox(height: 20),
            const Text('Results',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Divider(),
            _row('Epoch (s)', '${_result!.millisecondsSinceEpoch ~/ 1000}'),
            _row(
                'Epoch (ms)', '${_result!.millisecondsSinceEpoch}'),
            _row('UTC', _result!.toUtc().toIso8601String()),
            _row('Local', _isoLocal(_result!.toLocal())),
            _row('Relative', _relative(_result!)),
            _row(
              'Weekday',
              const [
                '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
                'Saturday', 'Sunday'
              ][_result!.toLocal().weekday],
            ),
          ],
        ],
      ),
    );
  }
}
