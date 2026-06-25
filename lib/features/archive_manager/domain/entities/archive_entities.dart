import 'package:equatable/equatable.dart';

enum ArchiveFormat {
  zip('zip', '.zip'),
  sevenZ('sevenZ', '.7z'),
  tar('tar', '.tar'),
  gzip('gzip', '.gz');

  const ArchiveFormat(this.wireName, this.extension);

  /// Name used on the platform channel.
  final String wireName;
  final String extension;

  /// Only ZIP supports password protection (AES-256 via the native
  /// engines). 7z encryption is not exposed in v1.
  bool get supportsPassword => this == ArchiveFormat.zip;

  static ArchiveFormat? fromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.zip')) return ArchiveFormat.zip;
    if (lower.endsWith('.7z')) return ArchiveFormat.sevenZ;
    if (lower.endsWith('.tar')) return ArchiveFormat.tar;
    if (lower.endsWith('.gz') || lower.endsWith('.tgz')) {
      return ArchiveFormat.gzip;
    }
    return null;
  }
}

enum ArchiveJobType { create, extract }

enum ArchiveJobStatus { queued, running, done, failed, cancelled }

/// A durable archive job (persisted in `archive_jobs` so background
/// work survives process death).
class ArchiveJob extends Equatable {
  const ArchiveJob({
    required this.id,
    required this.type,
    required this.format,
    required this.archivePath,
    required this.targetPath,
    this.status = ArchiveJobStatus.queued,
    this.progress = 0.0,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final ArchiveJobType type;
  final ArchiveFormat format;

  /// The archive file itself.
  final String archivePath;

  /// For create: source file/dir. For extract: destination directory.
  final String targetPath;
  final ArchiveJobStatus status;
  final double progress;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  ArchiveJob copyWith({
    ArchiveJobStatus? status,
    double? progress,
    String? error,
    DateTime? completedAt,
  }) => ArchiveJob(
    id: id,
    type: type,
    format: format,
    archivePath: archivePath,
    targetPath: targetPath,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error ?? this.error,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
  );

  @override
  List<Object?> get props => [id, status, progress, error];
}

/// A progress tick streamed from the native engine.
class ArchiveProgress extends Equatable {
  const ArchiveProgress({
    required this.jobId,
    required this.bytesDone,
    required this.bytesTotal,
    this.currentEntry = '',
  });

  final String jobId;
  final int bytesDone;
  final int bytesTotal;
  final String currentEntry;

  double get fraction =>
      bytesTotal <= 0 ? 0 : (bytesDone / bytesTotal).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [jobId, bytesDone, bytesTotal, currentEntry];
}

/// An entry listed inside an archive (for the archive browser).
class ArchiveEntry extends Equatable {
  const ArchiveEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.compressedSize,
  });

  final String name;
  final bool isDirectory;
  final int size;
  final int compressedSize;

  @override
  List<Object?> get props => [name, isDirectory, size];
}
