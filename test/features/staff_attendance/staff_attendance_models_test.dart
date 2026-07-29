// Slice 3 — model-level coverage: FaceCapture.modelTag serialization (Slice 2
// server contract: face.modelTag drives FACE_EMBEDDING_MISMATCH re-enrol) and
// StaffCheckOutcome.isNotEnrolled (drives the check-in card's "Enrol my face"
// affordance).

import 'package:akshara_erp/features/staff_attendance/staff_attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceCapture.toJson', () {
    test('sends the aligned crop — and NO embedding or modelTag', () {
      // The client no longer computes an embedding, so it must not claim one.
      // The server REFUSES a request carrying either field
      // (FACE_EMBEDDING_NOT_ACCEPTED), so sending them would break check-in
      // outright rather than degrade quietly.
      const capture = FaceCapture(
        cropBase64: 'Y3JvcC1ieXRlcw==',
        livenessPassed: true,
      );

      final json = capture.toJson();

      expect(json['crop'], 'Y3JvcC1ieXRlcw==');
      expect(json['livenessPassed'], isTrue);
      expect(json.containsKey('embedding'), isFalse);
      expect(json.containsKey('modelTag'), isFalse);
    });

    test('omits captureRef when null', () {
      const capture = FaceCapture(
        cropBase64: 'Y3JvcC1ieXRlcw==',
        livenessPassed: false,
      );

      final json = capture.toJson();

      expect(json.containsKey('captureRef'), isFalse);
      expect(json['livenessPassed'], isFalse);
    });

    test('carries captureRef when supplied', () {
      const capture = FaceCapture(
        cropBase64: 'Y3JvcC1ieXRlcw==',
        livenessPassed: true,
        captureRef: 'cap/1.png',
      );

      expect(capture.toJson()['captureRef'], 'cap/1.png');
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
