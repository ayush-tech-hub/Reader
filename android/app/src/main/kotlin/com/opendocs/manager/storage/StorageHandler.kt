package com.opendocs.manager.storage

import android.content.Context
import android.os.Environment
import android.os.StatFs
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Enumerates storage volume roots (internal + removable SD/USB). */
class StorageHandler(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRoots" -> result.success(getRoots())
            else -> result.notImplemented()
        }
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
