import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/byte_formatter.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/archive_entities.dart';
import '../providers/archive_providers.dart';

/// Browses an archive's contents (when [archivePath] is given) and
/// hosts the create/extract flows with live progress.
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key, this.archivePath});

  final String? archivePath;

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  @override
  void initState() {
    super.initState();
    final path = widget.archivePath;
    if (path != null) {
      Future.microtask(
        () => ref.read(archiveScreenProvider.notifier).loadEntries(path),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(archiveScreenProvider);
    final progress = ref.watch(archiveProgressProvider).valueOrNull;
    final activeJob = state.activeJob;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.archivePath == null
              ? l10n.archives
              : p.basename(widget.archivePath!),
        ),
        actions: [
          if (widget.archivePath != null) ...[
            IconButton(
              tooltip: l10n.extract,
              icon: const Icon(Icons.unarchive),
              onPressed: () => _extract(widget.archivePath!),
            ),
            IconButton(
              tooltip: l10n.extractInBackground,
              icon: const Icon(Icons.schedule),
              onPressed: () => _extractInBackground(widget.archivePath!),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (activeJob != null)
            _JobProgressBanner(
              job: activeJob,
              progress: progress?.jobId == activeJob.id ? progress : null,
              onCancel: () =>
                  ref.read(archiveScreenProvider.notifier).cancelActiveJob(),
            ),
          if (state.lastError != null)
            MaterialBanner(
              content: Text(state.lastError!),
              leading: const Icon(Icons.error_outline),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: state.entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (entries) => entries.isEmpty
                  ? Center(child: Text(l10n.archiveEmpty))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          leading: Icon(
                            entry.isDirectory
                                ? Icons.folder
                                : Icons.insert_drive_file,
                          ),
                          title: Text(entry.name),
                          subtitle: entry.isDirectory
                              ? null
                              : Text(formatBytes(entry.size)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.archive),
        label: Text(l10n.createArchive),
        onPressed: _create,
      ),
    );
  }

  Future<void> _create() async {
    final picked = await FilePicker.pickFiles(allowMultiple: true);
    if (picked == null || picked.paths.isEmpty || !mounted) return;
    final sources = picked.paths.whereType<String>().toList();
    final options = await showDialog<_CreateOptions>(
      context: context,
      builder: (context) => _CreateArchiveDialog(
        suggestedName: p.basenameWithoutExtension(sources.first),
      ),
    );
    if (options == null || !mounted) return;
    final destinationDir = await FilePicker.getDirectoryPath();
    if (destinationDir == null || !mounted) return;
    await ref.read(archiveScreenProvider.notifier).create(
          sources: sources,
          archivePath: p.join(
            destinationDir,
            '${options.name}${options.format.extension}',
          ),
          format: options.format,
          password: options.password,
          compressionLevel: options.level,
        );
  }

  Future<void> _extract(String archivePath) async {
    final destinationDir = await FilePicker.getDirectoryPath();
    if (destinationDir == null || !mounted) return;
    String? password;
    if (ArchiveFormat.fromPath(archivePath) == ArchiveFormat.zip) {
      password = await _promptOptionalPassword();
      if (!mounted) return;
    }
    await ref.read(archiveScreenProvider.notifier).extract(
          archivePath: archivePath,
          destinationDir: destinationDir,
          password: password,
        );
  }

  Future<void> _extractInBackground(String archivePath) async {
    final l10n = AppLocalizations.of(context);
    final destinationDir = await FilePicker.getDirectoryPath();
    if (destinationDir == null || !mounted) return;
    String? password;
    if (ArchiveFormat.fromPath(archivePath) == ArchiveFormat.zip) {
      password = await _promptOptionalPassword();
      if (!mounted) return;
    }
    final queued =
        await ref.read(archiveScreenProvider.notifier).extractInBackground(
              archivePath: archivePath,
              destinationDir: destinationDir,
              password: password,
            );
    if (queued && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backgroundJobQueued)),
      );
    }
  }

  Future<String?> _promptOptionalPassword() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.passwordOptional),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.password),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    return (password == null || password.isEmpty) ? null : password;
  }
}

class _JobProgressBanner extends StatelessWidget {
  const _JobProgressBanner({
    required this.job,
    required this.progress,
    required this.onCancel,
  });

  final ArchiveJob job;
  final ArchiveProgress? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label =
        job.type == ArchiveJobType.create ? l10n.compressing : l10n.extracting;
    final fraction =
        job.status == ArchiveJobStatus.done ? 1.0 : progress?.fraction;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.status == ArchiveJobStatus.done ? l10n.jobDone : label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (job.status == ArchiveJobStatus.running)
                  TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: fraction),
            if (progress != null && progress!.currentEntry.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  progress!.currentEntry,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateOptions {
  const _CreateOptions(this.name, this.format, this.password, this.level);

  final String name;
  final ArchiveFormat format;
  final String? password;
  final int level;
}

class _CreateArchiveDialog extends StatefulWidget {
  const _CreateArchiveDialog({required this.suggestedName});

  final String suggestedName;

  @override
  State<_CreateArchiveDialog> createState() => _CreateArchiveDialogState();
}

class _CreateArchiveDialogState extends State<_CreateArchiveDialog> {
  late final _nameController =
      TextEditingController(text: widget.suggestedName);
  final _passwordController = TextEditingController();
  ArchiveFormat _format = ArchiveFormat.zip;
  double _level = 6;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.createArchive),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.archiveName),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ArchiveFormat>(
              segments: [
                for (final format in ArchiveFormat.values)
                  ButtonSegment(
                    value: format,
                    label: Text(format.extension),
                  ),
              ],
              selected: {_format},
              onSelectionChanged: (selection) =>
                  setState(() => _format = selection.single),
            ),
            const SizedBox(height: 12),
            if (_format.supportsPassword)
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.passwordOptional),
              ),
            const SizedBox(height: 12),
            Text(l10n.compressionLevel(_level.round())),
            Slider(
              value: _level,
              min: 1,
              max: 9,
              divisions: 8,
              onChanged: (value) => setState(() => _level = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final password = _passwordController.text;
            Navigator.of(context).pop(
              _CreateOptions(
                _nameController.text.trim(),
                _format,
                (password.isEmpty || !_format.supportsPassword)
                    ? null
                    : password,
                _level.round(),
              ),
            );
          },
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
