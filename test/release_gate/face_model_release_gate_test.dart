// Release gate — staff attendance face verification.
//
// REWRITTEN 2026-07-29. This gate previously required a MobileFaceNet `.tflite`
// to be bundled in `assets/models/`, because verification ran on-device. That
// architecture is retired: no clean commercially licensed mobile-size model
// exists (see docs/engineering/FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md), so
// the embedding is now derived SERVER-SIDE from an aligned crop.
//
// Leaving the old gate in place would have been worse than deleting it: it
// blocks release demanding a file the architecture deliberately does not have,
// and if someone "fixed" it by dropping in an unlicensed model it would wave
// through exactly the thing the survey exists to prevent.
//
// What is release-blocking NOW is the client half of the wire contract, which
// is what this file asserts. The server half — model present, detector
// enabled — is verified at deploy by the service healthcheck, and threshold
// calibration is an operational gate (FACE_THRESHOLD_CALIBRATION_PROCEDURE.md).
//
//     RELEASE_GATE=1 flutter test test/release_gate/
import 'dart:io';

import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the client sends a face CROP, never an embedding (release gate)', () {
    // The server refuses a request carrying an embedding or a model tag
    // (FACE_EMBEDDING_NOT_ACCEPTED). A build that still sent one would fail
    // every check-in in the field, so this is release-blocking.
    const capture = FaceCapture(
      cropBase64: 'Y3JvcC1ieXRlcw==',
      livenessPassed: true,
    );
    final json = capture.toJson();

    expect(json['crop'], isNotEmpty,
        reason: 'the aligned crop is what the server derives the embedding from');
    expect(json.containsKey('embedding'), isFalse,
        reason: 'a client-computed embedding is refused by the server — '
            'template forgery is the reason derivation moved server-side');
    expect(json.containsKey('modelTag'), isFalse,
        reason: 'the server stamps the model tag; a client cannot claim one');
  });

  test('no bundled face model is expected any more (release gate)', () {
    // Assert the ABSENCE deliberately. If a `.tflite` reappears in
    // assets/models/ it is almost certainly an unlicensed model someone found
    // on GitHub — the precise failure the licensing survey exists to prevent.
    final dir = Directory('assets/models');
    if (!dir.existsSync()) return;
    final models = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.tflite'))
        .toList();
    expect(
      models,
      isEmpty,
      reason: 'Found a bundled model: ${models.map((f) => f.path).join(', ')}.\n\n'
          'Face verification runs SERVER-SIDE now. A .tflite here ships '
          'biometric model weights inside the APK, which is exactly what the '
          'licensing survey concluded cannot be done with any freely available '
          'mobile-size face model.\n\n'
          'See docs/engineering/FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md '
          'before adding anything to this directory.',
    );
  });
}
