/// Single source of truth for platform-channel contracts. Mirrored by
/// MainActivity.kt (Android) and AppDelegate.swift (iOS) — keep in sync.
abstract final class NativeChannels {
  static const String archive = 'opendocs/archive';
  static const String archiveProgress = 'opendocs/archive_progress';
  static const String pdfTools = 'opendocs/pdf_tools';
  static const String storage = 'opendocs/storage';
  static const String ocr = 'opendocs/ocr';
  static const String translate = 'opendocs/translate';
  static const String translateProgress = 'opendocs/translate_progress';
  static const String barcode = 'opendocs/barcode';
}

abstract final class ArchiveMethods {
  static const String create = 'create';
  static const String extract = 'extract';
  static const String extractInBackground = 'extractInBackground';
  static const String list = 'list';
  static const String cancel = 'cancel';
}

abstract final class PdfToolsMethods {
  static const String merge = 'merge';
  static const String split = 'split';
  static const String compress = 'compress';
  static const String reorderPages = 'reorderPages';
  static const String deletePages = 'deletePages';
  static const String rotatePages = 'rotatePages';
  static const String extractPages = 'extractPages';
  static const String watermark = 'watermark';
  static const String removeWatermark = 'removeWatermark';
  static const String getMetadata = 'getMetadata';
  static const String setMetadata = 'setMetadata';
  static const String encrypt = 'encrypt';
  static const String decrypt = 'decrypt';
}

abstract final class StorageMethods {
  static const String getRoots = 'getRoots';
}
