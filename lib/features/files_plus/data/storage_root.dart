import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resolves the root path to scan for whole-device tools (storage analyzer,
/// duplicate finder). On Android, requests All-Files-Access and scans the
/// shared storage root; everywhere else (and if permission is denied) the
/// user is asked to pick a folder via the system picker.
Future<String?> acquireStorageRootPath() async {
  if (Platform.isAndroid) {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (status.isGranted) return '/storage/emulated/0';
  }
  return FilePicker.platform.getDirectoryPath();
}
