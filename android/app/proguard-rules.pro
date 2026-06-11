# zip4j / commons-compress reflectively load codec classes.
-keep class net.lingala.zip4j.** { *; }
-keep class org.apache.commons.compress.** { *; }
-keep class org.tukaani.xz.** { *; }
# PdfBox-Android resources and fonts.
-keep class com.tom_roush.pdfbox.** { *; }
-dontwarn org.apache.commons.compress.**
-dontwarn com.tom_roush.pdfbox.**
