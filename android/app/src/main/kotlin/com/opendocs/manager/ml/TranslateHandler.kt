package com.opendocs.manager.ml

import android.content.Context
import android.net.TrafficStats
import android.os.Handler
import android.os.Looper
import android.os.Process
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore
import java.util.concurrent.atomic.AtomicLong

/**
 * On-device translation via ML Kit, with parallel multi-language model
 * downloads and live progress reporting.
 *
 * ML Kit's `downloadModelIfNeeded()` only exposes success/failure — no
 * byte-level progress callback exists in the public API. To still show
 * meaningful speed/ETA/remaining-size to the user, this class samples the
 * process-wide received-byte counter ([TrafficStats]) while downloads are
 * active and attributes the measured throughput across the jobs currently
 * in flight. The aggregate numbers (total bytes, total speed) are real,
 * OS-measured values; per-language byte counts are this real total
 * distributed proportionally, since ML Kit doesn't expose which language a
 * given socket belongs to. Total-size-per-language is an estimate (ML Kit
 * does not publish exact model sizes), used only to turn measured bytes
 * into a percentage/ETA.
 *
 * Downloads run on a bounded pool ([MAX_CONCURRENT_DOWNLOADS]) so multiple
 * languages genuinely download at once instead of the old one-at-a-time
 * sequential loop. "Resume" is two-layered: the underlying Play Services
 * delivery transport resumes interrupted transfers on retry by itself, and
 * this class additionally persists a small "pending downloads" set so that
 * if the app process is killed mid-download, the next launch automatically
 * re-requests those languages instead of silently losing the request.
 */
class TranslateHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val downloadPool = Executors.newFixedThreadPool(MAX_CONCURRENT_DOWNLOADS)
    private val opExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val downloadGate = Semaphore(MAX_CONCURRENT_DOWNLOADS)
    private val ticker = Executors.newSingleThreadScheduledExecutor()

    private var eventSink: EventChannel.EventSink? = null
    private val jobs = ConcurrentHashMap<String, DownloadJob>()
    private val lastRxBytes = AtomicLong(-1L)
    private var wifiOnly = false

    private data class DownloadJob(
        val code: String,
        var state: String, // queued | downloading | completed | failed | canceled
        var bytesDone: Long = 0L,
        val bytesTotal: Long = estimatedSizeBytes(),
        var cancelRequested: Boolean = false,
        var error: String? = null,
    )

    companion object {
        private const val MAX_CONCURRENT_DOWNLOADS = 4
        private const val PROGRESS_TICK_MS = 400L
        private const val PREFS_NAME = "translate_handler_prefs"
        private const val PENDING_KEY = "pending_downloads"

        /**
         * Conservative flat estimate of an ML Kit translation model's
         * on-disk size. Google does not publish exact per-language sizes;
         * real-world models are roughly in the 25-45 MB range, so 30 MB is
         * used uniformly. Only affects the displayed percentage/ETA, never
         * the real measured byte/speed counters.
         */
        private fun estimatedSizeBytes(): Long = 30L * 1024 * 1024

        /** All language codes ML Kit Translate can download, queried live
         * from the SDK so the list never drifts out of date. */
        fun allSupportedCodes(): Set<String> = TranslateLanguage.getAllLanguages().toSet()
    }

    fun shutdown() {
        ticker.shutdownNow()
        downloadPool.shutdown()
        opExecutor.shutdown()
    }

    /** Re-requests any downloads still pending from a prior, interrupted
     * app session. Safe to call multiple times. */
    fun prefetchModels() = resumePendingDownloads()

    // ---- EventChannel (download progress) ----------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(job: DownloadJob) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "code" to job.code,
                    "state" to job.state,
                    "bytesDone" to job.bytesDone,
                    "bytesTotal" to job.bytesTotal,
                    "error" to job.error,
                ),
            )
        }
    }

    private fun ensureTicking() {
        if (lastRxBytes.get() != -1L) return
        lastRxBytes.set(TrafficStats.getUidRxBytes(Process.myUid()))
        ticker.scheduleWithFixedDelay({ tick() }, PROGRESS_TICK_MS, PROGRESS_TICK_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
    }

    private fun tick() {
        val active = jobs.values.filter { it.state == "downloading" }
        if (active.isEmpty()) return
        val currentRx = TrafficStats.getUidRxBytes(Process.myUid())
        val previous = lastRxBytes.getAndSet(currentRx)
        val delta = if (previous < 0 || currentRx < previous) 0L else currentRx - previous
        val perJob = if (active.isNotEmpty()) delta / active.size else 0L
        for (job in active) {
            job.bytesDone = (job.bytesDone + perJob).coerceAtMost(
                (job.bytesTotal * 0.97).toLong(),
            )
            emit(job)
        }
    }

    // ---- MethodChannel -------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "translate" -> handleTranslate(call, result)
            "prefetchModels" -> {
                prefetchModels()
                result.success(null)
            }
            "getDownloadedLanguages" -> handleGetDownloaded(result)
            "getSupportedLanguages" -> handleGetSupportedLanguages(result)
            "downloadLanguage" -> {
                val code = call.argument<String>("code")
                if (code == null) {
                    result.error("INVALID_ARGS", "code is required", null)
                    return
                }
                startDownload(code)
                result.success(null)
            }
            "downloadAllLanguages" -> {
                for (code in allSupportedCodes()) startDownload(code)
                result.success(null)
            }
            "cancelDownload" -> {
                val code = call.argument<String>("code")
                jobs[code]?.cancelRequested = true
                result.success(null)
            }
            "deleteLanguage" -> handleDelete(call, result)
            "setWifiOnly" -> {
                wifiOnly = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- Download orchestration ----------------------------------------------

    private fun startDownload(code: String) {
        val lang = TranslateLanguage.fromLanguageTag(code) ?: return
        val existing = jobs[code]
        if (existing != null && (existing.state == "queued" || existing.state == "downloading")) {
            return // already in flight
        }
        val job = DownloadJob(code = code, state = "queued")
        jobs[code] = job
        emit(job)
        markPending(code, add = true)
        ensureTicking()

        downloadPool.execute {
            downloadGate.acquire()
            try {
                job.state = "downloading"
                emit(job)
                val conditions = DownloadConditions.Builder().let {
                    if (wifiOnly) it.requireWifi() else it
                }.build()
                val translator = Translation.getClient(
                    TranslatorOptions.Builder()
                        .setSourceLanguage(TranslateLanguage.ENGLISH)
                        .setTargetLanguage(lang)
                        .build(),
                )
                translator.use {
                    Tasks.await(it.downloadModelIfNeeded(conditions))
                }
                if (job.cancelRequested) {
                    // Best-effort cancellation: ML Kit gives us no mid-flight
                    // cancel hook, so the transfer already completed by the
                    // time we observe the flag — undo it immediately instead.
                    runCatching {
                        Tasks.await(
                            RemoteModelManager.getInstance()
                                .deleteDownloadedModel(TranslateRemoteModel.Builder(lang).build()),
                        )
                    }
                    job.state = "canceled"
                } else {
                    job.bytesDone = job.bytesTotal
                    job.state = "completed"
                }
                markPending(code, add = false)
            } catch (e: Throwable) {
                job.state = if (job.cancelRequested) "canceled" else "failed"
                job.error = e.message
                markPending(code, add = false)
            } finally {
                emit(job)
                downloadGate.release()
            }
        }
    }

    /** Re-requests any downloads that were still pending when the app was
     * last killed, so an interrupted download isn't silently lost. */
    private fun resumePendingDownloads() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pending = prefs.getStringSet(PENDING_KEY, emptySet()).orEmpty().toSet()
        for (code in pending) startDownload(code)
    }

    private fun markPending(code: String, add: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(PENDING_KEY, emptySet()).orEmpty().toMutableSet()
        if (add) current.add(code) else current.remove(code)
        prefs.edit().putStringSet(PENDING_KEY, current).apply()
    }

    // ---- Queries / lifecycle ops ----------------------------------------------

    private fun handleTranslate(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")!!
        val source = call.argument<String>("source")!!
        val target = call.argument<String>("target")!!
        opExecutor.execute {
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
                    // edge case where the user hasn't pre-downloaded it).
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
        opExecutor.execute {
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

    private fun handleGetSupportedLanguages(result: MethodChannel.Result) {
        opExecutor.execute {
            try {
                val downloaded = Tasks.await(
                    RemoteModelManager.getInstance()
                        .getDownloadedModels(TranslateRemoteModel::class.java),
                ).map { it.language }.toSet()
                val payload = allSupportedCodes().sorted().map { code ->
                    mapOf(
                        "code" to code,
                        "displayName" to displayNameFor(code),
                        "isDownloaded" to downloaded.contains(code),
                        "sizeEstimateBytes" to estimatedSizeBytes(),
                    )
                }
                mainHandler.post { result.success(payload) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("ML_KIT_ERROR", e.message, null) }
            }
        }
    }

    private fun handleDelete(call: MethodCall, result: MethodChannel.Result) {
        val code = call.argument<String>("code")
        val lang = code?.let { TranslateLanguage.fromLanguageTag(it) }
        if (code == null || lang == null) {
            result.error("INVALID_ARGS", "code is required", null)
            return
        }
        opExecutor.execute {
            try {
                Tasks.await(
                    RemoteModelManager.getInstance()
                        .deleteDownloadedModel(TranslateRemoteModel.Builder(lang).build()),
                )
                markPending(code, add = false)
                jobs.remove(code)
                mainHandler.post { result.success(null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("ML_KIT_ERROR", e.message, null) }
            }
        }
    }

    private fun displayNameFor(code: String): String {
        val name = Locale(code).getDisplayName(Locale.ENGLISH)
        if (name.isBlank() || name.equals(code, ignoreCase = true)) {
            return code.uppercase()
        }
        return name.replaceFirstChar { it.uppercase() }
    }
}
