// Guard: no pre-rename "Akshara" branding may reach a user-visible surface.
//
// The product ships as NIKSHA OS (see `lib/core/constants/app_constants.dart`).
// A branding sweep removed the residue once; this test is what stops it coming
// back one string at a time. Every wave in this project is expected to ship a
// guard rather than fix instances — this is that guard.
//
// ---------------------------------------------------------------------------
// What this checks, and why it is spelled this way
// ---------------------------------------------------------------------------
// Brand text is capital-`Akshara` followed by a NON-identifier character:
//
//     'Akshara Public School'   -> brand text     (followed by a space)
//     'Unlock Akshara'          -> brand text     (followed by a quote)
//     AksharaSpacing.s4         -> IDENTIFIER     (followed by 'S')
//     package:akshara_erp/...   -> IDENTIFIER     (lowercase)
//
// That single distinction does almost all the work here: every dangerous
// identifier in this repository is either lowercase or immediately followed by
// an uppercase letter, and no user-visible string is either.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Brand text: `Akshara` NOT followed by an identifier character.
///
/// The trailing character class is what separates 'Akshara ' (brand) from
/// 'AksharaSpacing' (a design-system class).
final RegExp _brandText = RegExp(r'Akshara(?![A-Za-z0-9_])');

/// All-caps brand text, e.g. a WhatsApp sender id or a PDF header.
final RegExp _brandTextCaps = RegExp(r'AKSHARA(?![A-Z0-9_])');

/// Lines that are allowed to keep the old name, each for a stated reason.
///
/// These are NOT cosmetic exemptions — every one of them would break something
/// real if renamed. Add to this list only with the same standard of proof.
const Map<String, String> _allowed = {
  // A Play Store package id can never change after the first upload, and it is
  // never shown to a user. Recorded in app_constants.dart.
  'com.akshara.erp': 'Android package id — immutable after first Play upload',

  // Renaming orphans every user's persisted value.
  'akshara_subscription_v1': 'persisted entitlement storage key',
  'akshara_exam_admin_v1': 'persisted exam-administration storage key',
  'akshara_school_configuration_v1': 'persisted school-configuration key',
  'akshara_exam_results_sync_v1': 'persisted results-sync key',
  'akshara_reliability.db': 'on-device SQLCipher database filename',

  // Wire contract with the backend; renaming breaks cache negotiation.
  'X-Akshara-Offline-Cache': 'HTTP header — client/server contract',

  // Seeded tenant identifiers; they match rows that already exist.
  'school_akshara_001': 'seeded tenant id',
  'org_akshara_001': 'seeded organization id',

  // Real infrastructure, not branding.
  'akshara-erp.firebasestorage.app': 'Firebase storage bucket',
  'aksharaerp.com': 'staging API hostname',

  // Registered with the WhatsApp provider. Renaming unilaterally breaks
  // template resolution until the provider-side registration is changed too.
  'AksharaERP': 'WhatsApp templateNamespace — external provider registration',

  // The one place the retired name legitimately belongs: the constant that
  // records the rename. Removing it here would erase the reason the rest of
  // this file exists.
  'The former "Akshara ERP" name': 'historical record of the rename itself',
};

bool _isAllowed(String line) =>
    _allowed.keys.any(line.contains) ||
    // `akshara-edge`, `akshara-stub`, … are AI provider ids persisted in
    // response caches and asserted by backend tests.
    RegExp(r"'akshara-(edge|stub|inference|education-pdf)").hasMatch(line);

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  group('NIKSHA branding guard', () {
    test('no user-visible "Akshara" branding remains in lib/', () {
      final offenders = <String>[];

      for (final file in _dartFiles('lib')) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!_brandText.hasMatch(line) && !_brandTextCaps.hasMatch(line)) {
            continue;
          }
          if (_isAllowed(line)) continue;
          offenders.add('${file.path}:${i + 1}\n    ${line.trim()}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'The product ships as NIKSHA OS. These lines still carry the '
            'pre-rename brand on a user-visible surface:\n\n'
            '${offenders.join('\n')}\n\n'
            'Fix the string. If the occurrence genuinely cannot be renamed '
            '(a persisted key, a wire contract, an external registration), add '
            'it to _allowed in this file WITH the reason — never silence it by '
            'loosening the pattern.',
      );
    });

    test('the app still names itself NIKSHA OS', () {
      // Cheap canary: if someone reverts app_constants, every other surface is
      // suspect too.
      final constants =
          File('lib/core/constants/app_constants.dart').readAsStringSync();
      expect(constants, contains("appName = 'NIKSHA OS'"));
      expect(constants, contains("companyName = 'NIKSHA Technologies"));
    });
  });
}
