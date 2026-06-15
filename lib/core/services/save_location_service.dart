import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'pdf_tools_save_dir';
const _folderName = 'PDF & Image Tools';

/// Manages the default output folder for all PDF tool operations.
///
/// Default: Downloads/PDF & Image Tools/
/// Can be overridden per-user via [setCustomSaveDir].
class SaveLocationService {
  Future<String> getDefaultSaveDir() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_prefKey);
    if (custom != null && Directory(custom).existsSync()) return custom;
    return _createToolsFolder();
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

  Future<String> _createToolsFolder() async {
    final base = await _downloadsDir();
    final dir = Directory(p.join(base, _folderName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<String> _downloadsDir() async {
    if (Platform.isAndroid) {
      const androidDownloads = '/storage/emulated/0/Download';
      if (Directory(androidDownloads).existsSync()) return androidDownloads;
    }
    if (Platform.isIOS) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads.path;
    return (await getApplicationDocumentsDirectory()).path;
  }
}
