package com.opendocs.manager

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
 */
class MainActivity : FlutterActivity() {

    private lateinit var archiveHandler: ArchiveEngineHandler
    private lateinit var pdfToolsHandler: PdfToolsHandler
    private lateinit var ocrHandler: OcrHandler
    private lateinit var translateHandler: TranslateHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        archiveHandler = ArchiveEngineHandler(applicationContext)
        MethodChannel(messenger, "opendocs/archive")
            .setMethodCallHandler(archiveHandler)
        EventChannel(messenger, "opendocs/archive_progress")
            .setStreamHandler(archiveHandler)

        pdfToolsHandler = PdfToolsHandler(applicationContext)
        MethodChannel(messenger, "opendocs/pdf_tools")
            .setMethodCallHandler(pdfToolsHandler)

        MethodChannel(messenger, "opendocs/storage")
            .setMethodCallHandler(StorageHandler(applicationContext))

        ocrHandler = OcrHandler(applicationContext)
        MethodChannel(messenger, "opendocs/ocr")
            .setMethodCallHandler(ocrHandler)

        translateHandler = TranslateHandler()
        MethodChannel(messenger, "opendocs/translate")
            .setMethodCallHandler(translateHandler)
    }

    override fun onDestroy() {
        if (::archiveHandler.isInitialized) archiveHandler.shutdown()
        if (::pdfToolsHandler.isInitialized) pdfToolsHandler.shutdown()
        if (::ocrHandler.isInitialized) ocrHandler.shutdown()
        if (::translateHandler.isInitialized) translateHandler.shutdown()
        super.onDestroy()
    }
}
