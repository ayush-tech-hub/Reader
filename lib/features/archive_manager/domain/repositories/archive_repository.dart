import '../../../../core/utils/result.dart';
import '../entities/archive_entities.dart';

abstract interface class ArchiveRepository {
  /// Compress [sources] into [archivePath]. Returns the queued job;
  /// progress arrives on [progressStream].
  Future<Result<ArchiveJob>> createArchive({
    required List<String> sources,
    required String archivePath,
    required ArchiveFormat format,
    String? password,
    int compressionLevel = 6,
  });

  /// Extract [archivePath] into [destinationDir].
  Future<Result<ArchiveJob>> extractArchive({
    required String archivePath,
    required String destinationDir,
    String? password,
  });

  Future<Result<List<ArchiveEntry>>> listEntries(
    String archivePath, {
    String? password,
  });

  Future<Result<void>> cancelJob(String jobId);

  /// All progress ticks from the native engine (filter by jobId).
  Stream<ArchiveProgress> get progressStream;

  /// Job ledger (for reconciling after process death).
  Future<Result<List<ArchiveJob>>> getJobs();
}
