#!/usr/bin/env python3
"""Final repository audit + D-5 Repository Certification.

`audit()` (unchanged) — the structural §4 gate before any Knowledge-Base phase:
  A1 every expected resource exists (queue entries terminal: VERIFIED or documented)
  A2 every PDF in resources/ re-opens (header + EOF + page structure)
  A3 every indexed resource has its metadata file
  A4 every checksum re-verifies against the file on disk
  A5 every master-index entry resolves to a real file (and vice versa: no orphans)
  A6 every required folder contains its expected resources
On PASS → PROJECT_STATUS.json: repository_status = REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION.
On FAIL → status stays NOT_READY; exit 1. Always writes reports/REPOSITORY_AUDIT_REPORT.md.

`certify()` (owner decision D-5) — the SOLE authority that grants
REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION. Certification requires BOTH the
structural audit AND real coverage (per-board Priority-A complete, per
quality_rules.json:certification_policy). It writes the evidence artifact
reports/CURRICULUM_REPOSITORY_CERTIFICATION.md and sets
PROJECT_STATUS.json:repository_certified. Default = NOT certified until real
coverage exists — a single dry-run file can never certify. KB work must gate on
`repository_certified`, never on the structural `repository_status` alone.

Usage:
  repository_audit.py [WORKSPACE]              structural audit (A1-A6)
  repository_audit.py --certify [WORKSPACE]    structural audit + D-5 certification
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from verification_engine import VerificationEngine, _load_json, _write_json  # noqa: E402

WORKSPACE = Path(__file__).resolve().parents[2]
READY = "REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION"


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _run_audit(engine: VerificationEngine, workspace: Path) -> tuple[bool, list[str], dict]:
    """The A1-A6 structural checks. Returns (passed, problems, stats)."""
    problems: list[str] = []
    stats = {"resources_checked": 0, "pdfs_checked": 0, "checksums_verified": 0}

    master = _load_json(engine._index("master"), {})
    queue = _load_json(engine._pm("download_queue"), [])
    failed = _load_json(engine._pm("failed_downloads"), [])
    exhausted = engine.rules["retry_policy"]["exhausted_status"]

    # A1 — every expected resource in a terminal, accounted state
    verified_ids = {rid for rid, e in master.items() if e.get("verification_status") == "VERIFIED"}
    documented_missing = {e.get("resource_id") for e in failed if e.get("status") == exhausted}
    documented_missing |= {e.get("resource_id") for e in queue
                           if e.get("status") == "NOT_PUBLICLY_AVAILABLE"}
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
            if f.is_file() and f.name != ".gitkeep" and str(f) not in indexed_paths:
                problems.append(f"A5: orphan file not in master index: {f.relative_to(workspace)}")

    # A6 — required folders non-empty (derived from verified queue destinations)
    for entry in queue:
        rid = entry.get("resource_id")
        if rid in verified_ids:
            folder = engine._p("resources_dir") / entry.get("destination", "")
            if not folder.exists() or not any(folder.iterdir()):
                problems.append(f"A6: required folder empty/missing: {folder.relative_to(workspace)}")

    return (not problems), problems, stats


def audit(workspace: Path) -> int:
    engine = VerificationEngine(workspace)
    passed, problems, stats = _run_audit(engine, workspace)

    now = _now()
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


# ------------------------------------------------------------ D-5 certification

def _compute_coverage(workspace: Path) -> dict:
    """Import the shared coverage library against this workspace's config."""
    common_dir = Path(__file__).resolve().parents[1] / "common"
    if str(common_dir) not in sys.path:
        sys.path.insert(0, str(common_dir))
    import coverage as cov  # noqa: E402
    from workspace import Workspace  # noqa: E402

    return cov.compute(Workspace(workspace))


