import 'package:akshara_erp/core/utils/whatsapp_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA-C-013 — WhatsApp / wa.me channel BEHAVIOUR certification.
///
/// WhatsApp is, by GA design, a CLIENT-SIDE `wa.me` deep link — NOT the paid
/// Meta/WhatsApp Business API (see whatsapp_launcher.dart: the free deep link is
/// the chosen, permanent approach; promotional outreach is handled separately).
/// So there is NO missing "WhatsApp provider" to flag — this cert certifies the
/// deep-link channel behaviour itself:
///
///   recipient  → a stored phone in any common Indian format normalizes to the
///                full international `91XXXXXXXXXX` form wa.me requires,
///   template   → the prefilled message is URL-encoded so any text (spaces, &,
///                commas, ₹, newlines) survives into the link verbatim,
///   destination→ the correct `https://wa.me/<intl>?text=<encoded>` deep link is
///                built (the user reviews + sends from WhatsApp themselves).
///
/// INFRA-BLOCKED (honestly marked, NOT forced): the actual `launchUrl` hand-off
/// to the installed WhatsApp app (and the user tapping send) is a real
/// device/url_launcher leg that cannot run headless; only the pure URI the
/// channel hands to the OS is certified here. (Existing low-level coverage:
/// test/core/utils/whatsapp_launcher_test.dart.)

void main() {
  group('QA-C-013 WhatsApp channel — recipient normalization', () {
    test('bare 10-digit national number gets the +91 country code', () {
      expect(
        WhatsAppLauncher.normalizeInternational('9876543210'),
        '919876543210',
      );
    });

    test('leading national trunk 0 is dropped before prefixing +91', () {
      expect(
        WhatsAppLauncher.normalizeInternational('09876543210'),
        '919876543210',
      );
    });

    test('a number that already carries +91 is kept as-is', () {
      expect(
        WhatsAppLauncher.normalizeInternational('+91 98765 43210'),
        '919876543210',
      );
      expect(
        WhatsAppLauncher.normalizeInternational('919876543210'),
        '919876543210',
      );
    });

    test('non-dialable input (too short) is rejected so no link is built', () {
      expect(WhatsAppLauncher.normalizeInternational('12345'), isNull);
    });
  });

  group('QA-C-013 WhatsApp channel — deep-link destination', () {
    test('builds the wa.me link to the normalized recipient', () {
      final uri = WhatsAppLauncher.buildChatUri(
        phoneE164: '9876543210',
        message: 'Hello',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      // path is the FULL international number, never the bare 10-digit one
      // (wa.me cannot resolve a country-code-less number).
      expect(uri.path, '/919876543210');
    });

    test('a stored +91 contact resolves to the same wa.me destination', () {
      final uri = WhatsAppLauncher.buildChatUri(
        phoneE164: '+91 98765-43210',
        message: 'Results are out',
      );
      expect(uri.toString().startsWith('https://wa.me/919876543210?text='),
          isTrue);
    });
  });

  group('QA-C-013 WhatsApp channel — message URL-encoding', () {
    test('spaces, ampersand and comma are percent-encoded into the text param',
        () {
      final uri = WhatsAppLauncher.buildChatUri(
        phoneE164: '9876543210',
        message: 'Hello & welcome, results out!',
      );
      // space -> %20, & -> %26, comma -> %2C; '!' stays literal (unreserved).
      expect(
        uri.query,
        contains('text=Hello%20%26%20welcome%2C%20results%20out!'),
      );
    });

    test('a realistic templated message round-trips through encode/decode intact',
        () {
      const message =
          'NIKSHA: Fee receipt for Asha (Class 3A) — ₹4,200 received.\nOpen the app to view.';
      final uri = WhatsAppLauncher.buildChatUri(
        phoneE164: '9876543210',
        message: message,
      );
      // The raw query carries the percent-encoded form (no literal spaces / ₹).
      final rawText = uri.query.substring('text='.length);
      expect(rawText.contains(' '), isFalse);
      // Decoding the text param recovers the exact prefilled message — the
      // channel does not mangle or truncate the template body.
      expect(Uri.decodeComponent(rawText), message);
    });
  });
}
