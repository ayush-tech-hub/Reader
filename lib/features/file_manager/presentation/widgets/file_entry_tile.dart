import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../domain/entities/file_entry.dart';

IconData iconForEntry(FileEntry entry) {
  if (entry.isDirectory) return Icons.folder;
  if (AppConstants.pdfExtensions.contains(entry.extension)) {
    return Icons.picture_as_pdf;
  }
  if (AppConstants.archiveExtensions.contains(entry.extension)) {
    return Icons.folder_zip;
  }
  if (AppConstants.imageExtensions.contains(entry.extension)) {
    return Icons.image;
  }
  return Icons.insert_drive_file;
}

class FileEntryTile extends StatelessWidget {
  const FileEntryTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    this.trailing,
  });

  final FileEntry entry;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final subtitle = entry.isDirectory
        ? localizations.formatShortDate(entry.modifiedAt)
        : '${formatBytes(entry.size)} · '
            '${localizations.formatShortDate(entry.modifiedAt)}';
    return ListTile(
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onLongPress())
          : Icon(iconForEntry(entry)),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      selected: selected,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class FileEntryGridTile extends StatelessWidget {
  const FileEntryGridTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconForEntry(entry), size: 40),
              const SizedBox(height: 8),
              Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!entry.isDirectory)
                Text(
                  formatBytes(entry.size),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
