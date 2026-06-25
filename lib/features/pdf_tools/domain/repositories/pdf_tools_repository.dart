import '../../../../core/utils/result.dart';
import '../entities/pdf_tool_entities.dart';

/// PDF page surgery. All operations write a new file at `outputPath`
/// and never mutate sources in place.
abstract interface class PdfToolsRepository {
  Future<Result<String>> merge({
    required List<String> sources,
    required String outputPath,
  });

  /// Splits into one document per range; returns the created paths.
  Future<Result<List<String>>> split({
    required String source,
    required List<PageRange> ranges,
    required String outputDir,
  });

  Future<Result<String>> compress({
    required String source,
    required String outputPath,
    CompressionQuality quality = CompressionQuality.medium,
    CustomCompressionSettings? customSettings,
  });

  Future<Result<String>> imagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
  });

  Future<Result<String>> reorderPages({
    required String source,
    required String outputPath,
    required List<int> newOrder, // 1-based source page numbers
  });

  Future<Result<String>> deletePages({
    required String source,
    required String outputPath,
    required List<int> pages,
  });

  Future<Result<String>> rotatePages({
    required String source,
    required String outputPath,
    required List<int> pages,
    required int degrees, // 90 | 180 | 270
  });

  Future<Result<String>> extractPages({
    required String source,
    required String outputPath,
    required PageRange range,
  });

  Future<Result<String>> removeWatermark({
    required String source,
    required String outputPath,
  });

  Future<Result<String>> watermark({
    required String source,
    required String outputPath,
    required WatermarkSpec spec,
  });

  Future<Result<PdfMetadata>> getMetadata(String source);

  Future<Result<String>> setMetadata({
    required String source,
    required String outputPath,
    required PdfMetadata metadata,
  });

  Future<Result<String>> encrypt({
    required String source,
    required String outputPath,
    required PdfEncryptSpec spec,
  });

  Future<Result<String>> decrypt({
    required String source,
    required String outputPath,
    required String password,
  });
}
