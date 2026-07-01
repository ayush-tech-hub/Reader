import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A single item in the recycle bin.
class TrashItem {
  const TrashItem({
    required this.id,
    required this.originalPath,
    required this.trashPath,
    required this.trashedAt,
    required this.isDirectory,
  });

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        id: json['id'] as String,
        originalPath: json['originalPath'] as String,
        trashPath: json['trashPath'] as String,
        trashedAt: DateTime.parse(json['trashedAt'] as String),
        isDirectory: json['isDirectory'] as bool? ?? false,
      );

  final String id;
  final String originalPath;
  final String trashPath;
  final DateTime trashedAt;
  final bool isDirectory;

  String get name => p.basename(originalPath);

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalPath': originalPath,
        'trashPath': trashPath,
        'trashedAt': trashedAt.toIso8601String(),
        'isDirectory': isDirectory,
      };
}

/// Moves deleted files to a hidden trash folder instead of removing them
/// permanently, and provides restore / permanent-delete / empty-bin operations.
///
/// Trash lives at `<applicationSupportDirectory>/.trash/` — out of sight
/// from the file browser but accessible to this service.  A JSON manifest
/// (`manifest.json`) tracks original paths so items can be restored.
class RecycleBinService {
  Directory? _trashDir;
  File? _manifestFile;

  Future<Directory> _getTrashDir() async {
    if (_trashDir != null) return _trashDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, '.trash'));
    await dir.create(recursive: true);
    _trashDir = dir;
    return dir;
  }

  Future<File> _getManifest() async {
    if (_manifestFile != null) return _manifestFile!;
    final dir = await _getTrashDir();
    _manifestFile = File(p.join(dir.path, 'manifest.json'));
    return _manifestFile!;
  }

  Future<List<TrashItem>> getItems() async {
    final f = await _getManifest();
    if (!await f.exists()) return [];
    try {
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final list = json['items'] as List<dynamic>? ?? [];
      return list
          .cast<Map<String, dynamic>>()
          .map(TrashItem.fromJson)
          .where((i) => File(i.trashPath).existsSync() ||
              Directory(i.trashPath).existsSync())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveItems(List<TrashItem> items) async {
    final f = await _getManifest();
    await f.writeAsString(
      jsonEncode({'items': items.map((i) => i.toJson()).toList()}),
    );
  }

  /// Moves [paths] to the trash folder. Returns without throwing on errors
  /// (individual items are skipped on failure).
  Future<void> moveToTrash(List<String> paths) async {
    final dir = await _getTrashDir();
    final existing = await getItems();

    for (final path in paths) {
      try {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;

        final id = _uuid();
        final name = p.basename(path);
        final trashPath = p.join(dir.path, '${id}_$name');
        final isDir = type == FileSystemEntityType.directory;

        if (isDir) {
          await Directory(path).rename(trashPath);
        } else {
          await File(path).rename(trashPath);
        }

        existing.add(TrashItem(
          id: id,
          originalPath: path,
          trashPath: trashPath,
          trashedAt: DateTime.now(),
          isDirectory: isDir,
        ));
      } catch (_) {
        // Skip items that cannot be moved (e.g. cross-volume failure).
      }
    }
    await _saveItems(existing);
  }

  /// Restores [item] to its original location.
  /// Throws if the destination already exists or the restore fails.
  Future<void> restore(TrashItem item) async {
    final dest = item.originalPath;
    if (await File(dest).exists() || await Directory(dest).exists()) {
      throw Exception('A file already exists at the original location');
    }
    await Directory(p.dirname(dest)).create(recursive: true);
    if (item.isDirectory) {
      await Directory(item.trashPath).rename(dest);
    } else {
      await File(item.trashPath).rename(dest);
    }
    final items = await getItems();
    await _saveItems(items.where((i) => i.id != item.id).toList());
  }

  /// Permanently removes [item] from the trash.
  Future<void> deletePermanently(TrashItem item) async {
    try {
      if (item.isDirectory) {
        await Directory(item.trashPath).delete(recursive: true);
      } else {
        await File(item.trashPath).delete();
      }
    } catch (_) {}
    final items = await getItems();
    await _saveItems(items.where((i) => i.id != item.id).toList());
  }

  /// Permanently deletes everything in the trash.
  Future<void> emptyTrash() async {
    final items = await getItems();
    for (final item in items) {
      try {
        if (item.isDirectory) {
          await Directory(item.trashPath).delete(recursive: true);
        } else {
          await File(item.trashPath).delete();
        }
      } catch (_) {}
    }
    await _saveItems([]);
  }

  /// Auto-removes items older than [days] days. Call on startup.
  Future<void> purgeOlderThan(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final items = await getItems();
    final toKeep = <TrashItem>[];
    for (final item in items) {
      if (item.trashedAt.isBefore(cutoff)) {
        try {
          if (item.isDirectory) {
            await Directory(item.trashPath).delete(recursive: true);
          } else {
            await File(item.trashPath).delete();
          }
        } catch (_) {}
      } else {
        toKeep.add(item);
      }
    }
    await _saveItems(toKeep);
  }

  static String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now.toRadixString(36);
  }
}
