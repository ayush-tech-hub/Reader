import 'dart:async';

import 'package:flutter/material.dart';

/// Displays current time in multiple time zones simultaneously.
class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

const _allZones = <(String, String, String)>[
  // (city, UTC offset label, IANA-ish display)
  ('London', 'Europe/London', 'UTC±0/+1'),
  ('New York', 'America/New_York', 'UTC-5/-4'),
  ('Los Angeles', 'America/Los_Angeles', 'UTC-8/-7'),
  ('Chicago', 'America/Chicago', 'UTC-6/-5'),
  ('São Paulo', 'America/Sao_Paulo', 'UTC-3'),
  ('Paris', 'Europe/Paris', 'UTC+1/+2'),
  ('Berlin', 'Europe/Berlin', 'UTC+1/+2'),
  ('Moscow', 'Europe/Moscow', 'UTC+3'),
  ('Dubai', 'Asia/Dubai', 'UTC+4'),
  ('Mumbai', 'Asia/Kolkata', 'UTC+5:30'),
  ('Bangkok', 'Asia/Bangkok', 'UTC+7'),
  ('Shanghai', 'Asia/Shanghai', 'UTC+8'),
  ('Tokyo', 'Asia/Tokyo', 'UTC+9'),
  ('Sydney', 'Australia/Sydney', 'UTC+10/+11'),
  ('Auckland', 'Pacific/Auckland', 'UTC+12/+13'),
  ('Honolulu', 'Pacific/Honolulu', 'UTC-10'),
  ('Toronto', 'America/Toronto', 'UTC-5/-4'),
  ('Mexico City', 'America/Mexico_City', 'UTC-6/-5'),
  ('Buenos Aires', 'America/Argentina/Buenos_Aires', 'UTC-3'),
  ('Johannesburg', 'Africa/Johannesburg', 'UTC+2'),
  ('Cairo', 'Africa/Cairo', 'UTC+2'),
  ('Lagos', 'Africa/Lagos', 'UTC+1'),
  ('Nairobi', 'Africa/Nairobi', 'UTC+3'),
  ('Riyadh', 'Asia/Riyadh', 'UTC+3'),
  ('Singapore', 'Asia/Singapore', 'UTC+8'),
  ('Hong Kong', 'Asia/Hong_Kong', 'UTC+8'),
  ('Seoul', 'Asia/Seoul', 'UTC+9'),
  ('Karachi', 'Asia/Karachi', 'UTC+5'),
  ('Dhaka', 'Asia/Dhaka', 'UTC+6'),
  ('Jakarta', 'Asia/Jakarta', 'UTC+7'),
];

// Static DST-unaware offsets (hours * 60 minutes from UTC).
// Good enough for most use cases; shows "UTC±" label for honesty.
const _offsets = <String, int>{
  'Europe/London': 0,        // approximate (may be BST +60 in summer)
  'America/New_York': -5 * 60,
  'America/Los_Angeles': -8 * 60,
  'America/Chicago': -6 * 60,
  'America/Sao_Paulo': -3 * 60,
  'Europe/Paris': 1 * 60,
  'Europe/Berlin': 1 * 60,
  'Europe/Moscow': 3 * 60,
  'Asia/Dubai': 4 * 60,
  'Asia/Kolkata': 5 * 60 + 30,
  'Asia/Bangkok': 7 * 60,
  'Asia/Shanghai': 8 * 60,
  'Asia/Tokyo': 9 * 60,
  'Australia/Sydney': 10 * 60,
  'Pacific/Auckland': 12 * 60,
  'Pacific/Honolulu': -10 * 60,
  'America/Toronto': -5 * 60,
  'America/Mexico_City': -6 * 60,
  'America/Argentina/Buenos_Aires': -3 * 60,
  'Africa/Johannesburg': 2 * 60,
  'Africa/Cairo': 2 * 60,
  'Africa/Lagos': 1 * 60,
  'Africa/Nairobi': 3 * 60,
  'Asia/Riyadh': 3 * 60,
  'Asia/Singapore': 8 * 60,
  'Asia/Hong_Kong': 8 * 60,
  'Asia/Seoul': 9 * 60,
  'Asia/Karachi': 5 * 60,
  'Asia/Dhaka': 6 * 60,
  'Asia/Jakarta': 7 * 60,
};

class _WorldClockScreenState extends State<WorldClockScreen> {
  Timer? _timer;
  DateTime _utcNow = DateTime.now().toUtc();
  final Set<String> _pinned = {
    'Asia/Kolkata', 'Europe/London', 'America/New_York',
    'Asia/Tokyo', 'Asia/Dubai',
  };
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _utcNow = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _localTime(String tz) {
    final offset = _offsets[tz] ?? 0;
    return _utcNow.add(Duration(minutes: offset));
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayed = _showAll
        ? _allZones
        : _allZones.where((z) => _pinned.contains(z.$2)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('World Clock'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? 'Show pinned' : 'Show all'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: displayed.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final (city, tz, utcLabel) = displayed[i];
          final local = _localTime(tz);
          final isPinned = _pinned.contains(tz);
          final isNight = local.hour < 6 || local.hour >= 22;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isNight ? scheme.surfaceContainerHighest : scheme.primaryContainer,
              child: Icon(
                isNight ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                color: isNight ? scheme.onSurfaceVariant : scheme.primary,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(city,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(utcLabel,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
            subtitle: Text(_fmtDate(local)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(local),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ],
            ),
            onLongPress: () => setState(() {
              if (isPinned) {
                _pinned.remove(tz);
              } else {
                _pinned.add(tz);
              }
            }),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Times shown are approximate (standard offset, DST not applied). Long-press to pin/unpin.',
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
