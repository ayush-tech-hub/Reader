import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Tools and Manager';

  @override
  String get home => 'होम';

  @override
  String get files => 'फ़ाइलें';

  @override
  String get archives => 'संग्रह';

  @override
  String get pdfTools => 'PDF उपकरण';

  @override
  String get toggleTheme => 'थीम बदलें';

  @override
  String get recentDocuments => 'हाल के दस्तावेज़';

  @override
  String get noRecentDocuments => 'आपके पढ़े दस्तावेज़ यहाँ दिखेंगे।';

  @override
  String get favorites => 'पसंदीदा';

  @override
  String get noFavorites => 'अभी कोई पसंदीदा नहीं।';

  @override
  String pageOfPages(int page, int total) {
    return 'पृष्ठ $page / $total';
  }

  @override
  String get search => 'खोजें';

  @override
  String get searchFiles => 'फ़ाइलें खोजें';

  @override
  String get searchInDocument => 'दस्तावेज़ में खोजें';

  @override
  String get previousMatch => 'पिछला परिणाम';

  @override
  String get nextMatch => 'अगला परिणाम';

  @override
  String get bookmarkPage => 'इस पृष्ठ को बुकमार्क करें';

  @override
  String get bookmarks => 'बुकमार्क';

  @override
  String get tableOfContents => 'विषय-सूची';

  @override
  String get noTableOfContents => 'इस दस्तावेज़ में विषय-सूची नहीं है।';

  @override
  String get pageByPage => 'पृष्ठ-दर-पृष्ठ मोड';

  @override
  String get continuousScroll => 'निरंतर स्क्रॉल';

  @override
  String get rotate => 'घुमाएँ';

  @override
  String get fitToWidth => 'चौड़ाई के अनुसार';

  @override
  String get goToPage => 'पृष्ठ पर जाएँ';

  @override
  String pageN(int page) {
    return 'पृष्ठ $page';
  }

  @override
  String get highlight => 'हाइलाइट';

  @override
  String get underline => 'रेखांकित';

  @override
  String get strikethrough => 'काटा हुआ';

  @override
  String get draw => 'चित्र बनाएँ';

  @override
  String get addNote => 'नोट जोड़ें';

  @override
  String get copyText => 'टेक्स्ट कॉपी करें';

  @override
  String get passwordRequired => 'पासवर्ड आवश्यक है';

  @override
  String get password => 'पासवर्ड';

  @override
  String get passwordOptional => 'पासवर्ड (वैकल्पिक)';

  @override
  String get open => 'खोलें';

  @override
  String get save => 'सहेजें';

  @override
  String get ok => 'ठीक है';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get create => 'बनाएँ';

  @override
  String get delete => 'हटाएँ';

  @override
  String deleteConfirm(int count) {
    return '$count आइटम हटाएँ? यह पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String get rename => 'नाम बदलें';

  @override
  String get copy => 'कॉपी करें';

  @override
  String get move => 'स्थानांतरित करें';

  @override
  String pasteN(int count) {
    return '$count आइटम पेस्ट करें';
  }

  @override
  String itemsSelected(int count) {
    return '$count चयनित';
  }

  @override
  String get newFolder => 'नया फ़ोल्डर';

  @override
  String get folderName => 'फ़ोल्डर का नाम';

  @override
  String get emptyFolder => 'यह फ़ोल्डर खाली है।';

  @override
  String get gridView => 'ग्रिड दृश्य';

  @override
  String get listView => 'सूची दृश्य';

  @override
  String get sortByName => 'नाम से क्रमबद्ध करें';

  @override
  String get sortBySize => 'आकार से क्रमबद्ध करें';

  @override
  String get sortByDate => 'तिथि से क्रमबद्ध करें';

  @override
  String get showHiddenFiles => 'छिपी फ़ाइलें दिखाएँ';

  @override
  String get createArchive => 'संग्रह बनाएँ';

  @override
  String get archiveName => 'संग्रह का नाम';

  @override
  String get archiveEmpty => 'संग्रह खाली है या अभी लोड नहीं हुआ।';

  @override
  String get extract => 'निकालें';

  @override
  String get compressing => 'संपीड़ित हो रहा है…';

  @override
  String get extracting => 'निकाला जा रहा है…';

  @override
  String get jobDone => 'पूर्ण';

  @override
  String compressionLevel(int level) {
    return 'संपीड़न स्तर: $level';
  }

  @override
  String get mergePdf => 'PDF मर्ज करें';

  @override
  String get splitPdf => 'PDF विभाजित करें';

  @override
  String get compressPdf => 'PDF संपीड़ित करें';

  @override
  String get imagesToPdf => 'छवियाँ PDF में';

  @override
  String get reorderPages => 'पृष्ठ पुनर्व्यवस्थित करें';

  @override
  String get deletePages => 'पृष्ठ हटाएँ';

  @override
  String get rotatePages => 'पृष्ठ घुमाएँ';

  @override
  String get extractPages => 'पृष्ठ निकालें';

  @override
  String get watermarkPdf => 'वॉटरमार्क PDF';

  @override
  String get watermarkText => 'वॉटरमार्क टेक्स्ट';

  @override
  String get editMetadata => 'मेटाडेटा संपादित करें';

  @override
  String get metaTitle => 'शीर्षक';

  @override
  String get metaAuthor => 'लेखक';

  @override
  String get metaSubject => 'विषय';

  @override
  String get metaKeywords => 'कीवर्ड';

  @override
  String get pageRangesHint => 'पृष्ठ सीमाएँ (जैसे 1-3, 5)';

  @override
  String get pageListHint => 'पृष्ठ (जैसे 1, 3, 5)';

  @override
  String get outputCreated => 'आउटपुट बन गया';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get splitScreen => 'विभाजित स्क्रीन';

  @override
  String get extractInBackground => 'पृष्ठभूमि में निकालें';

  @override
  String get backgroundJobQueued => 'निष्कर्षण कतारबद्ध; यह पृष्ठभूमि में चलेगा।';

  @override
  String get recentFiles => 'हाल की फ़ाइलें';

  @override
  String get noRecentFiles => 'आपकी खोली फ़ाइलें यहाँ दिखेंगी।';

  @override
  String get moreTools => 'और उपकरण';

  @override
  String get aiAssistant => 'AI सहायक';

  @override
  String get summarize => 'सारांश';

  @override
  String get askAQuestion => 'अपने दस्तावेज़ों के बारे में प्रश्न पूछें';

  @override
  String get noAnswerFound => 'कोई मेल नहीं मिला। पहले इंडेक्स बनाएँ।';

  @override
  String get pickDocument => 'एक दस्तावेज़ चुनें';

  @override
  String get noTextInDocument => 'इस दस्तावेज़ में टेक्स्ट नहीं — OCR आज़माएँ।';

  @override
  String get ocrPdf => 'OCR';

  @override
  String get translate => 'अनुवाद करें';

  @override
  String get smartSearch => 'स्मार्ट खोज';

  @override
  String get buildIndex => 'इंडेक्स बनाएँ';

  @override
  String get searchAllPdfs => 'सभी PDF में खोजें';

  @override
  String get semanticRanking => 'अर्थगत रैंकिंग';

  @override
  String get duplicateFinder => 'डुप्लिकेट खोजक';

  @override
  String get scan => 'स्कैन';

  @override
  String get scanHint => 'स्कैन करने के लिए फ़ोल्डर चुनें।';

  @override
  String get noDuplicates => 'कोई डुप्लिकेट नहीं मिला।';

  @override
  String get storageAnalyzer => 'स्टोरेज विश्लेषक';

  @override
  String get byFileType => 'फ़ाइल प्रकार से';

  @override
  String get largestFiles => 'सबसे बड़ी फ़ाइलें';

  @override
  String get batchTools => 'बैच उपकरण';

  @override
  String get batchExtract => 'फ़ोल्डर के सभी संग्रह निकालें';

  @override
  String get batchConvert => 'छवियों का फ़ोल्डर PDF में बदलें';

  @override
  String get batchRename => 'बैच नाम बदलें';

  @override
  String get renamePattern => 'नाम पैटर्न';

  @override
  String get folderSync => 'फ़ोल्डर सिंक';

  @override
  String get addSyncPair => 'सिंक जोड़ी जोड़ें';

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get tags => 'टैग';

  @override
  String get newTag => 'नया टैग';

  @override
  String get assignTags => 'टैग असाइन करें';

  @override
  String get workspace => 'कार्यक्षेत्र';

  @override
  String get openDocumentTab => 'दस्तावेज़ टैब खोलें';

  @override
  String get readAloud => 'ज़ोर से पढ़ें / रोकें';

  @override
  String get encryptPdf => 'PDF एन्क्रिप्ट करें';

  @override
  String get decryptPdf => 'पासवर्ड हटाएँ';

  @override
  String get userPassword => 'उपयोगकर्ता पासवर्ड (खोलने के लिए)';

  @override
  String get ownerPassword => 'स्वामी पासवर्ड (अनुमतियाँ)';

  @override
  String get allowPrinting => 'प्रिंट की अनुमति दें';

  @override
  String get allowCopying => 'टेक्स्ट कॉपी की अनुमति दें';

  @override
  String get allowEditing => 'संपादन की अनुमति दें';

  @override
  String get allowAnnotating => 'एनोटेशन की अनुमति दें';

  @override
  String processingTime(int ms) {
    return '$ms ms में प्रोसेस किया';
  }

  @override
  String get inputSize => 'इनपुट';

  @override
  String get outputSize => 'आउटपुट';

  @override
  String savedSpace(int percent) {
    return '$percent% बचाया';
  }

  @override
  String get viewFolder => 'फ़ोल्डर देखें';

  @override
  String get processAnother => 'अन्य प्रोसेस करें';

  @override
  String get shareFile => 'शेयर करें';

  @override
  String get openFile => 'खोलें';

  @override
  String get saveLocation => 'यहाँ सहेजा';

  @override
  String get privacyNotice => 'सभी प्रोसेसिंग आपके डिवाइस पर होती है। कोई डेटा अपलोड नहीं होता।';

  @override
  String get renameFile => 'फ़ाइल का नाम बदलें';

  @override
  String get newFileName => 'नया फ़ाइल नाम';

  @override
  String get changeOutputFolder => 'आउटपुट फ़ोल्डर बदलें';

  @override
  String get useDefaultFolder => 'डिफ़ॉल्ट पर रीसेट करें';

  @override
  String get defaultSaveFolder => 'डिफ़ॉल्ट फ़ोल्डर: Internal Storage/CompressX/';

  @override
  String get permissions => 'अनुमतियाँ';

  @override
  String get noOutputYet => 'प्रोसेसिंग के बाद परिणाम यहाँ दिखेंगे।';

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
  String get removeWatermark => 'वॉटरमार्क हटाएं';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get contactUs => 'संपर्क / सुझाव';

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
