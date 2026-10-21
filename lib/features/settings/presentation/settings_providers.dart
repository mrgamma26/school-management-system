import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/school_settings_repository.dart';
import '../domain/school_settings.dart';

final schoolSettingsRepositoryProvider = Provider<SchoolSettingsRepository>(
  (ref) => SchoolSettingsRepository(),
);

final schoolBrandingProvider = FutureProvider<SchoolBranding>((ref) {
  return ref.watch(schoolSettingsRepositoryProvider).loadPublicBranding();
});

final schoolSettingsProvider = FutureProvider<SchoolSettings>((ref) {
  return ref.watch(schoolSettingsRepositoryProvider).loadSettings();
});
