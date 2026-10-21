import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in the platform handler (mail app, dialer). Returns false when
/// nothing could handle it. Widget tests override [uriLauncherProvider] with a
/// fake so no platform channel is touched.
typedef UriLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) => launchUrl(uri);

final uriLauncherProvider = Provider<UriLauncher>((ref) => _defaultLauncher);

/// `mailto:` link for [email]. Returns null when [email] is blank.
Uri? supportMailtoUri(String? email, {String? subject}) {
  final address = email?.trim();
  if (address == null || address.isEmpty) return null;
  return Uri(
    scheme: 'mailto',
    path: address,
    query: subject == null || subject.trim().isEmpty
        ? null
        : 'subject=${Uri.encodeComponent(subject.trim())}',
  );
}

/// `tel:` link for [phone] (spaces and punctuation removed, a leading + kept).
/// Returns null when [phone] has no digits.
Uri? supportTelUri(String? phone) {
  final raw = phone?.trim() ?? '';
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return Uri(scheme: 'tel', path: raw.startsWith('+') ? '+$digits' : digits);
}
