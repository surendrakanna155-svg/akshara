import 'dart:ui';

/// Audit R1 (photo-swap guard): the liveness challenge runs on the live STREAM,
/// but the embedding comes from a separate STILL taken afterwards. Without
/// validating the still with the same rigor, an attacker could pass liveness
/// with their own face and swap in a photo (or a second person could lean in)
/// for the still. The still must therefore contain EXACTLY ONE face, and that
/// face must satisfy the same frontal-pose bounds as the liveness detector.
///
/// Pure data + pure function — no camera/mlkit dependency — unit-testable
/// headless. `mlkit_face_capture.dart` maps ML Kit `Face`s into
/// [StillFaceObservation]s and acts on the returned verdict.

/// The subset of an ML Kit `Face` the still-validation needs.
class StillFaceObservation {
  const StillFaceObservation({
    required this.boundingBox,
    this.headEulerAngleY,
    this.headEulerAngleZ,
  });

  final Rect boundingBox;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
}

/// The verdict: either [cropTarget] (valid — crop this box and embed) or
/// [error] (a retryable, user-facing reason). Exactly one is non-null.
class StillFaceValidation {
  const StillFaceValidation.valid(Rect this.cropTarget) : error = null;
  const StillFaceValidation.invalid(String this.error) : cropTarget = null;

  final Rect? cropTarget;
  final String? error;

  bool get isValid => cropTarget != null;
}

/// Validates the faces detected on the captured still:
///  - exactly ONE face (0 → retry, 2+ → "one face only");
///  - roughly frontal — |headEulerAngleY|, |headEulerAngleZ| within
///    [maxHeadTiltDegrees], mirroring the liveness detector's bounds (a
///    missing axis is not disqualifying, consistent with LivenessDetector).
StillFaceValidation validateStillFaces(
  List<StillFaceObservation> faces, {
  double maxHeadTiltDegrees = 15,
}) {
  if (faces.isEmpty) {
    return const StillFaceValidation.invalid(
      'Could not confirm the face in the photo. Try again.',
    );
  }
  if (faces.length > 1) {
    return const StillFaceValidation.invalid(
      'One face only — make sure no one else is in the frame and try again.',
    );
  }
  final face = faces.single;
  final y = face.headEulerAngleY;
  final z = face.headEulerAngleZ;
  final yawOk = y == null || y.abs() <= maxHeadTiltDegrees;
  final rollOk = z == null || z.abs() <= maxHeadTiltDegrees;
  if (!yawOk || !rollOk) {
    return const StillFaceValidation.invalid(
      'Face the camera straight on and try again.',
    );
  }
  return StillFaceValidation.valid(face.boundingBox);
}
