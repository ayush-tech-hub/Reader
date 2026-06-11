import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/core/utils/byte_formatter.dart';

void main() {
  group('formatBytes', () {
    test('formats sub-kilobyte values as bytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('formats binary units', () {
      expect(formatBytes(1024), '1.0 KiB');
      expect(formatBytes(1536), '1.5 KiB');
      expect(formatBytes(1024 * 1024), '1.0 MiB');
      expect(formatBytes(5 * 1024 * 1024 * 1024), '5.0 GiB');
    });

    test('handles >10GB archives', () {
      expect(formatBytes(11 * 1024 * 1024 * 1024), '11.0 GiB');
    });

    test('negative sizes render as a placeholder', () {
      expect(formatBytes(-1), '—');
    });
  });
}
