import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('hi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools and Manager'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @archives.
  ///
  /// In en, this message translates to:
  /// **'Archives'**
  String get archives;

  /// No description provided for @pdfTools.
  ///
  /// In en, this message translates to:
  /// **'PDF Tools'**
  String get pdfTools;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @recentDocuments.
  ///
  /// In en, this message translates to:
  /// **'Recent documents'**
  String get recentDocuments;

  /// No description provided for @noRecentDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents you read will appear here.'**
  String get noRecentDocuments;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.'**
  String get noFavorites;

  /// No description provided for @pageOfPages.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pageOfPages(int page, int total);

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchFiles.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get searchFiles;

  /// No description provided for @searchInDocument.
  ///
  /// In en, this message translates to:
  /// **'Search in document'**
  String get searchInDocument;

  /// No description provided for @previousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get previousMatch;

  /// No description provided for @nextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// No description provided for @bookmarkPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get bookmarkPage;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get tableOfContents;

  /// No description provided for @noTableOfContents.
  ///
  /// In en, this message translates to:
  /// **'This document has no table of contents.'**
  String get noTableOfContents;

  /// No description provided for @pageByPage.
  ///
  /// In en, this message translates to:
  /// **'Page-by-page mode'**
  String get pageByPage;

  /// No description provided for @continuousScroll.
  ///
  /// In en, this message translates to:
  /// **'Continuous scroll'**
  String get continuousScroll;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @fitToWidth.
  ///
  /// In en, this message translates to:
  /// **'Fit to width'**
  String get fitToWidth;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @pageN.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageN(int page);

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strike-through'**
  String get strikethrough;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get draw;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyText;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password required'**
  String get passwordRequired;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (optional)'**
  String get passwordOptional;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} item(s)? This cannot be undone.'**
  String deleteConfirm(int count);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @pasteN.
  ///
  /// In en, this message translates to:
  /// **'Paste {count} item(s)'**
  String pasteN(int count);

  /// No description provided for @itemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String itemsSelected(int count);

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty.'**
  String get emptyFolder;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get sortByName;

  /// No description provided for @sortBySize.
  ///
  /// In en, this message translates to:
  /// **'Sort by size'**
  String get sortBySize;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get sortByDate;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @createArchive.
  ///
  /// In en, this message translates to:
  /// **'Create archive'**
  String get createArchive;

  /// No description provided for @archiveName.
  ///
  /// In en, this message translates to:
  /// **'Archive name'**
  String get archiveName;

  /// No description provided for @archiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Archive is empty or not yet loaded.'**
  String get archiveEmpty;

  /// No description provided for @extract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get extract;

  /// No description provided for @compressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing…'**
  String get compressing;

  /// No description provided for @extracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting…'**
  String get extracting;

  /// No description provided for @jobDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get jobDone;

  /// No description provided for @compressionLevel.
  ///
  /// In en, this message translates to:
  /// **'Compression level: {level}'**
  String compressionLevel(int level);

  /// No description provided for @mergePdf.
  ///
  /// In en, this message translates to:
  /// **'Merge PDFs'**
  String get mergePdf;

  /// No description provided for @splitPdf.
  ///
  /// In en, this message translates to:
  /// **'Split PDF'**
  String get splitPdf;

  /// No description provided for @compressPdf.
  ///
  /// In en, this message translates to:
  /// **'Compress PDF'**
  String get compressPdf;

  /// No description provided for @imagesToPdf.
  ///
  /// In en, this message translates to:
  /// **'Images to PDF'**
  String get imagesToPdf;

  /// No description provided for @reorderPages.
  ///
  /// In en, this message translates to:
  /// **'Reorder pages'**
  String get reorderPages;

  /// No description provided for @deletePages.
  ///
  /// In en, this message translates to:
  /// **'Delete pages'**
  String get deletePages;

  /// No description provided for @rotatePages.
  ///
  /// In en, this message translates to:
  /// **'Rotate pages'**
  String get rotatePages;

  /// No description provided for @extractPages.
  ///
  /// In en, this message translates to:
  /// **'Extract pages'**
  String get extractPages;

  /// No description provided for @watermarkPdf.
  ///
  /// In en, this message translates to:
  /// **'Watermark PDF'**
  String get watermarkPdf;

  /// No description provided for @watermarkText.
  ///
  /// In en, this message translates to:
  /// **'Watermark text'**
  String get watermarkText;

  /// No description provided for @editMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit metadata'**
  String get editMetadata;

  /// No description provided for @metaTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get metaTitle;

  /// No description provided for @metaAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get metaAuthor;

  /// No description provided for @metaSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get metaSubject;

  /// No description provided for @metaKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get metaKeywords;

  /// No description provided for @pageRangesHint.
  ///
  /// In en, this message translates to:
  /// **'Page ranges (e.g. 1-3, 5)'**
  String get pageRangesHint;

  /// No description provided for @pageListHint.
  ///
  /// In en, this message translates to:
  /// **'Pages (e.g. 1, 3, 5)'**
  String get pageListHint;

  /// No description provided for @outputCreated.
  ///
  /// In en, this message translates to:
  /// **'Output created'**
  String get outputCreated;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @splitScreen.
  ///
  /// In en, this message translates to:
  /// **'Split screen'**
  String get splitScreen;

  /// No description provided for @extractInBackground.
  ///
  /// In en, this message translates to:
  /// **'Extract in background'**
  String get extractInBackground;

  /// No description provided for @backgroundJobQueued.
  ///
  /// In en, this message translates to:
  /// **'Extraction queued; it will run in the background.'**
  String get backgroundJobQueued;

  /// No description provided for @recentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get recentFiles;

  /// No description provided for @noRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Files you open will appear here.'**
  String get noRecentFiles;

  /// No description provided for @moreTools.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get moreTools;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get aiAssistant;

  /// No description provided for @summarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get summarize;

  /// No description provided for @askAQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a question about your documents'**
  String get askAQuestion;

  /// No description provided for @noAnswerFound.
  ///
  /// In en, this message translates to:
  /// **'No matching passages found. Build the index first.'**
  String get noAnswerFound;

  /// No description provided for @pickDocument.
  ///
  /// In en, this message translates to:
  /// **'Pick a document'**
  String get pickDocument;

  /// No description provided for @noTextInDocument.
  ///
  /// In en, this message translates to:
  /// **'No extractable text in this document — try OCR.'**
  String get noTextInDocument;

  /// No description provided for @ocrPdf.
  ///
  /// In en, this message translates to:
  /// **'OCR'**
  String get ocrPdf;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @smartSearch.
  ///
  /// In en, this message translates to:
  /// **'Smart search'**
  String get smartSearch;

  /// No description provided for @buildIndex.
  ///
  /// In en, this message translates to:
  /// **'Build index'**
  String get buildIndex;

  /// No description provided for @searchAllPdfs.
  ///
  /// In en, this message translates to:
  /// **'Search across all PDFs'**
  String get searchAllPdfs;

  /// No description provided for @semanticRanking.
  ///
  /// In en, this message translates to:
  /// **'Semantic ranking'**
  String get semanticRanking;

  /// No description provided for @duplicateFinder.
  ///
  /// In en, this message translates to:
  /// **'Duplicate finder'**
  String get duplicateFinder;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder to scan.'**
  String get scanHint;

  /// No description provided for @noDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found.'**
  String get noDuplicates;

  /// No description provided for @storageAnalyzer.
  ///
  /// In en, this message translates to:
  /// **'Storage analyzer'**
  String get storageAnalyzer;

  /// No description provided for @byFileType.
  ///
  /// In en, this message translates to:
  /// **'By file type'**
  String get byFileType;

  /// No description provided for @largestFiles.
  ///
  /// In en, this message translates to:
  /// **'Largest files'**
  String get largestFiles;

  /// No description provided for @batchTools.
  ///
  /// In en, this message translates to:
  /// **'Batch tools'**
  String get batchTools;

  /// No description provided for @batchExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract all archives in a folder'**
  String get batchExtract;

  /// No description provided for @batchConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert folder of images to PDF'**
  String get batchConvert;

  /// No description provided for @batchRename.
  ///
  /// In en, this message translates to:
  /// **'Batch rename files'**
  String get batchRename;

  /// No description provided for @renamePattern.
  ///
  /// In en, this message translates to:
  /// **'Rename pattern'**
  String get renamePattern;

  /// No description provided for @folderSync.
  ///
  /// In en, this message translates to:
  /// **'Folder sync'**
  String get folderSync;

  /// No description provided for @addSyncPair.
  ///
  /// In en, this message translates to:
  /// **'Add sync pair'**
  String get addSyncPair;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

  /// No description provided for @assignTags.
  ///
  /// In en, this message translates to:
  /// **'Assign tags'**
  String get assignTags;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @openDocumentTab.
  ///
  /// In en, this message translates to:
  /// **'Open a document tab'**
  String get openDocumentTab;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud / stop'**
  String get readAloud;

  /// No description provided for @encryptPdf.
  ///
  /// In en, this message translates to:
  /// **'Encrypt PDF'**
  String get encryptPdf;

  /// No description provided for @decryptPdf.
  ///
  /// In en, this message translates to:
  /// **'Remove Password'**
  String get decryptPdf;

  /// No description provided for @userPassword.
  ///
  /// In en, this message translates to:
  /// **'User password (to open)'**
  String get userPassword;

  /// No description provided for @ownerPassword.
  ///
  /// In en, this message translates to:
  /// **'Owner password (permissions)'**
  String get ownerPassword;

  /// No description provided for @allowPrinting.
  ///
  /// In en, this message translates to:
  /// **'Allow printing'**
  String get allowPrinting;

  /// No description provided for @allowCopying.
  ///
  /// In en, this message translates to:
  /// **'Allow copying text'**
  String get allowCopying;

  /// No description provided for @allowEditing.
  ///
  /// In en, this message translates to:
  /// **'Allow editing'**
  String get allowEditing;

  /// No description provided for @allowAnnotating.
  ///
  /// In en, this message translates to:
  /// **'Allow annotations'**
  String get allowAnnotating;

  /// No description provided for @processingTime.
  ///
  /// In en, this message translates to:
  /// **'Processed in {ms} ms'**
  String processingTime(int ms);

  /// No description provided for @inputSize.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get inputSize;

  /// No description provided for @outputSize.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get outputSize;

  /// No description provided for @savedSpace.
  ///
  /// In en, this message translates to:
  /// **'Saved {percent}%'**
  String savedSpace(int percent);

  /// No description provided for @viewFolder.
  ///
  /// In en, this message translates to:
  /// **'View folder'**
  String get viewFolder;

  /// No description provided for @processAnother.
  ///
  /// In en, this message translates to:
  /// **'Process another'**
  String get processAnother;

  /// No description provided for @shareFile.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareFile;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @saveLocation.
  ///
  /// In en, this message translates to:
  /// **'Saved to'**
  String get saveLocation;

  /// No description provided for @privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'All processing happens entirely on your device. No data is uploaded.'**
  String get privacyNotice;

  /// No description provided for @renameFile.
  ///
  /// In en, this message translates to:
  /// **'Rename file'**
  String get renameFile;

  /// No description provided for @newFileName.
  ///
  /// In en, this message translates to:
  /// **'New file name'**
  String get newFileName;

  /// No description provided for @changeOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Change output folder'**
  String get changeOutputFolder;

  /// No description provided for @useDefaultFolder.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get useDefaultFolder;

  /// No description provided for @defaultSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Default save folder: Internal Storage/CompressX/'**
  String get defaultSaveFolder;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @noOutputYet.
  ///
  /// In en, this message translates to:
  /// **'Results will appear here after processing.'**
  String get noOutputYet;

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{bytes} B'**
  String fileSizeBytes(int bytes);

  /// No description provided for @fileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{kb} KB'**
  String fileSizeKb(String kb);

  /// No description provided for @fileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String fileSizeMb(String mb);

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String versionLabel(String version, String build);

  /// No description provided for @aboutFeaturePdf.
  ///
  /// In en, this message translates to:
  /// **'Edit, merge, split & compress PDFs — fully offline'**
  String get aboutFeaturePdf;

  /// No description provided for @aboutFeatureFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse, organize and manage every file on your device'**
  String get aboutFeatureFiles;

  /// No description provided for @aboutFeatureStorage.
  ///
  /// In en, this message translates to:
  /// **'Analyze storage usage by category and free up space'**
  String get aboutFeatureStorage;

  /// No description provided for @aboutFeatureArchive.
  ///
  /// In en, this message translates to:
  /// **'Create and extract ZIP, RAR, 7Z and TAR archives'**
  String get aboutFeatureArchive;

  /// No description provided for @removeWatermark.
  ///
  /// In en, this message translates to:
  /// **'Remove Watermark'**
  String get removeWatermark;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact / Feedback'**
  String get contactUs;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Edit PDFs with ease'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In en, this message translates to:
  /// **'Merge, split, compress, watermark and reorganize PDFs — entirely on your device.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Manage every file'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In en, this message translates to:
  /// **'Browse, organize, tag and share files and folders with a full-featured file manager.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Understand your storage'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In en, this message translates to:
  /// **'See exactly what\'s taking up space — by category — and clean it up in a tap.'**
  String get onboardingBody3;

  /// No description provided for @storageOverview.
  ///
  /// In en, this message translates to:
  /// **'Storage overview'**
  String get storageOverview;

  /// No description provided for @usedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} used of {total}'**
  String usedOfTotal(String used, String total);

  /// No description provided for @tapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan your device'**
  String get tapToScan;

  /// No description provided for @categoryImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get categoryImages;

  /// No description provided for @categoryVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get categoryVideos;

  /// No description provided for @categoryAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get categoryAudio;

  /// No description provided for @categoryDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get categoryDocuments;

  /// No description provided for @categoryApks.
  ///
  /// In en, this message translates to:
  /// **'APK files'**
  String get categoryApks;

  /// No description provided for @categoryArchives.
  ///
  /// In en, this message translates to:
  /// **'Archives'**
  String get categoryArchives;

  /// No description provided for @categoryApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get categoryApps;

  /// No description provided for @categoryDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get categoryDownloads;

  /// No description provided for @categoryHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden files'**
  String get categoryHidden;

  /// No description provided for @categoryLargeFiles.
  ///
  /// In en, this message translates to:
  /// **'Large files'**
  String get categoryLargeFiles;

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String filesCount(int count);

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @scannedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Scanned {count} files…'**
  String scannedSoFar(int count);

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @sortByNewest.
  ///
  /// In en, this message translates to:
  /// **'Sort by newest'**
  String get sortByNewest;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @pathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get pathCopied;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveTo;

  /// No description provided for @noFilesInCategory.
  ///
  /// In en, this message translates to:
  /// **'No files found in this category.'**
  String get noFilesInCategory;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @pdfEditor.
  ///
  /// In en, this message translates to:
  /// **'PDF Editor'**
  String get pdfEditor;

  /// No description provided for @fileManager.
  ///
  /// In en, this message translates to:
  /// **'File Manager'**
  String get fileManager;

  /// No description provided for @compressPdfAction.
  ///
  /// In en, this message translates to:
  /// **'Compress PDF'**
  String get compressPdfAction;

  /// No description provided for @largeFilesShortcut.
  ///
  /// In en, this message translates to:
  /// **'Large files'**
  String get largeFilesShortcut;

  /// No description provided for @downloadsShortcut.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsShortcut;

  /// No description provided for @recentFilesSection.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get recentFilesSection;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @pinnedFolders.
  ///
  /// In en, this message translates to:
  /// **'Pinned folders'**
  String get pinnedFolders;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @pinFolder.
  ///
  /// In en, this message translates to:
  /// **'Pin folder'**
  String get pinFolder;

  /// No description provided for @unpinFolder.
  ///
  /// In en, this message translates to:
  /// **'Unpin folder'**
  String get unpinFolder;

  /// No description provided for @calculateSize.
  ///
  /// In en, this message translates to:
  /// **'Calculate size'**
  String get calculateSize;

  /// No description provided for @calculatingSize.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculatingSize;

  /// No description provided for @imageOcr.
  ///
  /// In en, this message translates to:
  /// **'Image OCR'**
  String get imageOcr;

  /// No description provided for @cameraOcr.
  ///
  /// In en, this message translates to:
  /// **'Camera OCR'**
  String get cameraOcr;

  /// No description provided for @liveOcr.
  ///
  /// In en, this message translates to:
  /// **'Live OCR'**
  String get liveOcr;

  /// No description provided for @batchOcr.
  ///
  /// In en, this message translates to:
  /// **'Batch OCR'**
  String get batchOcr;

  /// No description provided for @pdfOcr.
  ///
  /// In en, this message translates to:
  /// **'PDF OCR'**
  String get pdfOcr;

  /// No description provided for @ocrHistory.
  ///
  /// In en, this message translates to:
  /// **'OCR History'**
  String get ocrHistory;

  /// No description provided for @searchablePdf.
  ///
  /// In en, this message translates to:
  /// **'Searchable PDF'**
  String get searchablePdf;

  /// No description provided for @ocrResult.
  ///
  /// In en, this message translates to:
  /// **'OCR Result'**
  String get ocrResult;

  /// No description provided for @ocrText.
  ///
  /// In en, this message translates to:
  /// **'Recognized Text'**
  String get ocrText;

  /// No description provided for @ocrLanguage.
  ///
  /// In en, this message translates to:
  /// **'OCR Language'**
  String get ocrLanguage;

  /// No description provided for @ocrAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get ocrAuto;

  /// No description provided for @ocrPages.
  ///
  /// In en, this message translates to:
  /// **'{count} page(s) recognized'**
  String ocrPages(int count);

  /// No description provided for @ocrNoText.
  ///
  /// In en, this message translates to:
  /// **'No text recognized. Try a clearer image.'**
  String get ocrNoText;

  /// No description provided for @exportAs.
  ///
  /// In en, this message translates to:
  /// **'Export as…'**
  String get exportAs;

  /// No description provided for @exportAsTxt.
  ///
  /// In en, this message translates to:
  /// **'Plain Text (.txt)'**
  String get exportAsTxt;

  /// No description provided for @exportAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown (.md)'**
  String get exportAsMarkdown;

  /// No description provided for @exportAsHtml.
  ///
  /// In en, this message translates to:
  /// **'HTML (.html)'**
  String get exportAsHtml;

  /// No description provided for @exportAsJson.
  ///
  /// In en, this message translates to:
  /// **'JSON (.json)'**
  String get exportAsJson;

  /// No description provided for @exportAsCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (.csv)'**
  String get exportAsCsv;

  /// No description provided for @exportAsSearchablePdf.
  ///
  /// In en, this message translates to:
  /// **'Searchable PDF'**
  String get exportAsSearchablePdf;

  /// No description provided for @savedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads'**
  String get savedToDownloads;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordCount(int count);

  /// No description provided for @charCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String charCount(int count);

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @noOcrHistory.
  ///
  /// In en, this message translates to:
  /// **'No OCR history yet.'**
  String get noOcrHistory;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get addFiles;

  /// No description provided for @processAll.
  ///
  /// In en, this message translates to:
  /// **'Process all'**
  String get processAll;

  /// No description provided for @batchComplete.
  ///
  /// In en, this message translates to:
  /// **'Batch complete'**
  String get batchComplete;

  /// No description provided for @batchProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String batchProgress(int done, int total);

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @pdfReader.
  ///
  /// In en, this message translates to:
  /// **'PDF Reader'**
  String get pdfReader;

  /// No description provided for @documentReader.
  ///
  /// In en, this message translates to:
  /// **'Document Reader'**
  String get documentReader;

  /// No description provided for @wordEditor.
  ///
  /// In en, this message translates to:
  /// **'Word Editor'**
  String get wordEditor;

  /// No description provided for @excelViewer.
  ///
  /// In en, this message translates to:
  /// **'Excel Viewer'**
  String get excelViewer;

  /// No description provided for @pptViewer.
  ///
  /// In en, this message translates to:
  /// **'PowerPoint Viewer'**
  String get pptViewer;

  /// No description provided for @textReader.
  ///
  /// In en, this message translates to:
  /// **'Text Reader'**
  String get textReader;

  /// No description provided for @epubReader.
  ///
  /// In en, this message translates to:
  /// **'EPUB Reader'**
  String get epubReader;

  /// No description provided for @markdownReader.
  ///
  /// In en, this message translates to:
  /// **'Markdown Reader'**
  String get markdownReader;

  /// No description provided for @imageViewer.
  ///
  /// In en, this message translates to:
  /// **'Image Viewer'**
  String get imageViewer;

  /// No description provided for @allFilesReader.
  ///
  /// In en, this message translates to:
  /// **'All Files'**
  String get allFilesReader;

  /// No description provided for @scanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan Document'**
  String get scanDocument;

  /// No description provided for @documentSuite.
  ///
  /// In en, this message translates to:
  /// **'Document Suite'**
  String get documentSuite;

  /// No description provided for @ocrSuite.
  ///
  /// In en, this message translates to:
  /// **'OCR Suite'**
  String get ocrSuite;

  /// No description provided for @readerSuite.
  ///
  /// In en, this message translates to:
  /// **'Readers'**
  String get readerSuite;

  /// No description provided for @toolsSuite.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsSuite;

  /// No description provided for @recognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get recognizing;

  /// No description provided for @dropFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop files here or tap to add'**
  String get dropFilesHere;

  /// No description provided for @sourceFile.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceFile;

  /// No description provided for @recognizedPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get recognizedPages;

  /// No description provided for @tableDetected.
  ///
  /// In en, this message translates to:
  /// **'Table detected'**
  String get tableDetected;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'hi': return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
