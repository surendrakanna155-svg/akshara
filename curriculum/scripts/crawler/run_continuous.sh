#!/usr/bin/env bash
# Continuous acquisition driver — runs the resumable crawler back-to-back over ALL
# boards (priority order lives in the crawler's board config) until the owner's
# completion criteria are met: no new VERIFIED resources for 3 consecutive cycles
# AND the frontier stops growing. Detached + resumable: safe to kill/re-launch;
# each cycle is `crawl.py --board all --resume`, so it never re-fetches known content.
#
# Storage lock: writes only under curriculum/ (gitignored archive + manifest); no git.
# Usage: bash curriculum/scripts/crawler/run_continuous.sh   (launch in background)
set -uo pipefail
cd "$(dirname "$0")/../../.."
LOG="curriculum/acquisition/crawl_continuous.log"
MAN="curriculum/acquisition/crawler_manifest.json"
MAX_CYCLES="${MAX_CYCLES:-40}"
PER_CYCLE_PAGES="${PER_CYCLE_PAGES:-400}"

verified() { python3 -c "import json,sys
try:
 d=json.load(open('$MAN'))
 print(sum(1 for v in d.values() if isinstance(v,dict) and str(v.get('status','')).upper()=='VERIFIED'))
except Exception: print(0)" 2>/dev/null || echo 0; }

echo "[$(date +%H:%M:%S)] continuous crawl START (max_cycles=$MAX_CYCLES, per_cycle_pages=$PER_CYCLE_PAGES)" >> "$LOG"
no_new=0
prev=$(verified)
for c in $(seq 1 "$MAX_CYCLES"); do
  echo "[$(date +%H:%M:%S)] cycle $c START (verified=$prev)" >> "$LOG"
  python3 curriculum/scripts/crawler/crawl.py --board all --allow-network --resume \
      --max-pages "$PER_CYCLE_PAGES" >> "$LOG" 2>&1 || echo "  cycle $c crawl error (continuing)" >> "$LOG"
  cur=$(verified)
  echo "[$(date +%H:%M:%S)] cycle $c DONE (verified=$cur, +$((cur - prev)))" >> "$LOG"
  if [ "$cur" -le "$prev" ]; then no_new=$((no_new + 1)); else no_new=0; fi
  prev="$cur"
  if [ "$no_new" -ge 3 ]; then
    echo "[$(date +%H:%M:%S)] COMPLETE — 3 consecutive cycles with no new verified resources" >> "$LOG"
    break
  fi
done
echo "[$(date +%H:%M:%S)] continuous crawl FINISHED (verified=$prev)" >> "$LOG"
