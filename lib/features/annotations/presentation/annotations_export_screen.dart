import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../pdf_reader/domain/entities/reader_entities.dart';

final _annotationsProvider =
    FutureProvider<List<Annotation>>((ref) async {
  return ref.watch(readerLocalDataSourceProvider).getAllAnnotations();
});

class AnnotationsExportScreen extends ConsumerWidget {
  const AnnotationsExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_annotationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotations'),
        actions: [
          async.whenOrNull(
            data: (list) => list.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Export all',
                    onPressed: () => _export(context, list),
                  ),
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: async.when(
        data: (annotations) {
          if (annotations.isEmpty) {
            return Center(
              child: Text(
                'No annotations yet.\n'
                'Highlight or draw on a PDF to create annotations.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            );
          }

          // Group by document.
          final grouped = <String, List<Annotation>>{};
          for (final a in annotations) {
            grouped.putIfAbsent(a.documentPath, () => []).add(a);
          }
          final docs = grouped.keys.toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final docPath = docs[i];
              final annots = grouped[docPath]!;
              return _DocGroup(docPath: docPath, annotations: annots);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _export(
      BuildContext context, List<Annotation> annotations) async {
    final buf = StringBuffer();
    final grouped = <String, List<Annotation>>{};
    for (final a in annotations) {
      grouped.putIfAbsent(a.documentPath, () => []).add(a);
    }

    for (final entry in grouped.entries) {
      buf.writeln('=== ${p.basenameWithoutExtension(entry.key)} ===');
      for (final a in entry.value) {
        final label = a.type.name[0].toUpperCase() + a.type.name.substring(1);
        buf.writeln('[p.${a.page}] $label'
            '${a.note.isNotEmpty ? ': ${a.note}' : ''}');
      }
      buf.writeln();
    }

    final text = buf.toString();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'annotations_export.txt'));
      await file.writeAsString(text);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Annotations export',
      );
    } catch (_) {
      // Fallback: copy to clipboard.
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    }
  }
}

class _DocGroup extends StatelessWidget {
  const _DocGroup({required this.docPath, required this.annotations});

  final String docPath;
  final List<Annotation> annotations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.picture_as_pdf, color: scheme.primary),
          title: Text(
            p.basenameWithoutExtension(docPath),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${annotations.length} annotation${annotations.length != 1 ? 's' : ''}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
        for (final a in annotations)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            leading: _typeIcon(a.type, Color(a.color)),
            title: Text(
              a.note.isNotEmpty ? a.note : _typeName(a.type),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Page ${a.page}'),
          ),
        const Divider(),
      ],
    );
  }

  static Widget _typeIcon(AnnotationType type, Color color) {
    final icons = {
      AnnotationType.highlight: Icons.highlight,
      AnnotationType.underline: Icons.format_underline,
      AnnotationType.strikeout: Icons.strikethrough_s,
      AnnotationType.ink: Icons.edit,
      AnnotationType.note: Icons.sticky_note_2_outlined,
    };
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icons[type] ?? Icons.label_outline, size: 16, color: color),
    );
  }

  static String _typeName(AnnotationType type) {
    switch (type) {
      case AnnotationType.highlight:
        return 'Highlight';
      case AnnotationType.underline:
        return 'Underline';
      case AnnotationType.strikeout:
        return 'Strikeout';
      case AnnotationType.ink:
        return 'Drawing';
      case AnnotationType.note:
        return 'Note';
    }
  }
}
