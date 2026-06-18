import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/storage_scanner.dart';

/// A single pie slice: pre-resolved color/value pair so the painter stays
/// agnostic of [StorageCategory].
class StorageSlice {
  const StorageSlice({required this.color, required this.bytes});

  final Color color;
  final int bytes;
}

/// Animated donut chart for the storage breakdown. Slices animate their
/// sweep angle in on first build/update via an [AnimatedBuilder] driven by
/// the parent; this widget itself is a stateless painter wrapper.
class StoragePieChart extends StatelessWidget {
  const StoragePieChart({
    super.key,
    required this.slices,
    required this.progress,
    this.size = 220,
    this.centerLabel,
    this.centerSubLabel,
  });

  final List<StorageSlice> slices;

  /// 0..1 animation progress for the sweep-in effect.
  final double progress;
  final double size;
  final String? centerLabel;
  final String? centerSubLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _PiePainter(
              slices: slices,
              progress: progress,
              trackColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (centerLabel != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (centerSubLabel != null)
                  Text(
                    centerSubLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.progress,
    required this.trackColor,
  });

  final List<StorageSlice> slices;
  final double progress;
  final Color trackColor;

  static const _strokeWidth = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(_strokeWidth / 2);
    final total = slices.fold<int>(0, (sum, s) => sum + s.bytes);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..color = trackColor;
    canvas.drawArc(inner, 0, 2 * math.pi, false, track);

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.bytes <= 0) continue;
      final sweep = (slice.bytes / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(inner, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor;
}
