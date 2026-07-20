import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../attendance_capture_sources.dart';

/// The MobileFaceNet contract (locked, docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §7
/// + the Slice 3 build brief): 112x112x3 RGB input, output a 192-d embedding.
const int mobileFaceNetInputSize = 112;
const int mobileFaceNetOutputDims = 192;

/// The embedder identity sent to the server as `face.modelTag` (Slice 2): when
/// it and the enrolled reference's model tag are both non-empty and differ, the
/// server 422s FACE_EMBEDDING_MISMATCH instead of comparing incompatible spaces.
const String mobileFaceNetModelTag = 'mobilefacenet-v1';

/// Asset path for the bundled MobileFaceNet TFLite model. NOT bundled by
/// default — see assets/models/README.md. [MobileFaceNetEmbedder] fails loud
/// (FACE_MODEL_MISSING) rather than fabricate an embedding when it is absent.
const String mobileFaceNetAssetPath = 'assets/models/mobilefacenet.tflite';

/// A cropped, already-aligned-to-square face image ready for embedding:
/// [width] x [height] pixels, row-major RGB, one byte per channel, no alpha,
/// no row padding (`bytes.length == width * height * 3`).
class FaceImageRgb {
  const FaceImageRgb({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes;
}

/// Extracts a face embedding vector from a cropped RGB face image. The SERVER
/// is the authority on whether an embedding matches an enrolled reference —
/// this seam only ever produces the vector, never a match verdict.
abstract interface class FaceEmbedder {
  Future<List<double>> embed(FaceImageRgb face);

  /// Identifies the model that produced [embed]'s output — sent to the server
  /// as `face.modelTag` (see [mobileFaceNetModelTag]).
  String get modelTag;
}

/// Normalizes one 0..255 pixel channel to the MobileFaceNet input range:
/// `(x - 127.5) / 128`. A pure helper — no plugin dependency, directly testable.
double normalizePixel(int channelValue) => (channelValue - 127.5) / 128.0;

/// L2-normalizes an embedding vector to unit length — the standard MobileFaceNet
/// post-processing step so a server-side cosine-similarity match reduces to a
/// plain dot product. A pure helper — directly testable.
List<double> l2Normalize(List<double> vector) {
  var sumSquares = 0.0;
  for (final v in vector) {
    sumSquares += v * v;
  }
  final norm = math.sqrt(sumSquares);
  if (norm == 0) return List<double>.from(vector);
  return [for (final v in vector) v / norm];
}

/// Converts a row-major RGB byte buffer into the `[1, size, size, 3]` Float32
/// input tensor MobileFaceNet expects, normalizing each channel with
/// [normalizePixel]. A pure helper — directly testable without a real
/// interpreter. Throws [ArgumentError] when [image] is not exactly
/// `size x size` RGB.
List<List<List<List<double>>>> imageToInputTensor(
  FaceImageRgb image, {
  int size = mobileFaceNetInputSize,
}) {
  if (image.width != size || image.height != size) {
    throw ArgumentError(
      'Face image must be ${size}x$size for the embedder, got '
      '${image.width}x${image.height}',
    );
  }
  final expectedBytes = size * size * 3;
  if (image.bytes.length != expectedBytes) {
    throw ArgumentError(
      'Expected $expectedBytes RGB bytes for a ${size}x$size image, got '
      '${image.bytes.length}',
    );
  }

  return List.generate(
    1,
    (_) => List.generate(
      size,
      (y) => List.generate(size, (x) {
        final offset = (y * size + x) * 3;
        return [
          normalizePixel(image.bytes[offset]),
          normalizePixel(image.bytes[offset + 1]),
          normalizePixel(image.bytes[offset + 2]),
        ];
      }),
    ),
  );
}

/// Real [FaceEmbedder] backed by a bundled MobileFaceNet TFLite model
/// (Slice 3 device adapter). Loads the interpreter lazily on first [embed] —
/// construction does NO plugin/asset I/O, so building this in a provider stays
/// safe in widget tests that never actually capture a face.
///
/// If the model asset is missing or fails to load, this throws
/// [AttendanceCaptureException] (`FACE_MODEL_MISSING`) — fail loud, NEVER a
/// fake embedding (see assets/models/README.md for the pending model drop-in).
class MobileFaceNetEmbedder implements FaceEmbedder {
  MobileFaceNetEmbedder({String assetPath = mobileFaceNetAssetPath})
      : _assetPath = assetPath;

  final String _assetPath;
  Interpreter? _interpreter;

  @override
  String get modelTag => mobileFaceNetModelTag;

  Future<Interpreter> _loadInterpreter() async {
    final existing = _interpreter;
    if (existing != null) return existing;
    try {
      final interpreter = await Interpreter.fromAsset(_assetPath);
      _interpreter = interpreter;
      return interpreter;
    } catch (_) {
      throw const AttendanceCaptureException(
        AttendanceCaptureStep.face,
        'FACE_MODEL_MISSING',
        'Face model is not bundled in this build. Contact support to enable '
            'face check-in.',
      );
    }
  }

  @override
  Future<List<double>> embed(FaceImageRgb face) async {
    final interpreter = await _loadInterpreter();
    final input = imageToInputTensor(face);
    final output = List.generate(
      1,
      (_) => List<double>.filled(mobileFaceNetOutputDims, 0.0),
    );
    interpreter.run(input, output);
    return l2Normalize(output.first);
  }
}
