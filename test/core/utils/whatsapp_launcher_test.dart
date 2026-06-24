import 'package:akshara_erp/core/utils/whatsapp_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhatsAppLauncher.resolvePhoneDigits', () {
    test('strips symbols and keeps >= 10 digit numbers', () {
      expect(WhatsAppLauncher.resolvePhoneDigits('+91 98765-43210'), '919876543210');
      expect(WhatsAppLauncher.resolvePhoneDigits('9876543210'), '9876543210');
    });
    test('rejects too-short input', () {
      expect(WhatsAppLauncher.resolvePhoneDigits('12345'), isNull);
      expect(WhatsAppLauncher.resolvePhoneDigits(''), isNull);
    });
  });

  group('WhatsAppLauncher.normalizeInternational', () {
    test('prefixes default country code for bare 10-digit numbers', () {
      expect(WhatsAppLauncher.normalizeInternational('9876543210'), '919876543210');
    });
    test('drops national trunk 0 then prefixes country code', () {
      expect(WhatsAppLauncher.normalizeInternational('09876543210'), '919876543210');
    });
    test('keeps numbers that already include a country code', () {
      expect(WhatsAppLauncher.normalizeInternational('+91 98765 43210'), '919876543210');
      expect(WhatsAppLauncher.normalizeInternational('919876543210'), '919876543210');
    });
    test('honours a custom country code', () {
      expect(
        WhatsAppLauncher.normalizeInternational('5551234567', countryCode: '1'),
        '15551234567',
      );
    });
    test('returns null for non-dialable input', () {
      expect(WhatsAppLauncher.normalizeInternational('123'), isNull);
    });
  });

  group('WhatsAppLauncher.buildChatUri', () {
    test('builds wa.me link with country code and url-encoded message', () {
      final uri = WhatsAppLauncher.buildChatUri(
        phoneE164: '9876543210',
        message: 'Hello & welcome, results out!',
      );
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      // message is percent-encoded (space -> %20, & -> %26, comma -> %2C;
      // '!' stays literal — it is in encodeComponent's unreserved set).
      expect(uri.query, contains('text=Hello%20%26%20welcome%2C%20results%20out!'));
    });

    test('a 10-digit number never produces a country-code-less wa.me link', () {
      final uri = WhatsAppLauncher.buildChatUri(
        phoneE164: '8888812345',
        message: 'hi',
      );
      expect(uri.toString().startsWith('https://wa.me/918888812345?text='), isTrue);
    });
  });
}
