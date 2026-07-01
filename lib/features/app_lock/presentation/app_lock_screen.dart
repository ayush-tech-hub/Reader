// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_lock_service.dart';
import 'pin_number_pad.dart';

/// Full-screen overlay displayed when the app is locked.
/// The user must enter their PIN (or authenticate biometrically) to dismiss it.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _service = AppLockService();
  final _pin = StringBuffer();
  bool _wrongPin = false;
  bool _checkingBiometric = false;
  bool _canUseBiometric = false;

  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final biometricEnabled = await _service.isBiometricEnabled();
    if (!biometricEnabled) return;
    final canUse = await _service.canUseBiometric();
    if (mounted) setState(() => _canUseBiometric = canUse);
    if (canUse) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    setState(() => _checkingBiometric = true);
    final ok = await _service.authenticateWithBiometric();
    if (!mounted) return;
    setState(() => _checkingBiometric = false);
    if (ok) widget.onUnlocked();
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin.write(d);
      _wrongPin = false;
    });
    if (_pin.length == _pinLength) _verify();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    final s = _pin.toString();
    setState(() {
      _pin.clear();
      _pin.write(s.substring(0, s.length - 1));
      _wrongPin = false;
    });
  }

  Future<void> _verify() async {
    final ok = await _service.verifyPin(_pin.toString());
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _pin.clear();
        _wrongPin = true;
      });
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pinStr = _pin.toString();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(Icons.lock_outline, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'OpenDocs is locked',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your PIN to continue',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 40),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < pinStr.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (_wrongPin ? scheme.error : scheme.primary)
                        : scheme.outlineVariant,
                    border: Border.all(
                      color: _wrongPin
                          ? scheme.error
                          : (filled ? scheme.primary : scheme.outline),
                    ),
                  ),
                );
              }),
            ),

            if (_wrongPin) ...[
              const SizedBox(height: 12),
              Text(
                'Incorrect PIN',
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),

            // Biometric button
            if (_canUseBiometric)
              TextButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use biometric'),
                onPressed: _checkingBiometric ? null : _tryBiometric,
              ),

            const Spacer(),

            // Number pad
            PinNumberPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

