# ============================================================
# OpenDocs Manager — ProGuard / R8 rules
# ============================================================
# All third-party native libraries below use reflection, JNI,
# or service-loader discovery, which R8 cannot safely analyse
# statically. Keep them in full.
# ============================================================

# ---- Archive libraries ----------------------------------------
# zip4j reflectively loads codec and encryption classes.
-keep class net.lingala.zip4j.** { *; }
# commons-compress discovers compressor implementations via class names.
-keep class org.apache.commons.compress.** { *; }
# XZ streams are loaded by name inside commons-compress.
-keep class org.tukaani.xz.** { *; }
-dontwarn org.apache.commons.compress.**
-dontwarn org.tukaani.xz.**

# ---- PdfBox-Android -------------------------------------------
# PdfBox loads fonts, CMaps, and colour-space tables from assets
# via Class.forName; keep everything to avoid ClassNotFoundException.
-keep class com.tom_roush.pdfbox.** { *; }
-dontwarn com.tom_roush.pdfbox.**

# ---- ML Kit (text recognition + translation) -----------------
# ML Kit uses Play Services Tasks API and reflection internally.
# Without these rules R8 strips the GMS task plumbing and the app
# crashes with NoClassDefFoundError when OCR / translate is used.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# ---- WorkManager ----------------------------------------------
# WorkManager instantiates Worker subclasses by class name at runtime.
# R8 must preserve the constructor and the class name itself.
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.WorkerParameters
-dontwarn androidx.work.**

# ---- Kotlin coroutines ----------------------------------------
# Coroutine continuations contain volatile fields that hold the
# current state; R8 must not rename them or coroutines deadlock.
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-keepclassmembernames class kotlinx.coroutines.** {
    intrinsicName <fields>;
}
-keep class kotlinx.coroutines.android.** { *; }
-dontwarn kotlinx.coroutines.**

# ---- Flutter embedding & plugin registry ---------------------
# Flutter's GeneratedPluginRegistrant is compiled per-build and
# registered by class name; keep the embedding API surface.
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.**

# ---- sqflite JNI bridge --------------------------------------
# sqflite's native side is loaded via System.loadLibrary; the
# Java-side JNI bridge class must survive shrinking.
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**
