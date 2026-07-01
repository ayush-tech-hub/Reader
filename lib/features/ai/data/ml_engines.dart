import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/platform/native_channels.dart';

/// On-device OCR bridge. Android: PdfRenderer + ML Kit text recognition;
/// iOS: PDFKit + Vision. Both fully offline.
class OcrEngine {
  OcrEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(NativeChannels.ocr);

  final MethodChannel _channel;

  /// Recognizes text on every page of a (scanned) PDF; returns one
  /// string per page.
  Future<List<String>> recognizePdf(String path) async {
    try {
      final pages = await _channel.invokeListMethod<String>('recognizePdf', {
        'path': path,
      });
      return pages ?? const [];
    } on PlatformException catch (e) {
      throw NativeEngineException(e.message ?? 'OCR failed', e);
    }
  }
}

/// Lifecycle state of a single language pack download.
enum LanguageDownloadState { queued, downloading, completed, failed, canceled }

/// Live progress for one in-flight (or just-finished) language download.
/// [bytesDone]/[bytesTotal]/speed are derived from real measured network
/// throughput on the native side, attributed across concurrent downloads —
/// see TranslateHandler.kt for how the estimate is computed.
class LanguageDownloadProgress {
  const LanguageDownloadProgress({
    required this.code,
    required this.state,
    required this.bytesDone,
    required this.bytesTotal,
    this.error,
  });

  factory LanguageDownloadProgress.fromMap(Map<dynamic, dynamic> map) {
    return LanguageDownloadProgress(
      code: map['code'] as String,
      state: LanguageDownloadState.values.byName(map['state'] as String),
      bytesDone: (map['bytesDone'] as num).toInt(),
      bytesTotal: (map['bytesTotal'] as num).toInt(),
      error: map['error'] as String?,
    );
  }

  final String code;
  final LanguageDownloadState state;
  final int bytesDone;
  final int bytesTotal;
  final String? error;

  double get fraction =>
      bytesTotal <= 0 ? 0 : (bytesDone / bytesTotal).clamp(0.0, 1.0);
}

/// A translation language as reported by the on-device engine: its BCP-47
/// code, a human-readable name, and whether its model is already on disk.
class LanguagePack {
  const LanguagePack({
    required this.code,
    required this.displayName,
    required this.isDownloaded,
    required this.sizeEstimateBytes,
  });

  factory LanguagePack.fromMap(Map<dynamic, dynamic> map) {
    return LanguagePack(
      code: map['code'] as String,
      displayName: map['displayName'] as String,
      isDownloaded: map['isDownloaded'] as bool,
      sizeEstimateBytes: (map['sizeEstimateBytes'] as num).toInt(),
    );
  }

  final String code;
  final String displayName;
  final bool isDownloaded;
  final int sizeEstimateBytes;

  LanguagePack copyWith({bool? isDownloaded}) => LanguagePack(
        code: code,
        displayName: displayName,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        sizeEstimateBytes: sizeEstimateBytes,
      );
}

/// On-device translation bridge. Android: ML Kit Translate — the full set
/// of languages ML Kit supports is queried live from the SDK (no hardcoded
/// subset), downloads run several at a time, and progress/speed/ETA are
/// streamed over [NativeChannels.translateProgress]. iOS: returns a clear
/// unsupported error until the Apple Translation API path lands.
class TranslateEngine {
  TranslateEngine({MethodChannel? channel, EventChannel? progressChannel})
      : _channel = channel ?? const MethodChannel(NativeChannels.translate),
        _progressChannel = progressChannel ??
            const EventChannel(NativeChannels.translateProgress);

  final MethodChannel _channel;
  final EventChannel _progressChannel;
  Stream<LanguageDownloadProgress>? _broadcastProgress;

