#!/usr/bin/env python3
"""Final repository audit — the gate before any Knowledge-Base phase.

Verifies (per the Download Verification & Recovery Engine spec §4):
  A1 every expected resource exists (queue entries terminal: VERIFIED or documented)
  A2 every PDF in resources/ re-opens (header + EOF + page structure)
  A3 every indexed resource has its metadata file
  A4 every checksum re-verifies against the file on disk
  A5 every master-index entry resolves to a real file (and vice versa: no orphans)
  A6 every required folder contains its expected resources

On PASS  → PROJECT_STATUS.json: repository_status = REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION
On FAIL  → status stays NOT_READY; exit 1. Do not proceed to knowledge extraction.
Always writes reports/REPOSITORY_AUDIT_REPORT.md.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verification_engine import VerificationEngine, _load_json, _write_json  # noqa: E402

WORKSPACE = Path(__file__).resolve().parents[2]
READY = "REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION"


def audit(workspace: Path) -> int:
    engine = VerificationEngine(workspace)
    problems: list[str] = []
    stats = {"resources_checked": 0, "pdfs_checked": 0, "checksums_verified": 0}

    master = _load_json(engine._index("master"), {})
    queue = _load_json(engine._pm("download_queue"), [])
    failed = _load_json(engine._pm("failed_downloads"), [])
    exhausted = engine.rules["retry_policy"]["exhausted_status"]

    # A1 — every expected resource in a terminal, accounted state
    verified_ids = {rid for rid, e in master.items() if e.get("verification_status") == "VERIFIED"}
    documented_missing = {e.get("resource_id") for e in failed if e.get("status") == exhausted}
    for entry in queue:
        rid = entry.get("resource_id")
        if rid not in verified_ids and rid not in documented_missing:
            problems.append(f"A1: expected resource not verified and not documented missing: {rid}")

    # A3/A4/A5 — index ↔ metadata ↔ file ↔ checksum agreement
    for rid, e in master.items():
        if e.get("verification_status") != "VERIFIED":
            continue
        stats["resources_checked"] += 1
        fpath = workspace / e["repository_path"]
        mpath = workspace / e["metadata_path"]
        if not fpath.is_file():
            problems.append(f"A5: indexed file missing on disk: {rid} → {e['repository_path']}")
            continue
        if not mpath.is_file():
            problems.append(f"A3: metadata file missing: {rid} → {e['metadata_path']}")
        if engine._sha256(fpath) != e.get("checksum_sha256"):
            problems.append(f"A4: checksum mismatch on disk: {rid}")
        else:
            stats["checksums_verified"] += 1
        # A2 — PDFs re-open
        if fpath.suffix.lower() == ".pdf":
            stats["pdfs_checked"] += 1
            code, detail, _ = engine._verify_pdf(fpath)
            if code:
                problems.append(f"A2: PDF fails re-open: {rid} — {code}: {detail}")

    # A5 reverse — no orphan files outside the index
    resources_dir = engine._p("resources_dir")
    indexed_paths = {str(workspace / e["repository_path"]) for e in master.values()
                     if e.get("verification_status") == "VERIFIED"}
    if resources_dir.exists():
        for f in resources_dir.rglob("*"):
            if f.is_file() and str(f) not in indexed_paths:
                problems.append(f"A5: orphan file not in master index: {f.relative_to(workspace)}")

    # A6 — required folders non-empty (derived from verified queue destinations)
    for entry in queue:
        rid = entry.get("resource_id")
        if rid in verified_ids:
            folder = engine._p("resources_dir") / entry.get("destination", "")
            if not folder.exists() or not any(folder.iterdir()):
                problems.append(f"A6: required folder empty/missing: {folder.relative_to(workspace)}")

    # verdict + report
    passed = not problems
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    status = _load_json(engine._pm("project_status"), {})
    status["repository_status"] = READY if passed else "NOT_READY"
    status["last_repository_audit"] = {"at": now, "passed": passed, "problems": len(problems), **stats}
    _write_json(engine._pm("project_status"), status)

    lines = [
        "# Repository Audit Report",
        "",
        f"_Audited: {now}_",
        "",
        f"**Verdict: {'✅ PASS — ' + READY if passed else '❌ FAIL — repository NOT ready; do not proceed'}**",
        "",
        f"- Resources checked: {stats['resources_checked']}",
        f"- PDFs re-opened: {stats['pdfs_checked']}",
        f"- Checksums re-verified: {stats['checksums_verified']}",
        f"- Problems: {len(problems)}",
        "",
    ]
    if problems:
        lines.append("## Problems")
        lines.extend(f"- {p}" for p in problems)
    report = engine._report("repository_audit")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"{'PASS' if passed else 'FAIL'} — {len(problems)} problem(s); report: {report}")
    for p in problems[:20]:
        print(f"  {p}")
    return 0 if passed else 1


if __name__ == "__main__":
    ws = Path(sys.argv[1]) if len(sys.argv) > 1 else WORKSPACE
    raise SystemExit(audit(ws))
