import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../generated/app_localizations.dart';
import '../data/storage_root.dart';
import '../data/storage_scanner.dart';
import 'widgets/storage_pie_chart.dart';

class StorageAnalyzerScreen extends ConsumerStatefulWidget {
  const StorageAnalyzerScreen({super.key});

  @override
  ConsumerState<StorageAnalyzerScreen> createState() =>
      _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState extends ConsumerState<StorageAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  StorageScanReport? _report;
  int _scannedCount = 0;
  bool _scanning = false;
  int? _deviceTotalBytes;
  int? _deviceFreeBytes;
  late final AnimationController _pieController;

  @override
  void initState() {
    super.initState();
    _pieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.microtask(_scan);
  }

  @override
  void dispose() {
    _pieController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final root = await acquireStorageRootPath();
    if (root == null) return;

    final roots = await ref
        .read(fileManagerRepositoryProvider)
        .getStorageRoots();
    roots.fold((_) {}, (list) {
      if (list.isNotEmpty) {
        _deviceTotalBytes = list.first.totalBytes;
        _deviceFreeBytes = list.first.freeBytes;
      }
    });

    setState(() {
      _scanning = true;
      _report = null;
      _scannedCount = 0;
    });

    await for (final progress in ref.read(storageScannerProvider).scan(root)) {
      if (!mounted) return;
      setState(() {
        _scannedCount = progress.scannedCount;
        if (progress.done) {
          _report = progress.report;
          _scanning = false;
        }
      });
      if (progress.done) {
        _pieController
          ..reset()
          ..forward();
      }
    }
  }

  void _openCategory(StorageCategory category, CategoryBucket bucket) {
    HapticFeedback.selectionClick();
    context.push(
      '${Routes.storageCategory}?category=${category.name}',
      extra: bucket,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageAnalyzer),
        actions: [
          IconButton(
            tooltip: l10n.rescan,
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: _scanning
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.scanning),
                  const SizedBox(height: 4),
                  Text(
                    l10n.scannedSoFar(_scannedCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : report == null
          ? Center(child: Text(l10n.scanHint))
          : RefreshIndicator(
              onRefresh: _scan,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_deviceTotalBytes != null) ...[
                    _StorageUsageBar(
                      totalBytes: _deviceTotalBytes!,
                      freeBytes: _deviceFreeBytes ?? 0,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Center(
                    child: AnimatedBuilder(
                      animation: _pieController,
                      builder: (context, _) => StoragePieChart(
                        progress: _pieController.value,
                        centerLabel: formatBytes(report.totalBytes),
                        centerSubLabel: l10n.filesCount(report.totalFiles),
                        slices: [
                          for (final category in StorageCategory.values)
                            if (category.isPrimaryType)
                              StorageSlice(
                                color: category.color(scheme),
                                bytes:
                                    report.buckets[category]?.totalBytes ?? 0,
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.byFileType,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.6,
                        ),
                    itemCount: StorageCategory.values.length,
                    itemBuilder: (context, index) {
                      final category = StorageCategory.values[index];
                      final bucket =
                          report.buckets[category] ?? CategoryBucket();
                      return _CategoryCard(
                        category: category,
                        bucket: bucket,
                        index: index,
                        onTap: () => _openCategory(category, bucket),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _StorageUsageBar extends StatelessWidget {
  const _StorageUsageBar({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final used = (totalBytes - freeBytes).clamp(0, totalBytes);
    final fraction = totalBytes > 0 ? used / totalBytes : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.storageOverview,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.usedOfTotal(formatBytes(used), formatBytes(totalBytes)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.bucket,
    required this.index,
    required this.onTap,
  });

  final StorageCategory category;
  final CategoryBucket bucket;
  final int index;
  final VoidCallback onTap;

  String _label(AppLocalizations l10n) => switch (category) {
    StorageCategory.images => l10n.categoryImages,
    StorageCategory.videos => l10n.categoryVideos,
    StorageCategory.audio => l10n.categoryAudio,
    StorageCategory.documents => l10n.categoryDocuments,
    StorageCategory.apks => l10n.categoryApks,
    StorageCategory.archives => l10n.categoryArchives,
    StorageCategory.downloads => l10n.categoryDownloads,
    StorageCategory.hidden => l10n.categoryHidden,
    StorageCategory.largeFiles => l10n.categoryLargeFiles,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = category.color(scheme);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                  child: Icon(category.icon, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        formatBytes(bucket.totalBytes),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.filesCount(bucket.fileCount),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
