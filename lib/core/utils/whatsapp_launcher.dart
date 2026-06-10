import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phase-1 WhatsApp deep-link helper (no Business API).
abstract final class WhatsAppLauncher {
  static String? resolvePhoneDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return null;
    return digits;
  }

  static Uri buildChatUri({
    required String phoneE164,
    required String message,
  }) {
    final digits = phoneE164.replaceAll(RegExp(r'[^\d]'), '');
    final encoded = Uri.encodeComponent(message);
    return Uri.parse('https://wa.me/$digits?text=$encoded');
  }

  static Future<bool> openChat({
    required String phoneE164,
    required String message,
  }) async {
    final uri = buildChatUri(phoneE164: phoneE164, message: message);
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
