package com.opendocs.manager.ml

import android.content.Context
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * On-device OCR for scanned PDFs: renders each page with the platform
 * PdfRenderer and recognizes text with ML Kit (bundled Latin model —
 * fully offline, no network ever).
 */
class OcrHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val RENDER_DPI_SCALE = 2 // ~144dpi; OCR sweet spot
        private const val MAX_DIMENSION = 3000
    }

    fun shutdown() = executor.shutdown()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognizePdf") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")!!
        executor.execute {
            try {
                val pages = recognizePdf(path)
                mainHandler.post { result.success(pages) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("OCR_ERROR", e.message, null) }
            }
        }
    }

    private fun recognizePdf(path: String): List<String> {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val texts = mutableListOf<String>()
        ParcelFileDescriptor.open(
            File(path),
            ParcelFileDescriptor.MODE_READ_ONLY,
        ).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                for (index in 0 until renderer.pageCount) {
                    renderer.openPage(index).use { page ->
                        val width =
                            (page.width * RENDER_DPI_SCALE).coerceAtMost(MAX_DIMENSION)
                        val height =
                            (page.height * RENDER_DPI_SCALE).coerceAtMost(MAX_DIMENSION)
                        val bitmap =
                            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(android.graphics.Color.WHITE)
                        page.render(
                            bitmap, null, null,
                            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                        )
                        try {
                            val image = InputImage.fromBitmap(bitmap, 0)
                            val visionText = Tasks.await(recognizer.process(image))
                            texts.add(visionText.text)
                        } finally {
                            bitmap.recycle()
                        }
                    }
                }
            }
        }
        return texts
    }
}
