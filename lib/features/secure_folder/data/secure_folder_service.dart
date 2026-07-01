import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyEnabled = 'secure_folder_enabled';
const _keyPinHash = 'secure_folder_pin_hash';

/// Manages an on-device "secure folder": files moved here are stored in a
/// private app directory and are only accessible after PIN verification.
///
/// Encryption is intentional non-goal for v1 — the folder relies on Android
/// app-private storage (MODE_PRIVATE).  A future version could layer AES-GCM
/// on top once we bring in the `pointycastle` or `encrypt` package.
class SecureFolderService {
  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  Future<Directory> _vaultDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, '.vault'));
    await dir.create(recursive: true);
    return dir;
  }

  // ── Setup ──────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  Future<void> enable(String pin) async {
    assert(pin.length >= 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, _hash(pin));
    await prefs.setBool(_keyEnabled, true);
  }

  Future<void> disable(String pin) async {
    if (!await verifyPin(pin)) throw Exception('Incorrect PIN');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyEnabled, false);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  // ── File operations ────────────────────────────────────────────────────────

  Future<List<FileSystemEntity>> listFiles() async {
    final dir = await _vaultDir();
    return dir
        .listSync()
        .where((e) => e is File)
        .toList()
      ..sort((a, b) {
        final aName = p.basename(a.path);
        final bName = p.basename(b.path);
        return aName.compareTo(bName);
      });
  }

  /// Moves [sourcePath] into the vault.  Returns the vault path.
  Future<String> addFile(String sourcePath) async {
    final dir = await _vaultDir();
    final name = p.basename(sourcePath);
    final dest = _uniquePath(dir.path, name);
    await File(sourcePath).rename(dest);
    return dest;
  }

  /// Copies [sourcePath] into the vault (keeps the original).
  Future<String> copyFileIn(String sourcePath) async {
    final dir = await _vaultDir();
    final name = p.basename(sourcePath);
    final dest = _uniquePath(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Moves the file at [vaultPath] back to [destinationDir].
  Future<void> restoreFile(String vaultPath, String destinationDir) async {
    final name = p.basename(vaultPath);
    final dest = _uniquePath(destinationDir, name);
    await File(vaultPath).rename(dest);
  }

  /// Permanently deletes the file at [vaultPath].
  Future<void> deleteFile(String vaultPath) async {
    await File(vaultPath).delete();
  }

  String _uniquePath(String dir, String name) {
    var candidate = p.join(dir, name);
    var i = 1;
    while (File(candidate).existsSync()) {
      final ext = p.extension(name);
      final stem = p.basenameWithoutExtension(name);
      candidate = p.join(dir, '${stem}_$i$ext');
      i++;
    }
    return candidate;
  }
}
