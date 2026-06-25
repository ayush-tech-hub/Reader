import 'package:flutter/services.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/platform/native_channels.dart';
import '../../domain/entities/pdf_tool_entities.dart';

/// Bridge to the native PDF page-surgery engines: PdfBox-Android
/// (Kotlin, Apache-2.0) and PDFKit (Swift). Each method returns the
/// output path(s) produced by the native side.
class PdfToolsEngine {
  PdfToolsEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(NativeChannels.pdfTools);

  final MethodChannel _channel;

  Future<String> merge(List<String> sources, String outputPath) =>
      _invokeForPath(PdfToolsMethods.merge, {
        'sources': sources,
        'outputPath': outputPath,
      });

  Future<List<String>> split(
    String source,
    List<PageRange> ranges,
    String outputDir,
  ) async {
    try {
      final result = await _channel.invokeListMethod<String>(
        PdfToolsMethods.split,
        {
          'source': source,
          'ranges': [
            for (final r in ranges) {'start': r.start, 'end': r.end},
          ],
          'outputDir': outputDir,
        },
      );
      return result ?? [];
    } on PlatformException catch (e) {
      throw NativeEngineException(e.message ?? 'split failed', e);
    }
  }

  Future<String> compress(
    String source,
    String outputPath,
    CompressionQuality quality, {
    CustomCompressionSettings? customSettings,
  }) =>
      _invokeForPath(PdfToolsMethods.compress, {
        'source': source,
        'outputPath': outputPath,
        'quality': quality.name,
        if (customSettings != null) ...{
          'imageQuality': customSettings.imageQuality,
          'dpi': customSettings.dpi,
        },
      });

  Future<String> reorderPages(
    String source,
    String outputPath,
    List<int> newOrder,
  ) =>
      _invokeForPath(PdfToolsMethods.reorderPages, {
        'source': source,
        'outputPath': outputPath,
        'order': newOrder,
      });

  Future<String> deletePages(
    String source,
    String outputPath,
    List<int> pages,
  ) =>
      _invokeForPath(PdfToolsMethods.deletePages, {
        'source': source,
        'outputPath': outputPath,
        'pages': pages,
      });

  Future<String> rotatePages(
    String source,
    String outputPath,
    List<int> pages,
    int degrees,
  ) =>
      _invokeForPath(PdfToolsMethods.rotatePages, {
        'source': source,
        'outputPath': outputPath,
        'pages': pages,
        'degrees': degrees,
      });

  Future<String> extractPages(
    String source,
    String outputPath,
    PageRange range,
  ) =>
      _invokeForPath(PdfToolsMethods.extractPages, {
        'source': source,
        'outputPath': outputPath,
        'start': range.start,
        'end': range.end,
      });

  Future<String> watermark(
    String source,
    String outputPath,
    WatermarkSpec spec,
  ) =>
      _invokeForPath(PdfToolsMethods.watermark, {
        'source': source,
        'outputPath': outputPath,
        'text': spec.text,
        'fontSize': spec.fontSize,
        'opacity': spec.opacity,
        'rotation': spec.rotationDegrees,
        'color': spec.color,
        'position': spec.position.name,
      });

  Future<PdfMetadata> getMetadata(String source) async {
    try {
      final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
        PdfToolsMethods.getMetadata,
        {'source': source},
      );
      return PdfMetadata.fromMap(raw ?? const {});
    } on PlatformException catch (e) {
      throw NativeEngineException(e.message ?? 'getMetadata failed', e);
    }
  }

  Future<String> setMetadata(
    String source,
    String outputPath,
    PdfMetadata metadata,
  ) =>
      _invokeForPath(PdfToolsMethods.setMetadata, {
        'source': source,
        'outputPath': outputPath,
        ...metadata.toMap(),
      });

  Future<String> encrypt(
    String source,
    String outputPath,
    PdfEncryptSpec spec,
  ) =>
      _invokeForPath(PdfToolsMethods.encrypt, {
        'source': source,
        'outputPath': outputPath,
        'userPassword': spec.userPassword,
        'ownerPassword': spec.ownerPassword,
        'allowPrinting': spec.allowPrinting,
        'allowCopying': spec.allowCopying,
        'allowEditing': spec.allowEditing,
        'allowAnnotating': spec.allowAnnotating,
      });

  Future<String> decrypt(String source, String outputPath, String password) =>
      _invokeForPath(PdfToolsMethods.decrypt, {
        'source': source,
        'outputPath': outputPath,
        'password': password,
      });

  Future<String> _invokeForPath(
    String method,
    Map<String, Object?> args,
  ) async {
    try {
      final path = await _channel.invokeMethod<String>(method, args);
      if (path == null) {
        throw NativeEngineException('$method returned no output path');
      }
      return path;
    } on PlatformException catch (e) {
      throw NativeEngineException(e.message ?? '$method failed', e);
    }
  }
}
