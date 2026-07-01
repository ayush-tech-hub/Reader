import 'package:flutter/material.dart';

import '../data/app_lock_service.dart';
import 'pin_setup_screen.dart';

/// Screen for enabling, disabling, changing the app lock PIN,
/// and toggling biometric authentication.
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _service = AppLockService();

  bool _loading = true;
  bool _enabled = false;
  bool _biometricEnabled = false;
  bool _canBiometric = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled();
    final biometric = await _service.isBiometricEnabled();
    final canBio = await _service.canUseBiometric();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _biometricEnabled = biometric;
        _canBiometric = canBio;
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      // Navigate to PIN setup; enable only if setup succeeds.
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PinSetupScreen(),
        ),
      );
      if (ok == true && mounted) {
        setState(() => _enabled = true);
      }
    } else {
      final confirmed = await _confirmDisable();
      if (confirmed && mounted) {
        await _service.disable();
        setState(() {
          _enabled = false;
          _biometricEnabled = false;
        });
      }
    }
  }

  Future<bool> _confirmDisable() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable app lock?'),
        content: const Text(
          'Your PIN will be removed and the app will no longer '
          'require authentication on startup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _changePin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PinSetupScreen(),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated')),
      );
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    await _service.setBiometric(value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('Enable app lock'),
                  subtitle: const Text(
                    'Require PIN to open the app or after 30 seconds in background',
                  ),
                  value: _enabled,
                  onChanged: _toggleEnabled,
                ),
                if (_enabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Change PIN'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePin,
                  ),
                  if (_canBiometric) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Use biometric'),
                      subtitle: const Text(
                        'Allow fingerprint / face unlock in addition to PIN',
                      ),
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
                  ],
                ],
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'The PIN is stored as a secure hash on this device and '
                    'is never transmitted anywhere.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}
