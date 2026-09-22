import 'dart:developer' as developer;
import '../../../core/database/supabase_client.dart';
import '../domain/models/notification_model.dart';
import '../domain/models/teacher_comment.dart';
import '../domain/models/calendar_event.dart';

/// Data access for all communication tables:
/// [notification], [teachercomment] and [calendarevent].
class CommunicationsRepository {
  // ─────────────────────────────────────────────
  // Notifications
  // ─────────────────────────────────────────────

  /// Returns notifications sent to a specific guardian, newest first.
  Future<List<NotificationModel>> notificationsForGuardian(
    String guardianId,
  ) async {
    final rows = await supabase
        .from('notification')
        .select('*, staff!sentby(firstname, lastname)')
        .eq('guardianid', guardianId)
        .order('createdat', ascending: false);
    return rows.map((r) => NotificationModel.fromJson(r)).toList();
  }

  /// Returns all notifications sent by a staff member, newest first.
  Future<List<NotificationModel>> notificationsSentBy(String staffId) async {
    final rows = await supabase
        .from('notification')
        .select('*, guardian(firstname, lastname)')
        .eq('sentby', staffId)
        .order('createdat', ascending: false);
    return rows.map((r) => NotificationModel.fromJson(r)).toList();
  }

  /// Returns all notifications (for privileged roles — head teacher, admin).
  Future<List<NotificationModel>> allNotifications() async {
    final rows = await supabase
        .from('notification')
        .select(
          '*, guardian(firstname, lastname), staff!sentby(firstname, lastname)',
        )
        .order('createdat', ascending: false);
    return rows.map((r) => NotificationModel.fromJson(r)).toList();
  }

  /// Sends a notification to a guardian.
  /// If email delivery is enabled, calls the Edge Function to send email.
  Future<String> sendNotification({
    required String guardianId,
    required String staffId,
    required String subject,
    required String message,
    bool sendEmail = false,
  }) async {
    // Insert notification with appropriate email status
    final row = await supabase
        .from('notification')
        .insert({
          'guardianid': guardianId,
          'sentby': staffId,
          'subject': subject,
          'message': message,
          'emailstatus': sendEmail ? 'PENDING' : 'NOT_APPLICABLE',
          'readstatus': 'UNREAD',
          'sentat': DateTime.now().toIso8601String(),
        })
        .select('notificationid')
        .single();

    final notificationId = row['notificationid'] as String;

    // If email should be sent, trigger the Edge Function
    if (sendEmail) {
      try {
        // Fetch guardian and staff details
        final guardianData = await supabase
            .from('guardian')
            .select('firstname, lastname, email')
            .eq('guardianid', guardianId)
            .single();

        final staffData = await supabase
            .from('staff')
            .select('firstname, lastname')
            .eq('staffid', staffId)
            .single();

        final guardianName =
            '${guardianData['firstname']} ${guardianData['lastname']}';
        final senderName = '${staffData['firstname']} ${staffData['lastname']}';
        final guardianEmail = guardianData['email'] as String;

        // Call Edge Function
        final response = await supabase.functions.invoke(
          'send-notification-email',
          body: {
            'notificationId': notificationId,
            'guardianEmail': guardianEmail,
            'guardianName': guardianName,
            'subject': subject,
            'message': message,
            'senderName': senderName,
          },
        );

        // Note: Edge Function handles updating emailstatus to SENT or FAILED
        if (response.status != 200) {
          developer.log(
            'Email delivery warning',
            name: 'CommunicationsRepository',
            error: response.data,
          );
        }
      } catch (e) {
        // Log error but don't fail the notification creation
        developer.log(
          'Error triggering email',
          name: 'CommunicationsRepository',
          error: e,
        );
        // Update status to FAILED
        await supabase
            .from('notification')
            .update({'emailstatus': 'FAILED'})
            .eq('notificationid', notificationId);
      }
    }

    return notificationId;
  }

  /// Marks a notification as read (called by the guardian).
  Future<void> markRead(String notificationId) async {
    await supabase
        .from('notification')
        .update({
          'readstatus': 'READ',
          'readat': DateTime.now().toIso8601String(),
        })
        .eq('notificationid', notificationId);
  }

  // ─────────────────────────────────────────────
  // Teacher Comments
  // ─────────────────────────────────────────────

  /// Returns all teacher comments for a student, newest first.
  Future<List<TeacherComment>> commentsForStudent(String studentId) async {
    final rows = await supabase
        .from('teachercomment')
        .select(
          '*, staff(firstname, lastname), academicyear(academicyear, term)',
        )
        .eq('studentid', studentId)
        .order('createdat', ascending: false);
    return rows.map((r) => TeacherComment.fromJson(r)).toList();
  }

