import '../database/supabase_client.dart';
import '../errors/app_exception.dart';

/// Maximum audit log rows fetched in a single load.
const int kAuditLogPageSize = 500;

/// Maps Supabase errors to [AppException].
AppException _mapException(Object error) {
  final text = error.toString();

  if (text.contains('permission') || text.contains('denied')) {
    return ForbiddenException('You do not have permission to view audit logs.');
  }

  if (text.contains('network') ||
      text.contains('SocketException') ||
      text.contains('Connection refused')) {
    return NetworkException(
      'Network error. Check your connection and try again.',
    );
  }

  return ServerException('Error loading audit logs. Please try again.');
}

/// Data access layer for audit logs.
/// Audit logs are append-only; only read operations are available here.
class AuditRepository {
  /// Lists recent audit log entries matching the optional filters.
  ///
  /// [action] — filter by action name (e.g., 'GRADE_CORRECTED')
  /// [tableName] — filter by affected table name
  /// [fromDate] — filter records from this date onwards (UTC)
  /// [toDate] — filter records up to this date (UTC)
  /// [limit] — maximum number of records to return (default: [kAuditLogPageSize])
  Future<List<Map<String, dynamic>>> listAuditLogs({
    String? action,
    String? tableName,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = kAuditLogPageSize,
  }) async {
    try {
      dynamic q = supabase
          .from('auditlog')
          .select(
            'auditid, action, tablename, recordid, actorrole, reason, '
            'previousvalue, newvalue, createdat, '
            'userid(username)',
          );

      if (action != null && action.isNotEmpty) {
        q = q.eq('action', action);
      }
      if (tableName != null && tableName.isNotEmpty) {
        q = q.eq('tablename', tableName);
      }
      if (fromDate != null) {
        q = q.gte('createdat', fromDate.toUtc().toIso8601String());
      }
      if (toDate != null) {
        q = q.lte('createdat', toDate.toUtc().toIso8601String());
      }

      q = q.order('createdat', ascending: false).limit(limit);

      final rows = await q;
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Gets distinct table names that have audit entries.
  /// Useful for populating filter dropdowns.
  Future<List<String>> listTablesWithAuditEntries() async {
    try {
      final rows = await supabase
          .from('auditlog')
          .select('tablename')
          .order('tablename', ascending: true)
          .limit(kAuditLogPageSize);
      // Deduplicate in Dart since .distinct() is not available
      final tables = (rows as List)
          .map((row) => (row as Map<String, dynamic>)['tablename'] as String)
          .toSet()
          .toList();
      tables.sort();
      return tables;
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Gets distinct action names that have been logged.
  /// Useful for populating filter dropdowns.
  Future<List<String>> listAuditActions() async {
    try {
      final rows = await supabase
          .from('auditlog')
          .select('action')
          .order('action', ascending: true)
          .limit(kAuditLogPageSize);
      // Deduplicate in Dart since .distinct() is not available
      final actions = (rows as List)
          .map((row) => (row as Map<String, dynamic>)['action'] as String)
          .toSet()
          .toList();
      actions.sort();
      return actions;
    } catch (e) {
      throw _mapException(e);
    }
  }
}
