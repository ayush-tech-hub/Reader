import 'package:flutter/material.dart';

import '../../domain/entities/reader_entities.dart';

/// Paints stored annotations over a rendered page. [scale] converts
/// PDF page points to the widget's logical pixels.
class AnnotationPainter extends CustomPainter {
  const AnnotationPainter({required this.annotations, required this.scale});

  final List<Annotation> annotations;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      final paint = Paint()
        ..color = Color(annotation.color).withValues(alpha: annotation.opacity)
        ..strokeWidth = annotation.strokeWidth * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      switch (annotation.type) {
        case AnnotationType.highlight:
          paint.style = PaintingStyle.fill;
          for (final rect in annotation.rects) {
            canvas.drawRect(_toRect(rect), paint);
          }
        case AnnotationType.underline:
          paint.style = PaintingStyle.stroke;
          for (final rect in annotation.rects) {
            final r = _toRect(rect);
            canvas.drawLine(r.bottomLeft, r.bottomRight, paint);
          }
        case AnnotationType.strikeout:
          paint.style = PaintingStyle.stroke;
          for (final rect in annotation.rects) {
            final r = _toRect(rect);
            canvas.drawLine(r.centerLeft, r.centerRight, paint);
          }
        case AnnotationType.ink:
          paint.style = PaintingStyle.stroke;
          for (final stroke in annotation.strokes) {
            if (stroke.length < 2) continue;
            final path = Path()
              ..moveTo(stroke.first.x * scale, stroke.first.y * scale);
            for (final point in stroke.skip(1)) {
              path.lineTo(point.x * scale, point.y * scale);
            }
            canvas.drawPath(path, paint);
          }
        case AnnotationType.note:
          paint.style = PaintingStyle.fill;
          for (final rect in annotation.rects) {
            final r = _toRect(rect);
            canvas.drawCircle(r.center, 8 * scale, paint);
          }
      }
    }
  }

  Rect _toRect(PageRect rect) => Rect.fromLTRB(
    rect.left * scale,
    rect.top * scale,
    rect.right * scale,
    rect.bottom * scale,
  );

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) =>
      oldDelegate.annotations != annotations || oldDelegate.scale != scale;
}

/// Captures freehand ink strokes in page coordinates while the ink tool
/// is active, then hands the finished stroke to [onStrokeFinished].
class InkCaptureOverlay extends StatefulWidget {
  const InkCaptureOverlay({
    super.key,
    required this.scale,
    required this.color,
    required this.onStrokeFinished,
  });

  final double scale;
  final Color color;
  final ValueChanged<List<PagePoint>> onStrokeFinished;

  @override
  State<InkCaptureOverlay> createState() => _InkCaptureOverlayState();
}

class _InkCaptureOverlayState extends State<InkCaptureOverlay> {
  final List<Offset> _current = [];

  void _addPoint(Offset localPosition) {
    setState(() => _current.add(localPosition));
  }

  void _finish() {
    if (_current.length >= 2) {
      widget.onStrokeFinished([
        for (final offset in _current)
          PagePoint(offset.dx / widget.scale, offset.dy / widget.scale),
      ]);
    }
    setState(_current.clear);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _addPoint(details.localPosition),
      onPanUpdate: (details) => _addPoint(details.localPosition),
      onPanEnd: (_) => _finish(),
      child: CustomPaint(
        painter: _LiveStrokePainter(points: _current, color: widget.color),
        size: Size.infinite,
      ),
    );
  }
}

class _LiveStrokePainter extends CustomPainter {
  const _LiveStrokePainter({required this.points, required this.color});

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LiveStrokePainter oldDelegate) => true;
}
