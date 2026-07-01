import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/ai/data/ml_engines.dart';
import '../../data/ocr_export_service.dart';
import '../../data/ocr_history_datasource.dart';
import '../../domain/entities/ocr_result.dart';

// ════════════════════════════════════════════════════════════════════════════
// Infrastructure providers
// ════════════════════════════════════════════════════════════════════════════

/// Provides a lazily-initialised [OcrHistoryDatasource].
///
/// The datasource's [OcrHistoryDatasource.init] is NOT called here; it is
/// called inside [OcrHistoryNotifier.build] so that the async set-up is
/// tracked by the notifier's loading state.
final ocrHistoryDatasourceProvider = Provider<OcrHistoryDatasource>(
  (ref) => OcrHistoryDatasource(),
);

/// Provides a stateless [OcrExportService].
final ocrExportServiceProvider = Provider<OcrExportService>(
  (ref) => OcrExportService(),
);

/// Provides the [OcrEngine] that bridges to the native OCR implementation.
final ocrEngineProvider = Provider<OcrEngine>(
  (ref) => OcrEngine(),
);

// ════════════════════════════════════════════════════════════════════════════
// OCR history list
// ════════════════════════════════════════════════════════════════════════════

/// Manages the ordered list of [OcrResult] objects stored in local history.
///
/// The state is `AsyncValue<List<OcrResult>>`:
///   - [AsyncLoading] while the DB is opening or re-fetching.
///   - [AsyncData] with the current list once loaded.
///   - [AsyncError] if an unrecoverable error occurs.
class OcrHistoryNotifier extends AsyncNotifier<List<OcrResult>> {
  OcrHistoryDatasource get _ds => ref.read(ocrHistoryDatasourceProvider);

  @override
  Future<List<OcrResult>> build() async {
    await _ds.init();
    return _ds.getAll();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Persists [result] and refreshes the in-memory list.
  Future<void> save(OcrResult result) async {
    await _ds.save(result);
    await _reload();
  }

  /// Deletes the entry identified by [id] and refreshes the in-memory list.
  Future<void> delete(String id) async {
    await _ds.delete(id);
    await _reload();
  }

  /// Removes all history entries and refreshes the in-memory list.
  Future<void> clear() async {
    await _ds.clear();
    await _reload();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_ds.getAll);
  }
}

/// The [AsyncNotifierProvider] that exposes [OcrHistoryNotifier].
final ocrHistoryProvider =
    AsyncNotifierProvider<OcrHistoryNotifier, List<OcrResult>>(
  OcrHistoryNotifier.new,
);

// ════════════════════════════════════════════════════════════════════════════
// OCR job runner
// ════════════════════════════════════════════════════════════════════════════

/// Snapshot of an OCR job's lifecycle.
class OcrJobState {
  const OcrJobState({
    required this.isRunning,
    required this.progress,
    this.result,
    this.error,
  });

  /// Whether an OCR job is currently in flight.
  final bool isRunning;

  /// Completion fraction in `[0, 1]`.  Meaningful only while [isRunning].
  final double progress;

  /// The successfully recognised result, or `null` if not yet complete.
  final OcrResult? result;

  /// Human-readable error message, or `null` when no error has occurred.
  final String? error;

  OcrJobState copyWith({
    bool? isRunning,
    double? progress,
    OcrResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return OcrJobState(
      isRunning: isRunning ?? this.isRunning,
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives individual OCR jobs and automatically saves results to history.
class OcrJobNotifier extends Notifier<OcrJobState> {
  OcrEngine get _engine => ref.read(ocrEngineProvider);

  @override
  OcrJobState build() => const OcrJobState(
        isRunning: false,
        progress: 0,
        result: null,
        error: null,
      );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Runs OCR on every page of a PDF at [path] and saves the result to
  /// history.
  ///
  /// [script] selects the writing system (`null` = Latin/auto).
  /// Returns the completed [OcrResult] on success, or `null` on error.
  Future<OcrResult?> recognizePdf(String path, {String? script}) async {
    _startJob();
    try {
      final pages = await _engine.recognizePdf(path, script: script);
      final result = OcrResult.generate(
        sourcePath: path,
        sourceType: 'pdf',
        pageTexts: pages,
      );
      await _saveAndFinish(result);
      return result;
    } catch (e) {
      _failJob(e.toString());
      return null;
    }
  }

  /// Runs OCR on a single image at [path] and saves the result to history.
  ///
  /// [script] selects the writing system (`null` = Latin/auto).
  Future<OcrResult?> recognizeImage(String path, {String? script}) async {
    _startJob();
    try {
      final text = await _engine.recognizeImage(path, script: script);
      final result = OcrResult.generate(
        sourcePath: path,
        sourceType: 'image',
        pageTexts: [text],
      );
      await _saveAndFinish(result);
      return result;
    } on PlatformException catch (e) {
      _failJob(e.message ?? 'Image OCR failed');
      return null;
    } catch (e) {
      _failJob(e.toString());
      return null;
    }
  }

  /// Runs OCR on a list of image [paths], updating [OcrJobState.progress]
  /// after each image, and saves a single combined [OcrResult] to history.
  ///
  /// [script] selects the writing system; applied uniformly to all images.
  Future<OcrResult?> recognizeImageBatch(
    List<String> paths, {
    String? script,
  }) async {
    if (paths.isEmpty) return null;
    _startJob();

    final pageTexts = <String>[];
    try {
      for (var i = 0; i < paths.length; i++) {
        final text = await _engine.recognizeImage(paths[i], script: script);
        pageTexts.add(text);
        state = state.copyWith(progress: (i + 1) / paths.length);
      }

      // Use the first path as the canonical source for metadata.
      final result = OcrResult.generate(
        sourcePath: paths.first,
        sourceType: 'batch',
        pageTexts: pageTexts,
      );
      await _saveAndFinish(result);
      return result;
    } on PlatformException catch (e) {
      _failJob(e.message ?? 'Batch OCR failed');
      return null;
    } catch (e) {
      _failJob(e.toString());
      return null;
    }
  }

  /// Resets the notifier back to its initial state.
  void clearResult() {
    state = const OcrJobState(
      isRunning: false,
      progress: 0,
      result: null,
      error: null,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _startJob() {
    state = const OcrJobState(
      isRunning: true,
      progress: 0,
      result: null,
      error: null,
    );
  }

  Future<void> _saveAndFinish(OcrResult result) async {
    await ref.read(ocrHistoryProvider.notifier).save(result);
    state = OcrJobState(
      isRunning: false,
      progress: 1,
      result: result,
      error: null,
    );
  }

  void _failJob(String message) {
    state = OcrJobState(
      isRunning: false,
      progress: 0,
      result: null,
      error: message,
    );
  }
}

/// The [NotifierProvider] that exposes [OcrJobNotifier].
final ocrJobProvider = NotifierProvider<OcrJobNotifier, OcrJobState>(
  OcrJobNotifier.new,
);
