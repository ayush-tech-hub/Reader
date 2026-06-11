import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../generated/app_localizations.dart';
import '../../ai/data/text_analysis.dart' as ai;
import '../data/document_index_service.dart';

/// Smart search across every indexed PDF: FTS5 keyword hits, optionally
/// reranked with TF-IDF cosine similarity for semantic-style matching.
class SmartSearchScreen extends ConsumerStatefulWidget {
  const SmartSearchScreen({super.key});

  @override
  ConsumerState<SmartSearchScreen> createState() => _SmartSearchScreenState();
}

class _SmartSearchScreenState extends ConsumerState<SmartSearchScreen> {
  final _queryController = TextEditingController();
  List<IndexHit> _hits = const [];
  bool _semantic = true;
  bool _busy = false;
  (int, int, String)? _indexProgress;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() => _busy = true);
    final index = ref.read(documentIndexServiceProvider);
    List<IndexHit> hits;
    if (_semantic) {
      final candidates = await index.candidates(query);
      final ranked =
          ai.rankByTfIdf(query, [for (final c in candidates) c.content]);
      hits = [for (final (i, _) in ranked.take(50)) candidates[i]];
    } else {
      hits = await index.search(query);
    }
    if (mounted) {
      setState(() {
        _hits = hits;
        _busy = false;
      });
    }
  }

  Future<void> _buildIndex() async {
    final roots =
        await ref.read(fileManagerRepositoryProvider).getStorageRoots();
    final root = roots.valueOrNull?.firstOrNull;
    if (root == null || !mounted) return;
    final index = ref.read(documentIndexServiceProvider);
    await for (final progress in index.indexTree(root.path)) {
      if (!mounted) return;
      setState(() => _indexProgress = progress);
    }
    if (mounted) setState(() => _indexProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = _indexProgress;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.smartSearch),
        actions: [
          IconButton(
            tooltip: l10n.buildIndex,
            icon: const Icon(Icons.manage_search),
            onPressed: progress == null ? _buildIndex : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: l10n.searchAllPdfs,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: Text(l10n.semanticRanking),
            value: _semantic,
            onChanged: (value) => setState(() => _semantic = value),
          ),
          if (progress != null)
            ListTile(
              leading: const CircularProgressIndicator(),
              title: Text('${progress.$1} / ${progress.$2}'),
              subtitle: Text(
                progress.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _hits.length,
              itemBuilder: (context, index) {
                final hit = _hits[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(hit.name),
                  subtitle: Text(
                    hit.snippet.isNotEmpty
                        ? hit.snippet
                        : hit.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text('p.${hit.page}'),
                  onTap: () => context.push(
                    Uri(
                      path: Routes.reader,
                      queryParameters: {'path': hit.path},
                    ).toString(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