  /// Live progress events for every language download in flight, keyed by
  /// [LanguageDownloadProgress.code] at the listener side. A single shared
  /// broadcast stream — safe for multiple widgets to listen concurrently.
  Stream<LanguageDownloadProgress> get progressStream {
    return _broadcastProgress ??= _progressChannel
        .receiveBroadcastStream()
        .map(
          (dynamic event) =>
              LanguageDownloadProgress.fromMap(event as Map<dynamic, dynamic>),
        )
        .asBroadcastStream();
  }

  /// Re-requests any downloads that were still pending the last time the
  /// app ran (e.g. interrupted by the process being killed). Safe to call
  /// repeatedly; does not eagerly fetch languages the user never asked for.
  Future<void> prefetchModels() async {
    try {
      await _channel.invokeMethod<void>('prefetchModels');
    } catch (_) {
      // Non-fatal — the user can still trigger downloads manually.
    }
  }

  /// All languages the on-device engine can translate, with current
  /// download status and an estimated pack size — single round trip so the
  /// language list and "is it downloaded" status never disagree.
  Future<List<LanguagePack>> getSupportedLanguages() async {
    try {
      final result = await _channel.invokeListMethod<dynamic>(
        'getSupportedLanguages',
      );
      return [
        for (final entry in result ?? const [])
          LanguagePack.fromMap(entry as Map<dynamic, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Returns the BCP-47 codes of languages whose models are already stored
  /// on this device (i.e., no internet needed for those translations).
  Future<Set<String>> getDownloadedLanguages() async {
    try {
      final result = await _channel.invokeListMethod<String>(
        'getDownloadedLanguages',
      );
      return result?.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Starts downloading a single language pack. Returns immediately;
  /// observe [progressStream] for status. Multiple calls (including
  /// alongside [downloadAllLanguages]) run concurrently, bounded by the
  /// native download pool.
  Future<void> downloadLanguage(String code) async {
    try {
      await _channel.invokeMethod<void>('downloadLanguage', {'code': code});
    } catch (_) {
      // Surfaced via progressStream's "failed" state instead.
    }
  }

  /// Queues every not-yet-downloaded language for download at once.
  Future<void> downloadAllLanguages() async {
    try {
      await _channel.invokeMethod<void>('downloadAllLanguages');
    } catch (_) {
      // Surfaced via progressStream's "failed" state instead.
    }
  }

  /// Best-effort cancel: ML Kit exposes no mid-transfer cancellation, so a
  /// download already past this point on the native side will complete and
  /// then be deleted immediately rather than truly interrupted.
  Future<void> cancelDownload(String code) async {
    try {
      await _channel.invokeMethod<void>('cancelDownload', {'code': code});
    } catch (_) {}
  }

  /// Deletes a downloaded language pack to reclaim storage.
  Future<void> deleteLanguage(String code) async {
    try {
      await _channel.invokeMethod<void>('deleteLanguage', {'code': code});
    } on PlatformException catch (e) {
      throw NativeEngineException(e.message ?? 'Failed to delete language', e);
    }
  }

  /// When enabled, future downloads only proceed on Wi-Fi.
  Future<void> setWifiOnly(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setWifiOnly', {'enabled': enabled});
    } catch (_) {}
  }

  Future<String> translate({
    required String text,
    required String sourceLanguage, // BCP-47, e.g. 'en'
    required String targetLanguage,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('translate', {
        'text': text,
        'source': sourceLanguage,
        'target': targetLanguage,
      });
      return result ?? '';
    } on MissingPluginException {
      throw const NativeEngineException(
        'Translation is not available on this platform yet',
      );
    } on PlatformException catch (e) {
      throw NativeEngineException(e.message ?? 'Translation failed', e);
    }
  }
}

/// Voice reading via the OS text-to-speech engine (offline voices).
class TtsService {
  TtsService() {
    _tts
      ..setSpeechRate(0.5)
      ..awaitSpeakCompletion(true);
  }

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _speaking = true;
    await _tts.speak(text);
    _speaking = false;
  }

  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }

  Future<void> setLanguage(String bcp47) => _tts.setLanguage(bcp47);

  Future<void> dispose() => _tts.stop();
}
