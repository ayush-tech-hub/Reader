import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/entities/file_entry.dart';
import '../providers/file_manager_providers.dart';

/// Favorites & pinned folders — both backed by the same `favorites` table
/// (folders are favorites with [Favorite.isDirectory] true).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favorites)),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (favorites) {
          if (favorites.isEmpty) {
            return Center(child: Text(l10n.noFavorites));
          }
          final folders = favorites.where((f) => f.isDirectory).toList();
          final files = favorites.where((f) => !f.isDirectory).toList();
          return ListView(
            children: [
              if (folders.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    l10n.pinnedFolders,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final folder in folders)
                  ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder.name, maxLines: 1),
                    subtitle: Text(
                      p.dirname(folder.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.push_pin),
                      onPressed: () => ref
                          .read(fileManagerRepositoryProvider)
                          .removeFavorite(folder.path)
                          .then((_) => ref.invalidate(favoritesProvider)),
                    ),
                    onTap: () => context.push(
                      '${Routes.browser}?${Uri(queryParameters: {
                            'path': folder.path
                          }).query}',
                    ),
                  ),
              ],
              if (files.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    l10n.favorites,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final file in files) _FavoriteFileTile(favorite: file),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteFileTile extends ConsumerWidget {
  const _FavoriteFileTile({required this.favorite});

  final Favorite favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ext = p.extension(favorite.path).toLowerCase();
    return ListTile(
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text(favorite.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        p.dirname(favorite.path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.favorite),
        tooltip: l10n.removeFromFavorites,
        onPressed: () => ref
            .read(fileManagerRepositoryProvider)
            .removeFavorite(favorite.path)
            .then((_) => ref.invalidate(favoritesProvider)),
      ),
      onTap: () {
        final uri = Uri(queryParameters: {'path': favorite.path});
        if (AppConstants.pdfExtensions.contains(ext)) {
          context.push('${Routes.reader}?${uri.query}');
        } else if (AppConstants.archiveExtensions.contains(ext)) {
          context.push('${Routes.archive}?${uri.query}');
        }
      },
    );
  }
}
