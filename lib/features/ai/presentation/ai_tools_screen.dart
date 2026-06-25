import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../generated/app_localizations.dart';
import '../data/ml_engines.dart';
import '../data/text_analysis.dart' as ai;

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

  // Set of language codes whose ML Kit models are on-device.
  Set<String> _downloadedLanguages = {};
  bool _modelsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkDownloadedModels();
  }

  Future<void> _checkDownloadedModels() async {
    final downloaded =
        await ref.read(translateEngineProvider).getDownloadedLanguages();
    if (mounted) {
      setState(() {
        _downloadedLanguages = downloaded;
        _modelsChecked = true;
      });
    }
  }

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

  // (display name, BCP-47 code)
  static const _languages = [
    // ML Kit supported — models pre-downloaded at app startup
    ('Hindi', 'hi'),
    ('Bengali', 'bn'),
    ('Telugu', 'te'),
    ('Marathi', 'mr'),
    ('Tamil', 'ta'),
    ('Gujarati', 'gu'),
    ('Kannada', 'kn'),
    ('Malayalam', 'ml'),
    ('Punjabi', 'pa'),
    ('Urdu', 'ur'),
    ('Spanish', 'es'),
    ('French', 'fr'),
    // Not in ML Kit's 58-language catalogue — shown but disabled
    ('Odia', 'or'),
    ('Assamese', 'as'),
    ('Maithili', 'mai'),
    ('Sanskrit', 'sa'),
    ('Sindhi', 'sd'),
    ('Nepali', 'ne'),
    ('Konkani', 'kok'),
    ('Manipuri', 'mni'),
    ('Bodo', 'brx'),
    ('Dogri', 'doi'),
    ('Kashmiri', 'ks'),
    ('Santali', 'sat'),
  ];

  Future<void> _translate() async {
    if (!mounted) return;
    final downloaded = _downloadedLanguages;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select target language'),
        children: [
          for (final (name, code) in _languages)
            _LanguageOption(
              name: name,
              code: code,
              isSupported: TranslateEngine.supportedLanguageCodes.contains(
                code,
              ),
              isDownloaded: downloaded.contains(code),
              onTap: TranslateEngine.supportedLanguageCodes.contains(code)
                  ? () => Navigator.of(ctx).pop(code)
                  : null,
            ),
        ],
      ),
    );
    if (picked == null) return;
    _run(() async {
      final source = _output.isNotEmpty ? _output : await _documentText();
      return ref.read(translateEngineProvider).translate(
            text: source.length > 4000 ? source.substring(0, 4000) : source,
            sourceLanguage: 'en',
            targetLanguage: picked,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supported = TranslateEngine.supportedLanguageCodes;
    final allReady = _modelsChecked &&
        supported.every((c) => _downloadedLanguages.contains(c));
    final downloadedCount = _modelsChecked
        ? supported.where(_downloadedLanguages.contains).length
        : 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiAssistant)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Translation model status banner
          if (_modelsChecked && !allReady)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.download_outlined),
                title: const Text('Downloading translation models…'),
                subtitle: Text(
                  '$downloadedCount / ${supported.length} languages ready for offline use',
                ),
                trailing: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_modelsChecked && allReady)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.offline_pin,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                title: Text(
                  'All ${supported.length} translation models ready — fully offline',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          if (_modelsChecked) const SizedBox(height: 8),
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
    required this.isSupported,
    required this.isDownloaded,
    required this.onTap,
  });

  final String name;
  final String code;
  final bool isSupported;
  final bool isDownloaded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget trailing;
    if (!isSupported) {
      trailing = Text(
        'not available',
        style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
      );
    } else if (isDownloaded) {
      trailing = Icon(Icons.offline_pin, size: 16, color: colorScheme.primary);
    } else {
      trailing = Icon(
        Icons.cloud_download_outlined,
        size: 16,
        color: colorScheme.secondary,
      );
    }

    return ListTile(
      dense: true,
      enabled: isSupported,
      title: Text(
        name,
        style: textTheme.bodyMedium?.copyWith(
          color: isSupported ? null : colorScheme.outline,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
