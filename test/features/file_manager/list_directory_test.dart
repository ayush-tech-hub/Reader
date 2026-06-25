import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/features/file_manager/domain/entities/file_entry.dart';
import 'package:opendocs_manager/features/file_manager/domain/usecases/file_usecases.dart';

FileEntry _file(String name, {int size = 0, int day = 1}) => FileEntry(
      path: '/$name',
      name: name,
      isDirectory: false,
      size: size,
      modifiedAt: DateTime(2026, 1, day),
    );

FileEntry _dir(String name) => FileEntry(
      path: '/$name',
      name: name,
      isDirectory: true,
      size: 0,
      modifiedAt: DateTime(2026),
    );

void main() {
  group('ListDirectory.sortEntries', () {
    final entries = [
      _file('beta.pdf', size: 300, day: 3),
      _dir('zeta'),
      _file('Alpha.txt', size: 100, day: 5),
      _dir('archive'),
      _file('gamma.zip', size: 200, day: 1),
    ];

    test('directories always come first', () {
      final sorted = ListDirectory.sortEntries(
        entries,
        FileSortField.name,
        true,
      );
      expect(sorted.take(2).every((e) => e.isDirectory), isTrue);
    });

    test('sorts by name case-insensitively', () {
      final sorted = ListDirectory.sortEntries(
        entries,
        FileSortField.name,
        true,
      );
      expect(sorted.map((e) => e.name).toList(), [
        'archive',
        'zeta',
        'Alpha.txt',
        'beta.pdf',
        'gamma.zip',
      ]);
    });

    test('sorts by size descending', () {
      final sorted = ListDirectory.sortEntries(
        entries,
        FileSortField.size,
        false,
      );
      final files = sorted.where((e) => !e.isDirectory).toList();
      expect(files.map((e) => e.size).toList(), [300, 200, 100]);
    });

    test('sorts by date ascending', () {
      final sorted = ListDirectory.sortEntries(
        entries,
        FileSortField.date,
        true,
      );
      final files = sorted.where((e) => !e.isDirectory).toList();
      expect(files.map((e) => e.name).toList(), [
        'gamma.zip',
        'beta.pdf',
        'Alpha.txt',
      ]);
    });

    test('does not mutate the input list', () {
      final before = List.of(entries);
      ListDirectory.sortEntries(entries, FileSortField.size, true);
      expect(entries, before);
    });
  });
}
