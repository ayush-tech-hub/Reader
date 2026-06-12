import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/di/providers.dart';
import 'features/readers/presentation/reader_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBuiltInPlugins();

  final database = AppDatabase();
  await database.open();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const OpenDocsApp(),
    ),
  );
}
