import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'pdf_tools_save_dir';
const _folderName = 'CompressX';

/// Manages the output folder for all PDF tool operations.
///
/// Default root: Internal Storage/CompressX/
/// Callers can request type-specific subdirectories via [getSubDir].
/// Users can override the root via [setCustomSaveDir].
class SaveLocationService {
  /// Returns the default save directory (CompressX/PDFs/ subfolder).
  Future<String> getDefaultSaveDir() => getSubDir('PDFs');

  /// Returns (and creates) a subfolder inside the CompressX root.
  /// e.g. getSubDir('Images') → /storage/emulated/0/CompressX/Images/
  Future<String> getSubDir(String subfolder) async {
    final base = await _baseDir();
    final dir = Directory(p.join(base, subfolder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<void> setCustomSaveDir(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, path);
  }

  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  Future<String> _baseDir() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_prefKey);
    if (custom != null && Directory(custom).existsSync()) return custom;
    return _createBaseFolder();
  }

  Future<String> _createBaseFolder() async {
    final root = await _internalStorageRoot();
    final dir = Directory(p.join(root, _folderName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<String> _internalStorageRoot() async {
    if (Platform.isAndroid) {
      const androidRoot = '/storage/emulated/0';
      if (Directory(androidRoot).existsSync()) return androidRoot;
    }
    if (Platform.isIOS) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads.path;
    return (await getApplicationDocumentsDirectory()).path;
  }
}
