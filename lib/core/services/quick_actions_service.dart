import 'package:quick_actions/quick_actions.dart';

import '../router/app_router.dart';

const _kScanDoc = 'scan_document';
const _kQrScan = 'qr_scanner';
const _kRecent = 'recent_files';
const _kBrowser = 'file_browser';

/// Registers four home-screen quick actions and routes to the correct screen
/// when the user taps one while the app is cold-started or in the background.
///
/// Call [init] once from the root widget's [initState].
class QuickActionsService {
  const QuickActionsService();

  static const _actions = QuickActions();

  void init(void Function(String route) navigate) {
    _actions.initialize((shortcutType) {
      final route = switch (shortcutType) {
        _kScanDoc => Routes.cameraOcr,
        _kQrScan => Routes.qrScanner,
        _kRecent => Routes.home,
        _kBrowser => Routes.browser,
        _ => Routes.home,
      };
      navigate(route);
    });

    _actions.setShortcutItems(const [
      ShortcutItem(
        type: _kScanDoc,
        localizedTitle: 'Scan Document',
        icon: 'ic_shortcut_scan',
      ),
      ShortcutItem(
        type: _kQrScan,
        localizedTitle: 'Scan QR / Barcode',
        icon: 'ic_shortcut_qr',
      ),
      ShortcutItem(
        type: _kRecent,
        localizedTitle: 'Recent Files',
        icon: 'ic_shortcut_recent',
      ),
      ShortcutItem(
        type: _kBrowser,
        localizedTitle: 'File Browser',
        icon: 'ic_shortcut_folder',
      ),
    ]);
  }
}
