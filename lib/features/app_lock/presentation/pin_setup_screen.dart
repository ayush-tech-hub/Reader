// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_lock_service.dart';
import 'pin_number_pad.dart';

enum _PinStep { enter, confirm }

/// Screen for setting or changing the app lock PIN.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _service = AppLockService();
  final _pin = StringBuffer();
  String? _firstPin;
  _PinStep _step = _PinStep.enter;
  bool _mismatch = false;

  static const _pinLength = 4;

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin.write(d);
      _mismatch = false;
    });
    if (_pin.length == _pinLength) _advance();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    final s = _pin.toString();
    setState(() {
      _pin.clear();
      _pin.write(s.substring(0, s.length - 1));
      _mismatch = false;
    });
  }

  Future<void> _advance() async {
    if (_step == _PinStep.enter) {
      setState(() {
        _firstPin = _pin.toString();
        _pin.clear();
        _step = _PinStep.confirm;
      });
    } else {
      if (_pin.toString() == _firstPin) {
        await _service.enable(_pin.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App lock enabled')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _pin.clear();
          _firstPin = null;
          _step = _PinStep.enter;
          _mismatch = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pinStr = _pin.toString();

    final heading = _step == _PinStep.enter ? 'Set a PIN' : 'Confirm PIN';
    final sub = _step == _PinStep.enter
        ? 'Choose a 4-digit PIN to lock the app'
        : 'Re-enter the same PIN to confirm';

    return Scaffold(
      appBar: AppBar(title: const Text('App lock PIN')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.lock_outline, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(heading,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(sub,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.outline)),
            const SizedBox(height: 40),
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
                        ? (_mismatch ? scheme.error : scheme.primary)
                        : scheme.outlineVariant,
                    border: Border.all(
                      color: _mismatch
                          ? scheme.error
                          : (filled ? scheme.primary : scheme.outline),
                    ),
                  ),
                );
              }),
            ),
            if (_mismatch) ...[
              const SizedBox(height: 12),
              Text('PINs did not match — try again',
                  style: TextStyle(color: scheme.error, fontSize: 13)),
            ],
            const Spacer(),
            PinNumberPad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
