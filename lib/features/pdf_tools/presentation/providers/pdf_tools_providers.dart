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
  });

  final bool isWorking;
  final List<String> lastOutputs;
  final String? lastError;
}

final pdfToolsProvider =
    NotifierProvider.autoDispose<PdfToolsNotifier, PdfToolsState>(
  PdfToolsNotifier.new,
);

class PdfToolsNotifier extends AutoDisposeNotifier<PdfToolsState> {
  @override
  PdfToolsState build() => const PdfToolsState();

  PdfToolsRepository get _repo => ref.read(pdfToolsRepositoryProvider);

  Future<void> _run(Future<Result<List<String>>> Function() operation) async {
    state = const PdfToolsState(isWorking: true);
    final result = await operation();
    state = result.fold(
      (failure) => PdfToolsState(lastError: failure.message),
      (outputs) => PdfToolsState(lastOutputs: outputs),
    );
  }

  Future<Result<List<String>>> _single(
    Future<Result<String>> Function() operation,
  ) async {
    final result = await operation();
    return result.fold(Err.new, (path) => Ok([path]));
  }

  Future<void> merge(List<String> sources, String outputPath) => _run(
        () => _single(
            () => _repo.merge(sources: sources, outputPath: outputPath)),
      );

  Future<void> split(
    String source,
    List<PageRange> ranges,
    String outputDir,
  ) =>
      _run(
        () => _repo.split(source: source, ranges: ranges, outputDir: outputDir),
      );

  Future<void> compress(
    String source,
    String outputPath,
    CompressionQuality quality,
  ) =>
      _run(
        () => _single(
          () => _repo.compress(
            source: source,
            outputPath: outputPath,
            quality: quality,
          ),
        ),
      );

  Future<void> imagesToPdf(List<String> imagePaths, String outputPath) => _run(
        () => _single(
          () => _repo.imagesToPdf(
            imagePaths: imagePaths,
            outputPath: outputPath,
          ),
        ),
      );

  Future<void> reorderPages(
    String source,
    String outputPath,
    List<int> newOrder,
  ) =>
      _run(
        () => _single(
          () => _repo.reorderPages(
            source: source,
            outputPath: outputPath,
            newOrder: newOrder,
          ),
        ),
      );

  Future<void> deletePages(
    String source,
    String outputPath,
    List<int> pages,
  ) =>
      _run(
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
        () => _single(
          () => _repo.watermark(
            source: source,
            outputPath: outputPath,
            spec: spec,
          ),
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
        () => _single(
          () => _repo.setMetadata(
            source: source,
            outputPath: outputPath,
            metadata: metadata,
          ),
        ),
      );
}
