import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../data/ml_engines.dart';
import '../providers/language_pack_providers.dart';

/// Lets the user browse every offline translation language ML Kit
/// supports, download/cancel/delete individual packs or all of them at
/// once, and tune Wi-Fi-only / auto-cleanup behavior — all backed by
/// [languagePackProvider].
class LanguagePackManagerScreen extends ConsumerStatefulWidget {
  const LanguagePackManagerScreen({super.key});

  @override
  ConsumerState<LanguagePackManagerScreen> createState() =>
      _LanguagePackManagerScreenState();
}

class _LanguagePackManagerScreenState
    extends ConsumerState<LanguagePackManagerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDownloadAll(List<LanguagePack> pending) async {
    if (pending.isEmpty) return;
    final totalBytes = pending.fold<int>(
      0,
      (sum, l) => sum + l.sizeEstimateBytes,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download all languages?'),
        content: Text(
          'This will download ${pending.length} language packs '
          '(~${formatBytes(totalBytes)} estimated total). Downloads run '
          'in the background and can be canceled individually at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(languagePackProvider.notifier).downloadAll();
    }
  }

  Future<void> _confirmDelete(LanguagePack lang) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${lang.displayName}?'),
        content: const Text(
          'This deletes the downloaded language model. You can download '
          'it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(languagePackProvider.notifier).delete(lang.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(languagePackProvider);
    final notifier = ref.read(languagePackProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final filtered = _query.isEmpty
        ? state.languages
        : state.languages.where((l) {
            final q = _query.toLowerCase();
            return l.displayName.toLowerCase().contains(q) ||
                l.code.toLowerCase().contains(q);
          }).toList();

    final pending = state.languages.where((l) => !l.isDownloaded).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language packs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : notifier.refresh,
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.offline_pin, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${state.downloadedCount} / '
                                '${state.languages.length} languages '
                                'downloaded · ${formatBytes(state.downloadedBytesEstimate)}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Download over Wi-Fi only'),
                          value: state.wifiOnly,
                          onChanged: notifier.setWifiOnly,
                        ),
                        FutureBuilder<bool>(
                          future: notifier.autoRemoveUnusedEnabled(),
                          builder: (context, snapshot) {
                            final enabled = snapshot.data ?? false;
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text(
                                'Auto-remove packs unused for 30+ days',
                              ),
                              value: enabled,
                              onChanged: (value) async {
                                await notifier.setAutoRemoveUnused(value);
                                setState(() {});
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text(
                            pending.isEmpty
                                ? 'All languages downloaded'
                                : 'Download all (${pending.length})',
                          ),
                          onPressed: pending.isEmpty
                              ? null
                              : () => _confirmDownloadAll(pending),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search languages…',
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final lang = filtered[index];
                      final progress = state.progress[lang.code];
                      return _LanguageTile(
                        language: lang,
                        progress: progress,
                        onDownload: () => notifier.download(lang.code),
                        onCancel: () => notifier.cancel(lang.code),
                        onDelete: () => _confirmDelete(lang),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  final LanguagePack language;
  final LanguageDownloadProgress? progress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inProgress = progress != null &&
        (progress!.state == LanguageDownloadState.queued ||
            progress!.state == LanguageDownloadState.downloading);

    Widget trailing;
    if (inProgress) {
      trailing = IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close),
        onPressed: onCancel,
      );
    } else if (language.isDownloaded) {
      trailing = IconButton(
        tooltip: 'Remove',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      );
    } else {
      trailing = IconButton(
        tooltip: 'Download',
        icon: const Icon(Icons.download_outlined),
        onPressed: onDownload,
      );
    }

    String? subtitle;
    double? fraction;
    if (inProgress && progress != null) {
      fraction = progress!.fraction;
      final remaining = (progress!.bytesTotal - progress!.bytesDone)
          .clamp(0, progress!.bytesTotal);
      subtitle = progress!.state == LanguageDownloadState.queued
          ? 'Queued…'
          : '${(fraction * 100).toStringAsFixed(0)}% · '
              '${formatBytes(remaining)} remaining';
    } else if (progress?.state == LanguageDownloadState.failed) {
      subtitle = 'Download failed: ${progress?.error ?? 'unknown error'}';
    } else if (language.isDownloaded) {
      subtitle = 'Downloaded · ${formatBytes(language.sizeEstimateBytes)}';
    } else {
      subtitle = '~${formatBytes(language.sizeEstimateBytes)}';
    }

    return ListTile(
      leading: Icon(
        language.isDownloaded ? Icons.offline_pin : Icons.translate,
        color: language.isDownloaded ? colorScheme.primary : null,
      ),
      title: Text('${language.displayName} (${language.code})'),
      subtitle: fraction != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: fraction),
                ),
              ],
            )
          : Text(subtitle),
      isThreeLine: fraction != null,
      trailing: trailing,
    );
  }
}
