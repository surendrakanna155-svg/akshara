#!/usr/bin/env python3
"""Rebuild PROVENANCE_MANIFEST.json from the verified repository state.

The provenance manifest is the ONLY curriculum-acquisition artifact committed to
Git (owner local-storage lock, 2026-07-08): raw PDFs/ZIPs + derived knowledge are
LOCAL ONLY. This manifest records what was acquired, from where, and its sha256 so
the local repository is reproducible. It is regenerated (never hand-edited) by
joining COMPLETED_DOWNLOADS.json (sha/bytes/url/path) with DOWNLOAD_QUEUE.json
(title/board/class/subject/license) — a superset of the prior CBSE-SQP manifest.

Usage: build_provenance.py [--workspace DIR]
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402
from provenance_tier import license_to_tier  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def build(ws: Workspace) -> dict:
    completed = load_json(ws.pm("completed_downloads"), []) or []
    queue = {e["resource_id"]: e for e in (load_json(ws.pm("download_queue"), []) or [])}

    resources = []
    for c in completed:
        rid = c.get("resource_id")
        q = queue.get(rid, {})
        dest = c.get("destination_path") or ""
        local = f"curriculum/{dest}" if dest and not dest.startswith("curriculum/") else dest
        resources.append({
            "resource_id": rid,
            "title": q.get("title", rid),
            "board": q.get("board"),
            "class_label": q.get("class_label"),
            "subject": q.get("subject"),
            "document_type": q.get("document_type"),
            "resource_category": q.get("resource_category"),
            "academic_year": q.get("academic_year"),
            "publisher": q.get("publisher"),
            "source_url": c.get("original_url") or c.get("source_url") or q.get("source_url"),
            "source_page_url": q.get("source_page_url"),
            "source_website": q.get("source_website"),
            "sha256": c.get("checksum_sha256") or c.get("sha256"),
            "bytes": c.get("file_size_bytes"),
            "verification_status": c.get("verification_status", c.get("status", "VERIFIED")),
            "verified_at": c.get("verified_at"),
            "acquisition_date": c.get("acquired_at") or c.get("verified_at"),
            "license_status": q.get("license_status"),
            "license_note": q.get("license_note"),
            "provenance_tier": q.get("provenance_tier") or license_to_tier(q.get("license_status")),
            "assessment_subtype": q.get("assessment_subtype"),
            "local_path": local,
            "ncert_book_code": q.get("ncert_book_code"),
        })
    resources.sort(key=lambda r: r["resource_id"])

    # documented gaps (NOT_PUBLICLY_AVAILABLE) recorded in the queue
    gaps = [{
        "resource_id": e["resource_id"],
        "board": e.get("board"),
        "class_label": e.get("class_label"),
        "subject": e.get("subject"),
        "document_type": e.get("document_type"),
        "original_filename": e.get("original_filename"),
        "source_url": e.get("source_url"),
        "status": e.get("status"),
        "reason": e.get("last_note") or "not publicly available at official source this cycle",
    } for e in queue.values() if e.get("status") == "NOT_PUBLICLY_AVAILABLE"]
    gaps.sort(key=lambda g: g["resource_id"])

    by_board = Counter(r["board"] for r in resources)
    by_board_bytes: dict[str, int] = {}
    for r in resources:
        by_board_bytes[r["board"]] = by_board_bytes.get(r["board"], 0) + (r["bytes"] or 0)

    return {
        "_manifest": ("Provenance manifest — the ONLY curriculum-acquisition artifact committed to Git "
                      "(owner local-storage lock, 2026-07-08). Raw PDFs/ZIPs + all derived/AI-generated "
                      "knowledge are LOCAL ONLY and NOT committed. This manifest records what was acquired, "
                      "from where, and its sha256 so the local repository is reproducible."),
        "generated_at": utcnow(),
        "usage": "blueprint/pattern analysis + local archive only — no content republishing (owner D-8 / L2)",
        "totals": {
            "verified_resources": len(resources),
            "total_bytes": sum(r["bytes"] or 0 for r in resources),
            "documented_gaps": len(gaps),
            "by_board": dict(by_board),
            "by_board_bytes": by_board_bytes,
            "by_category": dict(Counter(r["resource_category"] for r in resources)),
            "by_provenance_tier": dict(Counter(r.get("provenance_tier", "UNKNOWN") for r in resources)),
        },
        "sources": {
            "cbse_sqp": "https://cbseacademic.nic.in/web_material/SQP/ClassX_2025_26/",
            "cbse_curriculum": "https://cbseacademic.nic.in/curriculum_2026.html",
            "ncert_textbooks": "https://ncert.nic.in/textbook.php",
            "ap_scert_textbooks": "https://cse.ap.gov.in/textBooksDownloadingPagetitleWise",
            "trusted_assessment": "configs/trusted_assessment_sources.json",
        },
        "resources": resources,
        "documented_gaps": gaps,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    manifest = build(ws)
    out = ws.root / "PROVENANCE_MANIFEST.json"
    write_json(out, manifest)
    t = manifest["totals"]
    print(f"provenance manifest: {t['verified_resources']} resources, "
          f"{t['total_bytes']/1_048_576:.1f} MiB, {t['documented_gaps']} gaps → {out}")
    print(f"  by board: {t['by_board']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
