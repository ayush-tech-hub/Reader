package com.opendocs.manager.ml

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Voice-to-text using Android's built-in SpeechRecognizer via the
 * RecognizerIntent.  The intent opens the system speech UI (the same one
 * used by Google Assistant) and returns the transcription through the
 * activity-result mechanism.
 *
 * Call [onActivityResult] from MainActivity.onActivityResult.
 */
class SpeechHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private var pendingResult: MethodChannel.Result? = null

    companion object {
        const val REQUEST_CODE = 0x5EEC
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                val available = RecognizerIntent.isRecognitionAvailable(activity)
                result.success(available)
            }
            "listen" -> {
                if (pendingResult != null) {
                    result.error("BUSY", "A recognition session is already active", null)
                    return
                }
                pendingResult = result
                val prompt = call.argument<String>("prompt") ?: "Speak now…"
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                try {
                    @Suppress("DEPRECATION")
                    activity.startActivityForResult(intent, REQUEST_CODE)
                } catch (e: Exception) {
                    pendingResult = null
                    result.error("UNAVAILABLE", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val pr = pendingResult ?: return true
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            pr.success(null)
            return true
        }
        val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        pr.success(results?.firstOrNull())
        return true
    }
}
