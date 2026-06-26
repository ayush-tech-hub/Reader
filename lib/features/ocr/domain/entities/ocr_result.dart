import 'package:path/path.dart' as p;

/// Immutable value object representing the result of a single OCR job.
///
/// One [OcrResult] can span multiple pages (e.g. a multi-page PDF or a
/// batch of images).  Individual page texts are stored in [pageTexts]; use
/// [fullText] to get all pages joined with a visual separator.
class OcrResult {
  const OcrResult({
    required this.id,
    required this.sourcePath,
    required this.sourceType,
    required this.pageTexts,
    required this.createdAt,
    this.languageCode,
  });

  // ── Identity ──────────────────────────────────────────────────────────────

  /// Unique identifier: `'<millisecondsSinceEpoch>_<abs(sourcePath.hashCode)>'`
  final String id;

  // ── Source metadata ───────────────────────────────────────────────────────

  /// Absolute path to the file that was recognised, or an empty string for
  /// camera captures.
  final String sourcePath;

  /// One of `'pdf'`, `'image'`, `'camera'`, or `'batch'`.
  final String sourceType;

  // ── OCR payload ───────────────────────────────────────────────────────────

  /// Recognised text keyed by page index; one entry per page / image.
  final List<String> pageTexts;

  // ── Timestamps & locale ───────────────────────────────────────────────────

  final DateTime createdAt;

  /// BCP-47 language hint used during recognition, or `null` when the engine
  /// chose automatically.
  final String? languageCode;

  // ── Derived getters ───────────────────────────────────────────────────────

  /// All pages joined with a visible section separator.
  String get fullText => pageTexts.join('\n\n---\n\n');

  /// Number of pages / images that were recognised.
  int get pageCount => pageTexts.length;

  /// Approximate word count over the entire result.
  int get wordCount =>
      fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// Human-readable name for the source: the file's basename, or `'Camera'`
  /// when the source was a live camera capture.
  String get sourceFileName =>
      sourceType == 'camera' ? 'Camera' : p.basename(sourcePath);

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Converts this result to a flat map suitable for SQLite storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_path': sourcePath,
      'source_type': sourceType,
      // pageTexts is stored as a JSON array; the datasource encodes it.
      'page_texts': pageTexts,
      'created_at': createdAt.millisecondsSinceEpoch,
      'language_code': languageCode,
    };
  }

  /// Restores an [OcrResult] from a SQLite row map produced by [toMap].
  ///
  /// The `page_texts` value may arrive either as an already-decoded
  /// `List<dynamic>` (when the datasource decodes JSON before passing the
  /// map) or as a raw `List<String>` – both cases are handled.
  factory OcrResult.fromMap(Map<String, dynamic> map) {
    final rawPages = map['page_texts'];
    final List<String> pages;
    if (rawPages is List) {
      pages = rawPages.map((e) => e.toString()).toList();
    } else {
      pages = const [];
    }

    return OcrResult(
      id: map['id'] as String,
      sourcePath: map['source_path'] as String,
      sourceType: map['source_type'] as String,
      pageTexts: pages,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      languageCode: map['language_code'] as String?,
    );
  }

  /// Convenience constructor that generates a stable [id] and sets
  /// [createdAt] to [DateTime.now].
  factory OcrResult.generate({
    required String sourcePath,
    required String sourceType,
    required List<String> pageTexts,
    String? languageCode,
  }) {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${sourcePath.hashCode.abs()}';
    return OcrResult(
      id: id,
      sourcePath: sourcePath,
      sourceType: sourceType,
      pageTexts: pageTexts,
      createdAt: DateTime.now(),
      languageCode: languageCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OcrResult && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OcrResult(id: $id, sourceType: $sourceType, pages: $pageCount, '
      'words: $wordCount)';
}
