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

/// On-device translation bridge. Android: ML Kit Translate (models are
/// downloaded once at app startup, then work fully offline forever).
/// iOS: returns a clear unsupported error until the Apple Translation API
/// path lands.
class TranslateEngine {
  TranslateEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(NativeChannels.translate);

  final MethodChannel _channel;

  /// BCP-47 language codes for which ML Kit models can be downloaded.
  /// Languages outside this set are shown as "not available offline" in the
  /// picker — the set must stay in sync with TranslateHandler.kt.
  static const supportedLanguageCodes = {
    'hi',
    'bn',
    'te',
    'mr',
    'ta',
    'gu',
    'kn',
    'ml',
    'pa',
    'ur',
    'es',
    'fr',
  };

  /// Triggers background download of all supported translation models.
  /// Safe to call repeatedly; already-downloaded models are skipped.
  Future<void> prefetchModels() async {
    try {
      await _channel.invokeMethod<void>('prefetchModels');
    } catch (_) {
      // Non-fatal — models will be downloaded lazily on first translate call.
    }
  }

  /// Returns the BCP-47 codes of languages whose ML Kit models are already
  /// stored on this device (i.e., no internet needed for those translations).
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
