import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tools and Manager';

  @override
  String get home => 'Home';

  @override
  String get files => 'Files';

  @override
  String get archives => 'Archives';

  @override
  String get pdfTools => 'PDF Tools';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get recentDocuments => 'Recent documents';

  @override
  String get noRecentDocuments => 'Documents you read will appear here.';

  @override
  String get favorites => 'Favorites';

  @override
  String get noFavorites => 'No favorites yet.';

  @override
  String pageOfPages(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get search => 'Search';

  @override
  String get searchFiles => 'Search files';

  @override
  String get searchInDocument => 'Search in document';

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get bookmarkPage => 'Bookmark this page';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get noTableOfContents => 'This document has no table of contents.';

  @override
  String get pageByPage => 'Page-by-page mode';

  @override
  String get continuousScroll => 'Continuous scroll';

  @override
  String get rotate => 'Rotate';

  @override
  String get fitToWidth => 'Fit to width';

  @override
  String get goToPage => 'Go to page';

  @override
  String pageN(int page) {
    return 'Page $page';
  }

  @override
  String get highlight => 'Highlight';

  @override
  String get underline => 'Underline';

  @override
  String get strikethrough => 'Strike-through';

  @override
  String get draw => 'Draw';

  @override
  String get addNote => 'Add note';

  @override
  String get copyText => 'Copy text';

  @override
  String get passwordRequired => 'Password required';

  @override
  String get password => 'Password';

  @override
  String get passwordOptional => 'Password (optional)';

  @override
  String get open => 'Open';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String deleteConfirm(int count) {
    return 'Delete $count item(s)? This cannot be undone.';
  }

  @override
  String get rename => 'Rename';

  @override
  String get copy => 'Copy';

  @override
  String get move => 'Move';

  @override
  String pasteN(int count) {
    return 'Paste $count item(s)';
  }

  @override
  String itemsSelected(int count) {
    return '$count selected';
  }

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get emptyFolder => 'This folder is empty.';

  @override
  String get gridView => 'Grid view';

  @override
  String get listView => 'List view';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get sortBySize => 'Sort by size';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get showHiddenFiles => 'Show hidden files';

  @override
  String get createArchive => 'Create archive';

  @override
  String get archiveName => 'Archive name';

  @override
  String get archiveEmpty => 'Archive is empty or not yet loaded.';

  @override
  String get extract => 'Extract';

  @override
  String get compressing => 'Compressing…';

  @override
  String get extracting => 'Extracting…';

  @override
  String get jobDone => 'Done';

  @override
  String compressionLevel(int level) {
    return 'Compression level: $level';
  }

  @override
  String get mergePdf => 'Merge PDFs';

  @override
  String get splitPdf => 'Split PDF';

  @override
  String get compressPdf => 'Compress PDF';

  @override
  String get imagesToPdf => 'Images to PDF';

  @override
  String get reorderPages => 'Reorder pages';

  @override
  String get deletePages => 'Delete pages';

  @override
  String get rotatePages => 'Rotate pages';

  @override
  String get extractPages => 'Extract pages';

  @override
  String get watermarkPdf => 'Watermark PDF';

  @override
  String get watermarkText => 'Watermark text';

  @override
  String get editMetadata => 'Edit metadata';

  @override
  String get metaTitle => 'Title';

  @override
  String get metaAuthor => 'Author';

  @override
  String get metaSubject => 'Subject';

  @override
  String get metaKeywords => 'Keywords';

  @override
  String get pageRangesHint => 'Page ranges (e.g. 1-3, 5)';

  @override
  String get pageListHint => 'Pages (e.g. 1, 3, 5)';

  @override
  String get outputCreated => 'Output created';

  @override
  String get retry => 'Retry';

  @override
  String get splitScreen => 'Split screen';

  @override
  String get extractInBackground => 'Extract in background';

  @override
  String get backgroundJobQueued => 'Extraction queued; it will run in the background.';

  @override
  String get recentFiles => 'Recent files';

  @override
  String get noRecentFiles => 'Files you open will appear here.';

  @override
  String get moreTools => 'More tools';

  @override
  String get aiAssistant => 'AI assistant';

  @override
  String get summarize => 'Summarize';

  @override
  String get askAQuestion => 'Ask a question about your documents';

  @override
  String get noAnswerFound => 'No matching passages found. Build the index first.';

  @override
  String get pickDocument => 'Pick a document';

  @override
  String get noTextInDocument => 'No extractable text in this document — try OCR.';

  @override
  String get ocrPdf => 'OCR';

  @override
  String get translate => 'Translate';

  @override
  String get smartSearch => 'Smart search';

  @override
  String get buildIndex => 'Build index';

  @override
  String get searchAllPdfs => 'Search across all PDFs';

  @override
  String get semanticRanking => 'Semantic ranking';

  @override
  String get duplicateFinder => 'Duplicate finder';

  @override
  String get scan => 'Scan';

  @override
  String get scanHint => 'Pick a folder to scan.';

  @override
  String get noDuplicates => 'No duplicates found.';

  @override
  String get storageAnalyzer => 'Storage analyzer';

  @override
  String get byFileType => 'By file type';

  @override
  String get largestFiles => 'Largest files';

  @override
  String get batchTools => 'Batch tools';

  @override
  String get batchExtract => 'Extract all archives in a folder';

  @override
  String get batchConvert => 'Convert folder of images to PDF';

  @override
  String get batchRename => 'Batch rename files';

  @override
  String get renamePattern => 'Rename pattern';

  @override
  String get folderSync => 'Folder sync';

  @override
  String get addSyncPair => 'Add sync pair';

  @override
  String get syncNow => 'Sync now';

  @override
  String get tags => 'Tags';

  @override
  String get newTag => 'New tag';

  @override
  String get assignTags => 'Assign tags';

  @override
  String get workspace => 'Workspace';

  @override
  String get openDocumentTab => 'Open a document tab';

  @override
  String get readAloud => 'Read aloud / stop';

  @override
  String get encryptPdf => 'Encrypt PDF';

  @override
  String get decryptPdf => 'Remove Password';

  @override
  String get userPassword => 'User password (to open)';

  @override
  String get ownerPassword => 'Owner password (permissions)';

  @override
  String get allowPrinting => 'Allow printing';

  @override
  String get allowCopying => 'Allow copying text';

  @override
  String get allowEditing => 'Allow editing';

  @override
  String get allowAnnotating => 'Allow annotations';

  @override
  String processingTime(int ms) {
    return 'Processed in $ms ms';
  }

  @override
  String get inputSize => 'Input';

  @override
  String get outputSize => 'Output';

  @override
  String savedSpace(int percent) {
    return 'Saved $percent%';
  }

  @override
  String get viewFolder => 'View folder';

  @override
  String get processAnother => 'Process another';

  @override
  String get shareFile => 'Share';

  @override
  String get openFile => 'Open';

  @override
  String get saveLocation => 'Saved to';

  @override
  String get privacyNotice => 'All processing happens entirely on your device. No data is uploaded.';

  @override
  String get renameFile => 'Rename file';

  @override
  String get newFileName => 'New file name';

  @override
  String get changeOutputFolder => 'Change output folder';

  @override
  String get useDefaultFolder => 'Reset to default';

  @override
  String get defaultSaveFolder => 'Default save folder: Internal Storage/CompressX/';

  @override
  String get permissions => 'Permissions';

  @override
  String get noOutputYet => 'Results will appear here after processing.';

  @override
  String fileSizeBytes(int bytes) {
    return '$bytes B';
  }

  @override
  String fileSizeKb(String kb) {
    return '$kb KB';
  }

  @override
  String fileSizeMb(String mb) {
    return '$mb MB';
  }

  @override
  String get about => 'About';

  @override
  String versionLabel(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutFeaturePdf => 'Edit, merge, split & compress PDFs — fully offline';

  @override
  String get aboutFeatureFiles => 'Browse, organize and manage every file on your device';

  @override
  String get aboutFeatureStorage => 'Analyze storage usage by category and free up space';

  @override
  String get aboutFeatureArchive => 'Create and extract ZIP, RAR, 7Z and TAR archives';

  @override
  String get removeWatermark => 'Remove Watermark';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get contactUs => 'Contact / Feedback';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get onboardingTitle1 => 'Edit PDFs with ease';

  @override
  String get onboardingBody1 => 'Merge, split, compress, watermark and reorganize PDFs — entirely on your device.';

  @override
  String get onboardingTitle2 => 'Manage every file';

  @override
  String get onboardingBody2 => 'Browse, organize, tag and share files and folders with a full-featured file manager.';

  @override
  String get onboardingTitle3 => 'Understand your storage';

  @override
  String get onboardingBody3 => 'See exactly what\'s taking up space — by category — and clean it up in a tap.';

  @override
  String get storageOverview => 'Storage overview';

  @override
  String usedOfTotal(String used, String total) {
    return '$used used of $total';
  }

  @override
  String get tapToScan => 'Tap to scan your device';

  @override
  String get categoryImages => 'Images';

  @override
  String get categoryVideos => 'Videos';

  @override
  String get categoryAudio => 'Audio';

  @override
  String get categoryDocuments => 'Documents';

  @override
  String get categoryApks => 'APK files';

  @override
  String get categoryArchives => 'Archives';

  @override
  String get categoryApps => 'Apps';

  @override
  String get categoryDownloads => 'Downloads';

  @override
  String get categoryHidden => 'Hidden files';

  @override
  String get categoryLargeFiles => 'Large files';

  @override
  String filesCount(int count) {
    return '$count files';
  }

  @override
  String get scanning => 'Scanning…';

  @override
  String scannedSoFar(int count) {
    return 'Scanned $count files…';
  }

  @override
  String get rescan => 'Rescan';

  @override
  String get sortByNewest => 'Sort by newest';

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get share => 'Share';

  @override
  String get copyPath => 'Copy path';

  @override
  String get pathCopied => 'Path copied to clipboard';

  @override
  String get moveTo => 'Move to…';

  @override
  String get noFilesInCategory => 'No files found in this category.';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get pdfEditor => 'PDF Editor';

  @override
  String get fileManager => 'File Manager';

  @override
  String get compressPdfAction => 'Compress PDF';

  @override
  String get largeFilesShortcut => 'Large files';

  @override
  String get downloadsShortcut => 'Downloads';

  @override
  String get recentFilesSection => 'Recent files';

  @override
  String get viewAll => 'View all';

  @override
  String get pinnedFolders => 'Pinned folders';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get pinFolder => 'Pin folder';

  @override
  String get unpinFolder => 'Unpin folder';

  @override
  String get calculateSize => 'Calculate size';

  @override
  String get calculatingSize => 'Calculating…';

  @override
  String get imageOcr => 'Image OCR';

  @override
  String get cameraOcr => 'Camera OCR';

  @override
  String get liveOcr => 'Live OCR';

  @override
  String get batchOcr => 'Batch OCR';

  @override
  String get pdfOcr => 'PDF OCR';

  @override
  String get ocrHistory => 'OCR History';

  @override
  String get searchablePdf => 'Searchable PDF';

  @override
  String get ocrResult => 'OCR Result';

  @override
  String get ocrText => 'Recognized Text';

  @override
  String get ocrLanguage => 'OCR Language';

  @override
  String get ocrAuto => 'Auto-detect';

  @override
  String ocrPages(int count) {
    return '$count page(s) recognized';
  }

  @override
  String get ocrNoText => 'No text recognized. Try a clearer image.';

  @override
  String get exportAs => 'Export as…';

  @override
  String get exportAsTxt => 'Plain Text (.txt)';

  @override
  String get exportAsMarkdown => 'Markdown (.md)';

  @override
  String get exportAsHtml => 'HTML (.html)';

  @override
  String get exportAsJson => 'JSON (.json)';

  @override
  String get exportAsCsv => 'CSV (.csv)';

  @override
  String get exportAsSearchablePdf => 'Searchable PDF';

  @override
  String get savedToDownloads => 'Saved to Downloads';

  @override
  String get copyAll => 'Copy all';

  @override
  String wordCount(int count) {
    return '$count words';
  }

  @override
  String charCount(int count) {
    return '$count chars';
  }

  @override
  String get clearHistory => 'Clear history';

  @override
  String get noOcrHistory => 'No OCR history yet.';

  @override
  String get addFiles => 'Add files';

  @override
  String get processAll => 'Process all';

  @override
  String get batchComplete => 'Batch complete';

  @override
  String batchProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get pickFromGallery => 'Pick from gallery';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get pdfReader => 'PDF Reader';

  @override
  String get documentReader => 'Document Reader';

  @override
  String get wordEditor => 'Word Editor';

  @override
  String get excelViewer => 'Excel Viewer';

  @override
  String get pptViewer => 'PowerPoint Viewer';

  @override
  String get textReader => 'Text Reader';

  @override
  String get epubReader => 'EPUB Reader';

  @override
  String get markdownReader => 'Markdown Reader';

  @override
  String get imageViewer => 'Image Viewer';

  @override
  String get allFilesReader => 'All Files';

  @override
  String get scanDocument => 'Scan Document';

  @override
  String get documentSuite => 'Document Suite';

  @override
  String get ocrSuite => 'OCR Suite';

  @override
  String get readerSuite => 'Readers';

  @override
  String get toolsSuite => 'Tools';

  @override
  String get recognizing => 'Recognizing…';

  @override
  String get dropFilesHere => 'Drop files here or tap to add';

  @override
  String get sourceFile => 'Source';

  @override
  String get recognizedPages => 'Pages';

  @override
  String get tableDetected => 'Table detected';
}
