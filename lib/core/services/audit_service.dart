import '../database/supabase_client.dart';

/// Records sensitive operations in the [auditlog] table.
///
/// Use this for account changes, grade corrections, progression decisions
/// and weeding decisions. Audit records are append-only — never delete them.
///
/// DB columns: auditid (bigserial), userid, recordid, actorrole,
///             action, tablename, previousvalue, newvalue, reason, createdat
class AuditService {
  /// Inserts one audit record.
  ///
  /// [userId]        — the systemuser.userid of the actor.
  /// [action]        — machine-readable action label e.g. 'GRADE_CORRECTED'.
  /// [tableName]     — the database table that was changed.
  /// [recordId]      — the primary key of the affected row (optional).
  /// [previousValue] — the row state before the change (optional).
  /// [newValue]      — the row state after the change (optional).
  /// [reason]        — human-readable justification (optional).
  /// [actorRole]     — role name of the actor (optional). Maps to `actorrole`.
  Future<void> log({
    required String userId,
    required String action,
    required String tableName,
    String? recordId,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
    String? reason,
    // Parameter kept as `actorRole`; old callers using `userType` need updating.
    String? actorRole,
  }) async {
    await supabase.from('auditlog').insert({
      'userid': userId,
      'recordid': recordId,
      'actorrole': actorRole, // DB column is `actorrole`, not `usertype`
      'action': action,
      'tablename': tableName,
      'previousvalue': previousValue,
      'newvalue': newValue,
      'reason': reason,
    });
  }
}
