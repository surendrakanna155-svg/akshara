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
STATE="curriculum/acquisition/crawler_state.json"
MAX_CYCLES="${MAX_CYCLES:-40}"
PER_CYCLE_PAGES="${PER_CYCLE_PAGES:-400}"

# NOTE: the manifest field is capital-S "Status" (manifest.py FIELDNAMES); an
# earlier lowercase "status" read here made verified() return 0 every cycle, so
# the "3 no-new" test fired on cycle 3 while the crawl was actively verifying
# hundreds/cycle (false completion). Read the correct field.
verified() { python3 -c "import json
try:
 d=json.load(open('$MAN'))
 print(sum(1 for v in d.values() if isinstance(v,dict) and str(v.get('Status','')).upper()=='VERIFIED'))
except Exception: print(0)" 2>/dev/null || echo 0; }

# Pending frontier work — completion must ALSO require the frontier to have
# drained, else a plateau of all-retry cycles would look like "done".
queued() { python3 -c "import json
try:
 d=json.load(open('$STATE')); q=d.get('queued',[])
 print(len(q) if isinstance(q,(list,dict)) else 0)
except Exception: print(-1)" 2>/dev/null || echo -1; }

echo "[$(date +%H:%M:%S)] continuous crawl START (max_cycles=$MAX_CYCLES, per_cycle_pages=$PER_CYCLE_PAGES)" >> "$LOG"
no_new=0
prev=$(verified)
for c in $(seq 1 "$MAX_CYCLES"); do
  echo "[$(date +%H:%M:%S)] cycle $c START (verified=$prev)" >> "$LOG"
  python3 curriculum/scripts/crawler/crawl.py --board all --allow-network --resume \
      --max-pages "$PER_CYCLE_PAGES" >> "$LOG" 2>&1 || echo "  cycle $c crawl error (continuing)" >> "$LOG"
  cur=$(verified)
  q=$(queued)
  echo "[$(date +%H:%M:%S)] cycle $c DONE (verified=$cur, +$((cur - prev)), frontier_queued=$q)" >> "$LOG"
  if [ "$cur" -le "$prev" ]; then no_new=$((no_new + 1)); else no_new=0; fi
  prev="$cur"
  # Complete only when BOTH conditions hold: no new verified for 3 cycles AND the
  # frontier has drained (queued==0). A non-empty queue means there is still work.
  if [ "$no_new" -ge 3 ] && [ "$q" = "0" ]; then
    echo "[$(date +%H:%M:%S)] COMPLETE — 3 consecutive no-new cycles AND frontier drained (queued=0)" >> "$LOG"
    break
  fi
done
echo "[$(date +%H:%M:%S)] continuous crawl FINISHED (verified=$prev)" >> "$LOG"
