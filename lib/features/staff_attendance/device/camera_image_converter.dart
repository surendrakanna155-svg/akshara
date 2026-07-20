import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Converts a `camera` package [CameraImage] (YUV_420_888 / NV21 on Android,
/// BGRA8888 on iOS) into an ML Kit [InputImage], per the standard
/// `google_mlkit_commons` `InputImage.fromBytes` pattern.
///
/// Split into small pure helpers ([concatenatePlanes], [rotationFromSensor])
/// plus this one impure entry point that reads the platform-specific
/// [CameraImage] — mirrors Google's own ML Kit Flutter example conversion.

/// Concatenates every plane's bytes, in order, into one buffer. Pure and
/// directly testable with synthetic [Uint8List]s (no camera plugin needed) —
/// this is what NV21/single-plane and multi-plane YUV_420_888 both reduce to.
Uint8List concatenatePlanes(List<Uint8List> planeBytes) {
  final builder = BytesBuilder(copy: false);
  for (final bytes in planeBytes) {
    builder.add(bytes);
  }
  return builder.toBytes();
}

/// Computes the ML Kit input rotation from the camera sensor orientation and
/// the current device rotation, per Google's documented compensation formula.
/// Pure — takes plain ints/bool, returns the mlkit-commons enum — directly
/// testable without a real camera/device.
InputImageRotation rotationFromSensor({
  required int sensorOrientation,
  required bool isFrontCamera,
  required int deviceOrientationDegrees,
}) {
  final int compensated;
  if (isFrontCamera) {
    compensated = (sensorOrientation + deviceOrientationDegrees) % 360;
  } else {
    compensated = (sensorOrientation - deviceOrientationDegrees + 360) % 360;
  }
  return InputImageRotationValue.fromRawValue(compensated) ??
      InputImageRotation.rotation0deg;
}

/// Builds an [InputImage] from a live [CameraImage] frame, or `null` when the
/// device delivered a raw format ML Kit doesn't support (the caller should
/// just skip that frame rather than crash the stream).
InputImage? inputImageFromCameraImage(
  CameraImage image, {
  required CameraDescription camera,
  required int deviceOrientationDegrees,
}) {
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  final bytes = concatenatePlanes(
    [for (final plane in image.planes) plane.bytes],
  );

  final rotation = rotationFromSensor(
    sensorOrientation: camera.sensorOrientation,
    isFrontCamera: camera.lensDirection == CameraLensDirection.front,
    deviceOrientationDegrees: deviceOrientationDegrees,
  );

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    ),
  );
}
