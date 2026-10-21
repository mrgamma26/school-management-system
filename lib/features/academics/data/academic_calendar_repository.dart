import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/academic_calendar.dart';

class AcademicCalendarRepository {
  static const _select =
      '''academic_year_id, name, start_date, end_date, status, is_current,
    academic_year_terms(academic_year_term_id, start_date, end_date, is_current,
      term_definitions(code, name, sequence))''';

  Future<List<AcademicCalendarYear>> listYears() async {
    try {
      final rows = await supabase
          .from('school_academic_years')
          .select(_select)
          .order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(AcademicCalendarYear.fromJson).toList();
    } catch (error) {
      throw ServerException('Could not load academic years: $error');
    }
  }

  Future<AcademicCalendarYear?> currentYear() async {
    final row = await supabase
        .from('school_academic_years')
        .select(_select)
        .eq('is_current', true)
        .maybeSingle();
    return row == null ? null : AcademicCalendarYear.fromJson(row);
  }

  Future<String> saveYear({
    String? id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required List<AcademicTermDraft> terms,
    required bool makeCurrent,
  }) async {
    try {
      final result = await supabase.rpc(
        'save_academic_year',
        params: {
          'p_academic_year_id': id,
          'p_name': name.trim(),
          'p_start_date': _date(startDate),
          'p_end_date': _date(endDate),
          'p_terms': terms.map((term) => term.toJson()).toList(),
          'p_make_current': makeCurrent,
        },
      );
      return result as String;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw const ForbiddenException(
          'Only an Administrator or Super User can manage academic years.',
        );
      }
      throw ValidationException(error.message);
    }
  }

  Future<void> activateYear(String id) => supabase.rpc(
    'activate_academic_year',
    params: {'p_academic_year_id': id},
  );

  Future<void> setCurrentTerm(String id) => supabase.rpc(
    'set_current_academic_term',
    params: {'p_academic_year_term_id': id},
  );

  static String _date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
}
