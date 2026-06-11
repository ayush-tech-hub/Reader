import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../../domain/repositories/pdf_tools_repository.dart';
import '../datasources/pdf_tools_engine.dart';

class PdfToolsRepositoryImpl implements PdfToolsRepository {
  const PdfToolsRepositoryImpl(this._engine);

  final PdfToolsEngine _engine;

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on NativeEngineException catch (e) {
      return Err(PdfFailure(e.message));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> merge({
    required List<String> sources,
    required String outputPath,
  }) =>
      _guard(() => _engine.merge(sources, outputPath));

  @override
  Future<Result<List<String>>> split({
    required String source,
    required List<PageRange> ranges,
    required String outputDir,
  }) =>
      _guard(() => _engine.split(source, ranges, outputDir));

  @override
  Future<Result<String>> compress({
    required String source,
    required String outputPath,
    CompressionQuality quality = CompressionQuality.medium,
  }) =>
      _guard(() => _engine.compress(source, outputPath, quality));

  /// Pure Dart: decode each image (downscaling very large ones) and lay
  /// it out one per page, fitted to A4.
  @override
  Future<Result<String>> imagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
  }) =>
      _guard(() async {
        const maxDimension = 2480; // ~A4 @ 300dpi
        final doc = pw.Document();
        for (final path in imagePaths) {
          final bytes = await File(path).readAsBytes();
          var decoded = img.decodeImage(bytes);
          if (decoded == null) {
            throw NativeEngineException('Not a supported image: $path');
          }
          if (decoded.width > maxDimension || decoded.height > maxDimension) {
            decoded = img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxDimension : null,
              height: decoded.height > decoded.width ? maxDimension : null,
            );
          }
          final jpg = img.encodeJpg(decoded, quality: 90);
          final image = pw.MemoryImage(jpg);
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
        }
        await File(outputPath).writeAsBytes(await doc.save());
        return outputPath;
      });

  @override
  Future<Result<String>> reorderPages({
    required String source,
    required String outputPath,
    required List<int> newOrder,
  }) =>
      _guard(() => _engine.reorderPages(source, outputPath, newOrder));

  @override
  Future<Result<String>> deletePages({
    required String source,
    required String outputPath,
    required List<int> pages,
  }) =>
      _guard(() => _engine.deletePages(source, outputPath, pages));

  @override
  Future<Result<String>> rotatePages({
    required String source,
    required String outputPath,
    required List<int> pages,
    required int degrees,
  }) =>
      _guard(() {
        if (degrees % 90 != 0) {
          throw const NativeEngineException('Rotation must be a multiple of 90');
        }
        return _engine.rotatePages(source, outputPath, pages, degrees % 360);
      });

  @override
  Future<Result<String>> extractPages({
    required String source,
    required String outputPath,
    required PageRange range,
  }) =>
      _guard(() => _engine.extractPages(source, outputPath, range));

  @override
  Future<Result<String>> watermark({
    required String source,
    required String outputPath,
    required WatermarkSpec spec,
  }) =>
      _guard(() => _engine.watermark(source, outputPath, spec));

  @override
  Future<Result<PdfMetadata>> getMetadata(String source) =>
      _guard(() => _engine.getMetadata(source));

  @override
  Future<Result<String>> setMetadata({
    required String source,
    required String outputPath,
    required PdfMetadata metadata,
  }) =>
      _guard(() => _engine.setMetadata(source, outputPath, metadata));
}
