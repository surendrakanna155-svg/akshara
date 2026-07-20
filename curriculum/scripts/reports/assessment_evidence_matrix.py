#!/usr/bin/env python3
"""Assessment evidence matrix — Board → Class → Subject → Assessment Type.

Scans verified resources on disk and completed-download registry. Does not
weaken COMPLETE criteria; reports honest per-type coverage gaps.

Usage: assessment_evidence_matrix.py [--workspace DIR]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve()
SCRIPTS = HERE.parents[1]
sys.path.insert(0, str(SCRIPTS / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402
from provenance_tier import license_to_tier, TIER_OFFICIAL, TIER_TRUSTED_THIRD_PARTY  # noqa: E402

WORKSPACE_ROOT = HERE.parents[2]
CLASS_ORDER = [str(i) for i in range(1, 11)]

# Canonical assessment types tracked for KIE/QP evidence
ASSESSMENT_TYPES = [
    "unit_test",
    "fa1", "fa2", "fa3", "fa4",
    "sa1", "sa2", "sa3",
    "quarterly", "half_yearly", "annual_final",
    "model_paper", "sample_paper", "specimen_paper", "previous_paper",
    "blueprint", "weightage", "marking_scheme", "assessment_guidelines",
    "formative_summative", "term_exam", "other_assessment",
]

_TYPE_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("unit_test", re.compile(r"unit[\s_-]*test", re.I)),
    ("fa1", re.compile(r"\bfa[\s_-]*1\b|formative[\s_-]*1|fa1", re.I)),
    ("fa2", re.compile(r"\bfa[\s_-]*2\b|formative[\s_-]*2|fa2", re.I)),
    ("fa3", re.compile(r"\bfa[\s_-]*3\b|formative[\s_-]*3|fa3", re.I)),
    ("fa4", re.compile(r"\bfa[\s_-]*4\b|formative[\s_-]*4|fa4", re.I)),
    ("sa1", re.compile(r"\bsa[\s_-]*1\b|summative[\s_-]*1|sa1", re.I)),
    ("sa2", re.compile(r"\bsa[\s_-]*2\b|summative[\s_-]*2|sa2", re.I)),
    ("sa3", re.compile(r"\bsa[\s_-]*3\b|summative[\s_-]*3|sa3", re.I)),
    ("quarterly", re.compile(r"quarterly", re.I)),
    ("half_yearly", re.compile(r"half[\s_-]*yearly|halfyearly", re.I)),
    ("annual_final", re.compile(r"annual|final[\s_-]*exam", re.I)),
    ("specimen_paper", re.compile(r"specimen", re.I)),
    ("model_paper", re.compile(r"model[\s_-]*(paper|question)", re.I)),
    ("sample_paper", re.compile(r"sample[\s_-]*(paper|question)|sqp", re.I)),
    ("previous_paper", re.compile(r"previous", re.I)),
    ("marking_scheme", re.compile(r"marking[\s_-]*scheme|answer[\s_-]*key", re.I)),
    ("blueprint", re.compile(r"blueprint|exam[\s_-]*pattern", re.I)),
    ("weightage", re.compile(r"weightage", re.I)),
    ("assessment_guidelines", re.compile(r"assessment[\s_-]*guideline|assessment[\s_-]*procedure", re.I)),
    ("formative_summative", re.compile(r"formative|summative|abhyasa[\s_-]*deepika|fasa", re.I)),
    ("term_exam", re.compile(r"term[\s_-]*exam|terminal", re.I)),
]

ASSESSMENT_FOLDERS = (
    "Sample_Papers", "Blueprints", "Previous_Papers", "Question_Banks", "Assessment",
    "Trusted_Third_Party_Assessment",
)
TEXTBOOK_ASSESSMENT_HINT = re.compile(
    r"assessment[\s_-]*procedure|about[\s_-]*the[\s_-]*textbook", re.I
)

SUBJECT_ALIASES: dict[str, list[str]] = {
    "english": ["english"],
    "mathematics": ["mathematics", "math", "maths"],
    "science": ["science", "evs", "physical", "biological", "general science"],
    "social_science": ["social", "history", "geography", "civics", "economics"],
    "computer_science": ["computer", "ict"],
    "physics": ["physics"],
    "chemistry": ["chemistry"],
    "biology": ["biology"],
    "history": ["history"],
    "geography": ["geography"],
    "civics": ["civics", "political"],
}


def _norm(s: str) -> str:
    return " ".join(s.lower().replace("_", " ").replace("-", " ").split())


def _subject_match(blob: str, subject_key: str) -> bool:
    b = _norm(blob)
    for tok in SUBJECT_ALIASES.get(subject_key, [subject_key]):
        if tok in b:
            return True
    return False


def _classify_assessment(name: str, doc_type: str = "", category: str = "") -> str:
    blob = f"{name} {doc_type} {category}"
    for atype, pat in _TYPE_PATTERNS:
        if pat.search(blob):
            return atype
    if category in ("sample_paper", "previous_paper", "blueprint", "question_bank"):
        return "other_assessment"
    return ""


def _load_resources(ws: Workspace) -> list[dict]:
    completed = load_json(ws.pm("completed_downloads"), []) or []
    queue = {e["resource_id"]: e for e in (load_json(ws.pm("download_queue"), []) or [])}
    rows: list[dict] = []
    for c in completed:
        if (c.get("verification_status") or c.get("status")) != "VERIFIED":
            continue
        q = queue.get(c.get("resource_id"), {})
        row = {**q, **c}
        if (row.get("license_status") or "").startswith("UNOFFICIAL"):
            continue
        row["provenance_tier"] = row.get("provenance_tier") or license_to_tier(row.get("license_status"))
        rows.append(row)

    # Also scan disk not in completed (legacy verified files)
    res_root = ws.p("resources_dir") / "curriculum"
    board_map = {b["code"]: b["board_folder"] for b in ws.config("boards")["boards"].values()}
    for board_code, bf in board_map.items():
        base = res_root / bf
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if path.suffix.lower() not in (".pdf", ".zip"):
                continue
            rel = str(path.relative_to(ws.p("resources_dir")))
            parent = path.parent.name
            if parent not in ASSESSMENT_FOLDERS and parent != "Textbooks":
                continue
            rows.append({
                "board": board_code,
                "local_path": rel,
                "expected_filename": path.name,
                "resource_category": (
                    "textbook" if parent == "Textbooks"
                    else "sample_paper" if parent in ("Sample_Papers", "Trusted_Third_Party_Assessment")
                    else "blueprint" if parent == "Blueprints"
                    else "previous_paper" if parent == "Previous_Papers"
                    else "question_bank" if parent == "Question_Banks"
                    else "assessment"
                ),
                "provenance_tier": (
                    TIER_TRUSTED_THIRD_PARTY if parent == "Trusted_Third_Party_Assessment"
                    else TIER_OFFICIAL
                ),
                "class_label": path.parts[-4] if len(path.parts) >= 4 else "",
                "subject": path.parts[-3] if len(path.parts) >= 3 else "",
            })
    return rows


def build(ws: Workspace) -> dict:
    boards_cfg = ws.config("boards")
    classes_cfg = ws.config("classes")["classes"]
    subjects_cfg = ws.config("subjects")["subjects"]
    resources = _load_resources(ws)

    cells: list[dict] = []
    type_gaps = Counter()

    for bkey in boards_cfg["board_order"]:
        b = boards_cfg["boards"][bkey]
        if not b.get("in_scope"):
            continue
        board_code = b["code"]
        for ckey in CLASS_ORDER:
            if ckey not in b["subjects_by_class"]:
                continue
            clabel = classes_cfg[ckey]["class_label"]
            grade = int(ckey)
            for sk in b["subjects_by_class"][ckey]:
                subj = subjects_cfg[sk]
                sf = subj["subject_folder"]
                found_types: dict[str, list[str]] = defaultdict(list)
                official_types: dict[str, list[str]] = defaultdict(list)
                trusted_types: dict[str, list[str]] = defaultdict(list)

                for r in resources:
                    if r.get("board") != board_code:
                        continue
                    if r.get("class_label") and r.get("class_label") != clabel:
                        # infer from path
                        lp = r.get("local_path") or r.get("destination_path") or ""
                        if clabel not in lp:
                            continue
                    else:
                        lp = r.get("local_path") or ""
                        if lp and clabel not in lp:
                            continue
                    subj_blob = f"{r.get('subject','')} {lp} {r.get('expected_filename','')}"
                    if not _subject_match(subj_blob, sk):
                        continue
                    fname = r.get("expected_filename") or Path(lp).name if lp else ""
                    cat = r.get("resource_category", "")
                    dtype = r.get("document_type", "")
                    atype = r.get("assessment_subtype") or _classify_assessment(fname, dtype, cat)
                    if not atype and cat == "textbook" and TEXTBOOK_ASSESSMENT_HINT.search(fname):
                        atype = "assessment_guidelines"
                    if atype:
                        tier = r.get("provenance_tier") or license_to_tier(r.get("license_status"))
                        found_types[atype].append(fname[:80])
                        if tier == TIER_TRUSTED_THIRD_PARTY:
                            trusted_types[atype].append(fname[:80])
                        elif tier == TIER_OFFICIAL:
                            official_types[atype].append(fname[:80])

                # Expected types by grade (honest — not all published publicly)
                if grade <= 5:
                    expected = ["sample_paper", "model_paper", "unit_test", "fa1", "sa1"]
                elif grade <= 8:
                    expected = ["unit_test", "fa1", "fa2", "sa1", "sa2", "quarterly", "half_yearly", "annual_final", "model_paper"]
                else:
                    expected = [
                        "sample_paper", "specimen_paper", "model_paper", "previous_paper",
                        "blueprint", "marking_scheme", "weightage", "fa1", "fa2", "sa1", "sa2",
                        "formative_summative", "annual_final",
                    ]

                missing = [t for t in expected if t not in found_types]
                has_official = bool(official_types)
                has_trusted = bool(trusted_types)
                has_any = bool(found_types)
                cells.append({
                    "board": board_code,
                    "class": clabel,
                    "grade": grade,
                    "subject": subj["display"],
                    "subject_key": sk,
                    "assessment_types_found": {k: len(v) for k, v in sorted(found_types.items())},
                    "official_assessment_types_found": {k: len(v) for k, v in sorted(official_types.items())},
                    "trusted_third_party_assessment_types_found": {k: len(v) for k, v in sorted(trusted_types.items())},
                    "assessment_files_sample": {k: v[:3] for k, v in found_types.items()},
                    "expected_public_types": expected,
                    "missing_assessment_types": missing,
                    "has_official_assessment_evidence": has_official,
                    "has_trusted_third_party_assessment_evidence": has_trusted,
                    "has_any_assessment_evidence": has_any,
                    "assessment_evidence_status": (
                        "COMPLETE" if not missing and has_any
                        else "PARTIAL" if has_any
                        else "MISSING"
                    ),
                })
                for m in missing:
                    type_gaps[m] += 1

    return {
        "generated_at": utcnow(),
        "audit_type": "ASSESSMENT_EVIDENCE_MATRIX",
        "provenance_policy": "official_first_with_trusted_third_party_assessment_expansion",
        "cell_count": len(cells),
        "cells_with_official_evidence": sum(1 for c in cells if c["has_official_assessment_evidence"]),
        "cells_with_trusted_third_party_evidence": sum(1 for c in cells if c["has_trusted_third_party_assessment_evidence"]),
        "cells_with_any_evidence": sum(1 for c in cells if c["has_any_assessment_evidence"]),
        "cells_missing_all_evidence": sum(1 for c in cells if not c["has_any_assessment_evidence"]),
        "top_missing_types": dict(type_gaps.most_common(20)),
        "cells": cells,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    report = build(ws)
    out = ws.p("reports_dir") / "ASSESSMENT_EVIDENCE_MATRIX.json"
    write_json(out, report)
    print(
        f"cells={report['cell_count']} "
        f"official={report['cells_with_official_evidence']} "
        f"trusted_t3p={report['cells_with_trusted_third_party_evidence']} "
        f"any={report['cells_with_any_evidence']} "
        f"missing_all={report['cells_missing_all_evidence']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
