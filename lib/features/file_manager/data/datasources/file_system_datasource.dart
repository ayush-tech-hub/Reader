import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/platform/native_channels.dart';
import '../../domain/entities/file_entry.dart';

/// Direct filesystem access (dart:io) plus the native storage channel
/// for enumerating volume roots (internal + removable).
class FileSystemDataSource {
  FileSystemDataSource({MethodChannel? storageChannel})
    : _storage = storageChannel ?? const MethodChannel(NativeChannels.storage);

  final MethodChannel _storage;

  Future<List<StorageRoot>> getStorageRoots() async {
    try {
      final raw = await _storage.invokeListMethod<Map<dynamic, dynamic>>(
        StorageMethods.getRoots,
      );
      if (raw != null && raw.isNotEmpty) {
        return raw
            .map(
              (m) => StorageRoot(
                path: m['path'] as String,
                label: m['label'] as String,
                isRemovable: m['removable'] as bool,
                totalBytes: (m['totalBytes'] as num?)?.toInt() ?? 0,
                freeBytes: (m['freeBytes'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList();
      }
    } on MissingPluginException {
      // Fall through to path_provider (dev desktops, tests).
    } on PlatformException catch (e) {
      throw NativeEngineException('Failed to enumerate storage', e);
    }
    final docs = await getApplicationDocumentsDirectory();
    return [
      StorageRoot(path: docs.path, label: 'Documents', isRemovable: false),
    ];
  }

  Future<List<FileEntry>> listDirectory(
    String path, {
    required bool showHidden,
  }) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw FileSystemException2('Directory not found: $path');
    }
    final entries = <FileEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      final entry = await _toEntry(entity);
      if (entry == null) continue;
      if (!showHidden && entry.isHidden) continue;
      entries.add(entry);
    }
    return entries;
  }

  /// Streams matches from a recursive, case-insensitive name search.
  /// Unreadable subtrees (permission denied, vanished dirs) are skipped
  /// instead of killing the whole search.
  Stream<FileEntry> search(String rootPath, String query) async* {
    final needle = query.toLowerCase();
    if (needle.isEmpty) return;
    final pending = <Directory>[Directory(rootPath)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Directory) pending.add(entity);
          if (p.basename(entity.path).toLowerCase().contains(needle)) {
            final entry = await _toEntry(entity);
            if (entry != null) yield entry;
          }
        }
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<void> copy(List<String> sources, String destinationDir) async {
    _ensureNotIntoSelf(sources, destinationDir);
    for (final source in sources) {
      final target = p.join(destinationDir, p.basename(source));
      if (p.equals(source, target)) continue;
      final type = await FileSystemEntity.type(source, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(source), Directory(target));
      } else {
        await _copyFileStreamed(File(source), File(target));
      }
    }
  }

  Future<void> move(List<String> sources, String destinationDir) async {
    _ensureNotIntoSelf(sources, destinationDir);
    for (final source in sources) {
      final target = p.join(destinationDir, p.basename(source));
      if (p.equals(source, target)) continue;
      final type = await FileSystemEntity.type(source, followLinks: false);
      try {
        if (type == FileSystemEntityType.directory) {
          await Directory(source).rename(target);
        } else {
          await File(source).rename(target);
        }
      } on FileSystemException {
        // Cross-volume move: copy then delete.
        await copy([source], destinationDir);
        await delete([source]);
      }
    }
  }

  Future<void> rename(String path, String newName) async {
    if (newName.contains(p.separator) || newName.isEmpty) {
      throw FileSystemException2('Invalid name: $newName');
    }
    final target = p.join(p.dirname(path), newName);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).rename(target);
    } else {
      await File(path).rename(target);
    }
  }

  Future<void> delete(List<String> paths) async {
    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type != FileSystemEntityType.notFound) {
        await File(path).delete();
      }
    }
  }

  Future<void> createDirectory(String parentPath, String name) async {
    if (name.contains(p.separator) || name.isEmpty) {
      throw FileSystemException2('Invalid folder name: $name');
    }
    await Directory(p.join(parentPath, name)).create();
  }

  /// Copying/moving a directory into itself (or into one of its own
  /// descendants) would recurse forever and fill the disk.
  void _ensureNotIntoSelf(List<String> sources, String destinationDir) {
    for (final source in sources) {
      if (p.equals(source, destinationDir) ||
          p.isWithin(source, destinationDir)) {
        throw FileSystemException2('Cannot copy or move a folder into itself');
      }
    }
  }

  Future<FileEntry?> _toEntry(FileSystemEntity entity) async {
    try {
      final stat = await entity.stat();
      final name = p.basename(entity.path);
      final isDir = stat.type == FileSystemEntityType.directory;
      return FileEntry(
        path: entity.path,
        name: name,
        isDirectory: isDir,
        size: isDir ? 0 : stat.size,
        modifiedAt: stat.modified,
        isHidden: name.startsWith('.'),
      );
    } on FileSystemException {
      return null; // unreadable entry — skip
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await _copyFileStreamed(entity, File(newPath));
      }
    }
  }

  /// Streamed copy so multi-GB files do not exhaust memory.
  Future<void> _copyFileStreamed(File source, File target) async {
    final sink = target.openWrite();
    try {
      await sink.addStream(source.openRead());
    } finally {
      await sink.close();
    }
  }
}
