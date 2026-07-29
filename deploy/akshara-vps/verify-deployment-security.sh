#!/usr/bin/env bash
# NIKSHA OS — deployment security verification.
#
# WHY THIS EXISTS
# The repo's own forced-auth test (eng4_5_forced_auth_test) asserts that
# sensitive routes reject anonymous callers, and it PASSES — while the deployed
# pilot answered them. The gap was never in the code: it is that a repo test
# cannot observe the RUNNING configuration. This script closes that gap by
# probing the deployment itself, from outside, with no credentials.
#
# Run it after every deploy. A green test suite is not evidence that the
# deployed system is configured correctly.
#
#   ./verify-deployment-security.sh https://your-host
#
# Exit 0 = all checks pass. Exit 1 = at least one FAIL. Nothing is mutated.
set -uo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  echo "usage: $0 <https://host>" >&2
  exit 2
fi

FAILURES=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILURES=$((FAILURES+1)); }

# NOTE: curl already prints 000 on a connection failure via -w, so a `|| echo`
# fallback would CONCATENATE and yield "000000". Capture, then default only when
# the output is empty.
code_of() { local c; c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$HOST$1" 2>/dev/null); echo "${c:-000}"; }
body_of() { curl -s --max-time 15 "$HOST$1" 2>/dev/null | head -c 400; }

echo "Deployment security verification — $HOST"
echo

# 1. Sensitive health endpoints must NOT answer an anonymous caller.
#    With APP_ENV=production and no INTERNAL_HEALTH_TOKEN the guard returns 403;
#    with a token configured and none supplied it also returns 403. Either way
#    an anonymous 200 means the deployment is NOT in production configuration.
echo "[1] Internal health endpoints reject anonymous access"
for p in /health/tenant-access /health/operations /health/providers /health/backup /health/storage; do
  c=$(code_of "$p")
  if [[ "$c" == "403" || "$c" == "401" ]]; then
    pass "$p -> $c"
  else
    fail "$p -> $c (expected 403/401; a 200 or 503-with-body means APP_ENV is not 'production' or the token is unset)"
  fi
done
echo

# 2. Liveness may stay open, but must disclose nothing.
echo "[2] Public liveness discloses nothing sensitive"
LIVE_BODY=$(body_of /health)
if grep -qiE 'bypassRls|role"|bucket|lastBackup|isolation|sha256|erp_tenant' <<<"$LIVE_BODY"; then
  fail "/health leaks internals: $(head -c 160 <<<"$LIVE_BODY")"
else
  pass "/health exposes no internals"
fi
echo

# 3. Authentication must precede validation — an anonymous caller must not be
#    told which parameters a route wants.
echo "[3] Auth precedes validation on protected routes"
for p in /attendance/register/monthly /audit/events /identity/roles; do
  c=$(code_of "$p")
  if [[ "$c" == "401" ]]; then
    pass "$p -> 401"
  elif [[ "$c" == "422" ]]; then
    fail "$p -> 422 (validated BEFORE authenticating — leaks the route's parameter contract)"
  else
    fail "$p -> $c (expected 401)"
  fi
done
echo

if (( FAILURES > 0 )); then
  echo "RESULT: $FAILURES check(s) FAILED — the deployment is not in production security configuration."
  echo "Most likely cause: APP_ENV is not 'production', or INTERNAL_HEALTH_TOKEN is unset."
  echo "Note: env vars are only re-read when the container is RECREATED, not restarted."
  exit 1
fi
echo "RESULT: all checks passed."
