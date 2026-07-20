// Slice 3 — computeFaceCropRect is pure geometry (no `image` package pixel
// work), so the margin-expand + clamp-to-bounds logic is directly testable.

import 'dart:ui';

import 'package:akshara_erp/features/staff_attendance/device/face_crop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeFaceCropRect', () {
    test('expands the bounding box by the margin fraction on each side', () {
      final crop = computeFaceCropRect(
        imageWidth: 1000,
        imageHeight: 1000,
        boundingBox: const Rect.fromLTWH(400, 400, 200, 200),
        marginFraction: 0.25,
      );

      // margin = 200 * 0.25 = 50 on each side.
      expect(crop.x, 350);
      expect(crop.y, 350);
      expect(crop.width, 300);
      expect(crop.height, 300);
    });

    test('clamps to the image bounds when the margin would overflow', () {
      final crop = computeFaceCropRect(
        imageWidth: 500,
        imageHeight: 500,
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        marginFraction: 0.5,
      );

      expect(crop.x, 0);
      expect(crop.y, 0);
      expect(crop.width, greaterThan(0));
      expect(crop.height, greaterThan(0));
      expect(crop.x + crop.width, lessThanOrEqualTo(500));
      expect(crop.y + crop.height, lessThanOrEqualTo(500));
    });

    test('clamps a bottom-right face near the image edge', () {
      final crop = computeFaceCropRect(
        imageWidth: 300,
        imageHeight: 300,
        boundingBox: const Rect.fromLTWH(250, 250, 40, 40),
        marginFraction: 0.5,
      );

      expect(crop.x + crop.width, lessThanOrEqualTo(300));
      expect(crop.y + crop.height, lessThanOrEqualTo(300));
    });

    test('never produces a zero-area crop even for a degenerate bounding box',
        () {
      final crop = computeFaceCropRect(
        imageWidth: 200,
        imageHeight: 200,
        boundingBox: const Rect.fromLTWH(100, 100, 0, 0),
      );

      expect(crop.width, greaterThanOrEqualTo(1));
      expect(crop.height, greaterThanOrEqualTo(1));
    });
  });
}
