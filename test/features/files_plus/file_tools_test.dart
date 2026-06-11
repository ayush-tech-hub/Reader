import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/features/files_plus/data/file_tools_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('planRename', () {
    test('expands {name}, {n} and {ext} tokens', () {
      final plan = FileToolsService.planRename(
        ['/docs/report.pdf', '/docs/data.csv'],
        'archive_{n}_{name}{ext}',
      );
      expect(plan['/docs/report.pdf'], '/docs/archive_1_report.pdf');
      expect(plan['/docs/data.csv'], '/docs/archive_2_data.csv');
    });

    test('keeps the original extension when the pattern has none', () {
      final plan =
          FileToolsService.planRename(['/x/photo.jpg'], 'holiday_{n}');
      expect(plan['/x/photo.jpg'], '/x/holiday_1.jpg');
    });
  });

  group('findDuplicates', () {
    test('groups files with identical content only', () async {
      final dir = await Directory.systemTemp.createTemp('opendocs_test');
      addTearDown(() => dir.delete(recursive: true));
      await File(p.join(dir.path, 'a.txt')).writeAsString('same content');
      await File(p.join(dir.path, 'b.txt')).writeAsString('same content');
      await File(p.join(dir.path, 'c.txt')).writeAsString('same size!!!');

      final groups =
          await const FileToolsService().findDuplicates(dir.path);

      expect(groups, hasLength(1));
      expect(groups.single, hasLength(2));
      expect(groups.single.map(p.basename), containsAll(['a.txt', 'b.txt']));
    });
  });

  group('syncFolders', () {
    test('mirrors new files and deletes orphans when asked', () async {
      final source = await Directory.systemTemp.createTemp('sync_src');
      final destination = await Directory.systemTemp.createTemp('sync_dst');
      addTearDown(() => source.delete(recursive: true));
      addTearDown(() => destination.delete(recursive: true));
      await File(p.join(source.path, 'keep.txt')).writeAsString('hello');
      await File(p.join(destination.path, 'orphan.txt')).writeAsString('x');

      final result = await const FileToolsService().syncFolders(
        sourceDir: source.path,
        destinationDir: destination.path,
        deleteOrphans: true,
      );

      expect(result.copied, 1);
      expect(result.deleted, 1);
      expect(File(p.join(destination.path, 'keep.txt')).existsSync(), isTrue);
      expect(
        File(p.join(destination.path, 'orphan.txt')).existsSync(),
        isFalse,
      );
    });
  });
}
