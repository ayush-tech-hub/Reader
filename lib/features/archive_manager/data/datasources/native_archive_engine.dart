import 'package:flutter/services.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/platform/native_channels.dart';
import '../../domain/entities/archive_entities.dart';
import 'archive_engine.dart';

/// Bridges to the native engines (Kotlin: zip4j + commons-compress with
/// WorkManager; Swift: ZIPFoundation/SWCompression with
/// BGProcessingTask). All I/O is streamed natively, so archives larger
/// than 10 GB never touch Dart memory.
class NativeArchiveEngine implements ArchiveEngine {
  NativeArchiveEngine({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _channel = methodChannel ?? const MethodChannel(NativeChannels.archive),
        _events =
            eventChannel ?? const EventChannel(NativeChannels.archiveProgress);

  final MethodChannel _channel;
  final EventChannel _events;

  Stream<ArchiveProgress>? _broadcast;

  @override
  bool supports(ArchiveFormat format) => true;

  @override
  Stream<ArchiveProgress> get progressStream =>
      _broadcast ??= _events.receiveBroadcastStream().map((dynamic event) {
        final map = event as Map<dynamic, dynamic>;
        return ArchiveProgress(
          jobId: map['jobId'] as String,
          bytesDone: (map['bytesDone'] as num).toInt(),
          bytesTotal: (map['bytesTotal'] as num).toInt(),
          currentEntry: (map['currentEntry'] as String?) ?? '',
        );
      }).asBroadcastStream();

  @override
  Future<void> create({
    required String jobId,
    required List<String> sources,
    required String archivePath,
    required ArchiveFormat format,
    String? password,
    int compressionLevel = 6,
  }) =>
      _invoke(ArchiveMethods.create, {
        'jobId': jobId,
        'sources': sources,
        'archivePath': archivePath,
        'format': format.wireName,
        'password': password,
        'level': compressionLevel,
      });

  @override
  Future<void> extract({
    required String jobId,
    required String archivePath,
    required String destinationDir,
    String? password,
  }) =>
      _invoke(ArchiveMethods.extract, {
        'jobId': jobId,
        'archivePath': archivePath,
        'destinationDir': destinationDir,
        'password': password,
      });

  @override
  Future<List<ArchiveEntry>> list(
    String archivePath, {
    String? password,
  }) async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      ArchiveMethods.list,
      {'archivePath': archivePath, 'password': password},
    );
    return (raw ?? [])
        .map(
          (m) => ArchiveEntry(
            name: m['name'] as String,
            isDirectory: m['isDirectory'] as bool,
            size: (m['size'] as num).toInt(),
            compressedSize: (m['compressedSize'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<void> cancel(String jobId) =>
      _invoke(ArchiveMethods.cancel, {'jobId': jobId});

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      throw ArchiveException(e.message ?? 'Archive operation failed', e);
    }
  }
}
