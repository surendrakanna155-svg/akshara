// Slice 3 — LivenessDetector is a PURE state machine (no camera/mlkit
// dependency), so it is fully unit-testable headless. Covers: happy path, two
// faces, no blink, head turned, and a blink-window timeout/reset.

import 'package:akshara_erp/features/staff_attendance/device/liveness_detector.dart';
import 'package:flutter_test/flutter_test.dart';

LivenessFrame _frontal({
  int faceCount = 1,
  double? leftOpen,
  double? rightOpen,
  double headEulerAngleY = 0,
  double headEulerAngleZ = 0,
}) =>
    LivenessFrame(
      faceCount: faceCount,
      leftEyeOpenProbability: leftOpen,
      rightEyeOpenProbability: rightOpen,
      headEulerAngleY: headEulerAngleY,
      headEulerAngleZ: headEulerAngleZ,
    );

void main() {
  group('LivenessDetector', () {
    test('starts in seekFace with the right instruction', () {
      final detector = LivenessDetector();
      expect(detector.stage, LivenessStage.seekFace);
      expect(detector.instruction, 'Center your face in the frame');
      expect(detector.passed, isFalse);
    });

    test('happy path: frontal face + a genuine open->closed->open blink passes',
        () {
      final detector = LivenessDetector();

      detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      expect(detector.stage, LivenessStage.blink);
      expect(detector.instruction, 'Blink now');
      expect(detector.passed, isFalse);

      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05));
      expect(detector.passed, isFalse, reason: 'eyes closed is only half the cycle');

      final stage = detector.onFrame(_frontal(leftOpen: 0.9, rightOpen: 0.9));

      expect(stage, LivenessStage.done);
      expect(detector.passed, isTrue);
      expect(detector.instruction, 'Verified');
    });

    test('two faces in frame never passes and resets to seekFace', () {
      final detector = LivenessDetector();
      detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95)); // -> blink
      expect(detector.stage, LivenessStage.blink);

      final stage = detector.onFrame(_frontal(faceCount: 2));

      expect(stage, LivenessStage.seekFace);
      expect(detector.passed, isFalse);
    });

    test('eyes never close (no blink) — never passes', () {
      final detector = LivenessDetector(blinkWindowFrames: 5);
      for (var i = 0; i < 20; i++) {
        detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      }
      expect(detector.passed, isFalse);
      expect(detector.stage, LivenessStage.blink);
    });

    test('head turned away stays in holdStill and never starts the blink challenge',
        () {
      final detector = LivenessDetector();

      final stage = detector.onFrame(_frontal(
        leftOpen: 0.95,
        rightOpen: 0.95,
        headEulerAngleY: 40,
      ));

      expect(stage, LivenessStage.holdStill);
      expect(detector.instruction, 'Hold still, facing the camera');
      expect(detector.passed, isFalse);
    });

    test('head roll (Z) beyond the tilt threshold also blocks the challenge', () {
      final detector = LivenessDetector();

      final stage = detector.onFrame(_frontal(
        leftOpen: 0.95,
        rightOpen: 0.95,
        headEulerAngleZ: -25,
      ));

      expect(stage, LivenessStage.holdStill);
    });

    test(
        'a blink cycle that times out mid-way resets — a stale "closed" flag '
        'cannot combine with a later "open" to fake a pass', () {
      final detector = LivenessDetector(blinkWindowFrames: 3);

      detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95)); // frame 1: enter blink
      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05)); // frame 2: eyes closed seen
      detector.onFrame(_frontal(leftOpen: 0.5, rightOpen: 0.5)); // frame 3: ambiguous
      detector.onFrame(_frontal(leftOpen: 0.5, rightOpen: 0.5)); // frame 4: window exceeded -> reset

      final afterTimeout =
          detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      expect(afterTimeout, LivenessStage.blink);
      expect(detector.passed, isFalse,
          reason: 'the pre-timeout "closed" must not still count');

      // A fresh, complete cycle after the reset still passes.
      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05));
      final done = detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));

      expect(done, LivenessStage.done);
      expect(detector.passed, isTrue);
    });

    test(
        'audit R1: a closed→open HALF-cycle never passes — eyes must be seen '
        'OPEN before the closed phase counts (full open→closed→open)', () {
      final detector = LivenessDetector();

      // Challenge entered with eyes already closed (e.g. a photo raised
      // mid-transition): closed must NOT count yet…
      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05));
      // …so a following open frame must NOT complete a "blink".
      final afterHalfCycle =
          detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      expect(afterHalfCycle, LivenessStage.blink);
      expect(detector.passed, isFalse,
          reason: 'closed→open is only half a blink');

      // The open frame above starts a REAL cycle: closed then open completes it.
      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05));
      final done = detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      expect(done, LivenessStage.done);
      expect(detector.passed, isTrue);
    });

    test('losing the face mid-blink resets the whole challenge', () {
      final detector = LivenessDetector();
      detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05));

      final stage = detector.onFrame(_frontal(faceCount: 0));

      expect(stage, LivenessStage.seekFace);
      expect(detector.passed, isFalse);
    });

    test('reset() manually restarts a passed detector', () {
      final detector = LivenessDetector();
      detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      detector.onFrame(_frontal(leftOpen: 0.05, rightOpen: 0.05));
      detector.onFrame(_frontal(leftOpen: 0.95, rightOpen: 0.95));
      expect(detector.passed, isTrue);

      detector.reset();

      expect(detector.passed, isFalse);
      expect(detector.stage, LivenessStage.seekFace);
    });

    test('missing eye-classification frames do not advance or break the window',
        () {
      final detector = LivenessDetector();
      final stage = detector.onFrame(const LivenessFrame(faceCount: 1));
      // No yaw/roll and no eye data — treated as frontal (can't disqualify on
      // missing data), so it should still enter the blink stage.
      expect(stage, LivenessStage.blink);
      expect(detector.passed, isFalse);
    });
  });
}
