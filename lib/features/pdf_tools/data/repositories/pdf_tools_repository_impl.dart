import 'dart:io';
import 'dart:isolate';

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/pdf_tool_entities.dart';
import '../../domain/repositories/pdf_tools_repository.dart';
import '../datasources/pdf_tools_engine.dart';

/// Top-level so it can run via [Isolate.run]. Exposed for tests.
/// Embeds the original JPEG/PNG bytes (the pdf package decodes them);
/// each image is fitted to an A4 page.
Future<String> buildPdfFromImages(
  List<String> imagePaths,
  String outputPath,
) async {
  final doc = pw.Document();
  for (final path in imagePaths) {
    final bytes = await File(path).readAsBytes();
    final pw.MemoryImage image;
    try {
      image = pw.MemoryImage(bytes);
    } catch (_) {
      throw NativeEngineException('Not a supported image: $path');
    }
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  await File(outputPath).writeAsBytes(await doc.save());
  return outputPath;
}

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
    CustomCompressionSettings? customSettings,
  }) =>
      _guard(
        () => _engine.compress(
          source,
          outputPath,
          quality,
          customSettings: customSettings,
        ),
      );

  /// Pure Dart: decode each image (downscaling very large ones) and lay
  /// it out one per page, fitted to A4. Decoding/encoding is CPU-bound
  /// (seconds per large photo), so it runs on a background isolate to
  /// keep the UI responsive.
  @override
  Future<Result<String>> imagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
  }) =>
      _guard(
        () => Isolate.run(() => buildPdfFromImages(imagePaths, outputPath)),
      );

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
          throw const NativeEngineException(
              'Rotation must be a multiple of 90');
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

  @override
  Future<Result<String>> encrypt({
    required String source,
    required String outputPath,
    required PdfEncryptSpec spec,
  }) =>
      _guard(() => _engine.encrypt(source, outputPath, spec));

  @override
  Future<Result<String>> decrypt({
    required String source,
    required String outputPath,
    required String password,
  }) =>
      _guard(() => _engine.decrypt(source, outputPath, password));
}
