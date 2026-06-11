import 'package:equatable/equatable.dart';

enum FileSortField { name, size, date }

enum FileViewMode { list, grid }

/// A file or directory shown in the browser.
class FileEntry extends Equatable {
  const FileEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
    this.isHidden = false,
  });

  final String path;
  final String name;
  final bool isDirectory;

  /// Bytes; 0 for directories (computed lazily if ever needed).
  final int size;
  final DateTime modifiedAt;
  final bool isHidden;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot).toLowerCase();
  }

  @override
  List<Object?> get props => [path, name, isDirectory, size, modifiedAt];
}

/// A storage volume root (internal storage, SD card, ...).
class StorageRoot extends Equatable {
  const StorageRoot({
    required this.path,
    required this.label,
    required this.isRemovable,
    this.totalBytes = 0,
    this.freeBytes = 0,
  });

  final String path;
  final String label;
  final bool isRemovable;
  final int totalBytes;
  final int freeBytes;

  @override
  List<Object?> get props => [path, label, isRemovable];
}

class Favorite extends Equatable {
  const Favorite({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.addedAt,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final DateTime addedAt;

  @override
  List<Object?> get props => [path];
}
