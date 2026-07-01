import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Scans pasted or typed text for academic citations and classifies
/// each one by style (APA, MLA, IEEE, Chicago, Harvard, DOI, URL).
///
/// Detection is heuristic — pattern matching over individual lines and
/// DOI/URL spans. It works well for reference-list sections of research
/// papers and is designed for quick extraction, not perfect parsing.
class CitationExtractorScreen extends StatefulWidget {
  const CitationExtractorScreen({super.key, required this.initialText});

  final String? initialText;

  @override
  State<CitationExtractorScreen> createState() =>
      _CitationExtractorScreenState();
}

class _CitationExtractorScreenState extends State<CitationExtractorScreen> {
  late final TextEditingController _ctrl;
  List<_Citation> _citations = [];
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
    if (_ctrl.text.isNotEmpty) _run();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run() {
    setState(() {
      _citations = _CitationExtractor.extract(_ctrl.text);
      _ran = true;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _ctrl.text = data!.text!;
      _run();
    }
  }

  void _copyAll() {
    final all = _citations.map((c) => '[${c.style}] ${c.text}').join('\n\n');
    Clipboard.setData(ClipboardData(text: all));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All citations copied')));
  }

  void _shareAll() {
    final all = _citations.map((c) => '[${c.style}] ${c.text}').join('\n\n');
    Share.share(all, subject: 'Extracted citations');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citation Extractor'),
        actions: [
          if (_citations.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy all',
              onPressed: _copyAll,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: _shareAll,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Input area ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _ctrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'Paste text containing references / bibliography…',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: 'Paste from clipboard',
                      onPressed: _paste,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear',
                      onPressed: () {
                        _ctrl.clear();
                        setState(() {
                          _citations = [];
                          _ran = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.find_in_page),
              label: const Text('Extract Citations'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
          const Divider(height: 24),

          // ── Results ────────────────────────────────────────────────────
          Expanded(
            child: _ran
                ? (_citations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('No citations detected',
                                style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 4),
                            const Text(
                              'Try pasting a reference list or bibliography.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${_citations.length} citation'
                                  '${_citations.length == 1 ? '' : 's'} found',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _citations.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 12),
                              itemBuilder: (context, i) {
                                final c = _citations[i];
                                return _CitationTile(citation: c);
                              },
                            ),
                          ),
                        ],
                      ))
                : const Center(
                    child: Text('Enter text above to detect citations',
                        style: TextStyle(color: Colors.grey)),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Citation tile ─────────────────────────────────────────────────────────────

class _CitationTile extends StatelessWidget {
  const _CitationTile({required this.citation});
  final _Citation citation;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StyleChip(style: citation.style),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: citation.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Citation copied')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(citation.text),
          ],
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.style});
  final String style;

  static Color _color(String style) => switch (style) {
        'APA' => const Color(0xFF1565C0),
        'MLA' => const Color(0xFF2E7D32),
        'IEEE' => const Color(0xFF6A1B9A),
        'Chicago' => const Color(0xFFB71C1C),
        'Harvard' => const Color(0xFFE65100),
        'DOI' => const Color(0xFF00695C),
        'URL' => const Color(0xFF4527A0),
        _ => Colors.grey.shade700,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(style);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        style,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Extractor logic ───────────────────────────────────────────────────────────

class _Citation {
  const _Citation({required this.style, required this.text});
  final String style;
  final String text;
}

abstract final class _CitationExtractor {
  static final _doi = RegExp(
    r'(?:https?://doi\.org/|doi:\s*)10\.\d{4,}/\S+',
    caseSensitive: false,
  );
  static final _url = RegExp(
    r'https?://[^\s\)>]+',
    caseSensitive: false,
  );
  // IEEE: [N] ...
  static final _ieee = RegExp(r'^\[\d+\]\s+\S');
  // APA: Lastname, A. B. (Year). ...  OR  Lastname, A. B., & Other, C. (Year).
  static final _apa =
      RegExp(r'^[A-ZÀ-Ö][a-zà-ö]+,\s+[A-Z]\.\s*.*\(\d{3,4}\)');
  // MLA: Lastname, Firstname. "Title" or Lastname, Firstname. Title.
  static final _mla =
      RegExp(r'^[A-ZÀ-Ö][a-zà-ö]+,\s+[A-ZÀ-Öa-zà-ö]+\.\s+"[^"]+"\.');
  // Chicago author-date: Lastname, Firstname. Year. "Title." ...
  static final _chicago =
      RegExp(r'^[A-ZÀ-Ö][a-zà-ö]+,\s+[A-ZÀ-Öa-zà-ö]+\.\s+\d{4}\.');
  // Harvard: Lastname, I. (Year) 'Title' ...  or similar
  static final _harvard =
      RegExp(r"^[A-ZÀ-Ö][a-zà-ö]+,\s+[A-Z]\.\s*\(\d{3,4}\)");
  // Generic academic: has (Year) and multiple commas (author, title, journal, …)
  static final _generic =
      RegExp(r'\(\d{3,4}\).*,|,.*\(\d{3,4}\)');

  static List<_Citation> extract(String text) {
    final seen = <String>{};
    final results = <_Citation>[];

    void add(String style, String raw) {
      final t = raw.trim();
      if (t.length < 8 || !seen.add(t)) return;
      results.add(_Citation(style: style, text: t));
    }

    // ── Inline DOI and URL spans ──────────────────────────────────────────
    for (final m in _doi.allMatches(text)) {
      add('DOI', m.group(0)!);
    }

    // ── Line-by-line reference detection ─────────────────────────────────
    // Merge continuation lines (a reference often spans multiple lines;
    // we join until we hit a blank line or a new reference starter).
    final paragraphs = _splitParagraphs(text);
    for (final para in paragraphs) {
      final line = para.trim();
      if (line.length < 12) continue;

      if (_ieee.hasMatch(line)) {
        add('IEEE', line);
      } else if (_apa.hasMatch(line)) {
        add('APA', line);
      } else if (_mla.hasMatch(line)) {
        add('MLA', line);
      } else if (_chicago.hasMatch(line)) {
        add('Chicago', line);
      } else if (_harvard.hasMatch(line)) {
        add('Harvard', line);
      } else if (_generic.hasMatch(line) && line.split(',').length >= 3) {
        add('Academic', line);
      } else {
        // URL-only lines
        final urlMatch = _url.firstMatch(line);
        if (urlMatch != null && line.length > 20) {
          add('URL', line);
        }
      }
    }

    return results;
  }

  /// Splits text into reference-sized chunks. Lines separated only by a
  /// newline are joined (continuation); blank lines create a break.
  static List<String> _splitParagraphs(String text) {
    final paras = <String>[];
    final buf = StringBuffer();

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (buf.isNotEmpty) {
          paras.add(buf.toString());
          buf.clear();
        }
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(line);
      }
    }
    if (buf.isNotEmpty) paras.add(buf.toString());

    return paras;
  }
}
