#!/usr/bin/env bash
# QA-R-010 (P1 · monitoring/ops) — akshara-watchdog.sh PURE-LOGIC unit test.
#
# Drives deploy/akshara-vps/monitoring/akshara-watchdog.sh with every external
# command shimmed (curl / df / openssl / docker / date / hostname on a private
# PATH) so the watchdog's decision logic is exercised deterministically, with no
# network, no real disk, no real Docker, and a frozen clock.
#
# What it proves (the watchdog's load-bearing logic):
#   1. DISK threshold   — disk% >= DISK_WARN_PCT  ⇒ WARN  (and below ⇒ OK).
#   2. TLS cert math     — days_left <= CERT_WARN_DAYS ⇒ WARN (and above ⇒ OK).
#   3. COOLDOWN / RECOVERED state machine —
#        a WARN/CRIT inside the cooldown window is suppressed (no resend);
#        a check flipping back to OK while a .firing state exists emits exactly
#        one "RECOVERED:" alert and clears the state.
#   4. SEVERITY routing — CRIT alerts take the SMS (Fast2SMS) path AND the webhook;
#        WARN alerts are webhook-only (never SMS).
#
# Self-contained + deterministic. Run with:  bash qa_r_010_watchdog_logic_test.sh
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHDOG="$SELF_DIR/akshara-watchdog.sh"

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; printf '       %s\n' "$2"; }

# Asserts $1 (haystack file) contains $2 (needle).
assert_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then ok "$label"
  else bad "$label" "expected to find: <$needle> in $file:\n$(cat "$file" 2>/dev/null)"; fi
}
# Asserts $1 (haystack file) does NOT contain $2 (needle).
assert_absent() {
  local file="$1" needle="$2" label="$3"
  if ! grep -qF -- "$needle" "$file" 2>/dev/null; then ok "$label"
  else bad "$label" "did NOT expect: <$needle> in $file:\n$(cat "$file" 2>/dev/null)"; fi
}

# ─── shim factory ────────────────────────────────────────────────────────────
# Builds a private bin/ dir of shims for one scenario. Behaviour is parameterised
# via env vars the shims read at call time:
#   SHIM_HEALTH_CODE   http code returned by every health-endpoint curl (default 200)
#   SHIM_HEALTH_BODY   body returned by every health-endpoint curl (default healthy)
#   SHIM_DISK_PCT      df disk percent (default 10)
#   SHIM_CERT_ENDDATE  openssl x509 -enddate output (default far future)
#   SHIM_CERT_EPOCH    epoch `date -d "<enddate>"` resolves to (default far future)
#   SHIM_NOW_EPOCH     epoch `date +%s` resolves to (frozen clock)
#   SHIM_DOCKER_STATUS container .State.Status (default running)
#   SHIM_DOCKER_HEALTH container .State.Health.Status (default empty = no healthcheck)
# Every curl invocation is appended (full argv) to $CURL_CAPTURE.
make_shims() {
  local bin="$1"
  mkdir -p "$bin"

  cat > "$bin/curl" <<'SH'
#!/usr/bin/env bash
# Capture the full argv so the test can inspect which sink was hit.
printf '%s\n' "curl $*" >> "$CURL_CAPTURE"
args="$*"
# Alert sinks: webhook (POST to ALERT_WEBHOOK_URL) and Fast2SMS (fast2sms.com).
if [[ "$args" == *"fast2sms.com"* ]]; then
  printf '%s\n' "SMS_SENT" >> "$CURL_CAPTURE"; exit 0
fi
if [[ "$args" == *"-X POST"* ]]; then
  printf '%s\n' "WEBHOOK_SENT" >> "$CURL_CAPTURE"; exit 0
fi
# Otherwise this is a health-endpoint probe (uses -w '\n%{http_code}').
printf '%s\n%s' "${SHIM_HEALTH_BODY:-{\"status\":\"ok\",\"database\":true,\"reachable\":true}}" "${SHIM_HEALTH_CODE:-200}"
exit 0
SH

  cat > "$bin/df" <<'SH'
#!/usr/bin/env bash
# Emulate `df -P /` 2-line output; NR==2 field 5 is the use%.
echo "Filesystem 1024-blocks Used Available Capacity Mounted"
echo "/dev/disk 100 50 50 ${SHIM_DISK_PCT:-10}% /"
SH

  cat > "$bin/openssl" <<'SH'
#!/usr/bin/env bash
# `openssl x509 -enddate -noout -in <cert>` → "notAfter=<date>".
echo "notAfter=${SHIM_CERT_ENDDATE:-Jan 1 00:00:00 2099 GMT}"
SH

  cat > "$bin/date" <<'SH'
#!/usr/bin/env bash
# Frozen clock + cert-enddate resolution.
case "$*" in
  *"-d "*)   echo "${SHIM_CERT_EPOCH:-4070908800}" ;;   # date -d "<enddate>" +%s
  "+%s")     echo "${SHIM_NOW_EPOCH:-1000000000}" ;;     # date +%s (NOW)
  *"-u "*|*"+%Y"*) echo "2026-06-30T00:00:00Z" ;;        # ts()
  *)         echo "2026-06-30T00:00:00Z" ;;
