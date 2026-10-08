import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialises the Supabase client from dart-define environment variables.
/// Run with: flutter run --dart-define-from-file=env/dev.json
///
/// Has a 10-second timeout to prevent hanging on slow/unreachable networks.
Future<void> initSupabase() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be defined.\n'
      'Run: flutter run --dart-define-from-file=env/dev.json',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  ).timeout(const Duration(seconds: 10));
}

/// Global Supabase client accessor.
final supabase = Supabase.instance.client;
