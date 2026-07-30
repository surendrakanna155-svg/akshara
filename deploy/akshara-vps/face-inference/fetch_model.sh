#!/usr/bin/env bash
# Fetch + quantise the AuraFace recognition model into ./models.
#
# The model is NOT vendored into this repository. It is Apache-2.0 and freely
# redistributable, but a 63 MB binary in git is a poor trade when the upstream
# is stable and the provenance matters more than the convenience — fetching it
# by URL keeps the source of truth visible at deploy time.
#
# Source   : https://huggingface.co/fal/AuraFace-v1  (glintr100.onnx)
# Licence  : Apache-2.0
# Training : "commercially and publicly available data sources", per the model
#            card — the reason this model exists, since ArcFace's training data
#            forbids commercial use.
# See docs/engineering/FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/models"
SRC="https://huggingface.co/fal/AuraFace-v1/resolve/main/glintr100.onnx"
mkdir -p "$DIR"

if [ ! -f "$DIR/glintr100.onnx" ]; then
  echo "==> downloading glintr100.onnx (~249 MB)"
  curl -fL --retry 3 -o "$DIR/glintr100.onnx" "$SRC"
fi

if [ ! -f "$DIR/glintr100_int8.onnx" ]; then
  echo "==> quantising to int8 (249 MB -> ~63 MB, 222 MB RSS at runtime)"
  python3 -c "
from onnxruntime.quantization import quantize_dynamic, QuantType
quantize_dynamic('$DIR/glintr100.onnx', '$DIR/glintr100_int8.onnx', weight_type=QuantType.QUInt8)
print('quantised')
"
fi

# Face DETECTOR — MediaPipe BlazeFace short-range.
# Source  : Google, https://storage.googleapis.com/mediapipe-models/...
# Licence : Apache-2.0 (Google publishes MediaPipe model weights under it and
#           ships them in its own commercial products).
# Chosen over OpenCV's YuNet, which is MIT but trained on WIDER FACE whose
# commercial terms could not be established — the same provenance bar the
# recognition model was held to.
DET="$DIR/blaze_face_short_range.tflite"
if [ ! -f "$DET" ]; then
  echo "==> downloading blaze_face_short_range.tflite (~224 KB)"
  curl -fL --retry 3 -o "$DET" \
    "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite"
fi

echo "==> ready:"
ls -lh "$DIR"
echo
echo "int8 reproduces the fp32 embedding at 0.9941 mean cosine — same space,"
echo "so it needs no separate model tag and no separate threshold."
