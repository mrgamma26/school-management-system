import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Closes a form page after saving or cancelling.
///
/// A form opened from a list is pushed, so it pops back to that list. A form
/// opened by a dashboard quick action or typed address replaces the page
/// (`go`), leaving nothing to pop; popping then leaves a blank screen, so it
/// goes to [fallback] instead.
void closeForm(BuildContext context, String fallback, [Object? result]) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop(result);
    return;
  }
  GoRouter.maybeOf(context)?.go(fallback);
}
