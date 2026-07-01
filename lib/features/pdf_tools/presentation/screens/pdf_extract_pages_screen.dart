import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Extract a page range from a PDF into a new document.
class PdfExtractPagesScreen extends StatefulWidget {
  const PdfExtractPagesScreen({super.key});

  @override
  State<PdfExtractPagesScreen> createState() => _PdfExtractPagesScreenState();
}

class _PdfExtractPagesScreenState extends State<PdfExtractPagesScreen> {
  String? _filePath;
  int _pageCount = 0;
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();
  bool _processing = false;
  String? _outputPath;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    final path = result.files.single.path!;
    final doc = await PdfDocument.openFile(path);
    final count = doc.pages.length;
    await doc.dispose();
    setState(() {
      _filePath = path;
      _pageCount = count;
      _toCtrl.text = '$count';
      _outputPath = null;
    });
  }

  Future<void> _extract() async {
    if (_filePath == null) return;
    final from = int.tryParse(_fromCtrl.text) ?? 1;
    final to = int.tryParse(_toCtrl.text) ?? _pageCount;

    if (from < 1 || to > _pageCount || from > to) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid range. Must be 1–$_pageCount.')),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      final src = await PdfDocument.openFile(_filePath!);
      final out = pw.Document();

      for (var i = from; i <= to; i++) {
        final page = src.pages[i];
        final img = await page.render(
          fullWidth: page.width * 2,
          fullHeight: page.height * 2,
        );
        final data = await img?.createImageIfNotAvailable();
        if (data == null) continue;
        final byteData = await data.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        out.addPage(pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          build: (_) => pw.Image(
            pw.MemoryImage(byteData.buffer.asUint8List()),
            fit: pw.BoxFit.fill,
          ),
        ));
        img?.dispose();
      }
      await src.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final baseName =
          _filePath!.split('/').last.replaceAll('.pdf', '');
      final outFile =
          File('${dir.path}/${baseName}_pages_${from}_to_$to.pdf');
      await outFile.writeAsBytes(await out.save());

      setState(() {
        _outputPath = outFile.path;
        _processing = false;
      });
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extract PDF Pages')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(_filePath == null
                  ? 'Pick PDF'
                  : _filePath!.split('/').last),
            ),
            if (_pageCount > 0) ...[
              const SizedBox(height: 20),
              Text(
                'PDF has $_pageCount pages. Select range to extract:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'From page',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _outputPath = null),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _toCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'To page',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() => _outputPath = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_outputPath == null)
                FilledButton.icon(
                  onPressed: _processing ? null : _extract,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.content_cut),
                  label: Text(_processing ? 'Extracting…' : 'Extract Pages'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                )
              else
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () => SharePlus.instance.shareXFiles(
                        [XFile(_outputPath!)],
                        subject: 'Extracted PDF pages',
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Share Extracted PDF'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _outputPath = null),
                      child: const Text('Extract Different Range'),
                    ),
                    Text(
                      'Saved: ${_outputPath!.split('/').last}',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
