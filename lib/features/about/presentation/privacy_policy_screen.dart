import 'package:flutter/material.dart';

import '../../../generated/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Section(
            icon: Icons.devices_outlined,
            title: 'Data Collection',
            body:
                'This app does not collect, store, or transmit any personal data. '
                'All files you open, edit, or analyze remain entirely on your device.',
          ),
          _Section(
            icon: Icons.wifi_off,
            title: 'Offline-First',
            body:
                'All PDF editing, file management, and storage analysis operations '
                'are performed locally on your device with no internet connection required. '
                'No data is uploaded to any server at any time.',
          ),
          _Section(
            icon: Icons.folder_outlined,
            title: 'File Access',
            body:
                'The app requests storage permissions solely to let you browse, manage, '
                'and analyze files on your device. We never access your files for any '
                'purpose other than performing the actions you explicitly request.',
          ),
          _Section(
            icon: Icons.translate_outlined,
            title: 'AI & Translation Features',
            body:
                'On-device AI features (summarization, OCR) run entirely locally. '
                'The optional translation feature uses Google ML Kit and may download '
                'language models (~30 MB each) on first use — no document content is sent.',
          ),
          _Section(
            icon: Icons.analytics_outlined,
            title: 'Analytics & Crash Reporting',
            body:
                'This app does not use any third-party analytics, advertising SDKs, '
                'or crash-reporting services. No usage data or diagnostics are shared '
                'with any third party.',
          ),
          _Section(
            icon: Icons.security_outlined,
            title: 'Third-Party Libraries',
            body:
                'This app is built with open-source libraries (Flutter, iText, etc.). '
                'These libraries are used solely for local processing and do not '
                'independently transmit data.',
          ),
          _Section(
            icon: Icons.child_care_outlined,
            title: "Children's Privacy",
            body:
                'This app does not knowingly collect information from children under 13. '
                'No personal information is collected from any user.',
          ),
          _Section(
            icon: Icons.update_outlined,
            title: 'Policy Updates',
            body:
                'If this policy changes, the updated version will be distributed with '
                'future app updates. Continued use of the app after an update constitutes '
                'acceptance of the revised policy.',
          ),
          const SizedBox(height: 8),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact',
                    style: textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For questions about this privacy policy, complaints, or feature '
                    'requests, please contact us at:\n\nweedywhy@gmail.com',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
