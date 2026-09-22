import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/supabase_client.dart';
import 'app/app.dart';

/// Application entry point.
/// Run with: flutter run --dart-define-from-file=env/dev.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initSupabase();
  } catch (e) {
    developer.log(
      'WARNING: Supabase initialization failed. App continuing in offline mode.',
      name: 'main',
      error: e,
    );
    // App continues despite Supabase init failure - graceful degradation
  }

  runApp(const ProviderScope(child: SchoolApp()));
}
