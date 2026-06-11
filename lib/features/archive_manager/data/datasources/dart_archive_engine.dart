import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/archive_entities.dart';
import 'archive_engine.dart';

/// Pure-Dart fallback engine (zip/tar/gzip, no password support, no
/// background execution). Used when the native channel is unavailable,
/// e.g. desktop development builds and widget tests.
class DartArchiveEngine implements ArchiveEngine {
  final _progressController = StreamController<ArchiveProgress>.broadcast();
  final _cancelled = <String>{};

  @override
  Stream<ArchiveProgress> get progressStream => _progressController.stream;

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
    switch (format) {
      case ArchiveFormat.zip:
        final encoder = ZipFileEncoder();
        encoder.create(archivePath, level: compressionLevel);
        try {
          for (final source in sources) {
            _checkCancelled(jobId);
            final type =
                await FileSystemEntity.type(source, followLinks: false);
            if (type == FileSystemEntityType.directory) {
              await encoder.addDirectory(Directory(source));
            } else {
              await encoder.addFile(File(source));
            }
          }
        } finally {
          await encoder.close();
        }
      case ArchiveFormat.tar:
        final encoder = TarFileEncoder();
        encoder.create(archivePath);
        try {
          for (final source in sources) {
            _checkCancelled(jobId);
            final type =
                await FileSystemEntity.type(source, followLinks: false);
            if (type == FileSystemEntityType.directory) {
              await encoder.addDirectory(Directory(source));
            } else {
              await encoder.addFile(File(source));
            }
          }
        } finally {
          await encoder.close();
        }
      case ArchiveFormat.gzip:
        if (sources.length != 1 || Directory(sources.single).existsSync()) {
          throw const ArchiveException('GZIP compresses a single file');
        }
        final input = File(sources.single);
        final output = File(archivePath);
        await output.writeAsBytes(
          const GZipEncoder().encode(await input.readAsBytes())!,
        );
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
        await extractFileToDisk(archivePath, destinationDir);
      case ArchiveFormat.gzip:
        final bytes = const GZipDecoder()
            .decodeBytes(await File(archivePath).readAsBytes());
        final name = p.basenameWithoutExtension(archivePath);
        await File(p.join(destinationDir, name)).writeAsBytes(bytes);
      case ArchiveFormat.sevenZ:
        throw const ArchiveException('7z requires the native engine');
    }
    _emitDone(jobId, archivePath);
  }

  @override
  Future<List<ArchiveEntry>> list(
    String archivePath, {
    String? password,
  }) async {
    if (ArchiveFormat.fromPath(archivePath) != ArchiveFormat.zip) {
      throw const ArchiveException('Listing requires the native engine');
    }
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
  }

  void _checkCancelled(String jobId) {
    if (_cancelled.remove(jobId)) {
      throw const ArchiveException('Cancelled');
    }
  }

  void _emitDone(String jobId, String archivePath) {
    final size = File(archivePath).existsSync()
        ? File(archivePath).lengthSync()
        : 0;
    _progressController.add(
      ArchiveProgress(jobId: jobId, bytesDone: size, bytesTotal: size),
    );
  }
}
