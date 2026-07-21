#!/usr/bin/env bash
# =============================================================================
# Verify an Akshara certified-estate backup is genuinely restorable  ·  R0-1
# -----------------------------------------------------------------------------
# Decrypts the archive to a scratch dir, re-checks every snapshot's sha256
# against the embedded SHA256SUMS.txt, and independently RECOMPUTES the frozen
# v1.4 certified-knowledge fingerprint from the restored knowledge_index.db,
# asserting it equals both the manifest-recorded value and the known constant
# e3a146f3…  — i.e. the backup is a genuine, restorable estate.
#
# This is the R0-1 "restore on another machine reproduces the fingerprint" check;
# run it wherever the archive lands (ideally the off-machine target).
#
# Usage:  AKSHARA_BACKUP_PASSPHRASE_FILE=~/.akshara/kie_backup.key \
#         ./restore_verify.sh /path/to/akshara_estate_STAMP.tar.gz.enc
# =============================================================================
set -euo pipefail

ARCHIVE="${1:-}"
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  echo "usage: restore_verify.sh <archive.tar.gz.enc>" >&2; exit 2
fi
PASS_FILE="${AKSHARA_BACKUP_PASSPHRASE_FILE:-}"
if [[ -z "$PASS_FILE" || ! -f "$PASS_FILE" ]]; then
  echo "FATAL: set AKSHARA_BACKUP_PASSPHRASE_FILE to the passphrase file." >&2; exit 2
fi

EXPECTED_V14="e3a146f3ffcb8718d66e2535a987daf193e1865715b55282e25ed82f5c1d0e47"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/akshara_restore_verify.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "== restore-verify: $(basename "$ARCHIVE") =="

# ---- decrypt + extract ----------------------------------------------------
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$ARCHIVE" -out "$WORK/estate.tar.gz" -pass "file:$PASS_FILE"
tar -xzf "$WORK/estate.tar.gz" -C "$WORK"

# ---- checksum every snapshot ----------------------------------------------
( cd "$WORK/databases" && shasum -a 256 -c "$WORK/SHA256SUMS.txt" ) \
  && echo "  [OK] all snapshot checksums match" \
  || { echo "  [FAIL] snapshot checksum mismatch" >&2; exit 1; }

# ---- recompute the v1.4 certified-knowledge fingerprint -------------------
KI="$WORK/databases/knowledge_index.db"
if [[ ! -f "$KI" ]]; then
  echo "  [FAIL] restored archive has no knowledge_index.db" >&2; exit 1
fi
recomputed="$(python3 - "$KI" <<'PY'
import sqlite3, sys, hashlib
db = sys.argv[1]
c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
# method (ki_meta.v14_method): sha256 of newline-joined SORTED
# concept_id|canonical_name|subject|taught_at_class|academic_discipline|section_heading|evidence_chunks
# over status='certified' rows.
rows = c.execute("""
  SELECT concept_id, canonical_name, subject, taught_at_class,
         academic_discipline, section_heading, evidence_chunks
  FROM ki_concept WHERE status='certified'
""").fetchall()
lines = ["|".join("" if v is None else str(v) for v in r) for r in rows]
lines.sort()
print(hashlib.sha256("\n".join(lines).encode()).hexdigest())
PY
)"
recorded="$(sqlite3 "file:$KI?mode=ro" "SELECT value FROM ki_meta WHERE key='certified_knowledge_fingerprint_v1.4';" 2>/dev/null || echo '')"

echo "  recomputed v1.4 fingerprint : $recomputed"
echo "  recorded   (ki_meta)        : $recorded"
echo "  constant   (expected)       : $EXPECTED_V14"

if [[ "$recomputed" == "$EXPECTED_V14" && "$recorded" == "$EXPECTED_V14" ]]; then
  echo "  [OK] fingerprint EXACT MATCH — backup is a genuine, restorable v1.4 estate"
  echo "== VERIFY PASS =="
else
  echo "  [FAIL] fingerprint mismatch — backup is NOT a faithful v1.4 estate" >&2
  exit 1
fi
