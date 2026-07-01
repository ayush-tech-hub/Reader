// ignore_for_file: unawaited_futures

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../ai/data/text_analysis.dart' as ai;

/// Scans an invoice or receipt PDF and extracts structured fields:
/// vendor, invoice number, date, totals, line items.
class InvoiceScanScreen extends ConsumerStatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  ConsumerState<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends ConsumerState<InvoiceScanScreen> {
  String? _pdfPath;
  ai.InvoiceData? _data;
  bool _busy = false;
  String? _error;

  Future<void> _pickAndScan() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _pdfPath = path;
      _busy = true;
      _data = null;
      _error = null;
    });

    try {
      final index = ref.read(documentIndexServiceProvider);
      var text = await index.documentText(path);
      if (text.trim().isEmpty) {
        // Try OCR if not already indexed.
        final pages = await ref.read(ocrEngineProvider).recognizePdf(path);
        text = pages.join('\n');
        if (text.trim().isNotEmpty) {
          await index.indexExternalText(path: path, pageTexts: pages);
        }
      }
      if (text.trim().isEmpty) {
        setState(() => _error = 'Could not extract text from this PDF.');
        return;
      }
      final data = ai.parseInvoice(text);
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice scanner'),
        actions: [
          if (data != null && !data.isEmpty)
            IconButton(
              tooltip: 'Copy as text',
              icon: const Icon(Icons.copy),
              onPressed: () {
                final buf = StringBuffer();
                if (data.vendor != null) buf.writeln('Vendor: ${data.vendor}');
                if (data.invoiceNumber != null) buf.writeln('Invoice #: ${data.invoiceNumber}');
                if (data.date != null) buf.writeln('Date: ${data.date}');
                if (data.dueDate != null) buf.writeln('Due: ${data.dueDate}');
                if (data.subtotal != null) buf.writeln('Subtotal: ${data.subtotal}');
                if (data.tax != null) buf.writeln('Tax: ${data.tax}');
                if (data.total != null) buf.writeln('Total: ${data.total}');
                Clipboard.setData(ClipboardData(text: buf.toString().trim()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
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
                _pdfPath == null ? 'Pick an invoice PDF' : p.basename(_pdfPath!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.folder_open),
              onTap: _busy ? null : _pickAndScan,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.document_scanner),
            label: const Text('Scan invoice'),
            onPressed: _busy ? null : _pickAndScan,
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          if (data != null) ...[
            if (data.isEmpty)
              Card(
                color: scheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No structured fields detected.\n'
                    'Try running OCR first if the PDF contains scanned images.',
                  ),
                ),
              )
            else ...[
              _FieldCard(
                title: 'Invoice details',
                fields: {
                  if (data.vendor != null) 'Vendor': data.vendor!,
                  if (data.invoiceNumber != null) 'Invoice #': data.invoiceNumber!,
                  if (data.date != null) 'Date': data.date!,
                  if (data.dueDate != null) 'Due date': data.dueDate!,
                },
              ),
              const SizedBox(height: 12),
              _FieldCard(
                title: 'Amounts',
                fields: {
                  if (data.subtotal != null) 'Subtotal': data.subtotal!,
                  if (data.tax != null) 'Tax / VAT': data.tax!,
                  if (data.total != null) 'Total': data.total!,
                },
              ),
              if (data.lineItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text(
                          'Line items',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final item in data.lineItems)
                        ListTile(
                          dense: true,
                          title: Text(item,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.title, required this.fields});
  final String title;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final entry in fields.entries)
            ListTile(
              dense: true,
              title: Text(entry.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      )),
              subtitle: SelectableText(entry.value),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
