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
        val extDirs = context.getExternalFilesDirs(null)

        // Primary internal storage. StatFs needs a path accessible without
        // MANAGE_EXTERNAL_STORAGE; the app-specific external dir is always
        // accessible and sits on the same filesystem as the public root.
        val primaryRoot = Environment.getExternalStorageDirectory().absolutePath
        val primaryStatPath = extDirs.firstOrNull()?.absolutePath ?: primaryRoot
        roots.add(describe(primaryRoot, "Internal storage", removable = false, statPath = primaryStatPath))

        // Secondary volumes (SD cards / USB) — app-specific dirs on each
        // volume are accessible without special permission.
        extDirs.drop(1).filterNotNull().forEach { dir ->
            // .../<volume>/Android/data/<pkg>/files -> <volume>
            val volume = dir.parentFile?.parentFile?.parentFile?.parentFile ?: return@forEach
            roots.add(describe(volume.absolutePath, volume.name.ifEmpty { "SD card" }, removable = true, statPath = dir.absolutePath))
        }
        return roots
    }

    private fun describe(
        path: String,
        label: String,
        removable: Boolean,
        statPath: String = path,
    ): Map<String, Any> {
        val stats = runCatching { StatFs(statPath) }.getOrNull()
        return mapOf(
            "path" to path,
            "label" to label,
            "removable" to removable,
            "totalBytes" to (stats?.totalBytes ?: 0L),
            "freeBytes" to (stats?.availableBytes ?: 0L),
        )
    }
}
