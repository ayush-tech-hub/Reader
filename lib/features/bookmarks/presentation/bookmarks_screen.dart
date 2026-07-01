import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../pdf_reader/domain/entities/reader_entities.dart';

final _allBookmarksProvider = FutureProvider<List<Bookmark>>((ref) async {
  return ref.watch(readerLocalDataSourceProvider).getAllBookmarks();
});

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allBookmarksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Bookmarks')),
      body: async.when(
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return Center(
              child: Text(
                'No bookmarks yet.\nOpen a PDF and bookmark pages to see them here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            );
          }
          // Group by document.
          final grouped = <String, List<Bookmark>>{};
          for (final bm in bookmarks) {
            grouped.putIfAbsent(bm.documentPath, () => []).add(bm);
          }
          final docs = grouped.keys.toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final docPath = docs[i];
              final bms = grouped[docPath]!;
              return _DocGroup(docPath: docPath, bookmarks: bms, ref: ref);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DocGroup extends StatelessWidget {
  const _DocGroup({
    required this.docPath,
    required this.bookmarks,
    required this.ref,
  });

  final String docPath;
  final List<Bookmark> bookmarks;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = p.basenameWithoutExtension(docPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.picture_as_pdf, color: scheme.primary),
          title: Text(
            name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: () => context.push(
              '${Routes.reader}?path=${Uri.encodeComponent(docPath)}',
            ),
            child: const Text('Open'),
          ),
        ),
        for (final bm in bookmarks)
          Dismissible(
            key: ValueKey(bm.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: scheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.delete_outline, color: scheme.onError),
            ),
            onDismissed: (_) async {
              if (bm.id != null) {
                await ref
                    .read(readerLocalDataSourceProvider)
                    .deleteBookmark(bm.id!);
                ref.invalidate(_allBookmarksProvider);
              }
            },
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: scheme.secondaryContainer,
                child: Text(
                  '${bm.page}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              title: Text(
                bm.label.isEmpty ? 'Page ${bm.page}' : bm.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_relative(bm.createdAt)),
              onTap: () => context.push(
                '${Routes.reader}?path=${Uri.encodeComponent(docPath)}'
                '&page=${bm.page}',
              ),
            ),
          ),
        const Divider(),
      ],
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}
