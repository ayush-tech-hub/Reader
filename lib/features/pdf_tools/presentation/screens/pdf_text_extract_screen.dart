import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

/// Extracts the full text content from a PDF and lets the user
/// search within it, copy it, or share it as a .txt file.
class PdfTextExtractScreen extends StatefulWidget {
  const PdfTextExtractScreen({super.key});

  @override
  State<PdfTextExtractScreen> createState() => _PdfTextExtractScreenState();
}

class _PdfTextExtractScreenState extends State<PdfTextExtractScreen> {
  String? _pdfPath;
  String _fullText = '';
  bool _loading = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndExtract() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _loading = true;
      _pdfPath = path;
      _fullText = '';
    });

    try {
      final doc = await PdfDocument.openFile(path);
      final buf = StringBuffer();
      for (int i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final text = await page.loadText();
        final content = text.fullText.trim();
        if (content.isNotEmpty) {
          buf.writeln('── Page ${i + 1} ──');
          buf.writeln(content);
          buf.writeln();
        }
      }
      doc.dispose();
      setState(() => _fullText = buf.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final src = _pdfPath;
    if (_fullText.isEmpty || src == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = '${p.basenameWithoutExtension(src)}_text.txt';
      final file = File(p.join(dir.path, name));
      await file.writeAsString(_fullText);
      await Share.shareXFiles([XFile(file.path)], subject: 'Extracted text');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String get _filtered {
    if (_query.trim().isEmpty) return _fullText;
    final lines = _fullText.split('\n');
    final q = _query.toLowerCase();
    final filtered = lines.where((l) => l.toLowerCase().contains(q)).toList();
    return filtered.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _fullText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract text'),
        actions: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _fullText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          if (hasText)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share as .txt',
              onPressed: _share,
            ),
        ],
      ),
      body: Column(
        children: [
          // File picker
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(
                _pdfPath == null
                    ? 'Pick a PDF file'
                    : p.basename(_pdfPath!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.folder_open),
              onTap: _loading ? null : _pickAndExtract,
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Extracting text…'),
                ],
              ),
            ),

          // Search bar (visible when text is ready)
          if (hasText)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search in text…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),

          // Text content
          Expanded(
            child: hasText
                ? _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matches for "$_query"',
                          style: TextStyle(color: scheme.outline),
                        ),
                      )
                    : _HighlightedTextView(
                        text: _filtered,
                        highlight: _query,
                      )
                : _pdfPath == null
                    ? Center(
                        child: Text(
                          'Pick a PDF to extract its text.',
                          style: TextStyle(color: scheme.outline),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HighlightedTextView extends StatelessWidget {
  const _HighlightedTextView({required this.text, required this.highlight});

  final String text;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (highlight.trim().isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6),
        ),
      );
    }

    // Build spans with highlighted matches.
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = highlight.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: TextStyle(
          backgroundColor: scheme.primaryContainer,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + q.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SelectableText.rich(
        TextSpan(
          children: spans,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
