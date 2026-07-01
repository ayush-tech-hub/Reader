// ignore_for_file: unawaited_futures

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../generated/app_localizations.dart';
import '../data/text_analysis.dart' as ai;
import 'providers/language_pack_providers.dart';
import 'screens/flashcard_screen.dart';
import 'screens/quiz_screen.dart';

/// Local document intelligence: summarization, extractive Q&A over the
/// search index, on-device OCR and translation. Everything runs
/// offline; an optional heavier model can plug in via LocalAiBackend.
class AiToolsScreen extends ConsumerStatefulWidget {
  const AiToolsScreen({super.key});

  @override
  ConsumerState<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends ConsumerState<AiToolsScreen> {
  final _questionController = TextEditingController();
  String? _documentPath;
  String _output = '';
  bool _busy = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _documentPath = path);
  }

  Future<void> _run(Future<String> Function() task) async {
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      final result = await task();
      if (mounted) setState(() => _output = result);
    } catch (e) {
      if (mounted) setState(() => _output = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _documentText() async {
    final l10n = AppLocalizations.of(context);
    final path = _documentPath;
    if (path == null) {
      throw Exception(l10n.pickDocument);
    }
    final index = ref.read(documentIndexServiceProvider);
    var text = await index.documentText(path);
    if (text.trim().isEmpty) {
      // Not indexed yet — index this file on demand.
      await index.indexFile(path);
      text = await index.documentText(path);
    }
    if (text.trim().isEmpty) {
      throw Exception(l10n.noTextInDocument);
    }
    return text;
  }

  Future<void> _summarize() => _run(() async {
        final text = await _documentText();
        final backend = ai.registeredAiBackend;
        if (backend != null) return backend.summarize(text);
        return ai.summarize(text, maxSentences: 7);
      });

  Future<void> _keywords() => _run(() async {
        final text = await _documentText();
        final words = ai.extractKeywords(text, maxKeywords: 15);
        return 'Key topics:\n\n${words.map((w) => '• $w').join('\n')}';
      });

  Future<void> _bulletPoints() => _run(() async {
        final text = await _documentText();
        return ai.extractBulletPoints(text, maxPoints: 8);
      });

  Future<void> _simplify() => _run(() async {
        final source = _output.isNotEmpty ? _output : await _documentText();
        return ai.simplify(source.length > 5000 ? source.substring(0, 5000) : source);
      });

  Future<void> _rewrite() => _run(() async {
        final source = _output.isNotEmpty ? _output : await _documentText();
        return ai.rewrite(source.length > 5000 ? source.substring(0, 5000) : source);
      });

  Future<void> _citations() => _run(() async {
        final text = await _documentText();
        final cites = ai.extractCitations(text);
        if (cites.isEmpty) return 'No citations detected.';
        final buf = StringBuffer('Found ${cites.length} citation(s):\n\n');
        for (final c in cites) {
          final kind = c.kind.name.toUpperCase();
          buf.writeln('[$kind] ${c.raw}');
          if (c.authors != null) buf.writeln('  Authors: ${c.authors}');
          if (c.year != null) buf.writeln('  Year: ${c.year}');
          buf.writeln();
        }
        return buf.toString().trim();
      });

  Future<void> _formulas() => _run(() async {
        final text = await _documentText();
        final fmls = ai.extractFormulas(text);
        if (fmls.isEmpty) return 'No formulas detected.';
        return fmls
            .map((f) => f.context.isEmpty ? f.raw : '${f.raw}\n  ↳ ${f.context}')
            .join('\n\n');
      });

  Future<void> _extractTables() => _run(() async {
        final text = await _documentText();
        final tables = ai.extractTables(text);
        if (tables.isEmpty) return 'No tables detected in document.';
        final buf = StringBuffer();
        for (var i = 0; i < tables.length; i++) {
          final t = tables[i];
          buf.writeln('Table ${i + 1} (${t.columnCount} columns, ${t.rows.length} rows)');
          buf.writeln(t.headers.join(' | '));
          buf.writeln('${List.filled(t.columnCount, '---').join(' | ')}');
          for (final row in t.rows) {
            buf.writeln(row.join(' | '));
          }
          buf.writeln();
        }
        return buf.toString().trim();
      });

  Future<void> _ask() => _run(() async {
        final l10n = AppLocalizations.of(context);
        final question = _questionController.text.trim();
        if (question.isEmpty) return '';
        final index = ref.read(documentIndexServiceProvider);
        final candidates = await index.candidates(question);
        if (candidates.isEmpty) {
          return l10n.noAnswerFound;
        }
        final ranked = ai.rankByTfIdf(question, [
          for (final c in candidates) c.content,
        ]);
        final passages = [for (final (i, _) in ranked.take(3)) candidates[i]];
        final backend = ai.registeredAiBackend;
        if (backend != null) {
          return backend.answer(question, [
            for (final passage in passages) passage.content,
          ]);
        }
        // Extractive baseline: best passages with citations.
        return passages
            .map(
              (passage) => '${ai.summarize(passage.content, maxSentences: 2)}'
                  '\n— ${passage.name}, p.${passage.page}',
            )
            .join('\n\n');
      });

  Future<void> _flashcards() async {
    String text;
    try {
      text = await _documentText();
    } catch (e) {
      if (mounted) setState(() => _output = e.toString());
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlashcardScreen(text: text),
      ),
    );
  }

  Future<void> _quiz() async {
    String text;
    try {
      text = await _documentText();
    } catch (e) {
      if (mounted) setState(() => _output = e.toString());
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(text: text),
      ),
    );
  }

  Future<void> _ocr() => _run(() async {
        final path = _documentPath;
        if (path == null) {
          throw Exception(AppLocalizations.of(context).pickDocument);
        }
        final pages = await ref.read(ocrEngineProvider).recognizePdf(path);
        await ref
            .read(documentIndexServiceProvider)
            .indexExternalText(path: path, pageTexts: pages);
        return pages.join('\n\n');
      });

  Future<void> _translate() async {
    if (!mounted) return;
    final languages = ref.read(languagePackProvider).languages;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select target language'),
        children: [
          for (final lang in languages)
            _LanguageOption(
              name: lang.displayName,
              code: lang.code,
              isDownloaded: lang.isDownloaded,
              onTap: () => Navigator.of(ctx).pop(lang.code),
            ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(Routes.languagePacks);
            },
            child: const Row(
              children: [
                Icon(Icons.settings_outlined, size: 18),
                SizedBox(width: 8),
                Text('Manage languages…'),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    _run(() async {
      final source = _output.isNotEmpty ? _output : await _documentText();
      final result = await ref.read(translateEngineProvider).translate(
            text: source.length > 4000 ? source.substring(0, 4000) : source,
            sourceLanguage: 'en',
            targetLanguage: picked,
          );
      await ref.read(languagePackProvider.notifier).recordUsage(picked);
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final packState = ref.watch(languagePackProvider);
    final total = packState.languages.length;
    final downloadedCount = packState.downloadedCount;
    final allReady = !packState.loading && total > 0 && downloadedCount == total;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiAssistant),
        actions: [
          IconButton(
            tooltip: 'Manage languages',
            icon: const Icon(Icons.translate),
            onPressed: () => context.push(Routes.languagePacks),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Translation model status banner
          if (!packState.loading && total > 0 && !allReady)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.download_outlined),
                title: const Text('Translation models'),
                subtitle: Text(
                  '$downloadedCount / $total languages ready for offline use',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Download more',
                  onPressed: () => context.push(Routes.languagePacks),
                ),
              ),
            )
          else if (!packState.loading && allReady)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.offline_pin,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                title: Text(
                  'All $total translation models ready — fully offline',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          if (!packState.loading) const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(
                _documentPath == null
                    ? l10n.pickDocument
                    : p.basename(_documentPath!),
              ),
              trailing: const Icon(Icons.folder_open),
              onTap: _pickDocument,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.summarize),
                label: Text(l10n.summarize),
                onPressed: _busy ? null : _summarize,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('Bullet points'),
                onPressed: _busy ? null : _bulletPoints,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.tag),
                label: const Text('Keywords'),
                onPressed: _busy ? null : _keywords,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.short_text),
                label: const Text('Simplify'),
                onPressed: _busy ? null : _simplify,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.spellcheck),
                label: const Text('Rewrite'),
                onPressed: _busy ? null : _rewrite,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Tables'),
                onPressed: _busy ? null : _extractTables,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.format_quote_outlined),
                label: const Text('Citations'),
                onPressed: _busy ? null : _citations,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.functions),
                label: const Text('Formulas'),
                onPressed: _busy ? null : _formulas,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.style_outlined),
                label: const Text('Flashcards'),
                onPressed: _busy ? null : _flashcards,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Quiz'),
                onPressed: _busy ? null : _quiz,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.document_scanner),
                label: Text(l10n.ocrPdf),
                onPressed: _busy ? null : _ocr,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.translate),
                label: Text(l10n.translate),
                onPressed: _busy ? null : _translate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: l10n.askAQuestion,
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _busy ? null : _ask,
              ),
            ),
            onSubmitted: (_) => _ask(),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_output.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_output),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Language picker row ---------------------------------------------------

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.name,
    required this.code,
    required this.isDownloaded,
    required this.onTap,
  });

  final String name;
  final String code;
  final bool isDownloaded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final trailing = isDownloaded
        ? Icon(Icons.offline_pin, size: 16, color: colorScheme.primary)
        : Icon(
            Icons.cloud_download_outlined,
            size: 16,
            color: colorScheme.secondary,
          );

    return ListTile(
      dense: true,
      title: Text(name),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
