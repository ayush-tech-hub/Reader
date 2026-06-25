import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart' hide ArchiveException;
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/archive_entities.dart';
import 'archive_engine.dart';

/// Pure-Dart fallback engine (zip/tar/gzip, no password support). Used
/// when the native channel is unavailable, e.g. desktop development
/// builds and widget tests.
///
/// CPU-bound encode/decode work runs via [Isolate.run] so the UI isolate
/// never blocks; gzip streams through dart:io's codec so file size is
/// not memory-bound. Cancellation is checked only before a job starts —
/// mid-job cancellation needs the native engine.
class DartArchiveEngine implements ArchiveEngine {
  final _progressController = StreamController<ArchiveProgress>.broadcast();
  final _cancelled = <String>{};

  @override
  Stream<ArchiveProgress> get progressStream => _progressController.stream;

  /// Call from the owning provider's onDispose.
  void dispose() {
    unawaited(_progressController.close());
  }

  @override
  bool supports(ArchiveFormat format) => format != ArchiveFormat.sevenZ;

  @override
  Future<void> cancel(String jobId) async => _cancelled.add(jobId);

  @override
  Future<void> create({
    required String jobId,
    required List<String> sources,
    required String archivePath,
    required ArchiveFormat format,
    String? password,
    int compressionLevel = 6,
  }) async {
    if (password != null) {
      throw const ArchiveException(
        'Password-protected archives require the native engine',
      );
    }
    _checkCancelled(jobId);
    switch (format) {
      case ArchiveFormat.zip:
        await Isolate.run(
          () => _createZip(sources, archivePath, compressionLevel),
        );
      case ArchiveFormat.tar:
        await Isolate.run(() => _createTar(sources, archivePath));
      case ArchiveFormat.gzip:
        if (sources.length != 1 || Directory(sources.single).existsSync()) {
          throw const ArchiveException('GZIP compresses a single file');
        }
        await _gzipFile(sources.single, archivePath);
      case ArchiveFormat.sevenZ:
        throw const ArchiveException('7z requires the native engine');
    }
    _emitDone(jobId, archivePath);
  }

  @override
  Future<void> extract({
    required String jobId,
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    final format = ArchiveFormat.fromPath(archivePath);
    if (format == null || !supports(format)) {
      throw ArchiveException('Unsupported archive: $archivePath');
    }
    _checkCancelled(jobId);
    switch (format) {
      case ArchiveFormat.zip:
      case ArchiveFormat.tar:
        await Isolate.run(() => extractFileToDisk(archivePath, destinationDir));
      case ArchiveFormat.gzip:
        await _gunzipFile(archivePath, destinationDir);
      case ArchiveFormat.sevenZ:
        throw const ArchiveException('7z requires the native engine');
    }
    _emitDone(jobId, archivePath);
  }

  @override
  Future<void> extractInBackground({
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    throw const ArchiveException(
      'Background extraction requires the native engine',
    );
  }

  @override
  Future<List<ArchiveEntry>> list(
    String archivePath, {
    String? password,
  }) async {
    if (ArchiveFormat.fromPath(archivePath) != ArchiveFormat.zip) {
      throw const ArchiveException('Listing requires the native engine');
    }
    return Isolate.run(() async {
      final inputStream = InputFileStream(archivePath);
      try {
        final archive = ZipDecoder().decodeBuffer(inputStream);
        return [
          for (final file in archive.files)
            ArchiveEntry(
              name: file.name,
              isDirectory: !file.isFile,
              size: file.size,
              compressedSize: 0,
            ),
        ];
      } finally {
        await inputStream.close();
      }
    });
  }

  void _checkCancelled(String jobId) {
    if (_cancelled.remove(jobId)) {
      throw const ArchiveException('Cancelled');
    }
  }

  void _emitDone(String jobId, String archivePath) {
    if (_progressController.isClosed) return;
    final size =
        File(archivePath).existsSync() ? File(archivePath).lengthSync() : 0;
    _progressController.add(
      ArchiveProgress(jobId: jobId, bytesDone: size, bytesTotal: size),
    );
  }
}

// ---- Isolate entry points (must be top-level/static) -----------------

Future<void> _createZip(
  List<String> sources,
  String archivePath,
  int compressionLevel,
) async {
  final encoder = ZipFileEncoder();
  encoder.create(archivePath, level: compressionLevel);
  try {
    for (final source in sources) {
      if (Directory(source).existsSync()) {
        await encoder.addDirectory(Directory(source));
      } else {
        await encoder.addFile(File(source));
      }
    }
  } finally {
    await encoder.close();
  }
}

Future<void> _createTar(List<String> sources, String archivePath) async {
  final encoder = TarFileEncoder();
  encoder.create(archivePath);
  try {
    for (final source in sources) {
      if (Directory(source).existsSync()) {
        await encoder.addDirectory(Directory(source));
      } else {
        await encoder.addFile(File(source));
      }
    }
  } finally {
    await encoder.close();
  }
}

/// Streamed gzip via dart:io — constant memory regardless of file size.
Future<void> _gzipFile(String source, String archivePath) async {
  final sink = File(archivePath).openWrite();
  await File(source).openRead().transform(gzip.encoder).pipe(sink);
}

Future<void> _gunzipFile(String archivePath, String destinationDir) async {
  final name = p.basenameWithoutExtension(archivePath);
  final sink = File(p.join(destinationDir, name)).openWrite();
  await File(archivePath).openRead().transform(gzip.decoder).pipe(sink);
}
