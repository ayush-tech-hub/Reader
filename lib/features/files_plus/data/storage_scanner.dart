import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// File-type buckets shown by the Storage Analyzer. [images]..[archives]
/// are mutually exclusive (used for the pie chart and sum to the device
/// total); [downloads], [hidden] and [largeFiles] are overlay categories
/// that may double-count files already in a type bucket above.
enum StorageCategory {
  images,
  videos,
  audio,
  documents,
  apks,
  archives,
  downloads,
  hidden,
  largeFiles;

  /// Whether this category participates in the mutually-exclusive pie
  /// breakdown (as opposed to being an overlay/shortcut category).
  bool get isPrimaryType => switch (this) {
        images || videos || audio || documents || apks || archives => true,
        downloads || hidden || largeFiles => false,
      };

  IconData get icon => switch (this) {
        StorageCategory.images => Icons.image_outlined,
        StorageCategory.videos => Icons.movie_outlined,
        StorageCategory.audio => Icons.audiotrack_outlined,
        StorageCategory.documents => Icons.description_outlined,
        StorageCategory.apks => Icons.android,
        StorageCategory.archives => Icons.folder_zip_outlined,
        StorageCategory.downloads => Icons.download_outlined,
        StorageCategory.hidden => Icons.visibility_off_outlined,
        StorageCategory.largeFiles => Icons.layers_outlined,
      };

  Color color(ColorScheme scheme) => switch (this) {
        StorageCategory.images => const Color(0xFF42A5F5),
        StorageCategory.videos => const Color(0xFFEF5350),
        StorageCategory.audio => const Color(0xFFAB47BC),
        StorageCategory.documents => const Color(0xFF26A69A),
        StorageCategory.apks => const Color(0xFF66BB6A),
        StorageCategory.archives => const Color(0xFFFFA726),
        StorageCategory.downloads => scheme.secondary,
        StorageCategory.hidden => scheme.outline,
        StorageCategory.largeFiles => const Color(0xFFEC407A),
      };
}

class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.size,
    required this.modifiedMs,
  });

  final String path;
  final int size;
  final int modifiedMs;
}

class CategoryBucket {
  CategoryBucket();

  int totalBytes = 0;
  int fileCount = 0;
  final List<ScannedFile> files = [];

  void add(ScannedFile file) {
    totalBytes += file.size;
    fileCount++;
    // Bounded so a huge gallery/library can't blow up memory; capped lists
    // are re-sorted and trimmed periodically by the scanner.
    files.add(file);
  }
}

class StorageScanReport {
  const StorageScanReport({
    required this.totalBytes,
    required this.totalFiles,
    required this.buckets,
  });

  final int totalBytes;
  final int totalFiles;
  final Map<StorageCategory, CategoryBucket> buckets;

  int get otherBytes {
    final typed = StorageCategory.values
        .where((c) => c.isPrimaryType)
        .fold<int>(0, (sum, c) => sum + (buckets[c]?.totalBytes ?? 0));
    return (totalBytes - typed).clamp(0, totalBytes);
  }
}

class ScanProgress {
  const ScanProgress({
    required this.scannedCount,
    required this.done,
    this.report,
  });

  final int scannedCount;
  final bool done;
  final StorageScanReport? report;
}

/// Offline, category-aware storage scanner. Streams progress so the UI can
/// show a live counter instead of blocking on one giant future; each
/// directory listing is itself async I/O, so the scan never holds the UI
/// thread for more than a single file-stat at a time.
class StorageScanner {
  const StorageScanner();

  static const _imageExt = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
    '.svg',
  };
  static const _videoExt = {
    '.mp4',
    '.mkv',
    '.mov',
    '.avi',
    '.webm',
    '.3gp',
    '.flv',
    '.wmv',
    '.m4v',
  };
  static const _audioExt = {
    '.mp3',
    '.wav',
    '.aac',
    '.flac',
    '.ogg',
    '.m4a',
    '.wma',
    '.opus',
  };
  static const _docExt = {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.odt',
    '.csv',
    '.epub',
    '.md',
    '.rtf',
  };
  static const _archiveExt = {
    '.zip',
    '.rar',
    '.7z',
    '.tar',
    '.gz',
    '.bz2',
    '.xz',
  };
  static const largeFileThreshold = 100 * 1024 * 1024; // 100 MiB
  static const _maxFilesPerBucket = 20000;

  Stream<ScanProgress> scan(String rootPath) async* {
    final buckets = {
      for (final c in StorageCategory.values) c: CategoryBucket(),
    };
    var totalBytes = 0;
    var totalFiles = 0;
    var scanned = 0;

    await for (final file in _walkFiles(rootPath)) {
      int size;
      DateTime modified;
      try {
        final stat = await file.stat();
        size = stat.size;
        modified = stat.modified;
      } on FileSystemException {
        continue;
      }
      totalBytes += size;
      totalFiles++;
      scanned++;

      final scanned0 = ScannedFile(
        path: file.path,
        size: size,
        modifiedMs: modified.millisecondsSinceEpoch,
      );
      final ext = p.extension(file.path).toLowerCase();
      final name = p.basename(file.path);

      final type = _classify(ext);
      if (type != null && buckets[type]!.fileCount < _maxFilesPerBucket) {
        buckets[type]!.add(scanned0);
      }
      if (name.startsWith('.') &&
          buckets[StorageCategory.hidden]!.fileCount < _maxFilesPerBucket) {
        buckets[StorageCategory.hidden]!.add(scanned0);
      }
      if (_isInDownloads(file.path) &&
          buckets[StorageCategory.downloads]!.fileCount < _maxFilesPerBucket) {
        buckets[StorageCategory.downloads]!.add(scanned0);
      }
      if (size >= largeFileThreshold &&
          buckets[StorageCategory.largeFiles]!.fileCount < _maxFilesPerBucket) {
        buckets[StorageCategory.largeFiles]!.add(scanned0);
      }

      if (scanned % 250 == 0) {
        yield ScanProgress(scannedCount: scanned, done: false);
      }
    }

    for (final bucket in buckets.values) {
      bucket.files.sort((a, b) => b.size.compareTo(a.size));
    }

    yield ScanProgress(
      scannedCount: scanned,
      done: true,
      report: StorageScanReport(
        totalBytes: totalBytes,
        totalFiles: totalFiles,
        buckets: buckets,
      ),
    );
  }

  StorageCategory? _classify(String ext) {
    if (_imageExt.contains(ext)) return StorageCategory.images;
    if (_videoExt.contains(ext)) return StorageCategory.videos;
    if (_audioExt.contains(ext)) return StorageCategory.audio;
    if (_docExt.contains(ext)) return StorageCategory.documents;
    if (ext == '.apk') return StorageCategory.apks;
    if (_archiveExt.contains(ext)) return StorageCategory.archives;
    return null;
  }

  bool _isInDownloads(String path) =>
      path.toLowerCase().contains('${p.separator}download');

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
