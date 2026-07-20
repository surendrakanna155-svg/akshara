import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../../router/route_names.dart';
import '../../../theme/theme_extensions.dart';
import '../attendance_capture_sources.dart';
import '../staff_attendance_models.dart';
import 'camera_image_converter.dart';
import 'face_crop.dart';
import 'face_embedder.dart';
import 'liveness_detector.dart';
import 'still_face_validation.dart';

/// Real [FaceCaptureSource] (Slice 3 device adapter): presents [FaceCaptureScreen]
/// — front camera + live liveness challenge + on-device embedding — and turns
/// its result into either a [FaceCapture] or the right [AttendanceCaptureException].
///
/// Navigates via `goRouterProvider.push(...)` (the app's existing pattern for
/// pushing a route from non-widget code — see `lib/app/app.dart`'s
/// `SyncBanner.onOpenSyncCenter`) rather than holding a [BuildContext], so this
/// source is constructible (and this whole seam remains injectable) without any
/// widget in scope. Construction does NO plugin work.
class MlkitFaceCaptureSource implements FaceCaptureSource {
  MlkitFaceCaptureSource({
    required GoRouter Function() router,
    FaceEmbedder? embedder,
  })  : _router = router,
        _embedder = embedder ?? MobileFaceNetEmbedder();

  final GoRouter Function() _router;
  final FaceEmbedder _embedder;

  @override
  Future<FaceCapture> capture() async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      cameras = const [];
    }
    if (cameras.isEmpty) {
      throw const AttendanceCaptureException(
        AttendanceCaptureStep.face,
        'CAMERA_UNAVAILABLE',
        'No camera is available on this device.',
      );
    }

    // The screen pops with: a FaceCapture on success, an
    // AttendanceCaptureException for a terminal failure the user cannot fix
    // by retrying (e.g. FACE_MODEL_MISSING — audit R1 P3-3, no dead-end
    // screens), or null when the user cancels.
    final result = await _router().push<Object?>(
      RouteNames.staffFaceCapture,
      extra: _embedder,
    );
    if (result is FaceCapture) return result;
    if (result is AttendanceCaptureException) throw result;
    throw const AttendanceCaptureException(
      AttendanceCaptureStep.face,
      'FACE_CAPTURE_CANCELLED',
      'Face capture was cancelled.',
    );
  }
}

/// Full-screen live face capture flow (Slice 3): front camera preview streamed
/// to ML Kit face detection, a blink-challenge [LivenessDetector], and — once
/// liveness passes — a still capture cropped/embedded on-device. Returns the
/// [FaceCapture] via `Navigator.pop`, or `null` when the user cancels.
///
/// This widget is exercised on a real device/emulator only — it is
/// deliberately NOT covered by the headless test suite (no fake camera/mlkit
/// plugin surface exists to drive it without a device).
class FaceCaptureScreen extends StatefulWidget {
  FaceCaptureScreen({super.key, FaceEmbedder? embedder})
      : embedder = embedder ?? MobileFaceNetEmbedder();

  final FaceEmbedder embedder;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  final LivenessDetector _liveness = LivenessDetector();

