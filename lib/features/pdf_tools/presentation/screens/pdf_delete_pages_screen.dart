import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Lets users select specific pages to remove from a PDF and saves the result.
class PdfDeletePagesScreen extends StatefulWidget {
  const PdfDeletePagesScreen({super.key});

  @override
  State<PdfDeletePagesScreen> createState() => _PdfDeletePagesScreenState();
}

class _PdfDeletePagesScreenState extends State<PdfDeletePagesScreen> {
  String? _filePath;
  int _pageCount = 0;
  final Set<int> _toDelete = {}; // 0-indexed
  bool _processing = false;
  String? _outputPath;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return;
    final path = result.files.single.path!;
    final doc = await PdfDocument.openFile(path);
    setState(() {
      _filePath = path;
      _pageCount = doc.pages.length;
      _toDelete.clear();
      _outputPath = null;
    });
    await doc.dispose();
  }

  Future<void> _process() async {
    if (_filePath == null || _toDelete.isEmpty) return;
    if (_toDelete.length >= _pageCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete all pages')),
      );
      return;
    }
    setState(() => _processing = true);

    try {
      final src = await PdfDocument.openFile(_filePath!);
      final out = pw.Document();

      for (var i = 0; i < src.pages.length; i++) {
        if (_toDelete.contains(i)) continue;
        final page = src.pages[i + 1];
        final img = await page.render(
          fullWidth: page.width * 2,
          fullHeight: page.height * 2,
        );
        final data = await img?.createImageIfNotAvailable();
        if (data == null) continue;
        final byteData =
            await data.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final pdfImg = pw.MemoryImage(byteData.buffer.asUint8List());
        out.addPage(pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          build: (_) => pw.Image(pdfImg, fit: pw.BoxFit.fill),
        ));
        img?.dispose();
      }
      await src.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final name =
          '${_filePath!.split('/').last.replaceAll('.pdf', '')}_deleted.pdf';
      final outFile = File('${dir.path}/$name');
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete PDF Pages')),
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
              const SizedBox(height: 12),
              Text(
                'Select pages to delete ($_pageCount pages total)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _pageCount,
                  itemBuilder: (_, i) {
                    final selected = _toDelete.contains(i);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _toDelete.remove(i);
                        } else {
                          _toDelete.add(i);
                        }
                        _outputPath = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.errorContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? scheme.error
                                : scheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected
                                  ? Icons.delete
                                  : Icons.description_outlined,
                              color: selected
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                              size: 20,
                            ),
                            Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_toDelete.isNotEmpty)
                Text(
                  '${_toDelete.length} page${_toDelete.length == 1 ? '' : 's'} selected for deletion',
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              if (_outputPath == null)
                FilledButton.icon(
                  onPressed: _toDelete.isEmpty || _processing ? null : _process,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep),
                  label: Text(_processing ? 'Processing…' : 'Delete Selected Pages'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.error,
                  ),
                )
              else
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () => SharePlus.instance.shareXFiles(
                        [XFile(_outputPath!)],
                        subject: 'PDF with pages deleted',
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Share Result'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                    const SizedBox(height: 8),
                    Text('Saved: ${_outputPath!.split('/').last}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
