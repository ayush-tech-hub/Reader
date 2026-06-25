import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opendocs_manager/core/utils/result.dart';
import 'package:opendocs_manager/features/pdf_reader/domain/entities/reader_entities.dart';
import 'package:opendocs_manager/features/pdf_reader/domain/repositories/pdf_reader_repository.dart';
import 'package:opendocs_manager/features/pdf_reader/domain/usecases/reader_usecases.dart';

class _MockRepository extends Mock implements PdfReaderRepository {}

void main() {
  late _MockRepository repository;
  late ToggleBookmark toggleBookmark;

  const documentPath = '/docs/sample.pdf';

  setUpAll(() {
    registerFallbackValue(
      Bookmark(documentPath: documentPath, page: 1, createdAt: DateTime(2026)),
    );
  });

  setUp(() {
    repository = _MockRepository();
    toggleBookmark = ToggleBookmark(repository);
  });

  test('adds a bookmark when the page is not bookmarked', () async {
    when(
      () => repository.getBookmarks(documentPath),
    ).thenAnswer((_) async => const Ok([]));
    when(() => repository.addBookmark(any())).thenAnswer(
      (invocation) async =>
          Ok(invocation.positionalArguments.single as Bookmark),
    );

    final result = await toggleBookmark(documentPath: documentPath, page: 7);

    expect(result.valueOrNull, isTrue);
    verify(() => repository.addBookmark(any())).called(1);
  });

  test('removes the bookmark when the page is already bookmarked', () async {
    final existing = Bookmark(
      id: 42,
      documentPath: documentPath,
      page: 7,
      createdAt: DateTime(2026),
    );
    when(
      () => repository.getBookmarks(documentPath),
    ).thenAnswer((_) async => Ok([existing]));
    when(
      () => repository.removeBookmark(42),
    ).thenAnswer((_) async => const Ok(null));

    final result = await toggleBookmark(documentPath: documentPath, page: 7);

    expect(result.valueOrNull, isFalse);
    verify(() => repository.removeBookmark(42)).called(1);
    verifyNever(() => repository.addBookmark(any()));
  });
}
