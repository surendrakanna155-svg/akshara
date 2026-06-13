#!/usr/bin/env bash
# Install Maestro CLI (macOS / Linux) — idempotent.
set -euo pipefail

export PATH="${HOME}/.maestro/bin:${PATH}"

if command -v maestro >/dev/null 2>&1; then
  echo "Maestro already installed: $(maestro --version 2>&1 | head -1)"
  exit 0
fi

echo "==> Installing Maestro..."
curl -Ls "https://get.maestro.mobile.dev" | bash
export PATH="${HOME}/.maestro/bin:${PATH}"
maestro --version
echo "==> Add to shell profile: export PATH=\"\${HOME}/.maestro/bin:\${PATH}\""
