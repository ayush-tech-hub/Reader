package com.opendocs.manager

import android.util.Log
import com.opendocs.manager.archive.ArchiveEngineHandler
import com.opendocs.manager.ml.OcrHandler
import com.opendocs.manager.ml.TranslateHandler
import com.opendocs.manager.pdf.PdfToolsHandler
import com.opendocs.manager.storage.StorageHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

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
class MainActivity : FlutterActivity() {

    private var archiveHandler: ArchiveEngineHandler? = null
    private var pdfToolsHandler: PdfToolsHandler? = null
    private var ocrHandler: OcrHandler? = null
    private var translateHandler: TranslateHandler? = null

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
            val handler = TranslateHandler()
            translateHandler = handler
            MethodChannel(messenger, "opendocs/translate")
                .setMethodCallHandler(handler)
            // Kick off background model downloads immediately so that
            // translation is ready for offline use on the first attempt.
            handler.prefetchModels()
            Log.d(TAG, "TranslateHandler registered; model prefetch started")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to register translate channel — translation unavailable", e)
        }

        Log.d(TAG, "configureFlutterEngine — all channels configured")
    }

    override fun onDestroy() {
        archiveHandler?.shutdown()
        pdfToolsHandler?.shutdown()
        ocrHandler?.shutdown()
        translateHandler?.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "OpenDocs"
    }
}
