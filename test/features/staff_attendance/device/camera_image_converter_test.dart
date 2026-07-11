// Slice 3 — the pure parts of camera_image_converter.dart: concatenatePlanes
// (works for both single-plane NV21 and multi-plane YUV_420_888 frames) and
// rotationFromSensor (the front/back rotation-compensation formula). Neither
// needs a real camera/CameraImage.

import 'dart:typed_data';

import 'package:akshara_erp/features/staff_attendance/device/camera_image_converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

void main() {
  group('concatenatePlanes', () {
    test('concatenates a single plane as-is (NV21 case)', () {
      final plane = Uint8List.fromList([1, 2, 3, 4]);
      expect(concatenatePlanes([plane]), [1, 2, 3, 4]);
    });

    test('concatenates multiple planes in order (YUV_420_888 case)', () {
      final y = Uint8List.fromList([1, 2, 3]);
      final u = Uint8List.fromList([4, 5]);
      final v = Uint8List.fromList([6, 7]);
      expect(concatenatePlanes([y, u, v]), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('an empty plane list yields an empty buffer', () {
      expect(concatenatePlanes(const []), isEmpty);
    });
  });

  group('rotationFromSensor', () {
    test('front camera: compensation = (sensor + device) % 360', () {
      final rotation = rotationFromSensor(
        sensorOrientation: 270,
        isFrontCamera: true,
        deviceOrientationDegrees: 90,
      );
      expect(rotation, InputImageRotation.rotation0deg);
    });

    test('back camera: compensation = (sensor - device + 360) % 360', () {
      final rotation = rotationFromSensor(
        sensorOrientation: 90,
        isFrontCamera: false,
        deviceOrientationDegrees: 0,
      );
      expect(rotation, InputImageRotation.rotation90deg);
    });

    test('a typical portrait front camera (sensor 270, device 0) -> 270deg', () {
      final rotation = rotationFromSensor(
        sensorOrientation: 270,
        isFrontCamera: true,
        deviceOrientationDegrees: 0,
      );
      expect(rotation, InputImageRotation.rotation270deg);
    });

    test('falls back to rotation0deg for a non-90-multiple compensation', () {
      final rotation = rotationFromSensor(
        sensorOrientation: 45,
        isFrontCamera: false,
        deviceOrientationDegrees: 0,
      );
      expect(rotation, InputImageRotation.rotation0deg);
    });
  });
}
