package com.opendocs.manager.archive

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.io.File
import net.lingala.zip4j.ZipFile

/**
 * Battery-efficient background extraction: WorkManager defers the job
 * when the battery is low and survives app death. Used for "extract in
 * background" on large archives; foreground jobs go through
 * [ArchiveEngineHandler] directly.
 */
class ArchiveWorker(
    context: Context,
    parameters: WorkerParameters,
) : CoroutineWorker(context, parameters) {

    companion object {
        const val KEY_ARCHIVE_PATH = "archivePath"
        const val KEY_DESTINATION = "destinationDir"
        const val KEY_PASSWORD = "password"

        fun enqueueExtraction(
            context: Context,
            archivePath: String,
            destinationDir: String,
            password: String?,
        ) {
            val request = OneTimeWorkRequestBuilder<ArchiveWorker>()
                .setInputData(
                    workDataOf(
                        KEY_ARCHIVE_PATH to archivePath,
                        KEY_DESTINATION to destinationDir,
                        KEY_PASSWORD to password,
                    )
                )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiresBatteryNotLow(true)
                        .setRequiresStorageNotLow(true)
                        .build()
                )
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "extract:$archivePath",
                ExistingWorkPolicy.KEEP,
                request,
            )
        }
    }

    override suspend fun doWork(): Result {
        val archivePath = inputData.getString(KEY_ARCHIVE_PATH) ?: return Result.failure()
        val destination = inputData.getString(KEY_DESTINATION) ?: return Result.failure()
        val password = inputData.getString(KEY_PASSWORD)
        return try {
            when {
                archivePath.lowercase().endsWith(".zip") -> {
                    val zip = if (password != null) {
                        ZipFile(archivePath, password.toCharArray())
                    } else {
                        ZipFile(archivePath)
                    }
                    zip.use { it.extractAll(destination) }
                }
                else -> {
                    // Re-use the streamed engine for non-zip formats.
                    File(destination).mkdirs()
                    return Result.failure(
                        workDataOf("error" to "Background extraction supports ZIP in v1")
                    )
                }
            }
            Result.success()
        } catch (e: Exception) {
            Result.failure(workDataOf("error" to (e.message ?: "extract failed")))
        }
    }
}
