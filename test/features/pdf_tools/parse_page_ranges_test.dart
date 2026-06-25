import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/features/pdf_tools/domain/entities/pdf_tool_entities.dart';
import 'package:opendocs_manager/features/pdf_tools/presentation/screens/pdf_tools_screen.dart';

void main() {
  group('parsePageRanges', () {
    test('parses single pages and ranges', () {
      expect(parsePageRanges('1-3, 5, 8-10'), const [
        PageRange(1, 3),
        PageRange(5, 5),
        PageRange(8, 10),
      ]);
    });

    test('ignores invalid fragments', () {
      expect(parsePageRanges('0, -2, abc, 4-2, 7'), const [PageRange(7, 7)]);
    });

    test('handles whitespace and empty input', () {
      expect(parsePageRanges('  2 - 4 '), const [PageRange(2, 4)]);
      expect(parsePageRanges(''), isEmpty);
    });
  });
}
