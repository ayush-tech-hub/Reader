package com.opendocs.manager.archive

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import net.lingala.zip4j.ZipFile
import net.lingala.zip4j.model.ZipParameters
import net.lingala.zip4j.progress.ProgressMonitor
import net.lingala.zip4j.model.enums.AesKeyStrength
import net.lingala.zip4j.model.enums.CompressionLevel
import net.lingala.zip4j.model.enums.EncryptionMethod
import org.apache.commons.compress.archivers.sevenz.SevenZFile
import org.apache.commons.compress.archivers.sevenz.SevenZOutputFile
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveOutputStream
import org.apache.commons.compress.compressors.gzip.GzipCompressorInputStream
import org.apache.commons.compress.compressors.gzip.GzipCompressorOutputStream

/**
 * Streamed compression engine. All entry I/O goes through fixed 1 MiB
 * buffers — never whole-file byte arrays — so archives larger than
 * 10 GB work within normal heap limits. Jobs run on Dispatchers.IO and
 * are cooperatively cancellable between buffer writes.
 */
class ArchiveEngineHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val cancelledJobs = ConcurrentHashMap.newKeySet<String>()
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val BUFFER_SIZE = 1024 * 1024
        private const val PROGRESS_INTERVAL_BYTES = 8L * 1024 * 1024
    }

    fun shutdown() = scope.cancel()

    // ---- EventChannel ---------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emitProgress(
        jobId: String,
        bytesDone: Long,
        bytesTotal: Long,
        currentEntry: String,
    ) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "jobId" to jobId,
                    "bytesDone" to bytesDone,
                    "bytesTotal" to bytesTotal,
                    "currentEntry" to currentEntry,
                )
            )
        }
    }

    // ---- MethodChannel -----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> runJob(call, result) { create(call) }
            "extract" -> runJob(call, result) { extract(call) }
            "extractInBackground" -> {
                ArchiveWorker.enqueueExtraction(
                    context,
                    call.argument<String>("archivePath")!!,
                    call.argument<String>("destinationDir")!!,
                    call.argument<String>("password"),
                )
                result.success(null)
            }
            "list" -> scope.launch {
                try {
                    val entries = list(call)
                    mainHandler.post { result.success(entries) }
                } catch (e: Throwable) {
                    mainHandler.post {
                        result.error("ARCHIVE_ERROR", e.message, null)
                    }
                }
            }
            "cancel" -> {
                call.argument<String>("jobId")?.let(cancelledJobs::add)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun runJob(
        call: MethodCall,
        result: MethodChannel.Result,
        body: suspend () -> Unit,
    ) {
        scope.launch {
            try {
                body()
                mainHandler.post { result.success(null) }
            } catch (e: CancelledJobException) {
                mainHandler.post { result.error("CANCELLED", "Cancelled", null) }
            } catch (e: Throwable) {
                // Throwable, not Exception: a corrupt archive can drive the
                // codecs into OutOfMemoryError and that must surface as a
                // channel error, not kill the process.
                mainHandler.post { result.error("ARCHIVE_ERROR", e.message, null) }
            } finally {
                call.argument<String>("jobId")?.let(cancelledJobs::remove)
            }
        }
    }

    private class CancelledJobException : Exception("Cancelled")

    private fun checkCancelled(jobId: String) {
        if (cancelledJobs.contains(jobId)) throw CancelledJobException()
    }

    // ---- Create ------------------------------------------------------------

    private fun create(call: MethodCall) {
        val jobId = call.argument<String>("jobId")!!
        val sources = call.argument<List<String>>("sources")!!.map(::File)
        val archivePath = call.argument<String>("archivePath")!!
        val format = call.argument<String>("format")!!
        val password = call.argument<String>("password")
        val level = call.argument<Int>("level") ?: 6
        val totalBytes = sources.sumOf { it.walkBottomUp().filter(File::isFile).sumOf(File::length) }

        when (format) {
            "zip" -> createZip(jobId, sources, archivePath, password, level, totalBytes)
            "sevenZ" -> createSevenZ(jobId, sources, archivePath, totalBytes)
            "tar" -> createTar(jobId, sources, archivePath, totalBytes)
            "gzip" -> createGzip(jobId, sources, archivePath)
            else -> throw IllegalArgumentException("Unknown format: $format")
        }
    }

    private fun createZip(
        jobId: String,
        sources: List<File>,
        archivePath: String,
        password: String?,
        level: Int,
        totalBytes: Long,
    ) {
        val zip = if (password != null) {
            ZipFile(archivePath, password.toCharArray())
        } else {
            ZipFile(archivePath)
        }
        zip.use {
            val parameters = ZipParameters().apply {
                compressionLevel = CompressionLevel.entries
                    .getOrElse(level.coerceIn(1, 9) - 1) { CompressionLevel.NORMAL }
                if (password != null) {
                    isEncryptFiles = true
                    encryptionMethod = EncryptionMethod.AES
                    aesKeyStrength = AesKeyStrength.KEY_STRENGTH_256
                }
            }
            // Run zip4j's task on its own thread and poll the monitor so
            // huge single files still report progress and stay cancellable.
            it.isRunInThread = true
            val monitor = it.progressMonitor
            var done = 0L
            for (source in sources) {
                checkCancelled(jobId)
                val sourceBytes = if (source.isDirectory) {
                    source.walkBottomUp().filter(File::isFile).sumOf(File::length)
                } else {
                    source.length()
                }
                if (source.isDirectory) {
                    it.addFolder(source, parameters)
                } else {
                    it.addFile(source, parameters)
                }
                while (monitor.state == ProgressMonitor.State.BUSY) {
                    if (cancelledJobs.contains(jobId)) {
                        monitor.isCancelAllTasks = true
                    }
                    emitProgress(
                        jobId,
                        done + monitor.workCompleted,
                        totalBytes,
                        monitor.fileName ?: source.name,
                    )
                    Thread.sleep(150)
                }
                when (monitor.result) {
                    ProgressMonitor.Result.ERROR ->
                        throw monitor.exception ?: RuntimeException("zip failed")
                    ProgressMonitor.Result.CANCELLED -> throw CancelledJobException()
                    else -> Unit
                }
                done += sourceBytes
                emitProgress(jobId, done, totalBytes, source.name)
            }
        }
    }

    private fun createSevenZ(
        jobId: String,
        sources: List<File>,
        archivePath: String,
        totalBytes: Long,
    ) {
        SevenZOutputFile(File(archivePath)).use { out ->
            var done = 0L
            for (source in sources) {
                forEachFile(source) { file, entryName ->
                    checkCancelled(jobId)
                    val entry = out.createArchiveEntry(file, entryName)
                    out.putArchiveEntry(entry)
                    if (file.isFile) {
                        FileInputStream(file).use { input ->
                            val buffer = ByteArray(BUFFER_SIZE)
                            var read: Int
                            while (input.read(buffer).also { r -> read = r } > 0) {
                                checkCancelled(jobId)
                                out.write(buffer, 0, read)
                                done += read
                                if (done % PROGRESS_INTERVAL_BYTES < BUFFER_SIZE) {
                                    emitProgress(jobId, done, totalBytes, entryName)
                                }
                            }
                        }
                    }
                    out.closeArchiveEntry()
                }
            }
            emitProgress(jobId, totalBytes, totalBytes, "")
        }
    }

    private fun createTar(
        jobId: String,
        sources: List<File>,
        archivePath: String,
        totalBytes: Long,
    ) {
        TarArchiveOutputStream(
            BufferedOutputStream(FileOutputStream(archivePath), BUFFER_SIZE)
        ).use { out ->
            out.setLongFileMode(TarArchiveOutputStream.LONGFILE_POSIX)
            out.setBigNumberMode(TarArchiveOutputStream.BIGNUMBER_POSIX)
            var done = 0L
            for (source in sources) {
                forEachFile(source) { file, entryName ->
                    checkCancelled(jobId)
                    val entry = TarArchiveEntry(file, entryName)
                    out.putArchiveEntry(entry)
                    if (file.isFile) {
                        done += copyStreamed(jobId, FileInputStream(file), out) {
                            emitProgress(jobId, done + it, totalBytes, entryName)
                        }
                    }
                    out.closeArchiveEntry()
                }
            }
        }
    }

    private fun createGzip(jobId: String, sources: List<File>, archivePath: String) {
        val source = sources.singleOrNull()
            ?: throw IllegalArgumentException("GZIP compresses a single file")
        require(source.isFile) { "GZIP compresses a single file" }
        val total = source.length()
        GzipCompressorOutputStream(
            BufferedOutputStream(FileOutputStream(archivePath), BUFFER_SIZE)
        ).use { out ->
            copyStreamed(jobId, FileInputStream(source), out) {
                emitProgress(jobId, it, total, source.name)
            }
        }
    }

    // ---- Extract ----------------------------------------------------------

    private fun extract(call: MethodCall) {
        val jobId = call.argument<String>("jobId")!!
        val archivePath = call.argument<String>("archivePath")!!
        val destinationDir = call.argument<String>("destinationDir")!!
        val password = call.argument<String>("password")
        val lower = archivePath.lowercase()

        when {
            lower.endsWith(".zip") ->
                extractZip(jobId, archivePath, destinationDir, password)
            lower.endsWith(".7z") ->
                extractSevenZ(jobId, archivePath, destinationDir, password)
            lower.endsWith(".tar") ->
                extractTar(jobId, FileInputStream(archivePath), destinationDir, File(archivePath).length())
            lower.endsWith(".tgz") || lower.endsWith(".tar.gz") ->
                extractTar(
                    jobId,
                    GzipCompressorInputStream(
                        BufferedInputStream(FileInputStream(archivePath), BUFFER_SIZE)
                    ),
                    destinationDir,
                    File(archivePath).length(),
                )
            lower.endsWith(".gz") -> extractGzip(jobId, archivePath, destinationDir)
            else -> throw IllegalArgumentException("Unsupported archive: $archivePath")
        }
    }

    private fun extractZip(
        jobId: String,
        archivePath: String,
        destinationDir: String,
        password: String?,
    ) {
        val zip = if (password != null) {
            ZipFile(archivePath, password.toCharArray())
        } else {
            ZipFile(archivePath)
        }
        zip.use {
            it.isRunInThread = false
            val total = File(archivePath).length()
            val headers = it.fileHeaders
            var index = 0
            for (header in headers) {
                checkCancelled(jobId)
                it.extractFile(header, destinationDir)
                index++
                emitProgress(
                    jobId,
                    total * index / headers.size.coerceAtLeast(1),
                    total,
                    header.fileName,
                )
            }
        }
    }

    private fun extractSevenZ(
        jobId: String,
        archivePath: String,
        destinationDir: String,
        password: String?,
    ) {
        val builder = SevenZFile.builder().setFile(File(archivePath))
        if (password != null) builder.setPassword(password.toCharArray())
        builder.get().use { sevenZ ->
            val total = File(archivePath).length()
            var done = 0L
            var entry = sevenZ.nextEntry
            while (entry != null) {
                checkCancelled(jobId)
                val target = safeResolve(destinationDir, entry.name)
                if (entry.isDirectory) {
                    target.mkdirs()
                } else {
                    target.parentFile?.mkdirs()
                    BufferedOutputStream(FileOutputStream(target), BUFFER_SIZE).use { out ->
                        val buffer = ByteArray(BUFFER_SIZE)
                        var read: Int
                        while (sevenZ.read(buffer).also { read = it } > 0) {
                            checkCancelled(jobId)
                            out.write(buffer, 0, read)
                        }
                    }
                    done += entry.size
                    emitProgress(jobId, done.coerceAtMost(total), total, entry.name)
                }
                entry = sevenZ.nextEntry
            }
        }
    }

    private fun extractTar(
        jobId: String,
        rawInput: InputStream,
        destinationDir: String,
        totalBytes: Long,
    ) {
        TarArchiveInputStream(BufferedInputStream(rawInput, BUFFER_SIZE)).use { tar ->
            var done = 0L
            var entry = tar.nextEntry
            while (entry != null) {
                checkCancelled(jobId)
                // Link entries are skipped: materializing symlinks would
                // let later entries write through them outside the
                // destination (link-based traversal).
                if (entry.isSymbolicLink || entry.isLink) {
                    entry = tar.nextEntry
                    continue
                }
                val target = safeResolve(destinationDir, entry.name)
                if (entry.isDirectory) {
                    target.mkdirs()
                } else {
                    target.parentFile?.mkdirs()
                    BufferedOutputStream(FileOutputStream(target), BUFFER_SIZE).use { out ->
                        done += copyStreamed(jobId, tar, out, closeInput = false) {
                            emitProgress(jobId, done + it, totalBytes, entry!!.name)
                        }
                    }
                }
                entry = tar.nextEntry
            }
        }
    }

    private fun extractGzip(jobId: String, archivePath: String, destinationDir: String) {
        val name = File(archivePath).name.removeSuffix(".gz")
        val target = safeResolve(destinationDir, name)
        val total = File(archivePath).length()
        GzipCompressorInputStream(
            BufferedInputStream(FileInputStream(archivePath), BUFFER_SIZE)
        ).use { input ->
            BufferedOutputStream(FileOutputStream(target), BUFFER_SIZE).use { out ->
                copyStreamed(jobId, input, out, closeInput = false) {
                    emitProgress(jobId, it.coerceAtMost(total), total, name)
                }
            }
        }
    }

    // ---- List ------------------------------------------------------------

    private fun list(call: MethodCall): List<Map<String, Any?>> {
        val archivePath = call.argument<String>("archivePath")!!
        val password = call.argument<String>("password")
        val lower = archivePath.lowercase()
        return when {
            lower.endsWith(".zip") -> {
                val zip = if (password != null) {
                    ZipFile(archivePath, password.toCharArray())
                } else {
                    ZipFile(archivePath)
                }
                zip.use {
                    it.fileHeaders.map { header ->
                        mapOf(
                            "name" to header.fileName,
                            "isDirectory" to header.isDirectory,
                            "size" to header.uncompressedSize,
                            "compressedSize" to header.compressedSize,
                        )
                    }
                }
            }
            lower.endsWith(".7z") -> {
                val builder = SevenZFile.builder().setFile(File(archivePath))
                if (password != null) builder.setPassword(password.toCharArray())
                builder.get().use { sevenZ ->
                    sevenZ.entries.map { entry ->
                        mapOf(
                            "name" to entry.name,
                            "isDirectory" to entry.isDirectory,
                            "size" to if (entry.isDirectory) 0L else entry.size,
                            "compressedSize" to 0L,
                        )
                    }
                }
            }
            else -> {
                // tar/gz: stream entry metadata without extracting.
                val input: InputStream = when {
                    lower.endsWith(".tgz") || lower.endsWith(".tar.gz") ->
                        GzipCompressorInputStream(
                            BufferedInputStream(FileInputStream(archivePath), BUFFER_SIZE)
                        )
                    lower.endsWith(".tar") -> FileInputStream(archivePath)
                    else -> return listOf(
                        mapOf(
                            "name" to File(archivePath).name.removeSuffix(".gz"),
                            "isDirectory" to false,
                            "size" to 0L,
                            "compressedSize" to File(archivePath).length(),
                        )
                    )
                }
                TarArchiveInputStream(BufferedInputStream(input, BUFFER_SIZE)).use { tar ->
                    val entries = mutableListOf<Map<String, Any?>>()
                    var entry = tar.nextEntry
                    while (entry != null) {
                        entries.add(
                            mapOf(
                                "name" to entry.name,
                                "isDirectory" to entry.isDirectory,
                                "size" to entry.size,
                                "compressedSize" to 0L,
                            )
                        )
                        entry = tar.nextEntry
                    }
                    entries
                }
            }
        }
    }

    // ---- Helpers -------------------------------------------------------------

    /** Walks [root]; calls [block] with each file/dir and its relative entry name. */
    private fun forEachFile(root: File, block: (File, String) -> Unit) {
        if (root.isFile) {
            block(root, root.name)
            return
        }
        val base = root.parentFile ?: root
        root.walkTopDown().forEach { file ->
            block(file, file.relativeTo(base).path)
        }
    }

    /** Prevents Zip-Slip: resolved entry paths must stay inside the destination. */
    private fun safeResolve(destinationDir: String, entryName: String): File {
        val destination = File(destinationDir).canonicalFile
        val target = File(destination, entryName).canonicalFile
        require(target.path.startsWith(destination.path + File.separator) || target == destination) {
            "Illegal entry path outside destination: $entryName"
        }
        return target
    }

    private inline fun copyStreamed(
        jobId: String,
        input: InputStream,
        output: OutputStream,
        closeInput: Boolean = true,
        onProgress: (Long) -> Unit,
    ): Long {
        var copied = 0L
        var sinceProgress = 0L
        try {
            val buffer = ByteArray(BUFFER_SIZE)
            var read: Int
            while (input.read(buffer).also { read = it } > 0) {
                checkCancelled(jobId)
                output.write(buffer, 0, read)
                copied += read
                sinceProgress += read
                if (sinceProgress >= PROGRESS_INTERVAL_BYTES) {
                    sinceProgress = 0
                    onProgress(copied)
                }
            }
        } finally {
            if (closeInput) input.close()
        }
        return copied
    }
}
