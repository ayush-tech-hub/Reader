import 'package:flutter/material.dart';

/// Cloud-storage hub screen.
///
/// Shows available cloud providers as connection cards. OAuth integration
/// for each provider is scaffolded here and will be activated when the
/// corresponding SDK dependency is added in a future release.
class CloudStorageScreen extends StatelessWidget {
  const CloudStorageScreen({super.key});

  static const _providers = [
    _Provider(
      name: 'Google Drive',
      tagline: '15 GB free · Google account',
      icon: Icons.add_to_drive_outlined,
      color: Color(0xFF4285F4),
    ),
    _Provider(
      name: 'Dropbox',
      tagline: '2 GB free · Personal or team',
      icon: Icons.cloud_download_outlined,
      color: Color(0xFF0061FF),
    ),
    _Provider(
      name: 'OneDrive',
      tagline: '5 GB free · Microsoft account',
      icon: Icons.cloud_queue_outlined,
      color: Color(0xFF0078D4),
    ),
    _Provider(
      name: 'WebDAV Server',
      tagline: 'Any self-hosted WebDAV endpoint',
      icon: Icons.cloud_circle_outlined,
      color: Color(0xFF455A64),
    ),
    _Provider(
      name: 'SFTP / SSH',
      tagline: 'Remote Linux servers',
      icon: Icons.terminal,
      color: Color(0xFF37474F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Storage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Connect a cloud or network storage provider to browse, '
            'open, and share files without leaving the app.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          for (final provider in _providers) ...[
            _ProviderCard(provider: provider),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          _InfoBanner(),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});
  final _Provider provider;

  @override
  Widget build(BuildContext context) {
    final color = provider.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(provider.icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(provider.tagline,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showDialog(context),
                child: const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(provider.icon, color: provider.color, size: 32),
        title: Text('Connect ${provider.name}'),
        content: const Text(
          'Cloud storage integration requires OAuth / credential setup.\n\n'
          'This feature is coming in a future update. Once enabled, '
          'you will be able to browse and open files directly from '
          'this provider without downloading them first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Files are opened directly — no cloud copies are stored '
              'on your device beyond what you explicitly save.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Provider {
  const _Provider({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
  });
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
}
