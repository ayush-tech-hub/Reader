package com.opendocs.manager.pdf

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.multipdf.PDFMergerUtility
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font
import com.tom_roush.pdfbox.pdmodel.graphics.image.JPEGFactory
import com.tom_roush.pdfbox.pdmodel.graphics.state.PDExtendedGraphicsState
import com.tom_roush.pdfbox.rendering.PDFRenderer
import com.tom_roush.pdfbox.util.Matrix
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * PDF page surgery backed by PdfBox-Android (Apache-2.0). Every method
 * writes a new output file; sources are never modified in place.
 */
class PdfToolsHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        /** Cap on rendered bitmap edges; malformed PDFs can declare
         *  arbitrarily large MediaBoxes and OOM the process otherwise. */
        private const val MAX_RENDER_DIMENSION = 4096f
    }

    init {
        PDFBoxResourceLoader.init(context)
    }

    fun shutdown() {
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                val outcome: Any? = when (call.method) {
                    "merge" -> merge(call)
                    "split" -> split(call)
                    "compress" -> compress(call)
                    "reorderPages" -> reorderPages(call)
                    "deletePages" -> deletePages(call)
                    "rotatePages" -> rotatePages(call)
                    "extractPages" -> extractPages(call)
                    "watermark" -> watermark(call)
                    "getMetadata" -> getMetadata(call)
                    "setMetadata" -> setMetadata(call)
                    else -> {
                        mainHandler.post { result.notImplemented() }
                        return@execute
                    }
                }
                mainHandler.post { result.success(outcome) }
            } catch (e: Throwable) {
                // Throwable, not Exception: malformed PDFs can trigger
                // OutOfMemoryError, which must become a channel error
                // instead of killing the process.
                mainHandler.post { result.error("PDF_TOOLS_ERROR", e.message, null) }
            }
        }
    }

    private fun merge(call: MethodCall): String {
        val sources = call.argument<List<String>>("sources")!!
        val outputPath = call.argument<String>("outputPath")!!
        val merger = PDFMergerUtility().apply {
            destinationFileName = outputPath
            sources.forEach { addSource(File(it)) }
        }
        merger.mergeDocuments(null)
        return outputPath
    }

    private fun split(call: MethodCall): List<String> {
        val source = call.argument<String>("source")!!
        val ranges = call.argument<List<Map<String, Int>>>("ranges")!!
        val outputDir = call.argument<String>("outputDir")!!
        val baseName = File(source).nameWithoutExtension
        val outputs = mutableListOf<String>()
        PDDocument.load(File(source)).use { document ->
            ranges.forEachIndexed { index, range ->
                val start = range.getValue("start")
                val end = range.getValue("end").coerceAtMost(document.numberOfPages)
                PDDocument().use { part ->
                    for (page in start..end) {
                        part.addPage(document.getPage(page - 1))
                    }
                    val path = File(outputDir, "${baseName}_part${index + 1}.pdf").path
                    part.save(path)
                    outputs.add(path)
                }
            }
        }
        return outputs
    }

    /**
     * Re-renders each page to a JPEG at a quality-dependent scale. This
     * is lossy but effective for scanned/image-heavy documents — the
     * dominant compression case on mobile.
     */
    private fun compress(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val quality = call.argument<String>("quality") ?: "medium"
        val (scale, jpegQuality) = when (quality) {
            "low" -> 1.0f to 0.5f
            "high" -> 2.0f to 0.85f
            else -> 1.5f to 0.7f
        }
        PDDocument.load(File(source)).use { document ->
            val renderer = PDFRenderer(document)
            PDDocument().use { output ->
                for (index in 0 until document.numberOfPages) {
                    val sourcePage = document.getPage(index)
                    val mediaBox = sourcePage.mediaBox
                    val maxEdge = maxOf(mediaBox.width, mediaBox.height)
                    val safeScale = if (maxEdge * scale > MAX_RENDER_DIMENSION) {
                        MAX_RENDER_DIMENSION / maxEdge
                    } else {
                        scale
                    }
                    val bitmap: Bitmap = renderer.renderImage(index, safeScale)
                    try {
                        val page = PDPage(mediaBox)
                        output.addPage(page)
                        val image =
                            JPEGFactory.createFromImage(output, bitmap, jpegQuality)
                        PDPageContentStream(output, page).use { stream ->
                            stream.drawImage(
                                image,
                                0f,
                                0f,
                                page.mediaBox.width,
                                page.mediaBox.height,
                            )
                        }
                    } finally {
                        bitmap.recycle()
                    }
                }
                output.save(outputPath)
            }
        }
        return outputPath
    }

    private fun reorderPages(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val order = call.argument<List<Int>>("order")!!
        PDDocument.load(File(source)).use { document ->
            PDDocument().use { output ->
                order.forEach { pageNumber ->
                    output.addPage(document.getPage(pageNumber - 1))
                }
                output.save(outputPath)
            }
        }
        return outputPath
    }

    private fun deletePages(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val toDelete = call.argument<List<Int>>("pages")!!.toSet()
        PDDocument.load(File(source)).use { document ->
            PDDocument().use { output ->
                for (page in 1..document.numberOfPages) {
                    if (page !in toDelete) output.addPage(document.getPage(page - 1))
                }
                output.save(outputPath)
            }
        }
        return outputPath
    }

    private fun rotatePages(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val pages = call.argument<List<Int>>("pages")!!.toSet()
        val degrees = call.argument<Int>("degrees")!!
        PDDocument.load(File(source)).use { document ->
            for (pageNumber in pages) {
                if (pageNumber in 1..document.numberOfPages) {
                    val page = document.getPage(pageNumber - 1)
                    page.rotation = (page.rotation + degrees) % 360
                }
            }
            document.save(outputPath)
        }
        return outputPath
    }

    private fun extractPages(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val start = call.argument<Int>("start")!!
        val end = call.argument<Int>("end")!!
        PDDocument.load(File(source)).use { document ->
            PDDocument().use { output ->
                for (page in start..end.coerceAtMost(document.numberOfPages)) {
                    output.addPage(document.getPage(page - 1))
                }
                output.save(outputPath)
            }
        }
        return outputPath
    }

    private fun watermark(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val text = call.argument<String>("text")!!
        val fontSize = (call.argument<Double>("fontSize") ?: 48.0).toFloat()
        val opacity = (call.argument<Double>("opacity") ?: 0.25).toFloat()
        val rotation = (call.argument<Double>("rotation") ?: 45.0)
        PDDocument.load(File(source)).use { document ->
            val graphicsState = PDExtendedGraphicsState().apply {
                nonStrokingAlphaConstant = opacity
            }
            for (page in document.pages) {
                PDPageContentStream(
                    document,
                    page,
                    PDPageContentStream.AppendMode.APPEND,
                    true,
                    true,
                ).use { stream ->
                    stream.setGraphicsStateParameters(graphicsState)
                    stream.beginText()
                    stream.setFont(PDType1Font.HELVETICA_BOLD, fontSize)
                    val matrix = Matrix()
                    matrix.translate(page.mediaBox.width / 2, page.mediaBox.height / 2)
                    matrix.rotate(Math.toRadians(rotation))
                    stream.setTextMatrix(matrix)
                    stream.showText(text)
                    stream.endText()
                }
            }
            document.save(outputPath)
        }
        return outputPath
    }

    private fun getMetadata(call: MethodCall): Map<String, String> {
        val source = call.argument<String>("source")!!
        PDDocument.load(File(source)).use { document ->
            val info = document.documentInformation
            return mapOf(
                "title" to (info.title ?: ""),
                "author" to (info.author ?: ""),
                "subject" to (info.subject ?: ""),
                "keywords" to (info.keywords ?: ""),
                "creator" to (info.creator ?: ""),
                "producer" to (info.producer ?: ""),
            )
        }
    }

    private fun setMetadata(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        PDDocument.load(File(source)).use { document ->
            document.documentInformation.apply {
                title = call.argument("title")
                author = call.argument("author")
                subject = call.argument("subject")
                keywords = call.argument("keywords")
                creator = call.argument("creator")
                producer = call.argument("producer")
            }
            document.save(outputPath)
        }
        return outputPath
    }
}
