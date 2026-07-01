import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/platform/native_channels.dart';

/// Insert blank pages into an existing PDF at user-specified positions.
class PdfAddPagesScreen extends StatefulWidget {
  const PdfAddPagesScreen({super.key});

  @override
  State<PdfAddPagesScreen> createState() => _PdfAddPagesScreenState();
}

class _PdfAddPagesScreenState extends State<PdfAddPagesScreen> {
  static const _channel = MethodChannel(NativeChannels.pdfTools);

  String? _pdfPath;
  int _totalPages = 0;
  bool _loading = false;
  bool _busy = false;
  String? _savedPath;
  String? _error;

  // Each insertion: (afterPage: 1-based, count)
  // afterPage == 0 means "before page 1"
  final List<({int afterPage, int count})> _insertions = [];

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _loading = true;
      _pdfPath = path;
      _insertions.clear();
      _savedPath = null;
      _error = null;
    });

    try {
      final doc = await PdfDocument.openFile(path);
      setState(() => _totalPages = doc.pages.length);
      doc.dispose();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addInsertion() {
    setState(() => _insertions.add((afterPage: _totalPages, count: 1)));
  }

  Future<void> _apply() async {
    final src = _pdfPath;
    if (src == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _savedPath = null;
    });
    try {
      Directory base;
      try {
        base = (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        base = await getApplicationDocumentsDirectory();
      }
      final stem = p.basenameWithoutExtension(src);
      final out = p.join(base.path, '${stem}_with_blanks.pdf');

      await _channel.invokeMethod<String>(
        PdfToolsMethods.addBlankPages,
        {
          'source': src,
          'outputPath': out,
          'insertions': [
            for (final ins in _insertions)
              {'afterPage': ins.afterPage, 'count': ins.count},
          ],
        },
      );
      if (mounted) setState(() => _savedPath = out);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add blank pages'),
        actions: [
          if (_pdfPath != null && _insertions.isNotEmpty)
            IconButton(
              tooltip: 'Apply',
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _busy ? null : _apply,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(
                _pdfPath == null
                    ? 'Pick a PDF file'
                    : p.basename(_pdfPath!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _totalPages > 0
                  ? Text('$_totalPages pages')
                  : null,
              trailing: const Icon(Icons.folder_open),
              onTap: _loading ? null : _pickPdf,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_pdfPath != null && !_loading) ...[
            const SizedBox(height: 12),
            if (_insertions.isEmpty)
              Text(
                'No insertions yet. Tap + to add a blank page.',
                style: TextStyle(color: scheme.outline),
              ),
            for (var i = 0; i < _insertions.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Insertion ${i + 1}',
                                style:
                                    Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('After page '),
                                SizedBox(
                                  width: 60,
                                  child: TextFormField(
                                    initialValue:
                                        _insertions[i].afterPage.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                    onChanged: (v) {
                                      final page = int.tryParse(v) ??
                                          _insertions[i].afterPage;
                                      setState(() {
                                        _insertions[i] = (
                                          afterPage: page.clamp(
                                              0, _totalPages),
                                          count: _insertions[i].count,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('× '),
                                SizedBox(
                                  width: 44,
                                  child: TextFormField(
                                    initialValue:
                                        _insertions[i].count.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                    onChanged: (v) {
                                      final count =
                                          (int.tryParse(v) ?? 1).clamp(1, 50);
                                      setState(() {
                                        _insertions[i] = (
                                          afterPage: _insertions[i].afterPage,
                                          count: count,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const Text(' blank page(s)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.delete_outline, color: scheme.error),
                        onPressed: () =>
                            setState(() => _insertions.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add insertion point'),
              onPressed: _addInsertion,
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          if (_savedPath != null)
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Saved: $_savedPath',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
