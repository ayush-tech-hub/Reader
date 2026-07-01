import 'package:flutter/material.dart';

/// The script (writing system) entries the OCR engine can handle.
const List<({String? value, String label, String hint})> kOcrScripts = [
  (value: null, label: 'Latin (auto)', hint: 'English, French, Spanish, German, …'),
  (value: 'chinese', label: 'Chinese', hint: 'Simplified & Traditional'),
  (value: 'devanagari', label: 'Devanagari', hint: 'Hindi, Nepali, Sanskrit, …'),
  (value: 'japanese', label: 'Japanese', hint: 'Hiragana, Katakana & Kanji'),
  (value: 'korean', label: 'Korean', hint: 'Hangul'),
];

/// A dropdown row for picking the OCR writing system.
///
/// Wrap in a [Row] or [Column] as needed — the widget itself is compact.
class OcrScriptSelector extends StatelessWidget {
  const OcrScriptSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(Icons.language, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text('Language:', style: textTheme.bodyMedium),
        const SizedBox(width: 8),
        DropdownButton<String?>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: kOcrScripts
              .map(
                (s) => DropdownMenuItem<String?>(
                  value: s.value,
                  child: Tooltip(
                    message: s.hint,
                    child: Text(s.label),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
