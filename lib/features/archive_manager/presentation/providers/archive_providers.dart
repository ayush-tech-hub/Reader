import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/archive_entities.dart';

/// Live progress ticks from the engine, keyed by job id.
final archiveProgressProvider =
    StreamProvider.autoDispose<ArchiveProgress>((ref) {
  return ref.watch(archiveRepositoryProvider).progressStream;
});

@immutable
class ArchiveScreenState {
  const ArchiveScreenState({
    this.entries = const AsyncValue.data([]),
    this.activeJob,
    this.lastError,
  });

  final AsyncValue<List<ArchiveEntry>> entries;
  final ArchiveJob? activeJob;
  final String? lastError;

  ArchiveScreenState copyWith({
    AsyncValue<List<ArchiveEntry>>? entries,
    ArchiveJob? activeJob,
    bool clearJob = false,
    String? lastError,
    bool clearError = false,
  }) =>
      ArchiveScreenState(
        entries: entries ?? this.entries,
        activeJob: clearJob ? null : (activeJob ?? this.activeJob),
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

final archiveScreenProvider = NotifierProvider.autoDispose<
    ArchiveScreenNotifier, ArchiveScreenState>(ArchiveScreenNotifier.new);

class ArchiveScreenNotifier extends AutoDisposeNotifier<ArchiveScreenState> {
  @override
  ArchiveScreenState build() => const ArchiveScreenState();

  Future<void> loadEntries(String archivePath, {String? password}) async {
    state = state.copyWith(entries: const AsyncValue.loading());
    final result = await ref
        .read(archiveRepositoryProvider)
        .listEntries(archivePath, password: password);
    state = state.copyWith(
      entries: result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        AsyncValue.data,
      ),
    );
  }

  Future<void> create({
    required List<String> sources,
    required String archivePath,
    required ArchiveFormat format,
    String? password,
    int compressionLevel = 6,
  }) async {
    final result = await ref.read(archiveRepositoryProvider).createArchive(
          sources: sources,
          archivePath: archivePath,
          format: format,
          password: password,
          compressionLevel: compressionLevel,
        );
    _applyJobResult(result);
  }

  Future<void> extract({
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    final result = await ref.read(archiveRepositoryProvider).extractArchive(
          archivePath: archivePath,
          destinationDir: destinationDir,
          password: password,
        );
    _applyJobResult(result);
  }

  /// Returns true when the background job was queued successfully.
  Future<bool> extractInBackground({
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    final result = await ref.read(archiveRepositoryProvider).extractInBackground(
          archivePath: archivePath,
          destinationDir: destinationDir,
          password: password,
        );
    return result.fold(
      (failure) {
        state = state.copyWith(lastError: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(clearError: true);
        return true;
      },
    );
  }

  Future<void> cancelActiveJob() async {
    final job = state.activeJob;
    if (job == null) return;
    await ref.read(archiveRepositoryProvider).cancelJob(job.id);
    state = state.copyWith(clearJob: true);
  }

  void _applyJobResult(Result<ArchiveJob> result) {
    state = result.fold(
      (failure) => state.copyWith(lastError: failure.message, clearJob: true),
      (job) => state.copyWith(activeJob: job, clearError: true),
    );
  }
}
