import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/features/pdf_reader/data/datasources/reader_local_datasource.dart';
import 'package:opendocs_manager/features/pdf_reader/domain/entities/reader_entities.dart';

void main() {
  group('annotation geometry codec', () {
    test('round-trips text-markup rects', () {
      final annotation = Annotation(
        documentPath: '/a.pdf',
        page: 3,
        type: AnnotationType.highlight,
        color: 0xFFFFEB3B,
        rects: const [PageRect(10, 20, 110, 36), PageRect(10, 40, 90, 56)],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final json = ReaderLocalDataSource.encodeGeometry(annotation);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(ReaderLocalDataSource.decodeRects(decoded), annotation.rects);
      expect(ReaderLocalDataSource.decodeStrokes(decoded), isEmpty);
    });

    test('round-trips ink strokes', () {
      final annotation = Annotation(
        documentPath: '/a.pdf',
        page: 1,
        type: AnnotationType.ink,
        color: 0xFFFF0000,
        strokes: const [
          [PagePoint(1, 2), PagePoint(3.5, 4.25), PagePoint(6, 8)],
          [PagePoint(10, 10), PagePoint(20, 20)],
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final json = ReaderLocalDataSource.encodeGeometry(annotation);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(ReaderLocalDataSource.decodeStrokes(decoded), annotation.strokes);
      expect(ReaderLocalDataSource.decodeRects(decoded), isEmpty);
    });
  });
}
