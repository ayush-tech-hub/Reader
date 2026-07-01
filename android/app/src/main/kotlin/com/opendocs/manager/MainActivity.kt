package com.opendocs.manager

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.opendocs.manager.archive.ArchiveEngineHandler
import com.opendocs.manager.ml.BarcodeHandler
import com.opendocs.manager.ml.OcrHandler
import com.opendocs.manager.ml.SpeechHandler
import com.opendocs.manager.ml.TranslateHandler
import com.opendocs.manager.security.BiometricHandler
import com.opendocs.manager.pdf.PdfToolsHandler
import com.opendocs.manager.storage.StorageHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Registers the native engines on the channels defined in
 * lib/core/platform/native_channels.dart — keep names in sync.
 *
 * Each handler is initialised inside an individual try-catch so that a
 * failure in one engine (e.g. a missing ML Kit model or a ProGuard-stripped
 * class) does not prevent the Flutter engine from starting and rendering the
 * UI. Failures are logged and the corresponding channel is simply left
 * unregistered; the Dart side receives a MissingPluginException when the
 * feature is used and can surface a meaningful error to the user.
 */
class MainActivity : FlutterFragmentActivity() {

    private var archiveHandler: ArchiveEngineHandler? = null
    private var pdfToolsHandler: PdfToolsHandler? = null
    private var ocrHandler: OcrHandler? = null
    private var translateHandler: TranslateHandler? = null
    private var barcodeHandler: BarcodeHandler? = null
    private var speechHandler: SpeechHandler? = null

    // Route requested by a widget button tap (consumed once by Flutter).
    private var pendingWidgetRoute: String? = null
    private var widgetChannel: MethodChannel? = null

    override fun onStart() {
        super.onStart()
        intent?.getStringExtra("widget_route")?.let { pendingWidgetRoute = it }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val route = intent.getStringExtra("widget_route") ?: return
        pendingWidgetRoute = route
        widgetChannel?.invokeMethod("navigate", route)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine — registering native channels")

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        try {
            Log.d(TAG, "Initialising ArchiveEngineHandler")
            val handler = ArchiveEngineHandler(applicationContext)
            archiveHandler = handler
            MethodChannel(messenger, "opendocs/archive")
                .setMethodCallHandler(handler)
            EventChannel(messenger, "opendocs/archive_progress")
                .setStreamHandler(handler)
            Log.d(TAG, "ArchiveEngineHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register archive channel — archive features unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising PdfToolsHandler")
            val handler = PdfToolsHandler(applicationContext)
            pdfToolsHandler = handler
            MethodChannel(messenger, "opendocs/pdf_tools")
                .setMethodCallHandler(handler)
            Log.d(TAG, "PdfToolsHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register pdf_tools channel — PDF tools unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising StorageHandler")
            MethodChannel(messenger, "opendocs/storage")
                .setMethodCallHandler(StorageHandler(applicationContext))
            Log.d(TAG, "StorageHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register storage channel — storage roots unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising OcrHandler")
            val handler = OcrHandler(applicationContext)
            ocrHandler = handler
            MethodChannel(messenger, "opendocs/ocr")
                .setMethodCallHandler(handler)
            Log.d(TAG, "OcrHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register OCR channel — OCR unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising TranslateHandler")
            val handler = TranslateHandler(applicationContext)
            translateHandler = handler
            MethodChannel(messenger, "opendocs/translate")
                .setMethodCallHandler(handler)
            EventChannel(messenger, "opendocs/translate_progress")
                .setStreamHandler(handler)
            // Resume any language downloads that were still in flight when
            // the app was last killed; does not eagerly fetch new ones.
            handler.prefetchModels()
            Log.d(TAG, "TranslateHandler registered; pending downloads resumed")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register translate channel — translation unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising BarcodeHandler")
            val handler = BarcodeHandler()
            barcodeHandler = handler
            MethodChannel(messenger, "opendocs/barcode")
                .setMethodCallHandler(handler)
            Log.d(TAG, "BarcodeHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register barcode channel — barcode scanning unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising BiometricHandler")
            MethodChannel(messenger, "opendocs/biometric")
                .setMethodCallHandler(BiometricHandler(this))
            Log.d(TAG, "BiometricHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register biometric channel — biometric auth unavailable", e)
        }

        try {
            Log.d(TAG, "Initialising SpeechHandler")
            val handler = SpeechHandler(this)
            speechHandler = handler
            MethodChannel(messenger, "opendocs/speech")
                .setMethodCallHandler(handler)
            Log.d(TAG, "SpeechHandler registered")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register speech channel — voice search unavailable", e)
        }

        // File-open channel: opens files, folders, and system settings screens.
        MethodChannel(messenger, "opendocs/file_open").setMethodCallHandler { call, result ->
            if (call.method == "openAppSettings") {
                val intent = Intent(Settings.ACTION_APPLICATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    startActivity(intent)
                    result.success(null)
                } catch (e: ActivityNotFoundException) {
                    result.error("NO_APP", "Cannot open app settings", null)
                }
                return@setMethodCallHandler
            }
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("INVALID_ARGS", "path is required", null)
                return@setMethodCallHandler
            }
            try {
                val file = File(path)
                val intent = if (file.isDirectory) {
                    // Try to open in a file manager via resource/folder MIME type.
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(Uri.fromFile(file), "resource/folder")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                } else {
                    val uri = FileProvider.getUriForFile(
                        applicationContext,
                        "${applicationContext.packageName}.fileprovider",
                        file,
                    )
                    val ext = file.extension.lowercase()
                    val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "*/*"
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, mime)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                }
                startActivity(intent)
                result.success(null)
            } catch (e: ActivityNotFoundException) {
                result.error("NO_APP", "No app found to handle this file type", null)
            } catch (e: Exception) {
                result.error("OPEN_ERROR", e.message, null)
            }
        }

        // Widget navigation channel: Flutter calls getInitialRoute once on startup;
        // subsequent taps arrive via invokeMethod("navigate", route).
        val wChannel = MethodChannel(messenger, "opendocs/widget")
        widgetChannel = wChannel
        wChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    result.success(pendingWidgetRoute)
                    pendingWidgetRoute = null
                }
                else -> result.notImplemented()
            }
        }

        Log.d(TAG, "configureFlutterEngine — all channels configured")
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (speechHandler?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        archiveHandler?.shutdown()
        pdfToolsHandler?.shutdown()
        ocrHandler?.shutdown()
        translateHandler?.shutdown()
        barcodeHandler?.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "OpenDocs"
    }
}