esac
SH

  cat > "$bin/docker" <<'SH'
#!/usr/bin/env bash
# `docker inspect -f '{{.State.Status}}' <c>` and the health-status form.
args="$*"
if [[ "$args" == *".State.Health"* ]]; then
  echo "${SHIM_DOCKER_HEALTH:-}"
else
  echo "${SHIM_DOCKER_STATUS:-running}"
fi
SH

  cat > "$bin/hostname" <<'SH'
#!/usr/bin/env bash
echo "testhost"
SH

  chmod +x "$bin"/*
}

# Runs the watchdog once in an isolated sandbox with the given scenario env.
# Sets CURL_CAPTURE / LOGFILE / STATEDIR globals for the caller to inspect.
run_watchdog() {
  local sandbox; sandbox="$(mktemp -d)"
  local bin="$sandbox/bin"
  CURL_CAPTURE="$sandbox/curl.capture"; : > "$CURL_CAPTURE"
  STATEDIR="$sandbox/state";  mkdir -p "$STATEDIR"
  LOGDIR="$sandbox/log";      mkdir -p "$LOGDIR"
  LOGFILE="$LOGDIR/watchdog.log"
  make_shims "$bin"

  # A monitoring.env that turns on BOTH alert sinks so routing is observable, and
  # an internal-health token so the health-endpoint hdr path is exercised.
  local envfile="$sandbox/monitoring.env"
  cat > "$envfile" <<EOF
EDGE_BASE=http://127.0.0.1:3000
PUBLIC_DOMAIN=example.test
CERT_PATH=$sandbox/fullchain.pem
DISK_WARN_PCT=${ENV_DISK_WARN_PCT:-85}
CERT_WARN_DAYS=${ENV_CERT_WARN_DAYS:-14}
CONTAINERS=akshara-edge
INTERNAL_HEALTH_TOKEN=tok
ALERT_WEBHOOK_URL=https://webhook.test/hook
ALERT_SMS_PHONES=+910000000000
ALERT_SMS_API_KEY=smskey
ALERT_COOLDOWN_MIN=${ENV_COOLDOWN_MIN:-60}
STATE_DIR=$STATEDIR
LOG_DIR=$LOGDIR
APP_ENV_FILE=$sandbox/.env.akshara
EOF
  # A readable cert file so the `[[ -r "$CERT_PATH" ]]` branch is taken.
  echo "dummy-cert" > "$sandbox/fullchain.pem"

  # Run with the shims FIRST on PATH and MONITORING_ENV pointed at our env file.
  env -i \
    PATH="$bin:/usr/bin:/bin" \
    HOME="$sandbox" \
    MONITORING_ENV="$envfile" \
    CURL_CAPTURE="$CURL_CAPTURE" \
    SHIM_HEALTH_CODE="${SHIM_HEALTH_CODE:-200}" \
    SHIM_HEALTH_BODY="${SHIM_HEALTH_BODY:-{\"status\":\"ok\",\"database\":true,\"reachable\":true}}" \
    SHIM_DISK_PCT="${SHIM_DISK_PCT:-10}" \
    SHIM_CERT_ENDDATE="${SHIM_CERT_ENDDATE:-Jan 1 00:00:00 2099 GMT}" \
    SHIM_CERT_EPOCH="${SHIM_CERT_EPOCH:-4070908800}" \
    SHIM_NOW_EPOCH="${SHIM_NOW_EPOCH:-1000000000}" \
    SHIM_DOCKER_STATUS="${SHIM_DOCKER_STATUS:-running}" \
    SHIM_DOCKER_HEALTH="${SHIM_DOCKER_HEALTH:-}" \
    bash "$WATCHDOG" >/dev/null 2>&1
  SANDBOX="$sandbox"
}

echo "QA-R-010 — akshara-watchdog.sh pure-logic tests"
echo

# ─── 1. DISK threshold ───────────────────────────────────────────────────────
# Healthy endpoints + healthy containers; only disk varies. Frozen clock + far
# cert keep every OTHER check OK, isolating the disk decision.

# 1a: disk 90% >= 85% warn threshold ⇒ WARN logged + webhook fired.
SHIM_DISK_PCT=90 run_watchdog
assert_contains "$LOGFILE" "ALERT[WARN] disk usage 90% >= 85%" "disk 90% >= 85% ⇒ WARN alert"
assert_contains "$LOGFILE" "disk=90%!" "disk 90% summary flags '!'"

# 1b: disk 10% < 85% ⇒ no disk warn.
SHIM_DISK_PCT=10 run_watchdog
assert_absent "$LOGFILE" "disk usage" "disk 10% < 85% ⇒ no disk WARN"
assert_contains "$LOGFILE" "disk=10%" "disk 10% summary OK (no '!')"

# 1c: boundary — disk exactly == threshold ⇒ WARN (>= is inclusive).
ENV_DISK_WARN_PCT=80 SHIM_DISK_PCT=80 run_watchdog
assert_contains "$LOGFILE" "disk usage 80% >= 80%" "disk == threshold ⇒ WARN (inclusive)"

# ─── 2. TLS cert-days math ────────────────────────────────────────────────────
# days_left = (cert_epoch - NOW) / 86400. NOW frozen at SHIM_NOW_EPOCH.
NOW=1000000000

# 2a: cert 5 days out (<= 14) ⇒ WARN.  5*86400 = 432000.
SHIM_NOW_EPOCH=$NOW SHIM_CERT_EPOCH=$((NOW + 5*86400)) run_watchdog
assert_contains "$LOGFILE" "TLS cert expires in 5d" "cert 5d <= 14d ⇒ WARN"
assert_contains "$LOGFILE" "cert=5d!" "cert 5d summary flags '!'"

# 2b: cert 40 days out (> 14) ⇒ OK, no cert warn.
SHIM_NOW_EPOCH=$NOW SHIM_CERT_EPOCH=$((NOW + 40*86400)) run_watchdog
assert_absent "$LOGFILE" "TLS cert expires" "cert 40d > 14d ⇒ no cert WARN"
assert_contains "$LOGFILE" "cert=40d" "cert 40d summary OK (no '!')"

# 2c: boundary — exactly 14 days ⇒ WARN (<= is inclusive).
SHIM_NOW_EPOCH=$NOW SHIM_CERT_EPOCH=$((NOW + 14*86400)) run_watchdog
assert_contains "$LOGFILE" "TLS cert expires in 14d" "cert == 14d ⇒ WARN (inclusive)"

# ─── 3. Cooldown / RECOVERED state machine ───────────────────────────────────

# 3a: COOLDOWN — a firing check whose state file is RECENT (within the window)
# must NOT resend. Build a sandbox, SEED disk.firing == NOW (so the check is
# already firing as of the frozen clock), run with WARN-level disk, and assert the
# cooldown gate (NOW - last < cooldown) suppresses a second webhook for disk.
cooldown_sandbox="$(mktemp -d)"; cooldown_bin="$cooldown_sandbox/bin"
CURL_CAPTURE="$cooldown_sandbox/curl.capture"; : > "$CURL_CAPTURE"
STATEDIR="$cooldown_sandbox/state"; mkdir -p "$STATEDIR"
LOGDIR="$cooldown_sandbox/log"; mkdir -p "$LOGDIR"; LOGFILE="$LOGDIR/watchdog.log"
make_shims "$cooldown_bin"
echo "$NOW" > "$STATEDIR/disk.firing"          # seed: disk already firing AT now
cat > "$cooldown_sandbox/monitoring.env" <<EOF
EDGE_BASE=http://127.0.0.1:3000
CERT_PATH=$cooldown_sandbox/none.pem
DISK_WARN_PCT=85
CERT_WARN_DAYS=14
CONTAINERS=akshara-edge
ALERT_WEBHOOK_URL=https://webhook.test/hook
ALERT_SMS_PHONES=+910000000000
ALERT_SMS_API_KEY=smskey
ALERT_COOLDOWN_MIN=60
STATE_DIR=$STATEDIR
LOG_DIR=$LOGDIR
APP_ENV_FILE=$cooldown_sandbox/.env
EOF
env -i PATH="$cooldown_bin:/usr/bin:/bin" HOME="$cooldown_sandbox" \
  MONITORING_ENV="$cooldown_sandbox/monitoring.env" CURL_CAPTURE="$CURL_CAPTURE" \
  SHIM_HEALTH_CODE=200 SHIM_HEALTH_BODY='{"status":"ok","database":true,"reachable":true}' \
  SHIM_DISK_PCT=90 SHIM_NOW_EPOCH=$NOW SHIM_DOCKER_STATUS=running \
  bash "$WATCHDOG" >/dev/null 2>&1
# disk is still WARN-level, but state ts == NOW ⇒ (NOW-last < cooldown) ⇒ suppressed.
assert_absent "$LOGFILE" "ALERT[WARN] disk usage" "cooldown: recent firing state suppresses resend"

# 3b: RECOVERED — a check that was firing flips to OK ⇒ exactly one RECOVERED
# alert + the .firing state is removed. Seed disk.firing, then run with HEALTHY
# disk so the disk check resolves OK.
rec_sandbox="$(mktemp -d)"; rec_bin="$rec_sandbox/bin"
CURL_CAPTURE="$rec_sandbox/curl.capture"; : > "$CURL_CAPTURE"
STATEDIR="$rec_sandbox/state"; mkdir -p "$STATEDIR"
LOGDIR="$rec_sandbox/log"; mkdir -p "$LOGDIR"; LOGFILE="$LOGDIR/watchdog.log"
make_shims "$rec_bin"
echo "$((NOW - 99999))" > "$STATEDIR/disk.firing"   # was firing earlier
cat > "$rec_sandbox/monitoring.env" <<EOF
EDGE_BASE=http://127.0.0.1:3000
CERT_PATH=$rec_sandbox/none.pem
DISK_WARN_PCT=85
CONTAINERS=akshara-edge
ALERT_WEBHOOK_URL=https://webhook.test/hook
ALERT_SMS_PHONES=+910000000000
ALERT_SMS_API_KEY=smskey
ALERT_COOLDOWN_MIN=60
STATE_DIR=$STATEDIR
LOG_DIR=$LOGDIR
APP_ENV_FILE=$rec_sandbox/.env
EOF
env -i PATH="$rec_bin:/usr/bin:/bin" HOME="$rec_sandbox" \
  MONITORING_ENV="$rec_sandbox/monitoring.env" CURL_CAPTURE="$CURL_CAPTURE" \
  SHIM_HEALTH_CODE=200 SHIM_HEALTH_BODY='{"status":"ok","database":true,"reachable":true}' \
  SHIM_DISK_PCT=10 SHIM_NOW_EPOCH=$NOW SHIM_DOCKER_STATUS=running \
  bash "$WATCHDOG" >/dev/null 2>&1
assert_contains "$LOGFILE" "ALERT[OK] RECOVERED: disk ok" "recovered: firing→OK emits one RECOVERED alert"
if [[ ! -f "$STATEDIR/disk.firing" ]]; then ok "recovered: .firing state cleared after recovery"
else bad "recovered: .firing state cleared after recovery" "disk.firing still present"; fi

# ─── 4. Severity routing — CRIT ⇒ SMS+webhook, WARN ⇒ webhook-only ───────────

# 4a: CRIT — make a health endpoint fail (api_ready DOWN). check_endpoint logs
# CRIT, which routes to BOTH webhook and Fast2SMS.
SHIM_HEALTH_CODE=503 SHIM_HEALTH_BODY='{"status":"degraded"}' run_watchdog
assert_contains "$LOGFILE" "ALERT[CRIT]" "CRIT: failing endpoint logs CRIT alert"
assert_contains "$CURL_CAPTURE" "SMS_SENT"     "CRIT ⇒ Fast2SMS (SMS) path taken"
assert_contains "$CURL_CAPTURE" "WEBHOOK_SENT" "CRIT ⇒ webhook path also taken"

# 4b: WARN — only disk warns (everything else healthy). WARN ⇒ webhook only, NO SMS.
SHIM_DISK_PCT=90 run_watchdog
assert_contains "$LOGFILE" "ALERT[WARN]"     "WARN: disk warns at WARN severity"
assert_contains "$CURL_CAPTURE" "WEBHOOK_SENT" "WARN ⇒ webhook path taken"
assert_absent  "$CURL_CAPTURE" "SMS_SENT"      "WARN ⇒ NO SMS (Fast2SMS path not taken)"

# 4c: container down ⇒ CRIT (container_* check) ⇒ SMS path.
SHIM_DOCKER_STATUS=exited run_watchdog
assert_contains "$LOGFILE" "container akshara-edge is exited" "container down ⇒ CRIT message"
assert_contains "$CURL_CAPTURE" "SMS_SENT" "container down (CRIT) ⇒ SMS path taken"

echo
echo "watchdog tests: ${PASS} passed / ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
