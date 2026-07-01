import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CaseConverterScreen extends StatefulWidget {
  const CaseConverterScreen({super.key});

  @override
  State<CaseConverterScreen> createState() => _CaseConverterScreenState();
}

class _CaseConverterScreenState extends State<CaseConverterScreen> {
  final _inputCtrl = TextEditingController();
  String _result = '';
  String _activeMode = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  String _toTitleCase(String s) {
    return s.replaceAllMapped(
      RegExp(r'\b\w'),
      (m) => m[0]!.toUpperCase(),
    );
  }

  String _toCamelCase(String s) {
    final words = s.trim().split(RegExp(r'[\s_\-]+'));
    if (words.isEmpty) return s;
    final first = words.first.toLowerCase();
    final rest = words.skip(1).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    });
    return first + rest.join();
  }

  String _toPascalCase(String s) {
    final words = s.trim().split(RegExp(r'[\s_\-]+'));
    return words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join();
  }

  String _toSnakeCase(String s) {
    return s
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m[0]!.toLowerCase()}',
        )
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase()
        .replaceAll(RegExp(r'^_'), '');
  }

  String _toKebabCase(String s) => _toSnakeCase(s).replaceAll('_', '-');

  String _toConstantCase(String s) => _toSnakeCase(s).toUpperCase();

  String _toSentenceCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _toAlternatingCase(String s) {
    bool upper = true;
    return s.split('').map((c) {
      if (c.trim().isEmpty) return c;
      final r = upper ? c.toUpperCase() : c.toLowerCase();
      upper = !upper;
      return r;
    }).join();
  }

  void _convert(String mode) {
    final input = _inputCtrl.text;
    if (input.isEmpty) return;
    String result;
    switch (mode) {
      case 'UPPER':
        result = input.toUpperCase();
      case 'lower':
        result = input.toLowerCase();
      case 'Title':
        result = _toTitleCase(input);
      case 'Sentence':
        result = _toSentenceCase(input);
      case 'camelCase':
        result = _toCamelCase(input);
      case 'PascalCase':
        result = _toPascalCase(input);
      case 'snake_case':
        result = _toSnakeCase(input);
      case 'kebab-case':
        result = _toKebabCase(input);
      case 'CONSTANT_CASE':
        result = _toConstantCase(input);
      case 'aLtErNaTiNg':
        result = _toAlternatingCase(input);
      default:
        result = input;
    }
    setState(() {
      _result = result;
      _activeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modes = [
      ('UPPER', 'UPPERCASE'),
      ('lower', 'lowercase'),
      ('Title', 'Title Case'),
      ('Sentence', 'Sentence case'),
      ('camelCase', 'camelCase'),
      ('PascalCase', 'PascalCase'),
      ('snake_case', 'snake_case'),
      ('kebab-case', 'kebab-case'),
      ('CONSTANT_CASE', 'CONSTANT_CASE'),
      ('aLtErNaTiNg', 'aLtErNaTiNg'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Case Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter text to convert…',
                labelText: 'Input',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (mode, label) in modes)
                  ChoiceChip(
                    label: Text(label),
                    selected: _activeMode == mode,
                    onSelected: (_) => _convert(mode),
                  ),
              ],
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Result',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
