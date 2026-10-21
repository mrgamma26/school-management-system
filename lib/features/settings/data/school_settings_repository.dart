import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/school_settings.dart';

class SchoolSettingsRepository {
  static const _settingsId = '00000000-0000-0000-0000-000000000001';

  Future<SchoolBranding> loadPublicBranding() async {
    try {
      final rows = await supabase.rpc('get_public_school_branding');
      final list = List<Map<String, dynamic>>.from(rows as List);
      return list.isEmpty
          ? const SchoolBranding(schoolName: 'School Management System')
          : SchoolBranding.fromJson(list.first);
    } catch (_) {
      return const SchoolBranding(schoolName: 'School Management System');
    }
  }

  Future<SchoolSettings> loadSettings() async {
    try {
      final row = await supabase
          .from('school_settings')
          .select()
          .eq('settings_id', _settingsId)
          .single();
      return SchoolSettings.fromJson(row);
    } catch (error) {
      throw ServerException('Could not load school settings: $error');
    }
  }

  Future<void> updateSettings(SchoolSettings settings, String userId) async {
    try {
      await supabase.from('school_settings').upsert({
        'settings_id': _settingsId,
        ...settings.toUpdateJson(userId),
      }, onConflict: 'settings_id');
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const ForbiddenException(
          'Only an Administrator or Super User can update school settings.',
        );
      }
      throw ValidationException(error.message);
    }
  }

  Future<String> uploadLogo({
    required Uint8List bytes,
    required String extension,
    required String mimeType,
  }) async {
    final path = 'school-logo.${extension.toLowerCase()}';
    await supabase.storage
        .from('school-branding')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return path;
  }

  String? publicLogoUrl(String? logoPath) {
    if (logoPath == null || logoPath.trim().isEmpty) return null;
    return supabase.storage.from('school-branding').getPublicUrl(logoPath);
  }

  Future<Uint8List?> downloadLogo(String? logoPath) async {
    if (logoPath == null || logoPath.trim().isEmpty) return null;
    try {
      return await supabase.storage.from('school-branding').download(logoPath);
    } catch (_) {
      return null;
    }
  }
}
