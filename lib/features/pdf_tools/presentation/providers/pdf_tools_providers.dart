import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../../domain/repositories/pdf_tools_repository.dart';

@immutable
class PdfToolsState {
  const PdfToolsState({
    this.isWorking = false,
    this.lastOutputs = const [],
    this.lastError,
    this.processingTimeMs,
    this.inputSizeBytes,
    this.outputSizeBytes,
    this.operationName,
  });

  final bool isWorking;
  final List<String> lastOutputs;
  final String? lastError;
  final int? processingTimeMs;
  final int? inputSizeBytes;
  final int? outputSizeBytes;
  final String? operationName;

  bool get hasResult => lastOutputs.isNotEmpty;

  int? get savedBytes => (inputSizeBytes != null && outputSizeBytes != null)
      ? inputSizeBytes! - outputSizeBytes!
      : null;

  double? get savedPercent =>
      (savedBytes != null && inputSizeBytes != null && inputSizeBytes! > 0)
          ? (savedBytes! / inputSizeBytes!) * 100
          : null;
}

final pdfToolsProvider =
    NotifierProvider.autoDispose<PdfToolsNotifier, PdfToolsState>(
  PdfToolsNotifier.new,
);

class PdfToolsNotifier extends AutoDisposeNotifier<PdfToolsState> {
  @override
  PdfToolsState build() => const PdfToolsState();

  PdfToolsRepository get _repo => ref.read(pdfToolsRepositoryProvider);

  Future<void> _run(
    String operationName,
    String? sourcePath,
    Future<Result<List<String>>> Function() operation,
  ) async {
    state = PdfToolsState(isWorking: true, operationName: operationName);
    final inputSize = sourcePath != null ? _fileSize(sourcePath) : null;
    final start = DateTime.now().millisecondsSinceEpoch;
    final result = await operation();
    final elapsed = DateTime.now().millisecondsSinceEpoch - start;
    state = result.fold(
      (failure) => PdfToolsState(lastError: failure.message),
      (outputs) {
        final outSize = outputs.length == 1 ? _fileSize(outputs.first) : null;
        return PdfToolsState(
          lastOutputs: outputs,
          processingTimeMs: elapsed,
          inputSizeBytes: inputSize,
          outputSizeBytes: outSize,
          operationName: operationName,
        );
      },
    );
  }

  int? _fileSize(String path) {
    try {
      return File(path).statSync().size;
    } catch (_) {
      return null;
    }
  }

  Future<Result<List<String>>> _single(
    Future<Result<String>> Function() operation,
  ) async {
    final result = await operation();
    return result.fold(Err.new, (path) => Ok([path]));
  }

  Future<void> merge(List<String> sources, String outputPath) => _run(
        'mergePdf',
        sources.isNotEmpty ? sources.first : null,
        () => _single(
            () => _repo.merge(sources: sources, outputPath: outputPath)),
      );

  Future<void> split(String source, List<PageRange> ranges, String outputDir) =>
      _run(
        'splitPdf',
        source,
        () => _repo.split(source: source, ranges: ranges, outputDir: outputDir),
      );

  Future<void> compress(
    String source,
    String outputPath,
    CompressionQuality quality,
  ) =>
      _run(
        'compressPdf',
        source,
        () => _single(
          () => _repo.compress(
            source: source,
            outputPath: outputPath,
            quality: quality,
          ),
        ),
      );

  Future<void> imagesToPdf(List<String> imagePaths, String outputPath) => _run(
        'imagesToPdf',
        null,
        () => _single(
          () =>
              _repo.imagesToPdf(imagePaths: imagePaths, outputPath: outputPath),
        ),
      );

  Future<void> reorderPages(
    String source,
    String outputPath,
    List<int> newOrder,
  ) =>
      _run(
        'reorderPages',
        source,
        () => _single(
          () => _repo.reorderPages(
            source: source,
            outputPath: outputPath,
            newOrder: newOrder,
          ),
        ),
      );

  Future<void> deletePages(String source, String outputPath, List<int> pages) =>
      _run(
        'deletePages',
        source,
        () => _single(
          () => _repo.deletePages(
            source: source,
            outputPath: outputPath,
            pages: pages,
          ),
        ),
      );

  Future<void> rotatePages(
    String source,
    String outputPath,
    List<int> pages,
    int degrees,
  ) =>
      _run(
        'rotatePages',
        source,
        () => _single(
          () => _repo.rotatePages(
            source: source,
            outputPath: outputPath,
            pages: pages,
            degrees: degrees,
          ),
        ),
      );

  Future<void> extractPages(
    String source,
    String outputPath,
    PageRange range,
  ) =>
      _run(
        'extractPages',
        source,
        () => _single(
          () => _repo.extractPages(
            source: source,
            outputPath: outputPath,
            range: range,
          ),
        ),
      );

  Future<void> watermark(
    String source,
    String outputPath,
    WatermarkSpec spec,
  ) =>
      _run(
        'watermarkPdf',
        source,
        () => _single(
          () => _repo.watermark(
              source: source, outputPath: outputPath, spec: spec),
        ),
      );

  Future<PdfMetadata?> getMetadata(String source) async {
    final result = await _repo.getMetadata(source);
    return result.valueOrNull;
  }

  Future<void> setMetadata(
    String source,
    String outputPath,
    PdfMetadata metadata,
  ) =>
      _run(
        'editMetadata',
        source,
        () => _single(
          () => _repo.setMetadata(
            source: source,
            outputPath: outputPath,
            metadata: metadata,
          ),
        ),
      );

  Future<void> encrypt(String source, String outputPath, PdfEncryptSpec spec) =>
      _run(
        'encryptPdf',
        source,
        () => _single(
          () =>
              _repo.encrypt(source: source, outputPath: outputPath, spec: spec),
        ),
      );

  Future<void> decrypt(String source, String outputPath, String password) =>
      _run(
        'decryptPdf',
        source,
        () => _single(
          () => _repo.decrypt(
            source: source,
            outputPath: outputPath,
            password: password,
          ),
        ),
      );
}
