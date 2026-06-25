import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/file_entry.dart';

/// Pending copy/move set ("clipboard"): pick files, navigate, paste.
@immutable
class FileClipboard {
  const FileClipboard({required this.paths, required this.isMove});

  final List<String> paths;
  final bool isMove;
}

@immutable
class BrowserState {
  const BrowserState({
    required this.currentPath,
    this.entries = const AsyncValue.loading(),
    this.viewMode = FileViewMode.list,
    this.sortField = FileSortField.name,
    this.sortAscending = true,
    this.showHidden = false,
    this.selection = const {},
    this.clipboard,
    this.searchResults,
  });

  final String currentPath;
  final AsyncValue<List<FileEntry>> entries;
  final FileViewMode viewMode;
  final FileSortField sortField;
  final bool sortAscending;
  final bool showHidden;
  final Set<String> selection;
  final FileClipboard? clipboard;

  /// Non-null while a search is active.
  final List<FileEntry>? searchResults;

  bool get selectionMode => selection.isNotEmpty;

  BrowserState copyWith({
    String? currentPath,
    AsyncValue<List<FileEntry>>? entries,
    FileViewMode? viewMode,
    FileSortField? sortField,
    bool? sortAscending,
    bool? showHidden,
    Set<String>? selection,
    FileClipboard? clipboard,
    bool clearClipboard = false,
    List<FileEntry>? searchResults,
    bool clearSearch = false,
  }) =>
      BrowserState(
        currentPath: currentPath ?? this.currentPath,
        entries: entries ?? this.entries,
        viewMode: viewMode ?? this.viewMode,
        sortField: sortField ?? this.sortField,
        sortAscending: sortAscending ?? this.sortAscending,
        showHidden: showHidden ?? this.showHidden,
        selection: selection ?? this.selection,
        clipboard: clearClipboard ? null : (clipboard ?? this.clipboard),
        searchResults:
            clearSearch ? null : (searchResults ?? this.searchResults),
      );
}

final browserProvider =
    NotifierProvider.autoDispose<BrowserNotifier, BrowserState>(
  BrowserNotifier.new,
);

class BrowserNotifier extends AutoDisposeNotifier<BrowserState> {
  @override
  BrowserState build() {
    Future.microtask(_init);
    return const BrowserState(currentPath: '');
  }

  /// Re-runs permission + root discovery (used by the error-state retry).
  Future<void> retryInit() => _init();

  Future<void> _init() async {
    if (!await ensureStorageAccess()) {
      state = state.copyWith(
        entries: AsyncValue.error(
          const PermissionFailure(
            'Storage permission is required to browse files. '
            'Grant it in system settings and pull to refresh.',
          ),
          StackTrace.current,
        ),
      );
      return;
    }
    final roots =
        await ref.read(fileManagerRepositoryProvider).getStorageRoots();
    final rootPath = roots.fold((_) => '/', (list) => list.first.path);
    await navigateTo(rootPath);
  }

  /// Android 11+ file managers need MANAGE_EXTERNAL_STORAGE (granted via
  /// a system settings screen); older devices use the legacy storage
  /// permission. iOS is sandboxed to the app container — nothing to ask.
  static Future<bool> ensureStorageAccess() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  Future<void> navigateTo(String path) async {
    state = state.copyWith(
      currentPath: path,
      entries: const AsyncValue.loading(),
      selection: {},
      clearSearch: true,
    );
    await refresh();
  }

  Future<void> refresh() async {
    final result = await ref.read(listDirectoryProvider).call(
          state.currentPath,
          showHidden: state.showHidden,
          sortField: state.sortField,
          ascending: state.sortAscending,
        );
    state = state.copyWith(
      entries: result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        AsyncValue.data,
      ),
    );
  }

  void setViewMode(FileViewMode mode) => state = state.copyWith(viewMode: mode);

  Future<void> setSort(FileSortField field) async {
    final ascending = state.sortField == field ? !state.sortAscending : true;
    state = state.copyWith(sortField: field, sortAscending: ascending);
    await refresh();
  }

  Future<void> toggleShowHidden() async {
    state = state.copyWith(showHidden: !state.showHidden);
    await refresh();
  }

  void toggleSelection(String path) {
    final selection = {...state.selection};
    selection.contains(path) ? selection.remove(path) : selection.add(path);
    state = state.copyWith(selection: selection);
  }

  void clearSelection() => state = state.copyWith(selection: {});

  void stageClipboard({required bool isMove}) {
    state = state.copyWith(
      clipboard: FileClipboard(paths: state.selection.toList(), isMove: isMove),
      selection: {},
    );
  }

  Future<Failure?> paste() async {
    final clipboard = state.clipboard;
    if (clipboard == null) return null;
    final repo = ref.read(fileManagerRepositoryProvider);
    final result = clipboard.isMove
        ? await repo.move(clipboard.paths, state.currentPath)
        : await repo.copy(clipboard.paths, state.currentPath);
    state = state.copyWith(clearClipboard: true);
    await refresh();
    return result.failureOrNull;
  }

  Future<Failure?> deleteSelection() async {
    final result = await ref
        .read(fileManagerRepositoryProvider)
        .delete(state.selection.toList());
    state = state.copyWith(selection: {});
    await refresh();
    return result.failureOrNull;
  }

  Future<Failure?> rename(String path, String newName) async {
    final result =
        await ref.read(fileManagerRepositoryProvider).rename(path, newName);
    await refresh();
    return result.failureOrNull;
  }

  Future<Failure?> createFolder(String name) async {
    final result = await ref
        .read(fileManagerRepositoryProvider)
        .createDirectory(state.currentPath, name);
    await refresh();
    return result.failureOrNull;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(clearSearch: true);
      return;
    }
    state = state.copyWith(searchResults: const []);
    final results = <FileEntry>[];
    // Batch state updates: one rebuild per ~200ms instead of one per hit.
    final stopwatch = Stopwatch()..start();
    await for (final entry in ref
        .read(fileManagerRepositoryProvider)
        .search(state.currentPath, query)) {
      results.add(entry);
      if (stopwatch.elapsedMilliseconds >= 200) {
        stopwatch.reset();
        state = state.copyWith(searchResults: List.of(results));
      }
      if (results.length >= 500) break; // soft cap; keep UI responsive
    }
    state = state.copyWith(searchResults: List.of(results));
  }

  Future<void> recordAccess(String path) => ref
      .read(fileManagerRepositoryProvider)
      .recordFileAccess(path)
      .then((_) {});
}

final favoritesProvider = FutureProvider.autoDispose<List<Favorite>>((
  ref,
) async {
  final result = await ref.watch(fileManagerRepositoryProvider).getFavorites();
  return result.fold((failure) => throw failure, (favorites) => favorites);
});

final recentFilesProvider = FutureProvider.autoDispose<List<FileEntry>>((
  ref,
) async {
  final result =
      await ref.watch(fileManagerRepositoryProvider).getRecentFiles();
  return result.fold((failure) => throw failure, (files) => files);
});
