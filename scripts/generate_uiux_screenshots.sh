#!/usr/bin/env bash
# Regenerates UI screenshots into docs/UIUX/ from golden test assets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter test test/golden/ --update-goldens

mkdir -p docs/UIUX

copy_golden() {
  local src="test/golden/goldens/${1}"
  local dest="docs/UIUX/${1}"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
    echo "copied $dest"
  fi
}

for prefix in \
  parent_dashboard \
  teacher_dashboard \
  student_dashboard \
  management_dashboard \
  finance_dashboard \
  inventory_dashboard \
  intelligence_dashboard
do
  for size in 390x844 428x926 834x1194; do
    copy_golden "${prefix}_${size}.png"
  done
done

echo "UIUX screenshots refreshed in docs/UIUX/"
