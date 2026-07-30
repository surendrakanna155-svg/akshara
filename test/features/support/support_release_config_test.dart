import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P0 root cause: `supportRepositoryProvider` switches to the real
/// `/support` API only when `SUPPORT_API_ENABLED` is defined, and that key was
/// simply MISSING from config/live_release.json — the one file
/// scripts/build_release.sh feeds to `--dart-define-from-file`. Every shipping
/// build therefore ran the in-memory mock and threw reports away.
///
/// A missing key is invisible in review, so it gets a test.
void main() {
  test('config/live_release.json enables the live support channel', () {
    final file = File('config/live_release.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'scripts/build_release.sh consumes this exact path',
    );

    final config =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    expect(
      config.containsKey('SUPPORT_API_ENABLED'),
      isTrue,
      reason: 'without this key release builds fall back to '
          'MockSupportRepository and "Report an issue" reaches nobody',
    );
    expect(config['SUPPORT_API_ENABLED'], isTrue);

    // The per-module flags are all short-circuited by ENABLE_API_MODE, so the
    // support flag is only meaningful alongside it.
    expect(config['ENABLE_API_MODE'], isTrue);
  });
}
