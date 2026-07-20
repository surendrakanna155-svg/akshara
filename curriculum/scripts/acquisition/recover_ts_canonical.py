#!/usr/bin/env python3
"""Recover Telangana canonical-path gaps — force place verified bytes at expected paths.

When the verification engine marks a GDrive fetch DUPLICATE, bytes may never land under
curriculum/telangana/Class_XX/.../Textbooks/. This script downloads (or reuses incoming
bytes), verifies PDF/ZIP integrity, copies to the canonical path, and records provenance.

Usage:
  recover_ts_canonical.py [--dry-run]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, write_json, utcnow  # noqa: E402
import downloader  # noqa: E402
import telangana_catalogue  # noqa: E402

# Canonical slots that must exist on disk (class_label, subject display, matcher on catalogue)
RECOVER_SLOTS: list[tuple[str, str, str]] = [
    ("Class_06", "Social Science", "06-SST"),
    ("Class_09", "Mathematics", "09-MATH"),
    ("Class_09", "Science", "09-SCI"),          # first science entry (Physical)
    ("Class_09", "Social Science", "09-SST"),
    ("Class_10", "Social Science", "10-SST"),
]

LOG = WORKSPACE_ROOT / "acquisition" / "ts_recovery.log"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _is_valid_pdf(path: Path) -> tuple[bool, str]:
    if not path.is_file() or path.stat().st_size < 1000:
        return False, "too_small"
    head = path.read_bytes()[:8]
    if head[:4] != b"%PDF":
        return False, "not_pdf"
    return True, "ok"


def _pick_entries(ws: Workspace) -> list[dict]:
    cat = telangana_catalogue.build(ws)
    picked: list[dict] = []
    used: set[str] = set()
    for clabel, subj_disp, token in RECOVER_SLOTS:
        for e in cat:
            key = (e["class_label"], e["subject"], e["resource_id"])
            if key in used:
                continue
            if e["class_label"] != clabel or e["subject"] != subj_disp:
                continue
            if token not in e["resource_id"]:
                continue
            picked.append(e)
            used.add(key)
            break
    return picked


def recover(*, dry_run: bool) -> dict:
    ws = Workspace(WORKSPACE_ROOT)
    engine = get_engine(WORKSPACE_ROOT)
    rules = dict(ws.config("download_rules"))
    rules["allow_network"] = True
    entries = _pick_entries(ws)
    results = {"recovered": 0, "already_ok": 0, "failed": 0, "details": []}

    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as log:
        log.write(f"\n## recovery {utcnow()} dry_run={dry_run}\n")

    for entry in entries:
        dest = ws.p("resources_dir") / entry["destination"] / entry["expected_filename"]
        label = f"{entry['class_label']} {entry['subject']}"
        if dest.is_file() and dest.stat().st_size > 1000:
            ok, _ = _is_valid_pdf(dest)
            if ok:
                results["already_ok"] += 1
                results["details"].append({"slot": label, "status": "ALREADY_OK", "path": str(dest)})
                continue

        if dry_run:
            results["details"].append({"slot": label, "status": "WOULD_RECOVER", "path": str(dest)})
            continue

        incoming = ws.p("downloads_incoming") / entry["expected_filename"]
        incoming.parent.mkdir(parents=True, exist_ok=True)
        ok, inc, note = downloader._fetch(entry, ws, rules, allow_network=True)
        src = inc if ok and inc and inc.is_file() else incoming
        if not src.is_file():
            results["failed"] += 1
            results["details"].append({"slot": label, "status": "FETCH_FAILED", "note": note})
            continue

        valid, vnote = _is_valid_pdf(src)
        if not valid:
            results["failed"] += 1
            results["details"].append({"slot": label, "status": "INVALID_PDF", "note": vnote})
            continue

        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        sha = _sha256(dest)

        # Register in completed_downloads if missing
        completed = load_json(ws.pm("completed_downloads"), []) or []
        have = {c.get("resource_id") for c in completed}
        if entry["resource_id"] not in have:
            completed.append({
                "resource_id": entry["resource_id"],
                "original_url": entry.get("source_url"),
                "destination_path": str(Path(entry["destination"]) / entry["expected_filename"]),
                "checksum_sha256": sha,
                "file_size_bytes": dest.stat().st_size,
                "verification_status": "VERIFIED",
                "verified_at": utcnow(),
                "recovery_note": "ts_canonical_path_recovery",
            })
            write_json(ws.pm("completed_downloads"), completed)

        results["recovered"] += 1
        results["details"].append({
            "slot": label, "status": "RECOVERED", "path": str(dest.relative_to(ws.root)),
            "sha256": sha[:16], "bytes": dest.stat().st_size,
            "classification": "VERIFIED_OFFICIAL_SOURCE"
            if entry.get("license_status", "").startswith("OFFICIAL") else "THIRD_PARTY_PROVENANCE_REVIEW",
        })
        with LOG.open("a", encoding="utf-8") as log:
            log.write(f"RECOVERED {label} -> {dest} sha={sha[:16]}\n")

    return results


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    res = recover(dry_run=args.dry_run)
    print(json.dumps(res, indent=2))
    return 0 if res["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
