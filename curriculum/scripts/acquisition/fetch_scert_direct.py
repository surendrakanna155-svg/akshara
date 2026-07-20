#!/usr/bin/env python3
"""Fetch official SCERT Telangana direct PDFs (immediate download + verify)."""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, write_json, utcnow, sanitize_filename  # noqa: E402
import downloader  # noqa: E402

# Probe-confirmed official SCERT direct PDFs (scert.telangana.gov.in)
OFFICIAL_SCERT: list[dict] = [
    {
        "resource_id": "AKS-TSSCERT-09-ENG-TEXT-SCERT-2025-000001",
        "board": "TSSCERT",
        "class_label": "Class_09",
        "subject": "English",
        "resource_category": "textbook",
        "document_type": "Textbook",
        "source_url": "https://scert.telangana.gov.in/pdf/publication/ebooks/9%20english-2024-25.pdf",
        "license_status": "OFFICIAL_PUBLIC_TS_SCERT_DIRECT",
        "expected_filename": "TSSCERT_Class_09_English_Textbook-SCERT_Our_World_through_English_2024-25_v1_English.pdf",
        "destination": "curriculum/telangana/Class_09/English/Textbooks",
    },
]


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _record(ws: Workspace, entry: dict, rel: str, sha: str) -> None:
    completed = load_json(ws.pm("completed_downloads"), []) or []
    row = {
        "resource_id": entry["resource_id"],
        "board": entry["board"],
        "class_label": entry["class_label"],
        "subject": entry["subject"],
        "resource_category": entry["resource_category"],
        "document_type": entry["document_type"],
        "license_status": entry["license_status"],
        "source_url": entry["source_url"],
        "local_path": rel,
        "sha256": sha,
        "status": "VERIFIED",
        "acquired_at": utcnow(),
        "acquisition_mode": "SCERT_DIRECT",
    }
    completed = [c for c in completed if c.get("resource_id") != entry["resource_id"]]
    completed.append(row)
    write_json(ws.pm("completed_downloads"), completed)


def fetch_one(ws: Workspace, entry: dict, engine) -> str:
    dest_dir = ws.p("resources_dir") / entry["destination"]
    dest_dir.mkdir(parents=True, exist_ok=True)
    final = dest_dir / entry["expected_filename"]
    if final.is_file() and final.stat().st_size > 10_000:
        return "EXISTING"

    rules = dict(ws.config("download_rules"))
    rules["allow_network"] = True
    ok, incoming, note = downloader._fetch(entry, ws, rules, True)
    if not ok:
        print(f"FETCH_FAIL {entry['resource_id']}: {note}")
        return "FETCH_FAIL"

    result = engine.verify_resource(dict(entry), incoming)
    if result.status not in ("VERIFIED", "DUPLICATE"):
        print(f"VERIFY_FAIL {entry['resource_id']}: {result.reason_code}")
        return "VERIFY_FAIL"

    shutil.copy2(incoming, final)
    rel = str(Path(entry["destination"]) / entry["expected_filename"])
    _record(ws, entry, rel, _sha256(final))
    print(f"OK {entry['board']} {entry['class_label']} {entry['subject']} -> {final.name}")
    return "VERIFIED"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    engine = get_engine(ws.root)
    stats: dict[str, int] = {}
    for entry in OFFICIAL_SCERT:
        outcome = fetch_one(ws, entry, engine)
        stats[outcome] = stats.get(outcome, 0) + 1
    print("DONE", stats)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
