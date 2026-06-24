import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phase-1 WhatsApp deep-link helper (no Business API).
///
/// Opens the native WhatsApp app at a `wa.me/<international-number>?text=<prefill>`
/// link. This is a pure deep link — the user reviews and sends the message
/// themselves, so it needs no Meta Business API, no template approval and no
/// per-message cost. This free deep-link is the chosen, permanent WhatsApp
/// approach: the paid Meta/WhatsApp Business API is intentionally NOT used.
/// (Promotional outreach is handled separately via social media.)
///
/// Used across roles wherever a contact's phone is shown (teacher→parent,
/// principal/HR→staff, parent→class-teacher); prefer `WhatsAppContactButton`
/// over calling this directly so behaviour stays consistent.
abstract final class WhatsAppLauncher {
  /// Default country calling code prepended to bare national numbers.
  /// India (+91); the app is single-region. Override per call if needed.
  static const String defaultCountryCode = '91';

  /// Returns the digit-only form if [input] looks like a usable phone number
  /// (>= 10 digits after stripping symbols), else null. Use as a validity gate
  /// before showing a "contact" affordance.
  static String? resolvePhoneDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return null;
    return digits;
  }

  /// Normalises [input] to the international digit string `wa.me` requires.
  ///
  /// - bare 10-digit national number  -> prefix [countryCode] (9876543210 -> 919876543210)
  /// - leading national trunk `0`     -> dropped before prefixing (09876543210 -> 919876543210)
  /// - already includes a country code (11–15 digits) -> kept as-is
  /// - fewer than 10 digits           -> null (not dialable)
  ///
  /// Without this, a 10-digit number produces `wa.me/9876543210`, which WhatsApp
  /// cannot resolve (it requires the full international number).
  static String? normalizeInternational(
    String input, {
    String countryCode = defaultCountryCode,
  }) {
    var digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) return '$countryCode$digits';
    if (digits.length >= 11 && digits.length <= 15) return digits;
    return null;
  }

  static Uri buildChatUri({
    required String phoneE164,
    required String message,
    String countryCode = defaultCountryCode,
  }) {
    final intl = normalizeInternational(phoneE164, countryCode: countryCode) ??
        phoneE164.replaceAll(RegExp(r'[^\d]'), '');
    final encoded = Uri.encodeComponent(message);
    return Uri.parse('https://wa.me/$intl?text=$encoded');
  }

  static Future<bool> openChat({
    required String phoneE164,
    required String message,
    String countryCode = defaultCountryCode,
  }) async {
    final uri = buildChatUri(
      phoneE164: phoneE164,
      message: message,
      countryCode: countryCode,
    );
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
