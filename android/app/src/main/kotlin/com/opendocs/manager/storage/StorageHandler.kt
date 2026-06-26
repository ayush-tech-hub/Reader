package com.opendocs.manager.storage

import android.content.Context
import android.content.pm.PackageManager
import android.os.Environment
import android.os.StatFs
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Enumerates storage volume roots (internal + removable SD/USB). */
class StorageHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRoots" -> result.success(getRoots())
            "getAppsBytes" -> result.success(getAppsBytes())
            else -> result.notImplemented()
        }
    }

    private fun getAppsBytes(): Map<String, Any> {
        val packages = context.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        var totalBytes = 0L
        for (app in packages) {
            totalBytes += runCatching { File(app.sourceDir).length() }.getOrElse { 0L }
            app.splitSourceDirs?.forEach { split ->
                totalBytes += runCatching { File(split).length() }.getOrElse { 0L }
            }
        }
        return mapOf("totalBytes" to totalBytes, "count" to packages.size)
    }

    private fun getRoots(): List<Map<String, Any>> {
        val roots = mutableListOf<Map<String, Any>>()

        val internal = Environment.getExternalStorageDirectory()
        roots.add(describe(internal.absolutePath, "Internal storage", removable = false))

        // Secondary volumes (SD cards / USB) surface as the ancestors of
        // the app-specific external dirs beyond the first one.
        context.getExternalFilesDirs(null).drop(1).filterNotNull().forEach { dir ->
            // .../<volume>/Android/data/<pkg>/files -> <volume>
            val volume = dir.parentFile?.parentFile?.parentFile?.parentFile ?: return@forEach
            roots.add(describe(volume.absolutePath, volume.name.ifEmpty { "SD card" }, removable = true))
        }
        return roots
    }

    private fun describe(path: String, label: String, removable: Boolean): Map<String, Any> {
        val stats = runCatching { StatFs(path) }.getOrNull()
        return mapOf(
            "path" to path,
            "label" to label,
            "removable" to removable,
            "totalBytes" to (stats?.totalBytes ?: 0L),
            "freeBytes" to (stats?.availableBytes ?: 0L),
        )
    }
}
