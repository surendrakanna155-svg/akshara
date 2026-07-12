#!/usr/bin/env python3
"""Official curriculum universe wave — discover → reconcile → acquire → report.

Replaces the narrow 148-cell subject matrix with evidence-derived per-book slots.
Atomic: DISCOVER → IMMEDIATE DOWNLOAD → VERIFY per source. No OCR.

Usage:
  run_official_universe_wave.py [--board all|cbse|ap|telangana|icse] [--dry-run]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "reports", "acquisition"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, write_json, utcnow  # noqa: E402
from source_probe import probe_url  # noqa: E402
import downloader  # noqa: E402
import official_universe  # noqa: E402
import build_provenance  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "official_universe_wave.log"
REPORT_JSON = WORKSPACE_ROOT / "reports" / "OFFICIAL_UNIVERSE_RECONCILIATION.json"
REPORT_MD = WORKSPACE_ROOT / "reports" / "OFFICIAL_UNIVERSE_RECONCILIATION.md"
MATRIX_JSON = WORKSPACE_ROOT / "reports" / "CANONICAL_CURRICULUM_MATRIX.json"

BOARD_FILTER = {
    "cbse": {"CBSE"},
    "ap": {"APSCERT"},
    "telangana": {"TSSCERT"},
    "icse": {"CISCE"},
    "all": {"CBSE", "APSCERT", "TSSCERT", "CISCE"},
}


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_disk_inventory(ws: Workspace) -> dict:
    root = ws.p("resources_dir") / "curriculum"
    inv: dict[str, dict] = {}
    by_name: dict[str, list] = defaultdict(list)
    by_code: dict[str, list] = defaultdict(list)
    count = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".pdf", ".zip"}:
            continue
        count += 1
        rel = str(path.relative_to(ws.root))
        try:
            sha = _sha256(path)
            info = {"path": rel, "size": path.stat().st_size, "name": path.name, "sha256": sha}
            inv[sha] = info
            by_name[path.name.lower()].append(info)
            m = re.search(r"Textbook-([a-z]{2,5}\d{1,2})", path.name, re.I)
            if m:
                by_code[m.group(1).lower()].append(info)
        except OSError:
            pass
    return {"file_count": count, "hashes": inv, "by_name": dict(by_name), "by_ncert_code": dict(by_code)}


def _final_path(ws: Workspace, entry: dict) -> Path:
    return ws.p("resources_dir") / entry.get("destination", "") / entry.get("expected_filename", "")


def _reconcile_slot(ws: Workspace, entry: dict, inv: dict) -> tuple[str, str | None, str | None]:
    """Return (status, local_path, sha256)."""
    fp = _final_path(ws, entry)
    if fp.is_file() and fp.stat().st_size > 0:
        return "EXISTING_CANONICAL", str(fp.relative_to(ws.root)), _sha256(fp)

    # NCERT book code match anywhere on disk
    code = entry.get("ncert_book_code", "")
    if code:
        for info in inv.get("by_ncert_code", {}).get(code.lower(), []):
            return "EXISTING_EQUIVALENT", info["path"], info["sha256"]

    # AP doc_id dedupe
    doc_id = entry.get("public_view_doc_id")
    if doc_id:
        completed = load_json(ws.pm("completed_downloads"), []) or []
        for c in completed:
            if doc_id in (c.get("original_url") or ""):
                lp = c.get("local_path") or c.get("final_path")
                if lp:
                    p = ws.root / lp if not Path(lp).is_absolute() else Path(lp)
                    if p.is_file():
                        return "EXISTING_EQUIVALENT", str(p.relative_to(ws.root)), _sha256(p)

    # Filename stem fuzzy match
    expected = entry.get("expected_filename", "").lower()
    stem = expected.rsplit(".", 1)[0][:40]
    for name, infos in inv.get("by_name", {}).items():
        if stem[:25] in name:
            info = infos[0]
            return "EXISTING_EQUIVALENT", info["path"], info["sha256"]

    return "MISSING", None, None


def _classify_outcome(entry: dict, verification_status: str | None) -> str:
    lic = entry.get("license_status", "")
    qp = entry.get("qp_scope", "")
    if lic == "PROVENANCE_QUALIFIED_MIRROR_NCERT_CONTENT":
        return "PROVENANCE_QUALIFIED_MIRROR_NCERT_CONTENT"
    if lic.startswith("UNOFFICIAL"):
        return "THIRD_PARTY_PROVENANCE_REVIEW"
    if qp == "BILINGUAL_SOURCE_ENGLISH_PRESENT":
        return "BILINGUAL_SOURCE_ENGLISH_PRESENT"
    if "OFFICIAL" in lic or "DIKSHA" in lic:
        return "VERIFIED_OFFICIAL_SOURCE"
    return "VERIFIED_OFFICIAL_SOURCE"


def _acquire_one(ws: Workspace, entry: dict, engine, rules: dict,
                 inv: dict, *, dry_run: bool) -> dict:
    outcome = {
        "slot_id": entry.get("slot_id"),
        "resource_id": entry.get("resource_id"),
        "board": entry.get("board"),
        "class_label": entry.get("class_label"),
        "official_subject": entry.get("official_subject"),
        "book_title": entry.get("book_title"),
        "resource_type": entry.get("resource_type"),
        "qp_scope": entry.get("qp_scope"),
        "source_url": entry.get("source_url"),
        "classification": "UNKNOWN",
        "local_path": None,
        "sha256": None,
        "detail": None,
    }

    status, path, sha = _reconcile_slot(ws, entry, inv)
    if status in ("EXISTING_CANONICAL", "EXISTING_EQUIVALENT"):
        outcome["classification"] = (
            "VERIFIED_EXISTING_SOURCE" if status == "EXISTING_CANONICAL"
            else "VERIFIED_EXISTING_EQUIVALENT"
        )
        outcome["local_path"] = path
        outcome["sha256"] = sha
        outcome["detail"] = status
        return outcome

    url = entry.get("source_url")
    if not url:
        outcome["classification"] = "SOURCE_MISSING"
        outcome["detail"] = "no source_url"
        return outcome

    pr = probe_url(url, referer=entry.get("source_portal"))
    if not pr["ok"] and entry.get("gdrive_file_id"):
        pr = {"ok": True, "reason": "GDRIVE_SKIP_PROBE"}
    if not pr["ok"] and "loadsupdocumentuploadbyid" in url:
        pr = {"ok": True, "reason": "AP_OFFICIAL_SKIP_PROBE"}
    if not pr["ok"] and "ncert.nic.in/textbook/pdf" in url:
        pr = {"ok": True, "reason": "NCERT_OFFICIAL_SKIP_PROBE"}
    if not pr["ok"] and "diksha.gov.in" in url:
        pr = {"ok": True, "reason": "DIKSHA_OFFICIAL_SKIP_PROBE"}
    if not pr["ok"] and "ncertbooks.net" in url:
        pr = {"ok": True, "reason": "NCERT_PATH_MIRROR_SKIP_PROBE"}
    if not pr["ok"]:
        outcome["classification"] = "DOWNLOAD_FAILED"
        outcome["detail"] = f"PROBE_FAIL {pr.get('reason')}"
        return outcome

    if dry_run:
        outcome["classification"] = "WOULD_DOWNLOAD"
        outcome["detail"] = "dry-run"
        return outcome

    ok, incoming, note = downloader._fetch(entry, ws, rules, allow_network=True)
    if not ok or not incoming:
        outcome["classification"] = "DOWNLOAD_FAILED"
        outcome["detail"] = f"FETCH_FAIL {note}"
        return outcome

    result = engine.verify_resource(entry, incoming)
    outcome["sha256"] = result.sha256
    outcome["local_path"] = result.final_path

    if result.status == "VERIFIED":
        outcome["classification"] = _classify_outcome(entry, result.status)
        outcome["detail"] = result.final_path
    elif result.status == "DUPLICATE":
        outcome["classification"] = "VERIFIED_EXISTING_EQUIVALENT"
        outcome["detail"] = result.detail
    else:
        outcome["classification"] = "DOWNLOAD_FAILED"
        outcome["detail"] = f"VERIFY_FAIL {result.reason_code}: {result.detail}"

    time.sleep(rules["networking"].get("polite_delay_seconds", 1))
    return outcome


def _render_report_md(report: dict) -> str:
    lines = [
        "# Official Curriculum Universe — Reconciliation Report",
        "",
        f"Generated: {report['generated_at']}",
        "",
        "## Summary",
        "",
        f"| Metric | Value |",
        f"|--------|------:|",
        f"| Previous expected matrix size | {report['previous_matrix_size']} |",
        f"| Corrected official source universe size | {report['corrected_universe_size']} |",
        f"| Missed subjects/resources discovered | {report['missed_discovered']} |",
        f"| Existing sources reused | {report['existing_reused']} |",
        f"| New files downloaded | {report['new_files_downloaded']} |",
        f"| Total verified/acquired source slots | {report['total_verified_acquired']} |",
        f"| Remaining genuine source gaps | {report['genuine_gaps']} |",
        f"| Third-party provenance-review | {report['third_party']} |",
        f"| Bilingual English-present | {report['bilingual']} |",
        f"| Commercial/legal blockers | {report['commercial_blockers']} |",
        f"| Ready for OCR/extraction | {report['ocr_ready']} |",
        "",
        "## A. Official Subject Universe (by board)",
        "",
    ]
    for board, subjects in sorted(report.get("subject_universe", {}).items()):
        lines.append(f"### {board}")
        for cls, subs in sorted(subjects.items()):
            lines.append(f"- **{cls}**: {', '.join(sorted(set(subs)))}")
        lines.append("")

    lines.extend(["## G. Genuinely Missing Sources", ""])
    for g in report.get("gap_list", []):
        lines.append(f"- **{g['board']} {g['class_label']}** — {g['official_subject']}: "
                     f"{g['book_title']} ({g.get('note', g['classification'])})")

    lines.extend(["", "## H. Commercial / Legally Blocked", ""])
    lines.append(f"Total ICSE commercial textbook slots: {report['commercial_blockers']}")

    lines.extend(["", "## New Downloads This Run", ""])
    for nd in report.get("new_download_list", [])[:50]:
        lines.append(f"- {nd['board']} {nd['class_label']} {nd['official_subject']}: {nd.get('local_path','')}")
    if len(report.get("new_download_list", [])) > 50:
        lines.append(f"- ... and {len(report['new_download_list']) - 50} more")

    return "\n".join(lines) + "\n"


def run_wave(board: str, *, dry_run: bool) -> dict:
    ws = Workspace(WORKSPACE_ROOT)
    allowed = BOARD_FILTER[board]
    rules = dict(ws.config("download_rules"))
    rules["allow_network"] = True
    engine = get_engine(WORKSPACE_ROOT)

    log(f"=== OFFICIAL UNIVERSE WAVE board={board} dry_run={dry_run} ===")

    # Step 1: Discover official universe
    universe = official_universe.discover_all(ws)
    slots = [s for s in universe["slots"] if s.get("board") in allowed]
    log(f"universe: {len(slots)} in-scope slots (total {universe['corrected_universe_size']})")

    # Step 2: Reconcile disk
    baseline_inv = build_disk_inventory(ws)
    baseline_count = baseline_inv["file_count"]
    log(f"baseline disk: {baseline_count} PDF/ZIP files")

    # Step 3: Atomic acquire
    outcomes: list[dict] = []
    stats = Counter()
    new_downloads: list[dict] = []
    reused: list[dict] = []

    for entry in slots:
        oc = _acquire_one(ws, entry, engine, rules, baseline_inv, dry_run=dry_run)
        outcomes.append(oc)
        stats[oc["classification"]] += 1
        if oc["classification"] in ("VERIFIED_OFFICIAL_SOURCE",
                                    "BILINGUAL_SOURCE_ENGLISH_PRESENT",
                                    "THIRD_PARTY_PROVENANCE_REVIEW",
                                    "NCERT_OFFICIAL_CHAPTER_PATH_MIRROR") and not dry_run:
            new_downloads.append(oc)
        if oc["classification"] in ("VERIFIED_EXISTING_SOURCE", "VERIFIED_EXISTING_EQUIVALENT"):
            reused.append(oc)
        log(f"  {entry.get('board')} {entry.get('class_label')} "
            f"{entry.get('official_subject')} [{entry.get('resource_type')}] "
            f"→ {oc['classification']} {str(oc.get('detail',''))[:50]}")

    post_inv = build_disk_inventory(ws)
    post_count = post_inv["file_count"]

    # Update queue + provenance
    if not dry_run:
        queue = load_json(ws.pm("download_queue"), []) or []
        have = {e.get("resource_id") for e in queue}
        for entry in slots:
            if entry["resource_id"] not in have:
                queue.append(entry)
                have.add(entry["resource_id"])
        write_json(ws.pm("download_queue"), queue)
        try:
            build_provenance.build(ws)
        except Exception as exc:
            log(f"provenance rebuild note: {exc}")
        engine.generate_report()

    # Build subject universe map
    subject_universe: dict[str, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    for s in slots:
        b = s.get("board", "")
        cl = s.get("class_label", "")
        sub = s.get("official_subject", "")
        subject_universe[b][cl].append(sub)

    gaps = [g for g in universe["gaps"] if g.get("board") in allowed]
    commercial = universe["commercial"]

    verified = sum(1 for o in outcomes if o["classification"] in (
        "VERIFIED_OFFICIAL_SOURCE", "VERIFIED_EXISTING_SOURCE",
        "VERIFIED_EXISTING_EQUIVALENT", "BILINGUAL_SOURCE_ENGLISH_PRESENT",
        "THIRD_PARTY_PROVENANCE_REVIEW", "NCERT_OFFICIAL_CHAPTER_PATH_MIRROR",
    ))
    third_party = sum(
        1 for s, o in zip(slots, outcomes)
        if s.get("qp_scope") == "THIRD_PARTY_PROVENANCE_REVIEW"
        and o["classification"] in ("VERIFIED_OFFICIAL_SOURCE", "VERIFIED_EXISTING_SOURCE",
                                    "VERIFIED_EXISTING_EQUIVALENT", "THIRD_PARTY_PROVENANCE_REVIEW")
    )
    bilingual = sum(
        1 for s, o in zip(slots, outcomes)
        if s.get("qp_scope") == "BILINGUAL_SOURCE_ENGLISH_PRESENT"
        and o["classification"] in ("VERIFIED_OFFICIAL_SOURCE", "VERIFIED_EXISTING_SOURCE",
                                    "VERIFIED_EXISTING_EQUIVALENT", "BILINGUAL_SOURCE_ENGLISH_PRESENT")
    )
    missed = universe["corrected_universe_size"] - universe["previous_matrix_size"]

    report = {
        "generated_at": utcnow(),
        "wave": "OFFICIAL_UNIVERSE_ACQUISITION",
        "board_filter": board,
        "dry_run": dry_run,
        "previous_matrix_size": universe["previous_matrix_size"],
        "corrected_universe_size": universe["corrected_universe_size"],
        "missed_discovered": missed,
        "existing_reused": len(reused),
        "new_files_downloaded": post_count - baseline_count,
        "new_verified_acquisitions": len(new_downloads),
        "total_verified_acquired": verified,
        "trusted_extraction_ready_count": universe.get("provenance_reconciliation", {}).get(
            "trusted_extraction_ready_count", verified),
        "genuine_gaps": len(gaps),
        "reconciliation_note": (
            "Prior report mixed universe slots (acquirable) with parallel gap entries "
            "(non-acquirable). Universe size counts slots only; gaps are separate and "
            "must not be subtracted from verified totals."
        ),
        "third_party": third_party,
        "bilingual": bilingual,
        "commercial_blockers": len(commercial),
        "ocr_ready": "YES" if verified > 0 and not dry_run else "NO",
        "baseline_file_count": baseline_count,
        "post_file_count": post_count,
        "outcome_stats": dict(stats),
        "by_board": universe["by_board"],
        "by_resource_type": universe["by_resource_type"],
        "subject_universe": {b: dict(v) for b, v in subject_universe.items()},
        "gap_list": gaps,
        "commercial_list": commercial,
        "language_register": universe["language_register"],
        "new_download_list": new_downloads,
        "outcomes": outcomes,
    }

    # Canonical matrix
    matrix = {
        "generated_at": utcnow(),
        "authority": "official_board_catalogues",
        "slot_count": len(slots),
        "slots": [{
            "slot_id": s.get("slot_id"),
            "board": s.get("board"),
            "class_label": s.get("class_label"),
            "medium": s.get("medium"),
            "official_subject": s.get("official_subject"),
            "book_title": s.get("book_title"),
            "part_volume": s.get("part_volume"),
            "resource_type": s.get("resource_type"),
            "qp_scope": s.get("qp_scope"),
            "ncert_book_code": s.get("ncert_book_code"),
            "discovery_evidence": s.get("discovery_evidence"),
            "source_url": s.get("source_url"),
        } for s in slots],
    }
    write_json(MATRIX_JSON, matrix)
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(_render_report_md(report), encoding="utf-8")

    log(f"=== WAVE DONE baseline={baseline_count} post={post_count} "
        f"verified={verified} gaps={report['genuine_gaps']} stats={dict(stats)} ===")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", choices=list(BOARD_FILTER), default="all")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    run_wave(args.board, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
