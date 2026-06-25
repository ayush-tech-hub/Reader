import 'package:equatable/equatable.dart';

/// An inclusive 1-based page range.
class PageRange extends Equatable {
  const PageRange(this.start, this.end)
      : assert(start >= 1 && end >= start, 'invalid range');

  final int start;
  final int end;

  @override
  List<Object?> get props => [start, end];
}

enum WatermarkPosition { center, topLeft, topRight, bottomLeft, bottomRight }

class WatermarkSpec extends Equatable {
  const WatermarkSpec({
    required this.text,
    this.fontSize = 48,
    this.opacity = 0.25,
    this.rotationDegrees = 45,
    this.color = 0xFF888888,
    this.position = WatermarkPosition.center,
  });

  final String text;
  final double fontSize;
  final double opacity;
  final double rotationDegrees;
  final int color;
  final WatermarkPosition position;

  @override
  List<Object?> get props => [text, fontSize, opacity, rotationDegrees, color];
}

class PdfMetadata extends Equatable {
  const PdfMetadata({
    this.title = '',
    this.author = '',
    this.subject = '',
    this.keywords = '',
    this.creator = '',
    this.producer = '',
  });

  final String title;
  final String author;
  final String subject;
  final String keywords;
  final String creator;
  final String producer;

  Map<String, String> toMap() => {
        'title': title,
        'author': author,
        'subject': subject,
        'keywords': keywords,
        'creator': creator,
        'producer': producer,
      };

  factory PdfMetadata.fromMap(Map<dynamic, dynamic> map) => PdfMetadata(
        title: (map['title'] as String?) ?? '',
        author: (map['author'] as String?) ?? '',
        subject: (map['subject'] as String?) ?? '',
        keywords: (map['keywords'] as String?) ?? '',
        creator: (map['creator'] as String?) ?? '',
        producer: (map['producer'] as String?) ?? '',
      );

  @override
  List<Object?> get props => [
        title,
        author,
        subject,
        keywords,
        creator,
        producer,
      ];
}

enum CompressionQuality { low, medium, high }

class PdfEncryptSpec extends Equatable {
  const PdfEncryptSpec({
    required this.userPassword,
    this.ownerPassword = '',
    this.allowPrinting = true,
    this.allowCopying = false,
    this.allowEditing = false,
    this.allowAnnotating = true,
  });

  final String userPassword;
  final String ownerPassword;
  final bool allowPrinting;
  final bool allowCopying;
  final bool allowEditing;
  final bool allowAnnotating;

  @override
  List<Object?> get props => [
        userPassword,
        ownerPassword,
        allowPrinting,
        allowCopying,
        allowEditing,
        allowAnnotating,
      ];
}
