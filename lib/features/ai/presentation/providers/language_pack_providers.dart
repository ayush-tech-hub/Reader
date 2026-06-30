import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../data/ml_engines.dart';

/// Snapshot of the language-pack manager: every translatable language with
/// its download status, plus live progress for whatever is mid-download.
class LanguagePackState {
  const LanguagePackState({
    this.languages = const [],
    this.progress = const {},
    this.loading = true,
    this.wifiOnly = false,
  });

  final List<LanguagePack> languages;
  final Map<String, LanguageDownloadProgress> progress;
  final bool loading;
  final bool wifiOnly;

  int get downloadedCount => languages.where((l) => l.isDownloaded).length;

  int get downloadedBytesEstimate => languages
      .where((l) => l.isDownloaded)
      .fold(0, (sum, l) => sum + l.sizeEstimateBytes);

  LanguagePackState copyWith({
    List<LanguagePack>? languages,
    Map<String, LanguageDownloadProgress>? progress,
    bool? loading,
    bool? wifiOnly,
  }) {
    return LanguagePackState(
      languages: languages ?? this.languages,
      progress: progress ?? this.progress,
      loading: loading ?? this.loading,
      wifiOnly: wifiOnly ?? this.wifiOnly,
    );
  }
}

/// Drives the language-pack manager screen: loads the full language list
/// from the native engine, tracks live per-language download progress, and
/// exposes download/cancel/delete actions plus opt-in auto-cleanup of
/// packs that haven't been used in a while.
class LanguagePackNotifier extends Notifier<LanguagePackState> {
  StreamSubscription<LanguageDownloadProgress>? _sub;

  static const _staleAfter = Duration(days: 30);
  static const _lastUsedKeyPrefix = 'lang_last_used_';

  @override
  LanguagePackState build() {
    ref.onDispose(() => _sub?.cancel());
    final engine = ref.read(translateEngineProvider);
    _sub = engine.progressStream.listen(_onProgress);
    unawaited(_init());
    return const LanguagePackState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final wifiOnly = prefs.getBool(SettingKeys.translateWifiOnly) ?? false;
    state = state.copyWith(wifiOnly: wifiOnly);
    if (wifiOnly) {
      await ref.read(translateEngineProvider).setWifiOnly(true);
    }
    await refresh();
    if (prefs.getBool(SettingKeys.autoRemoveUnusedLanguages) ?? false) {
      await pruneUnused(prefs: prefs);
    }
  }

  Future<void> refresh() async {
    final engine = ref.read(translateEngineProvider);
    final languages = await engine.getSupportedLanguages();
    state = state.copyWith(languages: languages, loading: false);
  }

  void _onProgress(LanguageDownloadProgress event) {
    final progress = Map<String, LanguageDownloadProgress>.from(
      state.progress,
    )..[event.code] = event;
    state = state.copyWith(progress: progress);

    final terminal = event.state == LanguageDownloadState.completed ||
        event.state == LanguageDownloadState.canceled;
    if (!terminal) return;

    final isDownloaded = event.state == LanguageDownloadState.completed;
    state = state.copyWith(
      languages: [
        for (final lang in state.languages)
          if (lang.code == event.code)
            lang.copyWith(isDownloaded: isDownloaded)
          else
            lang,
      ],
    );
  }

  Future<void> download(String code) =>
      ref.read(translateEngineProvider).downloadLanguage(code);

  Future<void> downloadAll() =>
      ref.read(translateEngineProvider).downloadAllLanguages();

  Future<void> cancel(String code) =>
      ref.read(translateEngineProvider).cancelDownload(code);

  Future<void> delete(String code) async {
    await ref.read(translateEngineProvider).deleteLanguage(code);
    state = state.copyWith(
      languages: [
        for (final lang in state.languages)
          if (lang.code == code) lang.copyWith(isDownloaded: false) else lang,
      ],
    );
  }

  Future<void> setWifiOnly(bool enabled) async {
    state = state.copyWith(wifiOnly: enabled);
    await ref.read(translateEngineProvider).setWifiOnly(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingKeys.translateWifiOnly, enabled);
  }

  Future<void> setAutoRemoveUnused(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingKeys.autoRemoveUnusedLanguages, enabled);
  }

  Future<bool> autoRemoveUnusedEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(SettingKeys.autoRemoveUnusedLanguages) ?? false;
  }

  /// Call after a successful translation so [pruneUnused] knows this
  /// language is still in active use.
  Future<void> recordUsage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_lastUsedKeyPrefix$code',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Deletes downloaded language packs that haven't been used in
  /// [_staleAfter]. Languages that were downloaded but never translated
  /// with are treated as used at download time, so they get one full
  /// grace period before being swept. Returns the codes removed.
  Future<List<String>> pruneUnused({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final cutoff = DateTime.now().subtract(_staleAfter).millisecondsSinceEpoch;
    final removed = <String>[];
    for (final lang in state.languages.where((l) => l.isDownloaded)) {
      final lastUsed = p.getInt('$_lastUsedKeyPrefix${lang.code}');
      if (lastUsed != null && lastUsed >= cutoff) continue;
      if (lastUsed == null) {
        // Never recorded — start the grace period now rather than
        // deleting a pack the user just downloaded.
        await p.setInt(
          '$_lastUsedKeyPrefix${lang.code}',
          DateTime.now().millisecondsSinceEpoch,
        );
        continue;
      }
      await delete(lang.code);
      removed.add(lang.code);
    }
    return removed;
  }
}

final languagePackProvider =
    NotifierProvider<LanguagePackNotifier, LanguagePackState>(
  LanguagePackNotifier.new,
);