  /// Returns comments written by a specific teacher for an academic year.
  Future<List<TeacherComment>> commentsByTeacher({
    required String staffId,
    required String academicYearId,
  }) async {
    final rows = await supabase
        .from('teachercomment')
        .select('*, student(firstname, lastname)')
        .eq('staffid', staffId)
        .eq('academicyearid', academicYearId)
        .order('createdat');
    return rows.map((r) => TeacherComment.fromJson(r)).toList();
  }

  /// Creates or updates the comment for a student+teacher+year combination.
  Future<void> saveComment({
    required String studentId,
    required String staffId,
    required String academicYearId,
    required String comment,
  }) async {
    if (comment.trim().isEmpty) {
      throw ArgumentError('Comment text cannot be empty.');
    }

    final existing = await supabase
        .from('teachercomment')
        .select('commentid')
        .eq('studentid', studentId)
        .eq('staffid', staffId)
        .eq('academicyearid', academicYearId)
        .maybeSingle();

    final data = {
      'studentid': studentId,
      'staffid': staffId,
      'academicyearid': academicYearId,
      'comment': comment.trim(),
    };

    if (existing == null) {
      await supabase.from('teachercomment').insert(data);
    } else {
      await supabase
          .from('teachercomment')
          .update({'comment': comment.trim()})
          .eq('commentid', existing['commentid']);
    }
  }

  /// Alias used by [TeacherCommentPage] — same as [saveComment].
  Future<void> upsertComment({
    required String studentId,
    required String staffId,
    required String academicYearId,
    required String comment,
  }) => saveComment(
    studentId: studentId,
    staffId: staffId,
    academicYearId: academicYearId,
    comment: comment,
  );

  /// Returns the existing comment for a student+teacher+year, or null.
  Future<Map<String, dynamic>?> getComment({
    required String staffId,
    required String studentId,
    required String academicYearId,
  }) async {
    return supabase
        .from('teachercomment')
        .select('commentid, comment')
        .eq('studentid', studentId)
        .eq('staffid', staffId)
        .eq('academicyearid', academicYearId)
        .maybeSingle();
  }

  /// Deletes a teacher comment.
  Future<void> deleteComment(String commentId) async {
    await supabase.from('teachercomment').delete().eq('commentid', commentId);
  }

  // ─────────────────────────────────────────────
  // Calendar Events
  // ─────────────────────────────────────────────

  /// Returns upcoming events (starttime >= now), optionally filtered by class.
  Future<List<CalendarEvent>> upcomingEvents({String? classId}) async {
    var query = supabase
        .from('calendarevent')
        .select('*, class(classname), staff!createdby(firstname, lastname)')
        .gte('starttime', DateTime.now().toIso8601String());

    if (classId != null) {
      query = query.or('classid.eq.$classId,classid.is.null');
    }

    final rows = await query.order('starttime');
    return rows.map((r) => CalendarEvent.fromJson(r)).toList();
  }

  /// Returns all events for an optional class filter.
  Future<List<CalendarEvent>> allEvents({String? classId}) async {
    var query = supabase
        .from('calendarevent')
        .select('*, class(classname), staff!createdby(firstname, lastname)');

    if (classId != null) {
      query = query.or('classid.eq.$classId,classid.is.null');
    }

    final rows = await query.order('starttime', ascending: false);
    return rows.map((r) => CalendarEvent.fromJson(r)).toList();
  }

  /// Creates a new calendar event.
  Future<String> createEvent({
    required String staffId,
    required String eventName,
    required String eventType,
    String? classId,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
      throw ArgumentError('End time must be after start time.');
    }
    final row = await supabase
        .from('calendarevent')
        .insert({
          'createdby': staffId,
          'classid': classId,
          'eventname': eventName,
          'eventtype': eventType,
          'description': description,
          'starttime': startTime.toIso8601String(),
          'endtime': endTime.toIso8601String(),
        })
        .select('eventid')
        .single();
    return row['eventid'] as String;
  }

  /// Updates a calendar event.
  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await supabase.from('calendarevent').update(data).eq('eventid', eventId);
  }

  /// Deletes a calendar event.
  Future<void> deleteEvent(String eventId) async {
    await supabase.from('calendarevent').delete().eq('eventid', eventId);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Returns the staffid for a given auth [userId].
  Future<String> staffIdForUser(String userId) async {
    final row = await supabase
        .from('staff')
        .select('staffid')
        .eq('userid', userId)
        .single();
    return row['staffid'] as String;
  }

  /// Returns the guardianid for a given auth [userId].
  Future<String> guardianIdForUser(String userId) async {
    final row = await supabase
        .from('guardian')
        .select('guardianid')
        .eq('userid', userId)
        .single();
    return row['guardianid'] as String;
  }
}
