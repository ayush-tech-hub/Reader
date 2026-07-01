import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

/// A curated set of seed colors for Material 3 dynamic theming.
const _kPalette = [
  (label: 'Default', color: Color(0xFF3F51B5)),
  (label: 'Teal', color: Color(0xFF009688)),
  (label: 'Indigo', color: Color(0xFF3949AB)),
  (label: 'Purple', color: Color(0xFF7B1FA2)),
  (label: 'Pink', color: Color(0xFFE91E63)),
  (label: 'Red', color: Color(0xFFF44336)),
  (label: 'Orange', color: Color(0xFFFF5722)),
  (label: 'Amber', color: Color(0xFFFFC107)),
  (label: 'Green', color: Color(0xFF4CAF50)),
  (label: 'Cyan', color: Color(0xFF00BCD4)),
  (label: 'Blue', color: Color(0xFF2196F3)),
  (label: 'Brown', color: Color(0xFF795548)),
  (label: 'Slate', color: Color(0xFF607D8B)),
  (label: 'Rose', color: Color(0xFFE57373)),
  (label: 'Lime', color: Color(0xFFCDDC39)),
  (label: 'Deep Purple', color: Color(0xFF673AB7)),
];

class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeColorProvider);
    final notifier = ref.read(themeColorProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('App theme color')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose a seed color for the Material You theme. '
            'The app will generate a full palette from your choice.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),

          // Preview card
          _PreviewCard(seedColor: current ?? const Color(0xFF3F51B5)),
          const SizedBox(height: 20),

          Text('Colors', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _kPalette.length,
            itemBuilder: (context, i) {
              final entry = _kPalette[i];
              final isSelected = current == null
                  ? entry.color == const Color(0xFF3F51B5)
                  : current.value == entry.color.value;

              return GestureDetector(
                onTap: () => notifier.setColor(
                  entry.color.value == const Color(0xFF3F51B5).value
                      ? null
                      : entry.color,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: entry.color.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _kPalette
                .map((e) => Tooltip(
                      message: e.label,
                      child: const SizedBox.shrink(),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset to default'),
            onPressed:
                current == null ? null : () => notifier.setColor(null),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.seedColor});
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.book, color: scheme.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 100,
                        decoration: BoxDecoration(
                          color: scheme.onPrimaryContainer.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 8,
                        width: 140,
                        decoration: BoxDecoration(
                          color: scheme.onPrimaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
