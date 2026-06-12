import 'package:equatable/equatable.dart';

/// A document in the reading history.
class RecentDocument extends Equatable {
  const RecentDocument({
    required this.path,
    required this.name,
    required this.lastPage,
    required this.totalPages,
    required this.lastOpenedAt,
    this.zoom = 1.0,
    this.pinned = false,
  });

  final String path;
  final String name;
  final int lastPage;
  final int totalPages;
  final double zoom;
  final bool pinned;
  final DateTime lastOpenedAt;

  @override
  List<Object?> get props => [path, lastPage, totalPages, zoom, pinned];
}

class Bookmark extends Equatable {
  const Bookmark({
    this.id,
    required this.documentPath,
    required this.page,
    this.label = '',
    required this.createdAt,
  });

  final int? id;
  final String documentPath;
  final int page;
  final String label;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, documentPath, page, label];
}

enum AnnotationType { highlight, underline, strikeout, ink, note }

/// A point in PDF page coordinates (points, origin top-left).
class PagePoint extends Equatable {
  const PagePoint(this.x, this.y);
  final double x;
  final double y;

  @override
  List<Object?> get props => [x, y];
}

/// A rect in PDF page coordinates.
class PageRect extends Equatable {
  const PageRect(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  List<Object?> get props => [left, top, right, bottom];
}

/// An app-side annotation rendered as an overlay (the source PDF is
/// never modified; flattening is a pdf_tools operation).
class Annotation extends Equatable {
  const Annotation({
    this.id,
    required this.documentPath,
    required this.page,
    required this.type,
    required this.color,
    this.opacity = 1.0,
    this.strokeWidth = 2.0,
    this.rects = const [],
    this.strokes = const [],
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String documentPath;
  final int page;
  final AnnotationType type;

  /// ARGB color value.
  final int color;
  final double opacity;
  final double strokeWidth;

  /// Text-markup geometry (highlight/underline/strikeout) and note anchor.
  final List<PageRect> rects;

  /// Ink geometry: a list of strokes, each a list of points.
  final List<List<PagePoint>> strokes;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props =>
      [id, documentPath, page, type, color, rects, strokes, note];
}

/// An entry in the PDF's own outline (table of contents).
class TocItem extends Equatable {
  const TocItem({
    required this.title,
    required this.page,
    this.children = const [],
  });

  final String title;
  final int page;
  final List<TocItem> children;

  @override
  List<Object?> get props => [title, page, children];
}

/// A single text-search hit.
class SearchHit extends Equatable {
  const SearchHit({required this.page, required this.snippet});

  final int page;
  final String snippet;

  @override
  List<Object?> get props => [page, snippet];
}
