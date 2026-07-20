// Audit R1 (P1-3, photo-swap guard) — validateStillFaces is pure and
// headless-testable: the captured STILL must contain exactly one face, and
// that face must satisfy the same frontal-pose bounds as the live challenge.

import 'dart:ui';

import 'package:akshara_erp/features/staff_attendance/device/still_face_validation.dart';
import 'package:flutter_test/flutter_test.dart';

const _box = Rect.fromLTWH(100, 100, 200, 200);

StillFaceObservation _face({double? y, double? z, Rect box = _box}) =>
    StillFaceObservation(boundingBox: box, headEulerAngleY: y, headEulerAngleZ: z);

void main() {
  group('validateStillFaces', () {
    test('zero faces → invalid (retryable), never a crop target', () {
      final verdict = validateStillFaces(const []);
      expect(verdict.isValid, isFalse);
      expect(verdict.cropTarget, isNull);
      expect(verdict.error, contains('Try again'));
    });

    test('one frontal face → valid with its bounding box as the crop target',
        () {
      final verdict = validateStillFaces([_face(y: 3, z: -4)]);
      expect(verdict.isValid, isTrue);
      expect(verdict.cropTarget, _box);
      expect(verdict.error, isNull);
    });

    test('TWO faces → invalid "one face only" (the photo-swap / second-person '
        'case must never pass)', () {
      final verdict = validateStillFaces([_face(), _face()]);
      expect(verdict.isValid, isFalse);
      expect(verdict.error, contains('One face only'));
    });

    test('non-frontal yaw beyond the bound → invalid', () {
      final verdict = validateStillFaces([_face(y: 40)]);
      expect(verdict.isValid, isFalse);
      expect(verdict.error, contains('straight'));
    });

    test('non-frontal roll beyond the bound → invalid', () {
      final verdict = validateStillFaces([_face(z: -25)]);
      expect(verdict.isValid, isFalse);
    });

    test('missing pose angles are not disqualifying (consistent with the '
        'liveness detector)', () {
      final verdict = validateStillFaces([_face()]);
      expect(verdict.isValid, isTrue);
    });

    test('the tilt bound is configurable and inclusive', () {
      expect(validateStillFaces([_face(y: 15)]).isValid, isTrue);
      expect(validateStillFaces([_face(y: 15.1)]).isValid, isFalse);
      expect(
        validateStillFaces([_face(y: 20)], maxHeadTiltDegrees: 25).isValid,
        isTrue,
      );
    });
  });
}
