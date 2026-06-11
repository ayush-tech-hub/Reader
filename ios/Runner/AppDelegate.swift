import Flutter
import UIKit

/// Registers the native engines on the channels defined in
/// lib/core/platform/native_channels.dart — keep names in sync.
@main
@objc class AppDelegate: FlutterAppDelegate {

  private var archiveHandler: ArchiveEngineHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let messenger = controller.binaryMessenger

    let archive = ArchiveEngineHandler()
    archiveHandler = archive
    FlutterMethodChannel(name: "opendocs/archive", binaryMessenger: messenger)
      .setMethodCallHandler(archive.handle)
    FlutterEventChannel(name: "opendocs/archive_progress", binaryMessenger: messenger)
      .setStreamHandler(archive)

    let pdfTools = PdfToolsHandler()
    FlutterMethodChannel(name: "opendocs/pdf_tools", binaryMessenger: messenger)
      .setMethodCallHandler(pdfTools.handle)

    FlutterMethodChannel(name: "opendocs/storage", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getRoots":
          let documents = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
          ).first ?? NSHomeDirectory()
          // iOS sandboxes apps to their container; the Files-app
          // integration (UISupportsDocumentBrowser) exposes Documents.
          result([
            [
              "path": documents,
              "label": "On My iPhone",
              "removable": false,
              "totalBytes": 0,
              "freeBytes": 0,
            ]
          ])
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
