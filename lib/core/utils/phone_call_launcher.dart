import 'package:url_launcher/url_launcher.dart';

/// Opens the native dialer at a `tel:` link for a contact's phone.
///
/// A thin, consistent wrapper over `url_launcher` (mirrors [WhatsAppLauncher]):
/// validate the number, then hand off to the OS dialer. The user places the
/// call themselves — no telephony permission is required.
abstract final class PhoneCallLauncher {
  /// Returns the digit-only form if [input] looks dialable (>= 10 digits after
  /// stripping symbols), else null. Use as a validity gate before showing a
  /// "call" affordance so a dead control is never rendered.
  static String? resolvePhoneDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    final bare = digits.replaceAll('+', '');
    if (bare.length < 10) return null;
    return digits;
  }

  static Uri buildDialUri(String input) {
    final digits = resolvePhoneDigits(input) ??
        input.replaceAll(RegExp(r'[^\d+]'), '');
    return Uri(scheme: 'tel', path: digits);
  }

  /// Opens the dialer; returns false when there is no dialable number or the
  /// platform cannot launch the `tel:` scheme.
  static Future<bool> dial(String input) async {
    if (resolvePhoneDigits(input) == null) return false;
    final uri = buildDialUri(input);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
