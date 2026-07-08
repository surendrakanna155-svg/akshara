#!/usr/bin/env bash
# Clean-slate reset for a fresh re-crawl. Moves EVERY persistent acquisition store
# to a timestamped, gitignored backup (curriculum/archives/, non-destructive) so the
# crawler AND the certified VerificationEngine start from nothing.
#
# WHY every store: the engine dedups new downloads against a PERSISTENT
# curriculum/indexes/checksum_index.json. If a "fresh" crawl is started with that
# index (or cache/, metadata/resources/) left in place, genuinely-new content whose
# sha256 was seen in a prior run is marked DUPLICATE and NOT saved — verified-but-not-
# on-disk (silent data loss). Resetting resources/ alone is NOT enough. (Learned the
# hard way: a re-crawl deduped 136 distinct PDFs against a stale index.)
#
# Usage: bash curriculum/scripts/crawler/reset_archive.sh [label]
set -uo pipefail
cd "$(dirname "$0")/../../.."
TS="${1:-$(date +%Y%m%d-%H%M%S)}"
BK="curriculum/archives/reset-$TS"
mkdir -p "$BK"
echo "clean-slate reset -> $BK (non-destructive)"
mv curriculum/indexes/*.json         "$BK/" 2>/dev/null && echo "  indexes/*.json (checksum dedup index + catalogues)"
[ -d curriculum/cache ]              && mv curriculum/cache "$BK/cache" 2>/dev/null && echo "  cache/"
[ -d curriculum/metadata/resources ] && mv curriculum/metadata/resources "$BK/metadata_resources" 2>/dev/null && echo "  metadata/resources/ (per-file .metadata.json)"
[ -d curriculum/resources ]          && mv curriculum/resources "$BK/resources" 2>/dev/null && echo "  resources/ (archive)"
mv curriculum/acquisition/crawler_state.json  "$BK/" 2>/dev/null && echo "  crawler_state.json (frontier)"
mv curriculum/acquisition/crawl_continuous.log "$BK/" 2>/dev/null
cp curriculum/acquisition/crawler_manifest.json "$BK/crawler_manifest.json" 2>/dev/null
echo '{}' > curriculum/acquisition/crawler_manifest.json
echo "reset complete. indexes/.gitkeep preserved: $([ -f curriculum/indexes/.gitkeep ] && echo yes || echo NO)"
