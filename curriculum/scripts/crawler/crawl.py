#!/usr/bin/env python3
"""crawl.py — continuous acquisition crawler CLI orchestrator.

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md.
Builds the MOST COMPLETE official curriculum repository by continuously
discovering (sitemap / link-following / direct-PDF probe / search-hook),
downloading, and verifying (V1-V11, via the certified ``verification_engine``)
resources across the five target boards (CBSE, NCERT, AP SCERT, TS SCERT,
CISCE), Classes 6-10. Goal = completeness, not speed.

Resumable + idempotent: safe to Ctrl-C and re-run.
  * ``frontier.py``  persists queued/visited/known-hash state -> crawler_state.json
  * ``manifest.py``  persists the per-resource ledger      -> crawler_manifest.json
both under ``curriculum/acquisition/`` by default.

Network is OFF by default (``--allow-network`` opts in) so ``--dry-run`` (and
CI) never makes an HTTP call — it only exercises seeding/classification/resume
wiring against the config-declared board seed URLs.

Usage:
  crawl.py --dry-run                                   # wiring check, no network
  crawl.py --board cbse --allow-network --max-pages 25  # one bounded session
  crawl.py --board all  --allow-network --resume        # continuous full crawl
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent          # curriculum/scripts/crawler
_COMMON = _SCRIPTS.parent / "common"
_VERIFICATION = _SCRIPTS.parent / "verification"
for _p in (_SCRIPTS, _COMMON, _VERIFICATION):
    p = str(_p)
    if p not in sys.path:
        sys.path.insert(0, p)

import discovery  # noqa: E402
import fetch as fetch_mod  # noqa: E402
import manifest  # noqa: E402
import verify  # noqa: E402
from frontier import Frontier  # noqa: E402
from workspace import Workspace, get_engine, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]  # curriculum/
ACQUISITION_DIR = WORKSPACE_ROOT / "acquisition"
STATE_PATH = ACQUISITION_DIR / "crawler_state.json"
MANIFEST_PATH = ACQUISITION_DIR / "crawler_manifest.json"

MAX_LINK_DEPTH = 4  # depth-bounded link-following (spec §Discovery.2)
MAX_RESOURCE_RETRIES = 2  # matches configs/retry_rules.json max_retries_per_source


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fold_in_existing_archive(ws: Workspace, fr: Frontier, manifest_path: Path) -> int:
    """Register the sha256 of every already-downloaded resource (the existing
    archive under resources/, plus any prior crawler_manifest entries) so the
    crawler never re-fetches content it already has.

    Spec: "Fold in the existing ~138-PDF archive (dedup — do not re-fetch)."
    """
    folded = 0
    resources_dir = ws.p("resources_dir")
    if resources_dir.is_dir():
        for path in resources_dir.rglob("*"):
            if path.is_file():
                sha = _sha256_file(path)
                if not fr.has_hash(sha):
                    fr.record_hash(sha, local_path=str(path), source="existing_archive")
                    folded += 1
    for rid, rec in manifest.load(manifest_path).items():
        sha = rec.get("sha256")
        if sha and not fr.has_hash(sha):
            fr.record_hash(sha, resource_id=rid, local_path=rec.get("local_path"), source="crawler_manifest")
            folded += 1
    return folded


def seed_frontier(fr: Frontier, board_filter: list[str]) -> int:
    """Seed the frontier from the per-board sitemap + section-landing-page
    targets (spec §Targets). Idempotent — already-queued/visited URLs are
    silently skipped by ``Frontier.add()``."""
    seeded = 0
    for board_key, cfg in discovery.BOARD_DOMAINS.items():
        if board_filter and board_key not in board_filter:
            continue
        for url in cfg.get("sitemaps", []):
            if fr.add(url, depth=0, kind="sitemap", discovered_via="config_seed", board=board_key):
                seeded += 1
        for url in cfg.get("seeds", []):
            if fr.add(url, depth=0, kind="page", discovered_via="config_seed", board=board_key):
                seeded += 1
    return seeded


def _board_list(arg: str) -> list[str]:
    if not arg or arg.lower() == "all":
        return []
    return [b.strip() for b in arg.split(",") if b.strip()]


def _process_sitemap(fr: Frontier, fetcher, rec: dict, board_key: str) -> None:
    result = fetcher.get(rec["url"])
    if not result.ok or result.body is None:
        fr.mark_visited(rec["url"], status=f"FETCH_FAILED:{result.status}", last_checked=utcnow())
        return
    parsed = discovery.parse_sitemap(result.body)
    for sm in parsed["sitemaps"]:
        fr.add(sm, depth=rec["depth"] + 1, kind="sitemap", discovered_via=rec["url"], board=board_key)
    for u in parsed["urls"]:
        kind = "resource" if discovery.is_resource_url(u) else "page"
        fr.add(u, depth=rec["depth"] + 1, kind=kind, discovered_via=rec["url"], board=board_key)
    fr.mark_visited(rec["url"], status="PARSED", last_checked=utcnow(),
                    evidence=f"{len(parsed['sitemaps'])} sub-sitemaps, {len(parsed['urls'])} urls")


def _process_page(fr: Frontier, fetcher, rec: dict, board_key: str, cfg: dict) -> None:
    url = rec["url"]
    if rec["depth"] >= MAX_LINK_DEPTH:
        fr.mark_visited(url, status="DEPTH_LIMIT", last_checked=utcnow())
        return
    if cfg.get("blocked"):
        found = discovery.search_discover(discovery.domain_of(url), "syllabus textbook class 6 7 8 9 10")
        for u in found:
            kind = "resource" if discovery.is_resource_url(u) else "page"
            fr.add(u, depth=rec["depth"] + 1, kind=kind, discovered_via=f"search:{url}", board=board_key)
        fr.mark_visited(url, status="BLOCKED_USED_SEARCH_HOOK", last_checked=utcnow(),
                        evidence=f"{len(found)} candidates from search hook")
        return
    result = fetcher.get(url)
    if not result.ok or result.body is None:
        fr.mark_visited(url, status=f"FETCH_FAILED:{result.status}", last_checked=utcnow())
        return
    host = discovery.domain_of(url)
    added = 0
    for link in discovery.extract_links(result.body, url):
        link_board = discovery.board_for_domain(discovery.domain_of(link))
        if discovery.domain_of(link) != host and link_board != board_key:
            continue  # same-domain only (spec §Discovery.2)
        kind = "resource" if discovery.is_resource_url(link) else "page"
        if kind == "page" and not discovery.looks_like_section(link):
            continue  # stay on-topic: only follow section-like landing pages
        if fr.add(link, depth=rec["depth"] + 1, kind=kind, discovered_via=url, board=board_key):
            added += 1
    fr.mark_visited(url, status="CRAWLED", last_checked=utcnow(), evidence=f"{added} links enqueued")


def _process_resource(fr: Frontier, fetcher, engine, ws: Workspace, records: dict,
                      rec: dict, board_key: str) -> dict:
    url = rec["url"]
    classification = verify.classify(url, board_key)
    ext = Path(url.split("?", 1)[0]).suffix.lstrip(".").lower() or "pdf"
    seq_key = f"{classification['board']}-{classification['class_code']}-{classification['subject_code']}-{classification['category']}"
    seq = fr.next_seq(seq_key)
    expected = verify.build_expected(ws, classification, url, ext, seq)

    retry_count = rec.get("meta", {}).get("retry_count", 0)
    incoming = ws.p("downloads_incoming")
    dest = incoming / expected["expected_filename"]
    result = fetcher.get_to_file(url, dest)

    if not result.ok or not result.path:
        exhausted = retry_count >= MAX_RESOURCE_RETRIES
        status = "NOT_PUBLICLY_AVAILABLE" if exhausted else "RETRY_PENDING"
        evidence = f"http={result.status} {result.reason}"[:200]
        fr.mark_visited(url, status=status, last_checked=utcnow(), evidence=evidence)
        if not exhausted:
            fr.add(url, depth=rec["depth"], kind="resource", discovered_via=rec.get("discovered_via", ""),
                  board=board_key, meta={"retry_count": retry_count + 1})
        manifest.upsert(records, expected["resource_id"], board=classification["board"],
                        class_label=classification["class_label"], subject=classification["subject"],
                        url=url, status=status, verification="NOT_VERIFIED", last_checked=utcnow(),
                        retry_count=retry_count + 1, discovered_via=rec.get("discovered_via", ""),
                        evidence=evidence)
        return {"downloaded": False, "verified": False}

    vres = verify.verify_file(engine, expected, result.path)
    if vres.sha256 and not fr.has_hash(vres.sha256):
        fr.record_hash(vres.sha256, resource_id=expected["resource_id"], source="crawl")

    status = {"VERIFIED": "VERIFIED", "DUPLICATE": "VERIFIED", "FAILED": "FAILED"}.get(vres.status, "FAILED")
    manifest.upsert(records, expected["resource_id"], board=classification["board"],
                    class_label=classification["class_label"], subject=classification["subject"],
                    url=url, status="DOWNLOADED" if status == "FAILED" else status,
                    verification=vres.status, last_checked=utcnow(), retry_count=retry_count,
                    sha256=vres.sha256, local_path=vres.final_path,
                    discovered_via=rec.get("discovered_via", ""), evidence=vres.detail or "")
    fr.mark_visited(url, status=status, last_checked=utcnow())
    return {"downloaded": True, "verified": vres.status == "VERIFIED"}


def run(*, board: str = "all", resume: bool = True, max_pages: int = 25,
        allow_network: bool = False, dry_run: bool = False,
        workspace_root: Path = WORKSPACE_ROOT, state_path: Path = STATE_PATH,
        manifest_path: Path = MANIFEST_PATH) -> dict:
    ws = Workspace(workspace_root)
    board_filter = _board_list(board)

    fr = Frontier.load(state_path) if resume else Frontier(state_path)
    folded = fold_in_existing_archive(ws, fr, manifest_path)
    seeded = seed_frontier(fr, board_filter)
    records = manifest.load(manifest_path)

    stats = {
        "folded_hashes": folded, "seeded": seeded, "pages_processed": 0,
        "resources_downloaded": 0, "resources_verified": 0,
        "network": bool(allow_network) and not dry_run,
    }

    if dry_run or not allow_network:
        # Wiring/seed check only — no HTTP calls. Queued items stay queued so
        # a later --allow-network run resumes straight into real discovery.
        fr.save(state_path)
        manifest.save(manifest_path, records)
        stats["frontier"] = fr.stats()
        stats["manifest_summary"] = manifest.summary(records)
        return stats

    fetcher = fetch_mod.Fetcher()
    engine = get_engine(workspace_root)
    robots = discovery.RobotsCache(lambda u: fetcher.text(u))

    pages = 0
    while pages < max_pages:
        rec = fr.pop()
        if rec is None:
            break
        url = rec["url"]
        board_key = rec.get("board") or discovery.board_for_domain(discovery.domain_of(url)) or ""
        cfg = discovery.BOARD_DOMAINS.get(board_key, {})

        if not robots.allowed(url, fetcher.user_agent):
            fr.mark_visited(url, status="ROBOTS_DISALLOWED", last_checked=utcnow())
            pages += 1
            continue

        if rec["kind"] == "sitemap":
            _process_sitemap(fr, fetcher, rec, board_key)
        elif rec["kind"] == "page":
            _process_page(fr, fetcher, rec, board_key, cfg)
        else:  # "resource": download -> verify -> manifest
            outcome = _process_resource(fr, fetcher, engine, ws, records, rec, board_key)
            if outcome["downloaded"]:
                stats["resources_downloaded"] += 1
            if outcome["verified"]:
                stats["resources_verified"] += 1
        pages += 1

        if pages % 5 == 0:  # periodic checkpoint: a kill mid-run loses <5 pages
            fr.save(state_path)
            manifest.save(manifest_path, records)

    fr.save(state_path)
    manifest.save(manifest_path, records)
    stats["pages_processed"] = pages
    stats["frontier"] = fr.stats()
    stats["manifest_summary"] = manifest.summary(records)
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--board", default="all",
                    help="board key(s), comma-separated: cbse,ap,telangana,icse or 'all' (default)")
    ap.add_argument("--resume", action="store_true", default=True,
                    help="resume from crawler_state.json (default on — the crawler is always resumable)")
    ap.add_argument("--no-resume", dest="resume", action="store_false",
                    help="start with a fresh frontier, ignoring saved state")
    ap.add_argument("--max-pages", type=int, default=25,
                    help="pages/resources to process this invocation (default 25)")
    ap.add_argument("--allow-network", action="store_true", default=False,
                    help="perform real HTTP calls (default OFF)")
    ap.add_argument("--dry-run", action="store_true", default=False,
                    help="seed + validate wiring only, never touches the network")
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()

    stats = run(board=args.board, resume=args.resume, max_pages=args.max_pages,
                allow_network=args.allow_network, dry_run=args.dry_run,
                workspace_root=args.workspace)
    print(f"crawl: {stats}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
