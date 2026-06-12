/// Data-layer exceptions. Repositories catch these and convert them to
/// domain [Failure]s — they must never escape the data layer.
sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class FileSystemException2 extends AppException {
  const FileSystemException2(super.message, [super.cause]);
}

class PdfOpenException extends AppException {
  const PdfOpenException(super.message, [super.cause]);
}

/// Thrown when a PDF requires a password (or it was wrong).
class PdfPasswordException extends AppException {
  const PdfPasswordException(super.message, [super.cause]);
}

class ArchiveException extends AppException {
  const ArchiveException(super.message, [super.cause]);
}

class DatabaseException2 extends AppException {
  const DatabaseException2(super.message, [super.cause]);
}

class NativeEngineException extends AppException {
  const NativeEngineException(super.message, [super.cause]);
}
