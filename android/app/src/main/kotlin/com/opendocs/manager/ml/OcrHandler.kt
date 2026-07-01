package com.opendocs.manager.ml

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
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

        /** Returns the recognizer that handles the requested writing system.
         *  Callers are responsible for closing the returned instance. */
        fun recognizerForScript(script: String?): TextRecognizer = when (script) {
            "chinese" -> TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            "devanagari" -> TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
            "japanese" -> TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
            "korean" -> TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
            else -> TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        }
    }

    fun shutdown() = executor.shutdown()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recognizePdf" -> {
                val path = call.argument<String>("path")!!
                val script = call.argument<String>("script")
                executor.execute {
                    try {
                        val pages = recognizePdf(path, script)
                        mainHandler.post { result.success(pages) }
                    } catch (e: Throwable) {
                        mainHandler.post { result.error("OCR_ERROR", e.message, null) }
                    }
                }
            }
            "recognizeImage" -> {
                val path = call.argument<String>("path")!!
                val script = call.argument<String>("script")
                executor.execute {
                    try {
                        val text = recognizeImage(path, script)
                        mainHandler.post { result.success(text) }
                    } catch (e: Throwable) {
                        mainHandler.post { result.error("OCR_ERROR", e.message, null) }
                    }
                }
            }
            "recognizeImageBatch" -> {
                val paths = call.argument<List<String>>("paths")!!
                val script = call.argument<String>("script")
                executor.execute {
                    try {
                        val texts = paths.map { recognizeImage(it, script) }
                        mainHandler.post { result.success(texts) }
                    } catch (e: Throwable) {
                        mainHandler.post { result.error("OCR_ERROR", e.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun recognizeImage(path: String, script: String? = null): String {
        val raw = BitmapFactory.decodeFile(path)
            ?: throw IllegalArgumentException("Cannot decode image: $path")
        val bitmap = clampBitmap(raw)
        try {
            val recognizer = recognizerForScript(script)
            val image = InputImage.fromBitmap(bitmap, 0)
            val visionText = Tasks.await(recognizer.process(image))
            return visionText.text
        } finally {
            if (bitmap !== raw) raw.recycle()
            bitmap.recycle()
        }
    }

    private fun clampBitmap(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        if (w <= MAX_DIMENSION && h <= MAX_DIMENSION) return src
        val scale = MAX_DIMENSION.toFloat() / maxOf(w, h)
        val matrix = Matrix().apply { setScale(scale, scale) }
        return Bitmap.createBitmap(src, 0, 0, w, h, matrix, true)
    }

    private fun recognizePdf(path: String, script: String? = null): List<String> {
        val recognizer = recognizerForScript(script)
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
