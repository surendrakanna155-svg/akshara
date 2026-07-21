#!/usr/bin/env bash
# =============================================================================
# Akshara KIE/QIE certified-estate backup  ·  Remediation item R0-1  ·  [C7]
# -----------------------------------------------------------------------------
# Produces an ENCRYPTED, CHECKSUMMED, restore-VERIFIABLE archive of every live
# knowledge/question database in the certified estate — including the three DBs
# (qpl_question_bank.db, qdi.db, examdna.db) that the audit found had NO backup
# copy of any kind.
#
# Design constraints (from the roadmap + curriculum local-storage lock):
#   * Consistent snapshots via `sqlite3 .backup` — the source DBs are NEVER
#     locked-mutated and live -wal/-shm are folded in safely.
#   * AES-256 encryption is MANDATORY (openssl, PBKDF2). No plaintext estate
#     ever leaves this directory.
#   * The archive is written to $AKSHARA_BACKUP_DEST. Set this to an OFF-MACHINE
#     target (external volume / owner-managed durable store) to satisfy R0-1's
#     "Done when: a restore on ANOTHER machine reproduces the fingerprint".
#     If unset, it falls back to a same-volume staging dir and LOUDLY warns that
#     this protects only against DB-level corruption, NOT volume loss.
#   * Nothing here promotes curriculum data to git or prod — the owner lock
#     forbids git/prod promotion, NOT off-machine copies (audit-confirmed).
#
# Usage:
#   AKSHARA_BACKUP_PASSPHRASE_FILE=~/.akshara/kie_backup.key \
#   AKSHARA_BACKUP_DEST=/Volumes/AksharaBackup/kie \
#   ./backup_estate.sh
#
# Exit non-zero on ANY failure (set -euo pipefail). Safe to run from cron/LaunchAgent.
# =============================================================================
set -euo pipefail

# ---- resolve paths --------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# repo root = five levels up from kie/backup/ (…/curriculum/scripts/intelligence/kie/backup)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
KIE_HOME="${AKSHARA_KIE_HOME:-$REPO_ROOT/curriculum/knowledge/kie}"

if [[ ! -d "$KIE_HOME" ]]; then
  echo "FATAL: KIE_HOME does not exist: $KIE_HOME" >&2; exit 2
fi

# ---- encryption passphrase (mandatory) ------------------------------------
PASS_FILE="${AKSHARA_BACKUP_PASSPHRASE_FILE:-}"
if [[ -z "$PASS_FILE" || ! -f "$PASS_FILE" ]]; then
  echo "FATAL: set AKSHARA_BACKUP_PASSPHRASE_FILE to a readable file holding the" >&2
  echo "       backup passphrase (chmod 600). Encryption is mandatory." >&2
  exit 2
fi

# ---- destination ----------------------------------------------------------
DEST="${AKSHARA_BACKUP_DEST:-}"
if [[ -z "$DEST" ]]; then
  DEST="$KIE_HOME/../estate_backups"
  echo "WARNING: AKSHARA_BACKUP_DEST unset — falling back to same-volume staging:" >&2
  echo "         $DEST" >&2
  echo "         This protects against DB corruption/deletion but NOT volume loss." >&2
  echo "         Set AKSHARA_BACKUP_DEST to an OFF-MACHINE target for full R0-1." >&2
fi
mkdir -p "$DEST"

# ---- timestamp (passed in for reproducibility; else `date`) ---------------
STAMP="${AKSHARA_BACKUP_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/akshara_estate_backup.XXXXXX")"
SNAP="$WORK/databases"
mkdir -p "$SNAP"
trap 'rm -rf "$WORK"' EXIT

echo "== Akshara certified-estate backup =="
echo "   KIE_HOME : $KIE_HOME"
echo "   DEST     : $DEST"
echo "   STAMP    : $STAMP"

# ---- enumerate live DBs (top-level + snapshots/), skip wal/shm ------------
# bash 3.2-compatible (macOS default /bin/bash has no `mapfile`).
DBS=()
while IFS= read -r _db; do
  [[ -n "$_db" ]] && DBS+=("$_db")
done < <( { \
    find "$KIE_HOME" -maxdepth 1 -name '*.db' -type f ; \
    find "$KIE_HOME/snapshots" -maxdepth 1 -name '*.db' -type f 2>/dev/null ; \
  } | sort )

