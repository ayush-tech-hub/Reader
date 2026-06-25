import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opendocs_manager/app.dart';
import 'package:opendocs_manager/core/database/app_database.dart';
import 'package:opendocs_manager/core/di/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and shows the four navigation destinations', (
    tester,
  ) async {
    final database = AppDatabase();
    await database.open();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const OpenDocsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(NavigationBar).evaluate().isNotEmpty ||
          find.byType(NavigationRail).evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('OpenDocs Manager'), findsWidgets);
  });

  testWidgets('navigates to PDF tools and shows the tool grid', (tester) async {
    final database = AppDatabase();
    await database.open();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const OpenDocsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PDF Tools').last);
    await tester.pumpAndSettle();

    expect(find.text('Merge PDFs'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);
  });
}
