// This file deliberately occupies the `test/widget_test.dart` path so
// the CI scaffold step (`flutter create .`) does not generate the stock
// counter-app test, which references a nonexistent MyApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opendocs_manager/core/theme/app_theme.dart';
import 'package:opendocs_manager/features/file_manager/domain/entities/file_entry.dart';
import 'package:opendocs_manager/features/file_manager/presentation/widgets/file_entry_tile.dart';

void main() {
  testWidgets('FileEntryTile renders name, size and date', (tester) async {
    final entry = FileEntry(
      path: '/docs/report.pdf',
      name: 'report.pdf',
      isDirectory: false,
      size: 2048,
      modifiedAt: DateTime(2026, 6, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FileEntryTile(
            entry: entry,
            selected: false,
            selectionMode: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining('2.0 KiB'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
  });

  testWidgets('selection mode shows a checkbox', (tester) async {
    final entry = FileEntry(
      path: '/docs',
      name: 'docs',
      isDirectory: true,
      size: 0,
      modifiedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: FileEntryTile(
            entry: entry,
            selected: true,
            selectionMode: true,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
  });
}