  bool _busyOnFrame = false;
  bool _streaming = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Lock portrait while capturing so the fixed device-orientation rotation
    // compensation below stays correct (see inputImageFromCameraImage).
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      final front =
          cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final camera = front.isNotEmpty
          ? front.first
          : (cameras.isNotEmpty ? cameras.first : null);
      if (camera == null) {
        if (!mounted) return;
        setState(() => _error = 'No camera is available on this device.');
        return;
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      setState(() => _controller = controller);
      await _startStream();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not start the camera: $e');
    }
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    _streaming = true;
    await controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    if (_busyOnFrame || _capturing) return;
    _busyOnFrame = true;
    _processFrame(image).whenComplete(() => _busyOnFrame = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    final detector = _faceDetector;
    if (controller == null || detector == null || !mounted) return;

    try {
      final inputImage = inputImageFromCameraImage(
        image,
        camera: controller.description,
        // Locked to portrait (see initState) — no rotation compensation needed.
        deviceOrientationDegrees: 0,
      );
      if (inputImage == null) return;

      final faces = await detector.processImage(inputImage);
      if (!mounted) return;

      final face = faces.isNotEmpty ? faces.first : null;
      final frame = LivenessFrame(
        faceCount: faces.length,
        leftEyeOpenProbability: face?.leftEyeOpenProbability,
        rightEyeOpenProbability: face?.rightEyeOpenProbability,
        headEulerAngleY: face?.headEulerAngleY,
        headEulerAngleZ: face?.headEulerAngleZ,
      );
      final stage = _liveness.onFrame(frame);
      if (!mounted) return;
      setState(() {});

      if (stage == LivenessStage.done) {
        await _capture();
      }
    } catch (e) {
      // A single bad frame must never crash the live stream — log and keep
      // waiting for the next one.
      if (!kReleaseMode) debugPrint('FaceCaptureScreen: frame processing failed: $e');
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    final controller = _controller;
    final detector = _faceDetector;
    if (controller == null || detector == null) {
      _capturing = false;
      return;
    }

    try {
      if (_streaming) {
        await controller.stopImageStream();
        _streaming = false;
      }
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      // Audit R1 (photo-swap guard): re-validate the STILL with the same
      // rigor as the live challenge — exactly one face, frontal pose. A
      // photo held up after liveness, or a second face leaning in, fails
      // here and restarts the whole challenge (never passes).
      final stillFaces =
          await detector.processImage(InputImage.fromFilePath(file.path));
      final verdict = validateStillFaces([
        for (final f in stillFaces)
          StillFaceObservation(
            boundingBox: f.boundingBox,
            headEulerAngleY: f.headEulerAngleY,
            headEulerAngleZ: f.headEulerAngleZ,
          ),
      ]);
      if (!verdict.isValid) {
        await _retryAfterError(verdict.error!);
        return;
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        await _retryAfterError(
          'Could not read the captured photo. Try again.',
        );
        return;
      }
      // Audit R1 (P2-1): ML Kit's fromFilePath honors EXIF orientation but the
      // raw decode does not — bake the orientation so the bounding box and the
      // pixels are in the same space before cropping.
      final oriented = bakeStillOrientation(decoded);

      final crop = computeFaceCropRect(
        imageWidth: oriented.width,
        imageHeight: oriented.height,
        boundingBox: verdict.cropTarget!,
      );
      final faceImage = cropAndResizeForEmbedder(oriented, crop);
      final embedding = await widget.embedder.embed(faceImage);

      if (!mounted) return;
      Navigator.of(context).pop(
        FaceCapture(
          embedding: embedding,
          livenessPassed: true,
          modelTag: widget.embedder.modelTag,
        ),
      );
    } on AttendanceCaptureException catch (e) {
      // Terminal, non-retryable failure (e.g. FACE_MODEL_MISSING — the model
      // cannot appear by retrying). Pop the typed exception so the source
      // surfaces the proper face-blocked reason instead of freezing the user
      // on a dead-end screen (audit R1 P3-3). NEVER a fabricated embedding.
      if (!mounted) return;
      Navigator.of(context).pop(e);
    } catch (e) {
      await _retryAfterError('Face capture failed. Try again.');
    }
  }

  Future<void> _retryAfterError(String message) async {
    if (!mounted) return;
    setState(() => _error = message);
    _liveness.reset();
    _capturing = false;
    await _startStream();
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      if (_streaming) {
        unawaited(controller.stopImageStream());
      }
      unawaited(controller.dispose());
    }
    unawaited(_faceDetector?.close());
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Verify your face'),
        leading: IconButton(
          key: const Key('face-capture-cancel'),
          icon: const Icon(Icons.close),
          onPressed: _cancel,
        ),
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (controller != null && controller.value.isInitialized)
              CameraPreview(controller)
            else
              const CircularProgressIndicator(color: Colors.white),
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Container(
                key: const Key('face-capture-instruction'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error ?? _liveness.instruction,
                  textAlign: TextAlign.center,
                  style: context.aksharaText.bodyLarge
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
