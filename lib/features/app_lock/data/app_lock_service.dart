import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyEnabled = 'app_lock_enabled';
const _keyPinHash = 'app_lock_pin_hash';
const _keyBiometric = 'app_lock_biometric';

const _biometricChannel = MethodChannel('opendocs/biometric');

/// Manages PIN-based (and optional biometric) app lock.
///
/// The PIN is never stored in plain text — only its SHA-256 hash is kept in
/// SharedPreferences.  Biometric authentication delegates to the Android
/// BiometricPrompt API via a MethodChannel.
class AppLockService {
  // ── PIN helpers ─────────────────────────────────────────────────────────────

  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  // ── Queries ──────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometric) ?? false;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPinHash);
  }

  // ── Setup ────────────────────────────────────────────────────────────────────

  /// Enables the lock.  [pin] must be at least 4 digits.
  Future<void> enable(String pin) async {
    assert(pin.length >= 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, _hash(pin));
    await prefs.setBool(_keyEnabled, true);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.remove(_keyBiometric);
    await prefs.setBool(_keyEnabled, false);
  }

  Future<void> changePin(String newPin) async {
    assert(newPin.length >= 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, _hash(newPin));
  }

  Future<void> setBiometric(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometric, enabled);
  }

  // ── Verification ────────────────────────────────────────────────────────────

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  /// Triggers the Android biometric prompt.
  /// Returns `true` on success, `false` on failure or if not available.
  Future<bool> authenticateWithBiometric() async {
    try {
      final result = await _biometricChannel.invokeMethod<bool>(
        'authenticate',
        {'title': 'Unlock OpenDocs', 'subtitle': 'Use biometric to unlock'},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether the device can offer biometric authentication.
  Future<bool> canUseBiometric() async {
    try {
      final result = await _biometricChannel.invokeMethod<bool>('canAuthenticate');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
