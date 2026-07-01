package com.opendocs.manager.ml

import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * On-device barcode and QR-code detection via ML Kit.
 * Accepts an image file path and returns all detected codes with
 * their format, type, and decoded value.  Fully offline.
 */
class BarcodeHandler : MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val scanner: BarcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .build(),
    )

    fun shutdown() {
        executor.shutdown()
        scanner.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanFromImage" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGS", "path is required", null)
                    return
                }
                executor.execute {
                    try {
                        val codes = scanFromImage(path)
                        mainHandler.post { result.success(codes) }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error("BARCODE_ERROR", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun scanFromImage(path: String): List<Map<String, Any?>> {
        val bitmap = BitmapFactory.decodeFile(path)
            ?: throw IllegalArgumentException("Cannot decode image: $path")
        val image = InputImage.fromBitmap(bitmap, 0)
        val barcodes = Tasks.await(scanner.process(image))
        return barcodes.map { it.toMap() }
    }

    private fun Barcode.toMap(): Map<String, Any?> = mapOf(
        "format" to formatName(format),
        "rawValue" to rawValue,
        "displayValue" to displayValue,
        "type" to valueType,
        "url" to (url?.url),
    )

    private fun formatName(format: Int): String = when (format) {
        Barcode.FORMAT_QR_CODE -> "QR_CODE"
        Barcode.FORMAT_AZTEC -> "AZTEC"
        Barcode.FORMAT_CODABAR -> "CODABAR"
        Barcode.FORMAT_CODE_39 -> "CODE_39"
        Barcode.FORMAT_CODE_93 -> "CODE_93"
        Barcode.FORMAT_CODE_128 -> "CODE_128"
        Barcode.FORMAT_DATA_MATRIX -> "DATA_MATRIX"
        Barcode.FORMAT_EAN_8 -> "EAN_8"
        Barcode.FORMAT_EAN_13 -> "EAN_13"
        Barcode.FORMAT_ITF -> "ITF"
        Barcode.FORMAT_PDF417 -> "PDF417"
        Barcode.FORMAT_UPC_A -> "UPC_A"
        Barcode.FORMAT_UPC_E -> "UPC_E"
        else -> "UNKNOWN"
    }
}
