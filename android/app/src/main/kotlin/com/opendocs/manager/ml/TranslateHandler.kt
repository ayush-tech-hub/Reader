package com.opendocs.manager.ml

import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * On-device translation via ML Kit. Each language model (~30 MB) is
 * downloaded once on first use; translation itself then runs fully
 * offline.
 */
class TranslateHandler : MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun shutdown() = executor.shutdown()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "translate") {
            result.notImplemented()
            return
        }
        val text = call.argument<String>("text")!!
        val source = call.argument<String>("source")!!
        val target = call.argument<String>("target")!!
        executor.execute {
            try {
                val sourceLanguage = TranslateLanguage.fromLanguageTag(source)
                val targetLanguage = TranslateLanguage.fromLanguageTag(target)
                if (sourceLanguage == null || targetLanguage == null) {
                    throw IllegalArgumentException("Unsupported language pair $source→$target")
                }
                val translator = Translation.getClient(
                    TranslatorOptions.Builder()
                        .setSourceLanguage(sourceLanguage)
                        .setTargetLanguage(targetLanguage)
                        .build()
                )
                translator.use {
                    Tasks.await(
                        it.downloadModelIfNeeded(DownloadConditions.Builder().build())
                    )
                    val translated = Tasks.await(it.translate(text))
                    mainHandler.post { result.success(translated) }
                }
            } catch (e: Throwable) {
                mainHandler.post { result.error("TRANSLATE_ERROR", e.message, null) }
            }
        }
    }
}
