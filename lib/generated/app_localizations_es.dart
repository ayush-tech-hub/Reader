import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Tools and Manager';

  @override
  String get home => 'Inicio';

  @override
  String get files => 'Archivos';

  @override
  String get archives => 'Comprimidos';

  @override
  String get pdfTools => 'Herramientas PDF';

  @override
  String get toggleTheme => 'Cambiar tema';

  @override
  String get recentDocuments => 'Documentos recientes';

  @override
  String get noRecentDocuments => 'Los documentos que leas aparecerán aquí.';

  @override
  String get favorites => 'Favoritos';

  @override
  String get noFavorites => 'Aún no hay favoritos.';

  @override
  String pageOfPages(int page, int total) {
    return 'Página $page de $total';
  }

  @override
  String get search => 'Buscar';

  @override
  String get searchFiles => 'Buscar archivos';

  @override
  String get searchInDocument => 'Buscar en el documento';

  @override
  String get previousMatch => 'Coincidencia anterior';

  @override
  String get nextMatch => 'Siguiente coincidencia';

  @override
  String get bookmarkPage => 'Marcar esta página';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get tableOfContents => 'Índice';

  @override
  String get noTableOfContents => 'Este documento no tiene índice.';

  @override
  String get pageByPage => 'Modo página a página';

  @override
  String get continuousScroll => 'Desplazamiento continuo';

  @override
  String get rotate => 'Rotar';

  @override
  String get fitToWidth => 'Ajustar al ancho';

  @override
  String get goToPage => 'Ir a la página';

  @override
  String pageN(int page) {
    return 'Página $page';
  }

  @override
  String get highlight => 'Resaltar';

  @override
  String get underline => 'Subrayar';

  @override
  String get strikethrough => 'Tachar';

  @override
  String get draw => 'Dibujar';

  @override
  String get addNote => 'Añadir nota';

  @override
  String get copyText => 'Copiar texto';

  @override
  String get passwordRequired => 'Se requiere contraseña';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordOptional => 'Contraseña (opcional)';

  @override
  String get open => 'Abrir';

  @override
  String get save => 'Guardar';

  @override
  String get ok => 'Aceptar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Crear';

  @override
  String get delete => 'Eliminar';

  @override
  String deleteConfirm(int count) {
    return '¿Eliminar $count elemento(s)? Esta acción no se puede deshacer.';
  }

  @override
  String get rename => 'Renombrar';

  @override
  String get copy => 'Copiar';

  @override
  String get move => 'Mover';

  @override
  String pasteN(int count) {
    return 'Pegar $count elemento(s)';
  }

  @override
  String itemsSelected(int count) {
    return '$count seleccionados';
  }

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get folderName => 'Nombre de la carpeta';

  @override
  String get emptyFolder => 'Esta carpeta está vacía.';

  @override
  String get gridView => 'Vista de cuadrícula';

  @override
  String get listView => 'Vista de lista';

  @override
  String get sortByName => 'Ordenar por nombre';

  @override
  String get sortBySize => 'Ordenar por tamaño';

  @override
  String get sortByDate => 'Ordenar por fecha';

  @override
  String get showHiddenFiles => 'Mostrar archivos ocultos';

  @override
  String get createArchive => 'Crear archivo comprimido';

  @override
  String get archiveName => 'Nombre del archivo';

  @override
  String get archiveEmpty => 'El archivo está vacío o aún no se ha cargado.';

  @override
  String get extract => 'Extraer';

  @override
  String get compressing => 'Comprimiendo…';

  @override
  String get extracting => 'Extrayendo…';

  @override
  String get jobDone => 'Completado';

  @override
  String compressionLevel(int level) {
    return 'Nivel de compresión: $level';
  }

  @override
  String get mergePdf => 'Unir PDFs';

  @override
  String get splitPdf => 'Dividir PDF';

  @override
  String get compressPdf => 'Comprimir PDF';

  @override
  String get imagesToPdf => 'Imágenes a PDF';

  @override
  String get reorderPages => 'Reordenar páginas';

  @override
  String get deletePages => 'Eliminar páginas';

  @override
  String get rotatePages => 'Rotar páginas';

  @override
  String get extractPages => 'Extraer páginas';

  @override
  String get watermarkPdf => 'Marca de agua';

  @override
  String get watermarkText => 'Texto de la marca de agua';

  @override
  String get editMetadata => 'Editar metadatos';

  @override
  String get metaTitle => 'Título';

  @override
  String get metaAuthor => 'Autor';

  @override
  String get metaSubject => 'Asunto';

  @override
  String get metaKeywords => 'Palabras clave';

  @override
  String get pageRangesHint => 'Rangos de páginas (p. ej. 1-3, 5)';

  @override
  String get pageListHint => 'Páginas (p. ej. 1, 3, 5)';

  @override
  String get outputCreated => 'Archivo creado';

  @override
  String get retry => 'Reintentar';

  @override
  String get splitScreen => 'Pantalla dividida';

  @override
  String get extractInBackground => 'Extraer en segundo plano';

  @override
  String get backgroundJobQueued => 'Extracción en cola; se ejecutará en segundo plano.';

  @override
  String get recentFiles => 'Archivos recientes';

  @override
  String get noRecentFiles => 'Los archivos que abras aparecerán aquí.';

  @override
  String get moreTools => 'Más herramientas';

  @override
  String get aiAssistant => 'Asistente IA';

  @override
  String get summarize => 'Resumir';

  @override
  String get askAQuestion => 'Haz una pregunta sobre tus documentos';

  @override
  String get noAnswerFound => 'No se encontraron pasajes. Construye el índice primero.';

  @override
  String get pickDocument => 'Elige un documento';

  @override
  String get noTextInDocument => 'Sin texto extraíble en este documento — prueba OCR.';

  @override
  String get ocrPdf => 'OCR';

  @override
  String get translate => 'Traducir';

  @override
  String get smartSearch => 'Búsqueda inteligente';

  @override
  String get buildIndex => 'Construir índice';

  @override
  String get searchAllPdfs => 'Buscar en todos los PDFs';

  @override
  String get semanticRanking => 'Clasificación semántica';

  @override
  String get duplicateFinder => 'Buscador de duplicados';

  @override
  String get scan => 'Escanear';

  @override
  String get scanHint => 'Elige una carpeta para escanear.';

  @override
  String get noDuplicates => 'No se encontraron duplicados.';

  @override
  String get storageAnalyzer => 'Analizador de almacenamiento';

  @override
  String get byFileType => 'Por tipo de archivo';

  @override
  String get largestFiles => 'Archivos más grandes';

  @override
  String get batchTools => 'Herramientas por lotes';

  @override
  String get batchExtract => 'Extraer todos los archivos de una carpeta';

  @override
  String get batchConvert => 'Convertir carpeta de imágenes a PDF';

  @override
  String get batchRename => 'Renombrar por lotes';

  @override
  String get renamePattern => 'Patrón de renombrado';

  @override
  String get folderSync => 'Sincronizar carpetas';

  @override
  String get addSyncPair => 'Añadir par de sincronización';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get tags => 'Etiquetas';

  @override
  String get newTag => 'Nueva etiqueta';

  @override
  String get assignTags => 'Asignar etiquetas';

  @override
  String get workspace => 'Espacio de trabajo';

  @override
  String get openDocumentTab => 'Abrir una pestaña de documento';

  @override
  String get readAloud => 'Leer en voz alta / detener';

  @override
  String get encryptPdf => 'Cifrar PDF';

  @override
  String get decryptPdf => 'Quitar contraseña';

  @override
  String get userPassword => 'Contraseña de usuario (para abrir)';

  @override
  String get ownerPassword => 'Contraseña de propietario (permisos)';

  @override
  String get allowPrinting => 'Permitir impresión';

  @override
  String get allowCopying => 'Permitir copiar texto';

  @override
  String get allowEditing => 'Permitir edición';

  @override
  String get allowAnnotating => 'Permitir anotaciones';

  @override
  String processingTime(int ms) {
    return 'Procesado en $ms ms';
  }

  @override
  String get inputSize => 'Entrada';

  @override
  String get outputSize => 'Salida';

  @override
  String savedSpace(int percent) {
    return 'Ahorrado $percent%';
  }

  @override
  String get viewFolder => 'Ver carpeta';

  @override
  String get processAnother => 'Procesar otro';

  @override
  String get shareFile => 'Compartir';

  @override
  String get openFile => 'Abrir';

  @override
  String get saveLocation => 'Guardado en';

  @override
  String get privacyNotice => 'Todo el procesamiento ocurre en tu dispositivo. No se sube ningún dato.';

  @override
  String get renameFile => 'Renombrar archivo';

  @override
  String get newFileName => 'Nuevo nombre de archivo';

  @override
  String get changeOutputFolder => 'Cambiar carpeta de salida';

  @override
  String get useDefaultFolder => 'Restablecer predeterminado';

  @override
  String get defaultSaveFolder => 'Carpeta predeterminada: Almacenamiento/CompressX/';

  @override
  String get permissions => 'Permisos';

  @override
  String get noOutputYet => 'Los resultados aparecerán aquí tras el procesamiento.';

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
  String get removeWatermark => 'Eliminar marca de agua';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get contactUs => 'Contacto / Comentarios';

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
