import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Message to show after a failed RPC call.
///
/// The review/finance RPCs raise readable business-rule messages
/// (SQLSTATE P0001, e.g. "Correction request is missing or already decided").
/// Those are safe to show as they are; everything else falls back to
/// [friendlyError] so database internals never reach the screen.
String rpcErrorMessage(Object error) {
  if (error is PostgrestException && error.code == 'P0001') {
    final message = error.message.trim();
    if (message.isNotEmpty) return message;
  }
  return friendlyError(error);
}
