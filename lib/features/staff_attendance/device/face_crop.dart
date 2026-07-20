import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'face_embedder.dart';

/// An integer, image-bounds-clamped crop rectangle.
class CropRect {
  const CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

/// Expands ML Kit's tight face [boundingBox] by [marginFraction] on each side
/// (so the embedder sees some context around the face, not just landmarks),
/// then clamps to the still image's bounds. Pure geometry — no `image` package
/// dependency — directly testable.
CropRect computeFaceCropRect({
  required int imageWidth,
  required int imageHeight,
  required Rect boundingBox,
  double marginFraction = 0.25,
}) {
  final marginX = boundingBox.width * marginFraction;
  final marginY = boundingBox.height * marginFraction;

  final left = (boundingBox.left - marginX).clamp(0, imageWidth.toDouble());
  final top = (boundingBox.top - marginY).clamp(0, imageHeight.toDouble());
  final right =
      (boundingBox.right + marginX).clamp(0, imageWidth.toDouble());
  final bottom =
      (boundingBox.bottom + marginY).clamp(0, imageHeight.toDouble());

  final width = (right - left).clamp(1, imageWidth.toDouble());
  final height = (bottom - top).clamp(1, imageHeight.toDouble());

  return CropRect(
    x: left.round(),
    y: top.round(),
    width: width.round(),
    height: height.round(),
  );
}

/// Bakes the JPEG EXIF orientation into the pixel data (audit R1, P2-1).
///
/// ML Kit's `InputImage.fromFilePath` honors the EXIF orientation tag, so its
/// bounding boxes are in the ORIENTED space — but `img.decodeImage` returns the
/// raw sensor pixels UNORIENTED. On devices that write orientation tags the two
/// spaces diverge (rotated/mirrored), the crop lands on the wrong pixels, and
/// the server match is guaranteed to fail. Baking first puts the decoded pixels
/// into the same oriented space the bounding boxes were computed in.
/// (No-op when the image carries no orientation tag / orientation == 1.)
img.Image bakeStillOrientation(img.Image decoded) => img.bakeOrientation(decoded);

/// Crops [crop] out of the decoded still [image], resizes it to the embedder's
/// `size x size` input, and returns raw row-major RGB bytes. Impure (uses the
/// `image` package's pixel codec) — the geometry itself is [computeFaceCropRect].
FaceImageRgb cropAndResizeForEmbedder(
  img.Image image,
  CropRect crop, {
  int size = mobileFaceNetInputSize,
}) {
  final cropped = img.copyCrop(
    image,
    x: crop.x,
    y: crop.y,
    width: crop.width,
    height: crop.height,
  );
  final resized = img.copyResize(
    cropped,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  final Uint8List rgb = resized.getBytes(order: img.ChannelOrder.rgb);
  return FaceImageRgb(width: size, height: size, bytes: rgb);
}
