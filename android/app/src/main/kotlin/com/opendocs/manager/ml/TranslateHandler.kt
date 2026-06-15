package com.opendocs.manager.ml

import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * On-device translation via ML Kit.
 *
 * All models are downloaded once at app startup via [prefetchModels] so that
 * translation runs fully offline on every subsequent launch. The prefetch
 * runs in the background and does not block the UI. The Flutter layer can
 * call "getDownloadedLanguages" to know which models are already on-device.
 */
class TranslateHandler : MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        /**
         * ML Kit Translation language codes that our app supports and for
         * which models are prefetched at startup.  These are BCP-47 tags
         * accepted by [TranslateLanguage.fromLanguageTag].
         *
         * Languages requested by the user that are NOT in ML Kit's 58-language
         * catalogue (Odia/or, Assamese/as, Maithili/mai, Sanskrit/sa,
         * Sindhi/sd, Nepali/ne, Konkani/kok, Manipuri/mni, Bodo/brx,
         * Dogri/doi, Kashmiri/ks, Santali/sat) are intentionally omitted —
         * the Flutter picker marks them as "not available offline".
         */
        val SUPPORTED_LANGUAGE_CODES: List<String> = listOf(
            "hi", // Hindi
            "bn", // Bengali
            "te", // Telugu
            "mr", // Marathi
            "ta", // Tamil
            "gu", // Gujarati
            "kn", // Kannada
            "ml", // Malayalam
            "pa", // Punjabi
            "ur", // Urdu
            "es", // Spanish
            "fr", // French
        )
    }

    fun shutdown() = executor.shutdown()

    /**
     * Downloads ML Kit translation models for every language in
     * [SUPPORTED_LANGUAGE_CODES] in the background so that they are ready
     * for offline use.  Safe to call multiple times; already-downloaded
     * models are skipped instantly by the ML Kit layer.
     */
    fun prefetchModels() {
        executor.execute {
            val conditions = DownloadConditions.Builder().build()
            for (code in SUPPORTED_LANGUAGE_CODES) {
                val lang = TranslateLanguage.fromLanguageTag(code) ?: continue
                try {
                    val translator = Translation.getClient(
                        TranslatorOptions.Builder()
                            .setSourceLanguage(TranslateLanguage.ENGLISH)
                            .setTargetLanguage(lang)
                            .build(),
                    )
                    translator.use {
                        Tasks.await(it.downloadModelIfNeeded(conditions))
                    }
                } catch (_: Throwable) {
                    // Per-language failure is silently ignored so other
                    // downloads continue uninterrupted.
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "translate" -> handleTranslate(call, result)
            "prefetchModels" -> {
                prefetchModels()
                result.success(null)
            }
            "getDownloadedLanguages" -> handleGetDownloaded(result)
            else -> result.notImplemented()
        }
    }

    private fun handleTranslate(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")!!
        val source = call.argument<String>("source")!!
        val target = call.argument<String>("target")!!
        executor.execute {
            try {
                val sourceLanguage = TranslateLanguage.fromLanguageTag(source)
                val targetLanguage = TranslateLanguage.fromLanguageTag(target)
                if (sourceLanguage == null || targetLanguage == null) {
                    throw IllegalArgumentException(
                        "Unsupported language pair $source→$target",
                    )
                }
                val translator = Translation.getClient(
                    TranslatorOptions.Builder()
                        .setSourceLanguage(sourceLanguage)
                        .setTargetLanguage(targetLanguage)
                        .build(),
                )
                translator.use {
                    // Download model if not already on device (covers the
                    // edge case where prefetch hasn't finished yet).
                    Tasks.await(
                        it.downloadModelIfNeeded(DownloadConditions.Builder().build()),
                    )
                    val translated = Tasks.await(it.translate(text))
                    mainHandler.post { result.success(translated) }
                }
            } catch (e: Throwable) {
                mainHandler.post { result.error("TRANSLATE_ERROR", e.message, null) }
            }
        }
    }

    private fun handleGetDownloaded(result: MethodChannel.Result) {
        executor.execute {
            try {
                val models = Tasks.await(
                    RemoteModelManager.getInstance()
                        .getDownloadedModels(TranslateRemoteModel::class.java),
                )
                val codes = models.map { it.language }
                mainHandler.post { result.success(codes) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("ML_KIT_ERROR", e.message, null) }
            }
        }
    }
}
