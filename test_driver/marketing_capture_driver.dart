// Host-side driver for the marketing screenshot pipeline.
//
//   flutter drive \
//     --driver=test_driver/marketing_capture_driver.dart \
//     --target=integration_test/marketing_capture_test.dart \
//     -d emulator-5554 --profile
//
// Patrol cannot do this. `patrol_test/helpers/patrol_helpers.dart`'s
// `capturePatrolScreenshot` returns early on Android/iOS and writes a `.marker`
// file — it records screenshot *intent* for regression tooling and never
// produces an image. The `patrol` package exposes no screenshot API at all.
//
// `integration_test` does: the on-device test calls `binding.takeScreenshot()`,
// which ships the bytes over the driver channel to this host process, which is
// the only side that can write to the repository. Navigation still uses
// `patrol_finders` (see the target file) — we keep Patrol's ergonomics and add
// the capture capability it lacks.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Where captures land before review. Git-ignored; promoted by hand into
/// `deploy/nikshaos/src/product-shots/` only after the §6.5 hygiene review.
const String kOutputDir = 'build/marketing-capture';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final file = File('$kOutputDir/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      stdout.writeln('captured: ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
