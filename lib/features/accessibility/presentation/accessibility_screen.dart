import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highContrast = ref.watch(highContrastProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Display ──────────────────────────────────────────────────────
          _SectionHeader('Display'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.contrast),
                  title: const Text('High-contrast mode'),
                  subtitle: const Text(
                    'Increases colour contrast for better readability',
                  ),
                  value: highContrast,
                  onChanged: (_) =>
                      ref.read(highContrastProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Text size ─────────────────────────────────────────────────
          _SectionHeader('Text size'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview text at ${(fontScale * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The quick brown fox jumps over the lazy dog.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontSize: 16 * fontScale),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: (kFontScales.length - 1).toDouble(),
                          divisions: kFontScales.length - 1,
                          value: kFontScales.indexOf(fontScale).toDouble().clamp(
                                0,
                                (kFontScales.length - 1).toDouble(),
                              ),
                          label: '${(fontScale * 100).round()}%',
                          onChanged: (v) {
                            final idx = v.round().clamp(
                              0,
                              kFontScales.length - 1,
                            );
                            ref
                                .read(fontScaleProvider.notifier)
                                .setScale(kFontScales[idx]);
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final scale in kFontScales)
                        ChoiceChip(
                          label: Text('${(scale * 100).round()}%'),
                          selected: fontScale == scale,
                          onSelected: (_) => ref
                              .read(fontScaleProvider.notifier)
                              .setScale(scale),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Tip ───────────────────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              title: Text(
                'System accessibility settings',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              subtitle: Text(
                'For TalkBack, switch access, and other assistive technologies, '
                'use Android system Settings → Accessibility.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer
                      .withOpacity(0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
