import 'package:equatable/equatable.dart';

/// Domain-layer failures, surfaced to presentation via [Result].
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class FileSystemFailure extends Failure {
  const FileSystemFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class PdfFailure extends Failure {
  const PdfFailure(super.message);
}

class PdfPasswordRequiredFailure extends Failure {
  const PdfPasswordRequiredFailure(super.message);
}

class ArchiveFailure extends Failure {
  const ArchiveFailure(super.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