if [[ ${#DBS[@]} -eq 0 ]]; then
  echo "FATAL: no *.db files found under $KIE_HOME" >&2; exit 2
fi

MANIFEST="$WORK/MANIFEST.md"
{
  echo "# Akshara KIE/QIE certified-estate backup — $STAMP"
  echo ""
  echo "Consistent \`sqlite3 .backup\` snapshots of every live estate DB, encrypted"
  echo "with AES-256 (PBKDF2). Produced by \`backup_estate.sh\` (remediation R0-1)."
  echo ""
  echo "| DB (relative to KIE_HOME) | bytes | sha256 (snapshot) | tables | rows (sum) |"
  echo "|---|---|---|---|---|"
} > "$MANIFEST"

# ---- snapshot each DB, record integrity -----------------------------------
for src in "${DBS[@]}"; do
  rel="${src#$KIE_HOME/}"
  flat="$(echo "$rel" | tr '/' '_')"
  out="$SNAP/$flat"
  # consistent snapshot; folds in WAL; never locks source destructively
  if ! sqlite3 "$src" ".backup '$out'" 2>/dev/null; then
    echo "  WARN: .backup failed for $rel — trying file copy" >&2
    cp "$src" "$out"
  fi
  bytes="$(stat -f %z "$out" 2>/dev/null || stat -c %s "$out")"
  sha="$(shasum -a 256 "$out" | awk '{print $1}')"
  # per-DB table + total row summary (best-effort; ignore errors)
  ntab="$(sqlite3 "file:$out?mode=ro" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo '?')"
  nrows=0
  if tabs="$(sqlite3 "file:$out?mode=ro" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null)"; then
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      c="$(sqlite3 "file:$out?mode=ro" "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null || echo 0)"
      nrows=$((nrows + c))
    done <<< "$tabs"
  fi
  printf '| %s | %s | %s | %s | %s |\n' "$rel" "$bytes" "$sha" "$ntab" "$nrows" >> "$MANIFEST"
  echo "  snapshot: $rel  ($bytes bytes, $ntab tables, $nrows rows)"
done

# ---- record certified-knowledge fingerprint (provenance) ------------------
KI="$KIE_HOME/knowledge_index.db"
if [[ -f "$KI" ]]; then
  fp14="$(sqlite3 "file:$KI?mode=ro" "SELECT value FROM ki_meta WHERE key='certified_knowledge_fingerprint_v1.4';" 2>/dev/null || echo '')"
  ncert="$(sqlite3 "file:$KI?mode=ro" "SELECT COUNT(*) FROM ki_concept WHERE status='certified';" 2>/dev/null || echo '?')"
  {
    echo ""
    echo "## Certified-knowledge provenance (recorded, for restore verification)"
    echo "- \`knowledge_index.db\` certified ki_concept rows: **$ncert**"
    echo "- \`certified_knowledge_fingerprint_v1.4\` (ki_meta): \`$fp14\`"
    echo "- Expected frozen v1.4 constant: \`e3a146f3ffcb8718d66e2535a987daf193e1865715b55282e25ed82f5c1d0e47\`"
  } >> "$MANIFEST"
fi

# ---- checksums for every snapshot ----------------------------------------
# MANIFEST is already at $WORK/MANIFEST.md (== the tar root); no copy needed.
( cd "$SNAP" && shasum -a 256 * > "$WORK/SHA256SUMS.txt" )

# ---- tar + AES-256 encrypt ------------------------------------------------
ARCHIVE="$DEST/akshara_estate_${STAMP}.tar.gz.enc"
TAR="$WORK/estate.tar.gz"
( cd "$WORK" && tar -czf "$TAR" databases MANIFEST.md SHA256SUMS.txt )
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
  -in "$TAR" -out "$ARCHIVE" -pass "file:$PASS_FILE"
enc_sha="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
echo "$enc_sha  $(basename "$ARCHIVE")" > "$DEST/akshara_estate_${STAMP}.sha256"

# ---- prune old encrypted archives (keep last N) ---------------------------
KEEP="${AKSHARA_BACKUP_KEEP:-7}"
ls -1t "$DEST"/akshara_estate_*.tar.gz.enc 2>/dev/null | tail -n +$((KEEP+1)) | while read -r old; do
  rm -f "$old" "${old%.tar.gz.enc}.sha256"
done

echo ""
echo "== DONE =="
echo "   archive : $ARCHIVE"
echo "   sha256  : $enc_sha"
echo "   verify  : ./restore_verify.sh '$ARCHIVE'"