def certify(workspace: Path) -> int:
    """D-5 gate: structural audit + coverage policy → certified flag + artifact."""
    engine = VerificationEngine(workspace)
    policy = engine_rules = None
    # load certification policy from quality_rules.json (config over code)
    quality = _load_json(workspace / "configs" / "quality_rules.json", {}) or {}
    policy = quality.get("certification_policy", {})
    target = policy.get("priority_a_target", 1.0)

    structural_passed, problems, stats = _run_audit(engine, workspace)
    coverage = _compute_coverage(workspace)
    overall = coverage["overall"]
    per_board = coverage["per_board"]

    reasons: list[str] = []
    if policy.get("require_structural_audit_pass", True) and not structural_passed:
        reasons.append(f"structural audit failed ({len(problems)} problem(s))")

    nonempty = overall["verified_resources"] > 0
    if policy.get("require_nonempty_repository", True) and not nonempty:
        reasons.append("repository is empty (zero verified resources)")

    boards = _load_json(workspace / "configs" / "boards.json", {}).get("boards", {})
    in_scope = [b for b in boards.values() if b.get("in_scope")]
    board_rows: list[tuple] = []
    if policy.get("require_all_in_scope_boards_priority_a_complete", True):
        for b in in_scope:
            code = b["code"]
            bd = per_board.get(code, {"A": {"accounted": 0, "expected": 0, "coverage": 0.0}})
            a = bd["A"]
            board_rows.append((code, a["accounted"], a["expected"], a["coverage"]))
            if a["expected"] == 0 or a["coverage"] < target:
                reasons.append(f"{code}: Priority-A coverage {a['coverage']*100:.1f}% "
                               f"({a['accounted']}/{a['expected']}) < target {target*100:.0f}%")

    certified = not reasons
    now = _now()

    # write the D-5 evidence artifact
    lines = [
        "# Curriculum Repository Certification (D-5)",
        "",
        f"_Evaluated: {now}_",
        "",
        f"**Verdict: {'✅ REPOSITORY CERTIFIED' if certified else '❌ NOT CERTIFIED'} — "
        f"{'grants' if certified else 'withholds'} `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION`**",
        "",
        "This artifact is the **sole authority** for starting Knowledge-Base work "
        "(owner decision D-5: `Downloaded → Verified → Repository Certified → Knowledge Base`). "
        "KB tooling must gate on `repository_certified`, not on the structural `repository_status`.",
        "",
        "## Gate results",
        "",
        f"- Structural audit (A1-A6): {'PASS' if structural_passed else 'FAIL'} "
        f"({len(problems)} problem(s); {stats['resources_checked']} resources, {stats['checksums_verified']} checksums)",
        f"- Repository non-empty: {'yes' if nonempty else 'no'} ({overall['verified_resources']} verified resources)",
        f"- Overall coverage (A+B, in-scope): {overall['coverage_completeness']*100:.1f}% "
        f"({overall['covered_cells']}/{overall['expected_cells']} cells; {overall['documented_cells']} documented gaps)",
        f"- Priority-A target per in-scope board: {target*100:.0f}%",
        "",
        "## Per-board Priority-A coverage",
        "",
        "| Board | A accounted/expected | A coverage |",
        "|---|---|---|",
    ]
    for code, acc, exp, c in board_rows:
        lines.append(f"| {code} | {acc}/{exp} | {c*100:.1f}% |")
    if not board_rows:
        lines.append("| (no in-scope boards) | 0/0 | 0.0% |")
    lines += ["", "## Blocking reasons" if reasons else "## Blocking reasons — none", ""]
    if reasons:
        lines.extend(f"- {r}" for r in reasons)
    else:
        lines.append("_All certification conditions satisfied._")
    report = engine._report("repository_certification")
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # set the certified flag (default false) + structural status
    status = _load_json(engine._pm("project_status"), {})
    status["repository_status"] = READY if structural_passed else "NOT_READY"
    status["repository_certified"] = certified
    status["certification"] = {
        "at": now,
        "certified": certified,
        "structural_passed": structural_passed,
        "nonempty": nonempty,
        "overall_coverage_pct": round(overall["coverage_completeness"] * 100, 1),
        "priority_a_target": target,
        "reasons": reasons,
        "authority_for": READY,
    }
    _write_json(engine._pm("project_status"), status)

    verdict = "CERTIFIED" if certified else "NOT CERTIFIED"
    print(f"{verdict} — repository_certified={certified}; report: {report}")
    for r in reasons[:20]:
        print(f"  blocked: {r}")
    return 0 if certified else 1


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    do_certify = "--certify" in args
    args = [a for a in args if a != "--certify"]
    ws = Path(args[0]) if args else WORKSPACE
    raise SystemExit(certify(ws) if do_certify else audit(ws))
