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
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.StandardDecryptionMaterial
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
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
        // PDFBoxResourceLoader sets a static Application context used by
        // font/CMap loaders.  Wrap in try-catch so that a missing asset
        // (e.g. stripped by isShrinkResources) logs an error instead of
        // propagating a Throwable out of configureFlutterEngine() and
        // preventing the Flutter engine from starting.
        try {
            PDFBoxResourceLoader.init(context)
            android.util.Log.d("PdfToolsHandler", "PDFBoxResourceLoader initialised")
        } catch (e: Throwable) {
            android.util.Log.e(
                "PdfToolsHandler",
                "PDFBoxResourceLoader.init failed — PDF tools may not work correctly",
                e,
            )
        }
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
                    "removeWatermark" -> removeWatermark(call)
                    "getMetadata" -> getMetadata(call)
                    "setMetadata" -> setMetadata(call)
                    "encrypt" -> encrypt(call)
                    "decrypt" -> decrypt(call)
                    "addBlankPages" -> addBlankPages(call)
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
        val customImageQuality = call.argument<Int>("imageQuality")
        val customDpi = call.argument<Int>("dpi")
        val (scale, jpegQuality) = if (customImageQuality != null && customDpi != null) {
            // Custom mode: use exact user-specified values.
            val renderScale = customDpi / 72.0f
            val jq = customImageQuality.coerceIn(1, 100) / 100.0f
            renderScale to jq
        } else {
            when (quality) {
                "low" -> 1.0f to 0.5f
                "high" -> 2.0f to 0.85f
                else -> 1.5f to 0.7f
            }
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

    /**
     * Removes watermarks using two strategies:
     *
     * 1. Annotation sweeping — removes all Stamp, Watermark, and FreeText
     *    annotations (covers watermarks added by Acrobat and similar tools).
     *
     * 2. Appended-stream trimming — when a page's content is stored as an
     *    array of streams (i.e. something was appended after the original
     *    content), the trailing stream is inspected; if it contains only text
     *    rendering operators it is almost certainly a text watermark added in
     *    append mode and is dropped.
     */
    private fun removeWatermark(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!

        PDDocument.load(File(source)).use { document ->
            for (page in document.pages) {
                // Strategy 1: remove watermark-type annotations.
                val annotations = page.annotations
                annotations.removeIf { ann ->
                    val sub = ann.subtype?.lowercase() ?: ""
                    sub == "stamp" || sub == "watermark" || sub == "freetext"
                }

                // Strategy 2: drop trailing appended content streams that
                // appear to be text-only overlays (our own watermark format).
                val cosPage = page.cosObject
                val contentsObj = cosPage.getItem(
                    com.tom_roush.pdfbox.cos.COSName.CONTENTS,
                )
                if (contentsObj is com.tom_roush.pdfbox.cos.COSArray &&
                    contentsObj.size() > 1
                ) {
                    val lastRef = contentsObj.get(contentsObj.size() - 1)
                    // Resolve the indirect COSObject reference to its actual stream.
                    val lastStream = when (lastRef) {
                        is com.tom_roush.pdfbox.cos.COSObject -> lastRef.getObject()
                        else -> lastRef
                    }
                    if (lastStream is com.tom_roush.pdfbox.cos.COSStream) {
                        val bytes = lastStream.createInputStream().use { it.readBytes() }
                        val text = String(bytes, Charsets.ISO_8859_1)
                        // Only remove the stream if it looks like a pure-text
                        // watermark (BT … ET block, no image operators).
                        if (text.contains("BT") && text.contains("ET") &&
                            !text.contains("Do") && !text.contains("BI")
                        ) {
                            contentsObj.remove(contentsObj.size() - 1)
                            cosPage.setItem(
                                com.tom_roush.pdfbox.cos.COSName.CONTENTS,
                                contentsObj,
                            )
                        }
                    }
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

    private fun encrypt(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val userPassword = call.argument<String>("userPassword") ?: ""
        val ownerPassword = call.argument<String>("ownerPassword").let {
            if (it.isNullOrEmpty()) userPassword + "_owner" else it
        }
        val allowPrinting = call.argument<Boolean>("allowPrinting") ?: true
        val allowCopying = call.argument<Boolean>("allowCopying") ?: false
        val allowEditing = call.argument<Boolean>("allowEditing") ?: false
        val allowAnnotating = call.argument<Boolean>("allowAnnotating") ?: true

        PDDocument.load(File(source)).use { document ->
            val ap = AccessPermission().apply {
                setCanPrint(allowPrinting)
                setCanExtractContent(allowCopying)
                setCanModify(allowEditing)
                setCanModifyAnnotations(allowAnnotating)
            }
            val policy = StandardProtectionPolicy(ownerPassword, userPassword, ap).apply {
                encryptionKeyLength = 256
            }
            document.protect(policy)
            document.save(outputPath)
        }
        return outputPath
    }

    private fun decrypt(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        val password = call.argument<String>("password") ?: ""

        PDDocument.load(File(source), password).use { document ->
            document.isAllSecurityToBeRemoved = true
            document.save(outputPath)
        }
        return outputPath
    }

    /**
     * Inserts blank pages into a PDF at specified positions.
     *
     * Arguments:
     * - source: String path to the input PDF
     * - outputPath: String path for the result
     * - insertions: List<Map<String, Any>> — each map has:
     *     "afterPage": Int (1-based; 0 = insert before page 1)
     *     "count": Int (how many blank pages to insert)
     * If no insertions provided, one blank page is appended at the end.
     */
    private fun addBlankPages(call: MethodCall): String {
        val source = call.argument<String>("source")!!
        val outputPath = call.argument<String>("outputPath")!!
        @Suppress("UNCHECKED_CAST")
        val insertions = call.argument<List<Map<String, Any>>>("insertions")
            ?: listOf(mapOf("afterPage" to -1, "count" to 1))

        PDDocument.load(File(source)).use { doc ->
            // Process insertions in reverse order so indices stay valid.
            val sorted = insertions.sortedByDescending { (it["afterPage"] as? Int) ?: -1 }
            for (ins in sorted) {
                val afterPage = (ins["afterPage"] as? Int) ?: -1
                val count = (ins["count"] as? Int) ?: 1
                // Determine the page size to match: use adjacent page or A4.
                val refPage = if (afterPage in 1..doc.numberOfPages)
                    doc.getPage(afterPage - 1)
                else if (doc.numberOfPages > 0) doc.getPage(0)
                else null
                val mediaBox = refPage?.mediaBox
                    ?: com.tom_roush.pdfbox.pdmodel.common.PDRectangle.A4
                val insertAt = if (afterPage < 0 || afterPage >= doc.numberOfPages)
                    doc.numberOfPages
                else afterPage
                for (i in 0 until count) {
                    val blank = PDPage(mediaBox)
                    doc.pages.insertBefore(blank, if (insertAt < doc.numberOfPages) doc.getPage(insertAt) else null)
                }
            }
            doc.save(outputPath)
        }
        return outputPath
    }
}
