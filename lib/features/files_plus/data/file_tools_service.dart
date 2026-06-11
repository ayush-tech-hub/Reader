import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Offline file intelligence: duplicate detection, storage analysis,
/// batch rename and one-way folder sync. Pure Dart, streamed I/O.
class FileToolsService {
  const FileToolsService();

  // ---- Duplicate detection -------------------------------------------

  /// Finds exact duplicates under [rootPath]: candidates are grouped by
  /// size first (cheap), then confirmed with a streamed SHA-256.
  Future<List<List<String>>> findDuplicates(String rootPath) async {
    final bySize = <int, List<File>>{};
    await for (final file in _walkFiles(rootPath)) {
      final length = await file.length();
      if (length == 0) continue;
      bySize.putIfAbsent(length, () => []).add(file);
    }
    final duplicates = <List<String>>[];
    for (final group in bySize.values.where((g) => g.length > 1)) {
      final byHash = <String, List<String>>{};
      for (final file in group) {
        try {
          final digest = await sha256.bind(file.openRead()).first;
          byHash.putIfAbsent(digest.toString(), () => []).add(file.path);
        } on FileSystemException {
          continue;
        }
      }
      duplicates.addAll(byHash.values.where((g) => g.length > 1));
    }
    duplicates.sort((a, b) => b.length.compareTo(a.length));
    return duplicates;
  }

  // ---- Storage analyzer -------------------------------------------------

  Future<StorageReport> analyzeStorage(String rootPath) async {
    var totalBytes = 0;
    var fileCount = 0;
    final byExtension = <String, int>{};
    final largest = <(String path, int size)>[];
    await for (final file in _walkFiles(rootPath)) {
      final size = await file.length();
      totalBytes += size;
      fileCount++;
      final ext = p.extension(file.path).toLowerCase();
      byExtension[ext.isEmpty ? '(none)' : ext] =
          (byExtension[ext.isEmpty ? '(none)' : ext] ?? 0) + size;
      largest.add((file.path, size));
      if (largest.length > 200) {
        largest.sort((a, b) => b.$2.compareTo(a.$2));
        largest.removeRange(100, largest.length);
      }
    }
    largest.sort((a, b) => b.$2.compareTo(a.$2));
    final extensions = byExtension.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return StorageReport(
      totalBytes: totalBytes,
      fileCount: fileCount,
      largestFiles: largest.take(25).toList(),
      byExtension: extensions,
    );
  }

  // ---- Batch rename ----------------------------------------------------

  /// Pattern tokens: {name} original base name, {ext} extension with
  /// dot, {n} 1-based counter. Returns old → new path mapping without
  /// touching disk; [applyRename] performs it.
  static Map<String, String> planRename(List<String> paths, String pattern) {
    final plan = <String, String>{};
    var counter = 1;
    for (final path in paths) {
      final dir = p.dirname(path);
      final ext = p.extension(path);
      final base = p.basenameWithoutExtension(path);
      final newName = pattern
          .replaceAll('{name}', base)
          .replaceAll('{ext}', ext)
          .replaceAll('{n}', '$counter');
      counter++;
      final target =
          newName.contains('.') ? newName : '$newName$ext';
      plan[path] = p.join(dir, target);
    }
    return plan;
  }

  Future<int> applyRename(Map<String, String> plan) async {
    var renamed = 0;
    for (final entry in plan.entries) {
      if (entry.key == entry.value) continue;
      if (await File(entry.value).exists()) continue; // never overwrite
      await File(entry.key).rename(entry.value);
      renamed++;
    }
    return renamed;
  }

  // ---- Folder sync (one-way mirror) ----------------------------------

  /// Copies files newer in [sourceDir] into [destinationDir]; with
  /// [deleteOrphans] files that no longer exist in the source are
  /// removed from the destination.
  Future<SyncResult> syncFolders({
    required String sourceDir,
    required String destinationDir,
    bool deleteOrphans = false,
  }) async {
    var copied = 0;
    var deleted = 0;
    await for (final file in _walkFiles(sourceDir)) {
      final relative = p.relative(file.path, from: sourceDir);
      final target = File(p.join(destinationDir, relative));
      final sourceStat = await file.stat();
      final exists = await target.exists();
      if (!exists ||
          (await target.stat()).modified.isBefore(sourceStat.modified)) {
        await target.parent.create(recursive: true);
        final sink = target.openWrite();
        try {
          await sink.addStream(file.openRead());
        } finally {
          await sink.close();
        }
        copied++;
      }
    }
    if (deleteOrphans) {
      await for (final file in _walkFiles(destinationDir)) {
        final relative = p.relative(file.path, from: destinationDir);
        if (!await File(p.join(sourceDir, relative)).exists()) {
          await file.delete();
          deleted++;
        }
      }
    }
    return SyncResult(copied: copied, deleted: deleted);
  }

  Stream<File> _walkFiles(String rootPath) async* {
    final pending = [Directory(rootPath)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Directory) pending.add(entity);
          if (entity is File) yield entity;
        }
      } on FileSystemException {
        continue;
      }
    }
  }
}

class StorageReport {
  const StorageReport({
    required this.totalBytes,
    required this.fileCount,
    required this.largestFiles,
    required this.byExtension,
  });

  final int totalBytes;
  final int fileCount;
  final List<(String path, int size)> largestFiles;
  final List<MapEntry<String, int>> byExtension;
}

class SyncResult {
  const SyncResult({required this.copied, required this.deleted});

  final int copied;
  final int deleted;
}
