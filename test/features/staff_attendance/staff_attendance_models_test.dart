// Slice 3 — model-level coverage: FaceCapture.modelTag serialization (Slice 2
// server contract: face.modelTag drives FACE_EMBEDDING_MISMATCH re-enrol) and
// StaffCheckOutcome.isNotEnrolled (drives the check-in card's "Enrol my face"
// affordance).

import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceCapture.toJson', () {
    test('includes modelTag alongside embedding/livenessPassed', () {
      const capture = FaceCapture(
        embedding: [0.1, 0.2, 0.3],
        livenessPassed: true,
        modelTag: 'mobilefacenet-v1',
      );

      final json = capture.toJson();

      expect(json['embedding'], [0.1, 0.2, 0.3]);
      expect(json['livenessPassed'], isTrue);
      expect(json['modelTag'], 'mobilefacenet-v1');
    });

    test('defaults modelTag to an empty string when not provided', () {
      const capture = FaceCapture(embedding: [0.1], livenessPassed: true);

      expect(capture.modelTag, '');
      expect(capture.toJson()['modelTag'], '');
    });

    test('omits captureRef when null but always sends modelTag', () {
      const capture = FaceCapture(
        embedding: [0.1],
        livenessPassed: false,
        modelTag: 'mobilefacenet-v1',
      );

      final json = capture.toJson();

      expect(json.containsKey('captureRef'), isFalse);
      expect(json.containsKey('modelTag'), isTrue);
    });
  });

  group('StaffCheckOutcome.isNotEnrolled', () {
    test('true only for a faceBlocked outcome with the FACE_NOT_ENROLLED code',
        () {
      final outcome = StaffCheckOutcome.faceBlocked(
        'No enrolled reference face',
        code: 'STAFF_ATTENDANCE_FACE_NOT_ENROLLED',
      );

      expect(outcome.isNotEnrolled, isTrue);
    });

    test('false for a different face-blocked reason (e.g. no-match)', () {
      final outcome = StaffCheckOutcome.faceBlocked(
        'no match',
        code: 'STAFF_ATTENDANCE_FACE_NO_MATCH',
      );

      expect(outcome.isNotEnrolled, isFalse);
    });

    test('false for a faceBlocked outcome with no code (e.g. capture cancelled)',
        () {
      final outcome = StaffCheckOutcome.faceBlocked('Face capture was cancelled');
      expect(outcome.isNotEnrolled, isFalse);
    });

    test('false for a location-blocked outcome', () {
      final outcome = StaffCheckOutcome.locationBlocked('too far');
      expect(outcome.isNotEnrolled, isFalse);
    });

    test('false for a recorded outcome', () {
      final outcome = StaffCheckOutcome.recorded(const StaffCheckRecord(
        id: 'chk_1',
        eventType: 'check_in',
        method: 'face_match',
      ));
      expect(outcome.isNotEnrolled, isFalse);
    });
  });
}
