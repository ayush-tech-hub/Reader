import '../../domain/entities/archive_entities.dart';

/// Compression engine abstraction. The production implementation is
/// [NativeArchiveEngine] (Kotlin/Swift via platform channels, streamed
/// I/O, background-capable); [DartArchiveEngine] is a zip/tar/gz
/// fallback for platforms without the native side (dev desktops).
abstract interface class ArchiveEngine {
  bool supports(ArchiveFormat format);

  Future<void> create({
    required String jobId,
    required List<String> sources,
    required String archivePath,
    required ArchiveFormat format,
    String? password,
    int compressionLevel = 6,
  });

  Future<void> extract({
    required String jobId,
    required String archivePath,
    required String destinationDir,
    String? password,
  });

  /// Queues a battery-aware OS background job (WorkManager /
  /// BGProcessingTask) that survives app death. No progress stream;
  /// the OS runs it when constraints allow.
  Future<void> extractInBackground({
    required String archivePath,
    required String destinationDir,
    String? password,
  });

  Future<List<ArchiveEntry>> list(String archivePath, {String? password});

  Future<void> cancel(String jobId);

  Stream<ArchiveProgress> get progressStream;
}
