#!/usr/bin/env bash
# Regenerate the self-hosted Material Symbols font (perf WEB-002: 4.5 MB → ~408 KB).
# The size win comes ENTIRELY from INSTANCING the variable font to wght=400/opsz=24
# while KEEPING the FILL axis (for filled icons). ALL glyphs + ligatures are kept
# (--glyphs='*'), so NO icon can ever go missing — safe by construction. (Text-based
# subsetting was rejected: Material Symbols icons are ligatures sharing the same
# letters, so it can't shrink safely and risks dropping used icons.)
#
#   bash scripts/build_icon_font.sh
#
# Requires fonttools + brotli (one-off): python3 -m venv .venv-fonts &&
#   .venv-fonts/bin/pip install fonttools brotli
set -euo pipefail
cd "$(dirname "$0")/.."

PY=.venv-fonts/bin
SRC=node_modules/material-symbols/material-symbols-rounded.woff2
OUT=public/fonts/material-symbols-rounded-subset.woff2
mkdir -p public/fonts

"$PY/fonttools" varLib.instancer "$SRC" wght=400 GRAD=0 opsz=24 --output=/tmp/ms-fillaxis.ttf >/dev/null
"$PY/pyftsubset" /tmp/ms-fillaxis.ttf --glyphs='*' --layout-features='*' \
  --notdef-outline --recommended-glyphs --flavor=woff2 --output-file="$OUT" >/dev/null
ls -la "$OUT" | awk '{printf "icon font (all glyphs, instanced): %.1f KB\n", $5/1024}'
