import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opendocs_manager/core/error/exceptions.dart';
import 'package:opendocs_manager/core/error/failures.dart';
import 'package:opendocs_manager/features/archive_manager/data/datasources/archive_engine.dart';
import 'package:opendocs_manager/features/archive_manager/data/datasources/archive_jobs_datasource.dart';
import 'package:opendocs_manager/features/archive_manager/data/repositories/archive_repository_impl.dart';
import 'package:opendocs_manager/features/archive_manager/domain/entities/archive_entities.dart';

class _MockEngine extends Mock implements ArchiveEngine {}

class _MockJobs extends Mock implements ArchiveJobsDataSource {}

void main() {
  late _MockEngine engine;
  late _MockJobs jobs;
  late ArchiveRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      ArchiveJob(
        id: 'x',
        type: ArchiveJobType.create,
        format: ArchiveFormat.zip,
        archivePath: '/a.zip',
        targetPath: '/src',
        createdAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    engine = _MockEngine();
    jobs = _MockJobs();
    repository = ArchiveRepositoryImpl(engine, jobs);
    when(() => jobs.insert(any())).thenAnswer((_) async {});
    when(() => jobs.update(any())).thenAnswer((_) async {});
    when(
      () => engine.progressStream,
    ).thenAnswer((_) => const Stream<ArchiveProgress>.empty());
  });

  group('createArchive', () {
    test('runs the engine and records a completed job', () async {
      when(() => engine.supports(ArchiveFormat.zip)).thenReturn(true);
      when(
        () => engine.create(
          jobId: any(named: 'jobId'),
          sources: any(named: 'sources'),
          archivePath: any(named: 'archivePath'),
          format: ArchiveFormat.zip,
          password: any(named: 'password'),
          compressionLevel: any(named: 'compressionLevel'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.createArchive(
        sources: ['/src/file.txt'],
        archivePath: '/out/file.zip',
        format: ArchiveFormat.zip,
      );

      final job = result.valueOrNull;
      expect(job, isNotNull);
      expect(job!.status, ArchiveJobStatus.done);
      expect(job.progress, 1.0);
      // queued -> running -> done
      verify(() => jobs.insert(any())).called(1);
      verify(() => jobs.update(any())).called(2);
    });

    test('rejects passwords for formats without password support', () async {
      when(() => engine.supports(ArchiveFormat.tar)).thenReturn(true);

      final result = await repository.createArchive(
        sources: ['/src'],
        archivePath: '/out.tar',
        format: ArchiveFormat.tar,
        password: 'secret',
      );

      expect(result.failureOrNull, isA<ArchiveFailure>());
      verifyNever(() => jobs.insert(any()));
    });

    test('marks the job failed when the engine throws', () async {
      when(() => engine.supports(ArchiveFormat.zip)).thenReturn(true);
      when(
        () => engine.create(
          jobId: any(named: 'jobId'),
          sources: any(named: 'sources'),
          archivePath: any(named: 'archivePath'),
          format: ArchiveFormat.zip,
          password: any(named: 'password'),
          compressionLevel: any(named: 'compressionLevel'),
        ),
      ).thenThrow(const ArchiveException('disk full'));

      final result = await repository.createArchive(
        sources: ['/src/file.txt'],
        archivePath: '/out/file.zip',
        format: ArchiveFormat.zip,
      );

      expect(result.failureOrNull, const ArchiveFailure('disk full'));
      final updates = verify(() => jobs.update(captureAny())).captured;
      final lastUpdate = updates.last as ArchiveJob;
      expect(lastUpdate.status, ArchiveJobStatus.failed);
      expect(lastUpdate.error, 'disk full');
    });
  });

  group('extractArchive', () {
    test('detects the format from the file name', () async {
      when(
        () => engine.extract(
          jobId: any(named: 'jobId'),
          archivePath: any(named: 'archivePath'),
          destinationDir: any(named: 'destinationDir'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.extractArchive(
        archivePath: '/downloads/backup.7z',
        destinationDir: '/out',
      );

      expect(result.valueOrNull?.format, ArchiveFormat.sevenZ);
    });

    test('fails on unrecognized extensions', () async {
      final result = await repository.extractArchive(
        archivePath: '/downloads/file.rar',
        destinationDir: '/out',
      );

      expect(result.failureOrNull, isA<ArchiveFailure>());
    });
  });

  test('ArchiveFormat.fromPath recognizes compound extensions', () {
    expect(ArchiveFormat.fromPath('a.tar.gz'), ArchiveFormat.gzip);
    expect(ArchiveFormat.fromPath('a.tgz'), ArchiveFormat.gzip);
    expect(ArchiveFormat.fromPath('a.TAR'), ArchiveFormat.tar);
    expect(ArchiveFormat.fromPath('a.zip'), ArchiveFormat.zip);
    expect(ArchiveFormat.fromPath('a.pdf'), isNull);
  });
}
