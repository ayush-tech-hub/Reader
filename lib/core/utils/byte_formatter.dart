import 'dart:math' as math;

/// Formats a byte count as a human-readable string (binary units).
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 0) return '—';
  if (bytes < 1024) return '$bytes B';
  const suffixes = ['KiB', 'MiB', 'GiB', 'TiB'];
  final exponent = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    suffixes.length,
  );
  final value = bytes / math.pow(1024, exponent);
  return '${value.toStringAsFixed(decimals)} ${suffixes[exponent - 1]}';
}
