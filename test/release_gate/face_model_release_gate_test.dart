// Release gate — the MobileFaceNet model must ship in the production build.
//
// Owner decision D9 (2026-07-29): face verification is a **committed product
// capability** and `nikshaos.in` advertises it ("verified by live camera and
// geofence"). MobileFaceNet is therefore a **mandatory pre-launch dependency**,
// not an optional extra.
//
// ---------------------------------------------------------------------------
// Why this is gated rather than always-on
// ---------------------------------------------------------------------------
// The model is a large binary that is deliberately not in the repository yet
// (see `assets/models/README.md`). Failing every developer's `flutter test`
// until it lands would be noise, and noisy gates get muted — which is exactly
// how a launch-blocking dependency goes missing.
//
// So it runs only when explicitly asked:
//
//     RELEASE_GATE=1 flutter test test/release_gate/
//
// Wire that into the release checklist and CI's release job. A normal
// development run reports the state and passes.
//
// ---------------------------------------------------------------------------
// What is already done, so nobody re-does it
// ---------------------------------------------------------------------------
// Verified 2026-07-29 — the capability is complete apart from the binary:
//   · `MobileFaceNetEmbedder` loads lazily and throws FACE_MODEL_MISSING rather
//     than ever fabricating an embedding
//   · embeddings are L2-normalised, so server-side cosine similarity is a dot
//     product
//   · `_shared/attendance_auth/face_match.ts` is NaN-safe: a non-finite score
//     returns 0 (fails CLOSED) and the verdict uses `similarity >= threshold`,
//     never the `score < t` form that lets NaN pass
//   · the acceptance threshold is env-resolvable (`FACE_MATCH_MIN_SIMILARITY`)
//     with a conservative default
//   · ML Kit capture and the enrolment screen are implemented
//   · the geofence half of the claim works today
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Declared in `lib/features/staff_attendance/device/face_embedder.dart`.
const String kModelPath = 'assets/models/mobilefacenet.tflite';

/// Model contract the embedder expects — 112x112x3 RGB in, 192-d out.
const int kInputSize = 112;
const int kOutputDims = 192;

bool get _gateEnabled =>
    (Platform.environment['RELEASE_GATE'] ?? '').isNotEmpty;

void main() {
  test('MobileFaceNet model is bundled (release gate)', () {
    final model = File(kModelPath);
    final present = model.existsSync();

    if (!_gateEnabled) {
      // Informational on a normal run — never fails, always visible.
      printOnFailure('');
      // ignore: avoid_print
      print(
        present
            ? '✓ $kModelPath present (${model.lengthSync()} bytes)'
            : '⚠ $kModelPath NOT bundled — face verification cannot run in a '
                'build from this tree. This is a MANDATORY pre-launch '
                'dependency (owner decision D9). Enforce with '
                'RELEASE_GATE=1 flutter test test/release_gate/',
      );
      return;
    }

    expect(
      present,
      isTrue,
      reason: '$kModelPath is missing.\n\n'
          'Face verification is a committed capability and the public website '
          'advertises it. A release without this file ships a product that '
          'cannot do what nikshaos.in says it does.\n\n'
          'Required model: MobileFaceNet, TFLite, ${kInputSize}x$kInputSize x3 '
          'RGB input, $kOutputDims-d output embedding.\n'
          'Confirm the licence permits redistribution in a commercial app '
          'before adding it. See assets/models/README.md and '
          'docs/engineering/FACE_VERIFICATION_IMPLEMENTATION_GAP.md.',
    );

    // Guard against an empty or truncated drop-in — a 0-byte file would satisfy
    // existsSync() and then fail at runtime as FACE_MODEL_MISSING, which is the
    // confusing failure this gate exists to prevent.
    expect(
      model.lengthSync(),
      greaterThan(100 * 1024),
      reason: 'A MobileFaceNet TFLite model is on the order of a megabyte. '
          '${model.lengthSync()} bytes is a placeholder or a truncated '
          'download, not a model.',
    );
  });

  test('the model path is declared as a Flutter asset', () {
    // The file can be present on disk and still not ship if the asset
    // declaration is dropped — a silent way to fail the gate above.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('assets/models/'),
      isTrue,
      reason: 'pubspec.yaml no longer declares assets/models/, so the face '
          'model would not be bundled even once it is added.',
    );
  });
}
