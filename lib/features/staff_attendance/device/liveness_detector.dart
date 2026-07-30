/// A single per-frame face observation fed into [LivenessDetector]. Pure data
/// — no camera/mlkit dependency — so the detector is unit-testable headless.
///
/// [leftEyeOpenProbability] / [rightEyeOpenProbability] are only available when
/// the upstream detector runs with classification enabled; [headEulerAngleY] /
/// [headEulerAngleZ] are the face's yaw/roll in degrees (see
/// google_mlkit_face_detection's `Face`). Any of these may be null when the
/// underlying detector could not compute them for this frame.
class LivenessFrame {
  const LivenessFrame({
    required this.faceCount,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headEulerAngleY,
    this.headEulerAngleZ,
  });

  final int faceCount;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
}

/// The liveness challenge's current stage, driving both [LivenessDetector.passed]
/// and the on-screen [LivenessDetector.instruction].
enum LivenessStage {
  /// Waiting for exactly one face to appear in frame.
  seekFace,

  /// A single face is present but not (yet) roughly frontal.
  holdStill,

  /// Frontal and stable — waiting for a genuine open→closed→open blink.
  blink,

  /// The blink challenge completed — liveness is proven for this session.
  done,
}

/// A PURE, unit-testable liveness state machine (no camera/mlkit dependency).
///
/// Per docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §7, liveness (anti-photo/replay)
/// is required alongside the server-authoritative face match. This requires,
/// in order:
///   1. exactly one face in frame;
///   2. a roughly frontal head pose (|yaw|, |roll| within [maxHeadTiltDegrees]);
///   3. a genuine blink — both eyes open, then both closed, then both open
///      again — within [blinkWindowFrames] frames of entering the challenge.
///
/// [passed] only ever becomes true after a real blink cycle is observed; it is
/// NEVER hardcoded and NEVER settable from outside [onFrame].
class LivenessDetector {
  LivenessDetector({
    this.maxHeadTiltDegrees = 15,
    this.eyeOpenThreshold = 0.8,
    this.eyeClosedThreshold = 0.3,
    this.blinkWindowFrames = 45,
  });

  /// Max |headEulerAngleY| / |headEulerAngleZ| (degrees) still considered
  /// "roughly frontal".
  final double maxHeadTiltDegrees;

  /// Eye-open probability at/above which an eye counts as open.
  final double eyeOpenThreshold;

  /// Eye-open probability at/below which an eye counts as closed.
  final double eyeClosedThreshold;

  /// How many frames the open→closed→open cycle may take before the blink
  /// challenge restarts (a genuine user can simply try again).
  final int blinkWindowFrames;

  LivenessStage _stage = LivenessStage.seekFace;
  bool _eyesOpenSeen = false;
  bool _eyesClosedSeen = false;
  int _blinkFrameCount = 0;

  LivenessStage get stage => _stage;

  /// True only once a full open→closed→open blink was observed while frontal.
  bool get passed => _stage == LivenessStage.done;

  /// The current on-screen instruction for the person being verified.
  String get instruction => switch (_stage) {
        LivenessStage.seekFace => 'Center your face in the frame',
        LivenessStage.holdStill => 'Hold still, facing the camera',
        LivenessStage.blink => 'Blink now',
        LivenessStage.done => 'Verified',
      };

  /// Restarts the whole challenge from [LivenessStage.seekFace].
  void reset() {
    _stage = LivenessStage.seekFace;
    _eyesOpenSeen = false;
    _eyesClosedSeen = false;
    _blinkFrameCount = 0;
  }

  /// Feeds one frame's observation and returns the (possibly unchanged)
  /// [stage]. A no-op once [passed] — call [reset] first to run it again.
  LivenessStage onFrame(LivenessFrame frame) {
    if (_stage == LivenessStage.done) return _stage;

    if (frame.faceCount != 1) {
      reset();
      return _stage;
    }

    if (!_isFrontal(frame)) {
      // A face is present but not frontal — drop any in-progress blink
      // attempt; the challenge must happen while facing the camera.
      _stage = LivenessStage.holdStill;
      _eyesOpenSeen = false;
      _eyesClosedSeen = false;
      _blinkFrameCount = 0;
      return _stage;
    }

    if (_stage == LivenessStage.seekFace || _stage == LivenessStage.holdStill) {
      _stage = LivenessStage.blink;
      _eyesOpenSeen = false;
      _eyesClosedSeen = false;
      _blinkFrameCount = 0;
    }

    // _stage == blink from here.
    final leftOpen = frame.leftEyeOpenProbability;
    final rightOpen = frame.rightEyeOpenProbability;
    if (leftOpen == null || rightOpen == null) {
      // No eye classification yet this frame — wait; don't burn the window.
      return _stage;
    }

    _blinkFrameCount++;
    final bothClosed =
        leftOpen <= eyeClosedThreshold && rightOpen <= eyeClosedThreshold;
    final bothOpen =
        leftOpen >= eyeOpenThreshold && rightOpen >= eyeOpenThreshold;

    // Audit R1 (P3): the full documented open→CLOSED→open cycle is required.
    // Eyes must be seen OPEN first — otherwise a challenge entered with eyes
    // already closed (e.g. a photo raised mid-transition) would pass on a mere
    // closed→open half-cycle.
    if (!_eyesOpenSeen) {
      if (bothOpen) _eyesOpenSeen = true;
    } else if (!_eyesClosedSeen) {
      if (bothClosed) _eyesClosedSeen = true;
    } else if (bothOpen) {
      _stage = LivenessStage.done;
      return _stage;
    }

    if (_blinkFrameCount > blinkWindowFrames) {
      // Timed out waiting for the cycle to complete — restart the challenge
      // (stay frontal, no need to re-seek the face) rather than fail forever.
      _eyesOpenSeen = false;
      _eyesClosedSeen = false;
      _blinkFrameCount = 0;
    }

    return _stage;
  }

  bool _isFrontal(LivenessFrame frame) {
    final y = frame.headEulerAngleY;
    final z = frame.headEulerAngleZ;
    // Fast-mode detection may not report yaw (ML Kit only guarantees it in
    // "accurate" mode) — treat a missing axis as not disqualifying rather than
    // block the whole challenge on an angle the detector can't compute.
    final yawOk = y == null || y.abs() <= maxHeadTiltDegrees;
    final rollOk = z == null || z.abs() <= maxHeadTiltDegrees;
    return yawOk && rollOk;
  }
}
