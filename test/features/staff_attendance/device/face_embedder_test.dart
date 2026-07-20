// Slice 3 — face_embedder.dart's pure helpers (normalizePixel, l2Normalize,
// imageToInputTensor) are directly testable without a real interpreter.
// MobileFaceNetEmbedder's missing-asset failure path is ALSO testable headless:
// Interpreter.fromAsset's first step is a plain rootBundle.load(...) — since
// assets/models/mobilefacenet.tflite is deliberately not bundled (see
// assets/models/README.md), that load fails before any native/FFI TFLite code
// ever runs, so no real device/tflite runtime is required to observe the
// FACE_MODEL_MISSING fail-loud path.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:akshara_erp/features/staff_attendance/attendance_capture_sources.dart';
import 'package:akshara_erp/features/staff_attendance/device/face_embedder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizePixel', () {
    test('maps 0..255 to the MobileFaceNet (x-127.5)/128 range', () {
      expect(normalizePixel(0), closeTo(-0.99609375, 1e-9));
      expect(normalizePixel(255), closeTo(0.99609375, 1e-9));
      expect(normalizePixel(127), closeTo(-0.00390625, 1e-9));
      expect(normalizePixel(128), closeTo(0.00390625, 1e-9));
    });
  });

  group('l2Normalize', () {
    test('produces a unit-length vector', () {
      final normalized = l2Normalize([3, 4]);
      expect(normalized[0], closeTo(0.6, 1e-9));
      expect(normalized[1], closeTo(0.8, 1e-9));
      final norm = math.sqrt(normalized[0] * normalized[0] + normalized[1] * normalized[1]);
      expect(norm, closeTo(1.0, 1e-9));
    });

    test('preserves the all-zero vector rather than dividing by zero', () {
      expect(l2Normalize([0, 0, 0]), [0, 0, 0]);
    });

    test('is a pure function of its input (does not mutate the source list)',
        () {
      final source = [1.0, 2.0, 2.0];
      final normalized = l2Normalize(source);
      expect(source, [1.0, 2.0, 2.0]);
      expect(normalized, isNot(same(source)));
    });
  });

  group('imageToInputTensor', () {
    FaceImageRgb solidImage(int size, int r, int g, int b) {
      final bytes = Uint8List(size * size * 3);
      for (var i = 0; i < bytes.length; i += 3) {
        bytes[i] = r;
        bytes[i + 1] = g;
        bytes[i + 2] = b;
      }
      return FaceImageRgb(width: size, height: size, bytes: bytes);
    }

    test('shapes a [1, size, size, 3] tensor with normalized channels', () {
      const size = 4;
      final tensor = imageToInputTensor(solidImage(size, 255, 0, 128), size: size);

      expect(tensor.length, 1);
      expect(tensor[0].length, size);
      expect(tensor[0][0].length, size);
      expect(tensor[0][0][0].length, 3);

      final pixel = tensor[0][2][3];
      expect(pixel[0], closeTo(normalizePixel(255), 1e-9));
      expect(pixel[1], closeTo(normalizePixel(0), 1e-9));
      expect(pixel[2], closeTo(normalizePixel(128), 1e-9));
    });

    test('rejects an image that is not size x size', () {
      final wrongSize = FaceImageRgb(
        width: mobileFaceNetInputSize,
        height: mobileFaceNetInputSize - 1,
        bytes: Uint8List((mobileFaceNetInputSize) * (mobileFaceNetInputSize - 1) * 3),
      );
      expect(() => imageToInputTensor(wrongSize), throwsArgumentError);
    });

    test('rejects a byte buffer of the wrong length for its declared dimensions',
        () {
      final malformed = FaceImageRgb(
        width: mobileFaceNetInputSize,
        height: mobileFaceNetInputSize,
        bytes: Uint8List(10), // far short of size*size*3
      );
      expect(() => imageToInputTensor(malformed), throwsArgumentError);
    });
  });

  group('MobileFaceNetEmbedder', () {
    test('modelTag is the locked mobilefacenet-v1 identity', () {
      expect(MobileFaceNetEmbedder().modelTag, 'mobilefacenet-v1');
      expect(MobileFaceNetEmbedder().modelTag, mobileFaceNetModelTag);
    });

    test('construction does no plugin/asset work (safe in providers/tests)',
        () {
      expect(() => MobileFaceNetEmbedder(), returnsNormally);
    });

    test('embed() fails loud with FACE_MODEL_MISSING when the model asset is '
        'not bundled — NEVER a fake embedding', () async {
      final embedder = MobileFaceNetEmbedder();
      final face = FaceImageRgb(
        width: mobileFaceNetInputSize,
        height: mobileFaceNetInputSize,
        bytes: Uint8List(mobileFaceNetInputSize * mobileFaceNetInputSize * 3),
      );

      await expectLater(
        () => embedder.embed(face),
        throwsA(
          isA<AttendanceCaptureException>()
              .having((e) => e.code, 'code', 'FACE_MODEL_MISSING')
              .having((e) => e.step, 'step', AttendanceCaptureStep.face),
        ),
      );
    });
  });
}
