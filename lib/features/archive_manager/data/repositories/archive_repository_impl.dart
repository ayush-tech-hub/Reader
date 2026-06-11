import 'dart:math';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/archive_entities.dart';
import '../../domain/repositories/archive_repository.dart';
import '../datasources/archive_engine.dart';
import '../datasources/archive_jobs_datasource.dart';

class ArchiveRepositoryImpl implements ArchiveRepository {
  ArchiveRepositoryImpl(this._engine, this._jobs);

  final ArchiveEngine _engine;
  final ArchiveJobsDataSource _jobs;

  static final _random = Random.secure();

  static String newJobId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  @override
  Stream<ArchiveProgress> get progressStream => _engine.progressStream;

  @override
  Future<Result<ArchiveJob>> createArchive({
    required List<String> sources,
    required String archivePath,
    required ArchiveFormat format,
    String? password,
    int compressionLevel = 6,
  }) async {
    if (!_engine.supports(format)) {
      return Err(ArchiveFailure('${format.name} is not supported here'));
    }
    if (password != null && !format.supportsPassword) {
      return Err(
        ArchiveFailure('${format.name} does not support passwords'),
      );
    }
    final job = ArchiveJob(
      id: newJobId(),
      type: ArchiveJobType.create,
      format: format,
      archivePath: archivePath,
      targetPath: sources.first,
      createdAt: DateTime.now(),
    );
    return _runJob(
      job,
      () => _engine.create(
        jobId: job.id,
        sources: sources,
        archivePath: archivePath,
        format: format,
        password: password,
        compressionLevel: compressionLevel,
      ),
    );
  }

  @override
  Future<Result<ArchiveJob>> extractArchive({
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    final format = ArchiveFormat.fromPath(archivePath);
    if (format == null) {
      return Err(ArchiveFailure('Unrecognized archive: $archivePath'));
    }
    final job = ArchiveJob(
      id: newJobId(),
      type: ArchiveJobType.extract,
      format: format,
      archivePath: archivePath,
      targetPath: destinationDir,
      createdAt: DateTime.now(),
    );
    return _runJob(
      job,
      () => _engine.extract(
        jobId: job.id,
        archivePath: archivePath,
        destinationDir: destinationDir,
        password: password,
      ),
    );
  }

  @override
  Future<Result<void>> extractInBackground({
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    try {
      await _engine.extractInBackground(
        archivePath: archivePath,
        destinationDir: destinationDir,
        password: password,
      );
      return const Ok(null);
    } on ArchiveException catch (e) {
      return Err(ArchiveFailure(e.message));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  /// Records the job, starts the engine and persists the terminal
  /// state. The engine call itself returns when the native side has
  /// *accepted or finished* the job; progress flows on [progressStream].
  Future<Result<ArchiveJob>> _runJob(
    ArchiveJob job,
    Future<void> Function() start,
  ) async {
    try {
      await _jobs.insert(job);
      final running = job.copyWith(status: ArchiveJobStatus.running);
      await _jobs.update(running);
      await start();
      final done = running.copyWith(
        status: ArchiveJobStatus.done,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      await _jobs.update(done);
      return Ok(done);
    } on ArchiveException catch (e) {
      final failed = job.copyWith(
        status: ArchiveJobStatus.failed,
        error: e.message,
        completedAt: DateTime.now(),
      );
      await _jobs.update(failed);
      return Err(ArchiveFailure(e.message));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ArchiveEntry>>> listEntries(
    String archivePath, {
    String? password,
  }) async {
    try {
      return Ok(await _engine.list(archivePath, password: password));
    } on ArchiveException catch (e) {
      return Err(ArchiveFailure(e.message));
    }
  }

  @override
  Future<Result<void>> cancelJob(String jobId) async {
    try {
      await _engine.cancel(jobId);
      return const Ok(null);
    } on ArchiveException catch (e) {
      return Err(ArchiveFailure(e.message));
    }
  }

  @override
  Future<Result<List<ArchiveJob>>> getJobs() async {
    try {
      return Ok(await _jobs.getAll());
    } catch (e) {
      return Err(DatabaseFailure(e.toString()));
    }
  }
}
