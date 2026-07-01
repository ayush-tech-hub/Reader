import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// Exports all non-sensitive SharedPreferences settings to a JSON file
/// and allows restoring them from a previous backup.
///
/// Excluded keys: PIN hashes and biometric state (security-sensitive).
/// Database content (bookmarks, reading history) is not included in
/// this backup; those can be restored by syncing the SQLite files
/// directly via the Files browser.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _busy = false;
  String? _lastMessage;
  bool _isError = false;

  // Keys excluded from backup for security
  static const _excluded = {
    'app_lock_pin_hash',
    'app_lock_enabled',
    'app_lock_biometric',
    'secure_folder_pin_hash',
    'secure_folder_enabled',
  };

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _lastMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => !_excluded.contains(k)).toList()
        ..sort();

      final data = <String, dynamic>{
        '_version': 1,
        '_backup_date': DateTime.now().toIso8601String(),
        '_app': 'OpenDocs Manager',
      };
      for (final key in keys) {
        final v = prefs.get(key);
        if (v != null) data[key] = v;
      }

      final json = const JsonEncoder.withIndent('  ').convert(data);

      Directory dir;
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final path = '${dir.path}/opendocs_backup_$stamp.json';
      await File(path).writeAsString(json);

      if (!mounted) return;
      setState(() {
        _lastMessage = 'Backup saved: $path';
        _isError = false;
      });

      Share.shareXFiles([XFile(path)], subject: 'OpenDocs Backup');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastMessage = 'Backup failed: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _lastMessage = null;
    });
    try {
      final raw = await File(path).readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      // Basic validation
      if (data['_app'] != 'OpenDocs Manager') {
        throw const FormatException(
            'This file is not a valid OpenDocs backup.');
      }

      final prefs = await SharedPreferences.getInstance();
      int count = 0;
      for (final entry in data.entries) {
        if (entry.key.startsWith('_')) continue;
        if (_excluded.contains(entry.key)) continue;
        final v = entry.value;
        if (v is String) {
          await prefs.setString(entry.key, v);
        } else if (v is bool) {
          await prefs.setBool(entry.key, v);
        } else if (v is int) {
          await prefs.setInt(entry.key, v);
        } else if (v is double) {
          await prefs.setDouble(entry.key, v);
        }
        count++;
      }

      if (!mounted) return;
      setState(() {
        _lastMessage =
            'Restored $count settings from backup.\n'
            'Restart the app for all changes to take effect.';
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastMessage = 'Restore failed: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Backup card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text('Backup',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exports all app settings (theme, font scale, reading '
                    'goals, language packs, etc.) to a JSON file. '
                    'Security keys (PIN, biometric state) are excluded.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _backup,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Create Backup'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Restore card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restore,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 10),
                      Text('Restore',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a previously created .json backup file to restore '
                    'all exported settings. Sensitive keys are not restored. '
                    'A restart is required after restoring.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Choose Backup File…'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // What's included note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What is included',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final item in [
                  'Theme (light/dark/system)',
                  'Font scale',
                  'Reading goals',
                  'High-contrast mode',
                  'Sort preferences',
                  'Reading notes (text only)',
                  'Language pack preferences',
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(item, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Text('Not included',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                for (final item in [
                  'PIN / biometric settings (security)',
                  'Bookmarks & reading history (database)',
                  'OCR history (database)',
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.remove, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(item, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_lastMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isError ? Colors.red : Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (_isError ? Colors.red : Colors.green)
                        .withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: _isError ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_lastMessage!)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
