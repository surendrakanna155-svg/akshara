#!/usr/bin/env python3
"""Board → Class 1–10 → Subject coverage audit for KIE/QP readiness.

Authority: configs/boards.json + configs/classes.json (locked scope).
Evidence: CANONICAL_CURRICULUM_MATRIX.json, disk inventory, PROVENANCE_MANIFEST.

Usage:
  subject_coverage_audit.py [--workspace DIR]
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve()
SCRIPTS = HERE.parents[1]
sys.path.insert(0, str(SCRIPTS / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = HERE.parents[2]
CLASS_ORDER = [str(i) for i in range(1, 11)]

# Config subject_key → official-subject tokens used in universe slots
SUBJECT_ALIASES: dict[str, list[str]] = {
    "english": ["english"],
    "mathematics": ["mathematics", "math"],
    "science": ["science", "environmental studies", "evs", "physical science", "biological science", "general science"],
    "social_science": ["social science", "social studies", "history", "geography", "civics", "economics", "political"],
    "physics": ["physics"],
    "chemistry": ["chemistry"],
    "biology": ["biology", "biological"],
    "history": ["history"],
    "geography": ["geography"],
    "civics": ["civics", "political"],
    "computer_science": ["computer", "computer applications", "computer science", "ict"],
}

ASSESSMENT_TYPES = {"SAMPLE_QUESTION_PAPER", "MARKING_SCHEME", "ASSESSMENT_RESOURCE"}
SYLLABUS_TYPES = {"SYLLABUS"}
TEXTBOOK_TYPES = {"CORE_TEXTBOOK", "SUPPLEMENTARY_READER", "WORKBOOK"}

# Official curriculum: AP/TS Class 5 uses integrated EVS — no separate SST textbook.
EVS_ONLY_CLASS5_BOARDS = {"ap", "telangana"}


def _norm(s: str) -> str:
    return " ".join(s.lower().replace("_", " ").replace("-", " ").split())


def _subject_matches(official_subject: str, subject_key: str) -> bool:
    off = _norm(official_subject)
    for token in SUBJECT_ALIASES.get(subject_key, [subject_key]):
        if token in off or off in token:
            return True
    return False


def _has_files(path: Path) -> bool:
    if not path.is_dir():
        return False
    return any(p.is_file() and p.suffix.lower() in {".pdf", ".zip"} for p in path.iterdir())


def _load_slots(ws: Workspace) -> list[dict]:
    matrix = load_json(ws.p("reports_dir") / "CANONICAL_CURRICULUM_MATRIX.json", {})
    return matrix.get("slots", [])


def _slots_for_cell(slots: list[dict], board_code: str, clabel: str, subject_key: str) -> list[dict]:
    matched = []
    for s in slots:
        if s.get("board") != board_code or s.get("class_label") != clabel:
            continue
        if _subject_matches(s.get("official_subject", ""), subject_key):
            matched.append(s)
    return matched


def _disk_paths(ws: Workspace, board_folder: str, clabel: str, subject_folder: str) -> dict[str, Path]:
    base = ws.p("resources_dir") / "curriculum" / board_folder / clabel / subject_folder
    return {
        "textbooks": base / "Textbooks",
        "syllabus": base / "Syllabus",
        "sample_papers": base / "Sample_Papers",
        "blueprints": base / "Blueprints",
        "question_banks": base / "Question_Banks",
        "previous_papers": base / "Previous_Papers",
    }


def _trusted_license(lic: str) -> bool:
    if not lic or lic.startswith("UNOFFICIAL"):
        return False
    if "DIKSHA" in lic or lic.startswith("OFFICIAL"):
        return True
    return False


def _load_completed(ws: Workspace) -> list[dict]:
    completed = load_json(ws.pm("completed_downloads"), []) or []
    queue = {e["resource_id"]: e for e in (load_json(ws.pm("download_queue"), []) or [])}
    enriched: list[dict] = []
    for c in completed:
        q = queue.get(c.get("resource_id"), {})
        row = {**q, **c}
        vstat = row.get("verification_status") or row.get("status")
        if vstat == "VERIFIED":
            enriched.append(row)
    return enriched


def _completed_for_cell(completed: list[dict], board_code: str, clabel: str, subject_key: str) -> list[dict]:
    matched = []
    for c in completed:
        if c.get("board") != board_code or c.get("class_label") != clabel:
            continue
        subj_disp = c.get("subject", "")
        if _subject_matches(subj_disp, subject_key):
            matched.append(c)
    return matched


def audit(ws: Workspace) -> dict:
    boards_cfg = ws.config("boards")
    classes_cfg = ws.config("classes")["classes"]
    subjects_cfg = ws.config("subjects")["subjects"]
    board_order = boards_cfg["board_order"]
    boards = boards_cfg["boards"]

    slots = _load_slots(ws)
    completed = _load_completed(ws)
    rows = []
    status_counts = {"COMPLETE": 0, "PARTIAL": 0, "MISSING": 0, "OUT_OF_SCOPE_WITH_REASON": 0}

    for bkey in board_order:
        b = boards[bkey]
        if not b.get("in_scope"):
            continue
        board_code = b["code"]
        bf = b["board_folder"]

        for ckey in CLASS_ORDER:
            if ckey not in b["subjects_by_class"]:
                continue
            clabel = classes_cfg[ckey]["class_label"]
            grade = int(ckey)

            for sk in b["subjects_by_class"][ckey]:
                subj = subjects_cfg[sk]
                display = subj["display"]
                sf = subj["subject_folder"]

                row = {
                    "board": board_code,
                    "class": clabel,
                    "grade": grade,
                    "subject": display,
                    "subject_key": sk,
                }

                cell_slots = _slots_for_cell(slots, board_code, clabel, sk)
                trusted_slots = [s for s in cell_slots if s.get("trusted_ocr_corpus")]
                quarantined_slots = [s for s in cell_slots if not s.get("trusted_ocr_corpus")]
                paths = _disk_paths(ws, bf, clabel, sf)

                has_syllabus_slot = any(s.get("resource_type") in SYLLABUS_TYPES for s in cell_slots)
                has_assessment_slot = any(s.get("resource_type") in ASSESSMENT_TYPES for s in cell_slots)
                has_textbook_slot = any(s.get("resource_type") in TEXTBOOK_TYPES for s in cell_slots)
                has_trusted_textbook = any(
                    s.get("resource_type") in TEXTBOOK_TYPES and s.get("trusted_ocr_corpus") for s in cell_slots
                )

                disk_textbook = _has_files(paths["textbooks"])
                disk_syllabus = _has_files(paths["syllabus"])
                disk_assessment = (
                    _has_files(paths["sample_papers"])
                    or _has_files(paths["blueprints"])
                    or _has_files(paths["question_banks"])
                    or _has_files(paths.get("previous_papers", paths["sample_papers"]))
                )
                comp = _completed_for_cell(completed, board_code, clabel, sk)
                comp_trusted = [
                    c for c in comp
                    if _trusted_license(c.get("license_status", ""))
                    or (c.get("resource_id", "").startswith("AKS-") and "DIKSHA" in (c.get("expected_filename") or c.get("destination_path") or ""))
                ]
                if comp_trusted:
                    for c in comp_trusted:
                        cat = c.get("resource_category", "")
                        if cat in ("sample_paper", "previous_paper", "blueprint", "question_bank"):
                            disk_assessment = True
                        if cat in ("textbook", "syllabus"):
                            disk_textbook = disk_textbook or cat == "textbook"
                            if cat == "syllabus":
                                disk_syllabus = True

                # --- ICSE: in-scope subjects; proprietary textbooks not legally acquirable ---
                if bkey == "icse":
                    cisce_official = [
                        s for s in cell_slots
                        if s.get("qp_scope") != "COMMERCIAL_BLOCKED"
                        and s.get("resource_type") not in TEXTBOOK_TYPES
                    ]
                    cisce_trusted = [s for s in cisce_official if s.get("trusted_ocr_corpus")]
                    row["syllabus_available"] = any(
                        s.get("resource_type") in SYLLABUS_TYPES for s in cisce_trusted
                    ) or disk_syllabus
                    row["textbook_content_available"] = False
                    row["assessment_boundary_available"] = any(
                        s.get("resource_type") in ASSESSMENT_TYPES for s in cisce_trusted
                    ) or disk_assessment
                    row["trusted_extraction_ready"] = bool(cisce_trusted or comp_trusted)

                    if row["syllabus_available"] and row["assessment_boundary_available"]:
                        row["status"] = "PARTIAL"
                        row["missing"] = (
                            "Trusted textbook/chapter/concept corpus — ICSE textbooks are "
                            "proprietary publisher works with no free official distribution"
                        )
                        row["legally_acquirable_now"] = "NO"
                        row["qp_ready"] = False
                        status_counts["PARTIAL"] += 1
                    elif row["syllabus_available"] or row["assessment_boundary_available"]:
                        row["status"] = "PARTIAL"
                        row["missing"] = (
                            "Incomplete official CISCE syllabus/specimen set; no trusted textbook"
                        )
                        row["legally_acquirable_now"] = "YES" if not row["syllabus_available"] else "NO"
                        row["qp_ready"] = False
                        status_counts["PARTIAL"] += 1
                    else:
                        row["status"] = "MISSING"
                        row["missing"] = (
                            "No trusted official CISCE curriculum package and no acquirable "
                            "textbook for this subject"
                        )
                        row["legally_acquirable_now"] = "YES"
                        row["qp_ready"] = False
                        status_counts["MISSING"] += 1
                    rows.append(row)
                    continue

                # (legacy ICSE branch removed — handled above)

                # --- AP/TS Class 5 Social Science: official EVS-only structure ---
                if sk == "social_science" and grade == 5 and bkey in EVS_ONLY_CLASS5_BOARDS:
                    evs_slots = _slots_for_cell(slots, board_code, clabel, "science")
                    evs_trusted = [s for s in evs_slots if s.get("trusted_ocr_corpus")]
                    row["syllabus_available"] = bool(evs_trusted) or _has_files(
                        _disk_paths(ws, bf, clabel, subjects_cfg["science"]["subject_folder"])["textbooks"]
                    )
                    row["textbook_content_available"] = bool(evs_trusted)
                    row["assessment_boundary_available"] = row["syllabus_available"]
                    row["trusted_extraction_ready"] = bool(evs_trusted)
                    row["status"] = "OUT_OF_SCOPE_WITH_REASON"
                    row["out_of_scope_reason"] = (
                        f"{board_code} Class 5 official curriculum uses integrated EVS (Science slot); "
                        "no separate Social Science textbook is published by the state SCERT."
                    )
                    row["missing"] = "N/A — covered via EVS integration"
                    row["legally_acquirable_now"] = "NO"
                    row["qp_ready"] = bool(evs_trusted)
                    status_counts["OUT_OF_SCOPE_WITH_REASON"] += 1
                    rows.append(row)
                    continue

                # --- CBSE Class 10 Computer Applications (Code 165): syllabus+SQP authoritative ---
                if bkey == "cbse" and sk == "computer_science" and grade == 10:
                    row["syllabus_available"] = has_syllabus_slot or disk_syllabus
                    row["textbook_content_available"] = row["syllabus_available"]  # no NCERT textbook required
                    row["assessment_boundary_available"] = has_assessment_slot or disk_assessment
                    row["trusted_extraction_ready"] = bool(trusted_slots)
                    if row["syllabus_available"] and row["assessment_boundary_available"] and trusted_slots:
                        row["status"] = "COMPLETE"
                        row["missing"] = ""
                        row["legally_acquirable_now"] = "YES"
                        row["qp_ready"] = True
                        row["note"] = "Authoritative package = CBSE syllabus + SQP + marking scheme (no NCERT textbook)"
                        status_counts["COMPLETE"] += 1
                    else:
                        row["status"] = "PARTIAL"
                        row["missing"] = "Trusted CBSE Computer Applications syllabus/SQP/marking scheme incomplete"
                        row["legally_acquirable_now"] = "YES"
                        row["qp_ready"] = False
                        status_counts["PARTIAL"] += 1
                    rows.append(row)
                    continue

                # --- CBSE Class 9 CS (if in scope) ---
                if bkey == "cbse" and sk == "computer_science" and grade == 9:
                    row["syllabus_available"] = has_syllabus_slot or disk_syllabus
                    row["textbook_content_available"] = has_textbook_slot or disk_textbook
                    row["assessment_boundary_available"] = has_assessment_slot or disk_assessment
                    row["trusted_extraction_ready"] = bool(trusted_slots)
                    if row["trusted_extraction_ready"] and (row["textbook_content_available"] or row["syllabus_available"]):
                        row["status"] = "COMPLETE" if row["assessment_boundary_available"] else "PARTIAL"
                        row["missing"] = "" if row["status"] == "COMPLETE" else "Assessment boundary docs (SQP/blueprint)"
                        row["legally_acquirable_now"] = "YES"
                        row["qp_ready"] = row["status"] == "COMPLETE"
                        status_counts[row["status"]] += 1
                    else:
                        row["status"] = "MISSING"
                        row["missing"] = "Trusted CBSE Class 9 Computer Science sources"
                        row["legally_acquirable_now"] = "YES"
                        row["qp_ready"] = False
                        status_counts["MISSING"] += 1
                    rows.append(row)
                    continue

                # --- Primary classes 1–5: textbook TOC is syllabus boundary ---
                primary = grade <= 5
                secondary_exam = grade >= 9

                row["syllabus_available"] = (
                    has_syllabus_slot
                    or disk_syllabus
                    or (primary and (has_trusted_textbook or (disk_textbook and trusted_slots)))
                    or (has_trusted_textbook and not primary)
                )
                row["textbook_content_available"] = has_trusted_textbook or any(
                    c.get("resource_category") == "textbook" for c in comp_trusted
                ) or (
                    disk_textbook and bool(trusted_slots) and not quarantined_slots
                )
                if quarantined_slots and not trusted_slots:
                    row["textbook_content_available"] = False
                elif quarantined_slots and trusted_slots:
                    row["textbook_content_available"] = True

                if secondary_exam:
                    # Secondary: require actual assessment artifacts on disk or in matrix.
                    row["assessment_boundary_available"] = (
                        has_assessment_slot or disk_assessment
                    )
                elif grade >= 6:
                    row["assessment_boundary_available"] = has_assessment_slot or disk_assessment
                else:
                    # Primary 1–5: public FA/SA papers rarely published separately;
                    # count only if explicit assessment files exist.
                    row["assessment_boundary_available"] = (
                        has_assessment_slot or disk_assessment
                    )

                row["trusted_extraction_ready"] = bool(trusted_slots) or bool(
                    comp_trusted and any(
                        c.get("resource_category") in ("textbook", "syllabus", "sample_paper", "question_bank")
                        for c in comp_trusted
                    )
                )

                missing_parts = []
                if not row["syllabus_available"]:
                    missing_parts.append("syllabus/curriculum boundary")
                if not row["textbook_content_available"]:
                    if quarantined_slots and disk_textbook:
                        missing_parts.append("trusted textbook (only quarantined third-party copy on disk)")
                    else:
                        missing_parts.append("trusted textbook/content")
                if not row["assessment_boundary_available"]:
                    missing_parts.append("assessment boundary (SQP/blueprint/weightage)")
                if not row["trusted_extraction_ready"]:
                    missing_parts.append("trusted extraction corpus slot")

                row["missing"] = "; ".join(missing_parts)
                row["legally_acquirable_now"] = "YES" if bkey != "icse" else "NO"

                if not missing_parts:
                    row["status"] = "COMPLETE"
                    row["qp_ready"] = True
                    status_counts["COMPLETE"] += 1
                elif row["syllabus_available"] or row["textbook_content_available"] or disk_textbook:
                    row["status"] = "PARTIAL"
                    row["qp_ready"] = False
                    status_counts["PARTIAL"] += 1
                else:
                    row["status"] = "MISSING"
                    row["qp_ready"] = False
                    status_counts["MISSING"] += 1

                rows.append(row)

    # Dual-dimension status: curriculum knowledge vs assessment evidence
    cur_counts = Counter()
    ass_counts = Counter()
    for row in rows:
        if row.get("status") == "OUT_OF_SCOPE_WITH_REASON":
            row["curriculum_knowledge_status"] = "OUT_OF_SCOPE_WITH_REASON"
            row["assessment_evidence_status"] = "OUT_OF_SCOPE_WITH_REASON"
            cur_counts["OUT_OF_SCOPE_WITH_REASON"] += 1
            ass_counts["OUT_OF_SCOPE_WITH_REASON"] += 1
            continue

        cur_parts = []
        if not row.get("syllabus_available"):
            cur_parts.append("syllabus/curriculum boundary")
        if not row.get("textbook_content_available"):
            cur_parts.append("trusted textbook/content")
        if not row.get("trusted_extraction_ready"):
            cur_parts.append("trusted extraction corpus")

        ass_parts = []
        if not row.get("assessment_boundary_available"):
            ass_parts.append("official sample/specimen/blueprint/weightage evidence")

        row["curriculum_missing"] = "; ".join(cur_parts)
        row["assessment_missing"] = "; ".join(ass_parts)

        if not cur_parts:
            row["curriculum_knowledge_status"] = "COMPLETE"
        elif row.get("syllabus_available") or row.get("textbook_content_available"):
            row["curriculum_knowledge_status"] = "PARTIAL"
        else:
            row["curriculum_knowledge_status"] = "MISSING"

        if not ass_parts:
            row["assessment_evidence_status"] = "COMPLETE"
        elif row.get("assessment_boundary_available"):
            row["assessment_evidence_status"] = "PARTIAL"
        else:
            row["assessment_evidence_status"] = "MISSING"

        cur_counts[row["curriculum_knowledge_status"]] += 1
        ass_counts[row["assessment_evidence_status"]] += 1

        row["qp_ready"] = (
            row["curriculum_knowledge_status"] == "COMPLETE"
            and row["assessment_evidence_status"] == "COMPLETE"
        )

    partial_missing = [r for r in rows if r["status"] in ("PARTIAL", "MISSING")
                       or r.get("curriculum_knowledge_status") in ("PARTIAL", "MISSING")
                       or r.get("assessment_evidence_status") in ("PARTIAL", "MISSING")]
    not_qp_ready = [r for r in rows if not r.get("qp_ready", False)]

    report = {
        "generated_at": utcnow(),
        "audit_type": "BOARD_CLASS_SUBJECT_COVERAGE",
        "scope_authority": {
            "boards_config": "curriculum/configs/boards.json",
            "classes_config": "curriculum/configs/classes.json",
            "classes": "1-10",
            "medium": ["English"],
            "board_order": ["CBSE", "APSCERT", "TSSCERT", "CISCE"],
        },
        "total_required_combinations": len(rows),
        "status_counts": status_counts,
        "curriculum_status_counts": dict(cur_counts),
        "assessment_status_counts": dict(ass_counts),
        "kie_all_ready": (
            cur_counts["MISSING"] == 0 and cur_counts["PARTIAL"] == 0
            and ass_counts["MISSING"] == 0 and ass_counts["PARTIAL"] == 0
        ),
        "rows": rows,
        "partial_missing": [
            {
                "board": r["board"],
                "class": r["class"],
                "subject": r["subject"],
                "status": r["status"],
                "missing": r.get("missing", ""),
                "legally_acquirable_now": r.get("legally_acquirable_now", ""),
            }
            for r in partial_missing
        ],
        "not_ready_for_question_generation": [
            {"board": r["board"], "class": r["class"], "subject": r["subject"], "status": r["status"]}
            for r in not_qp_ready
        ],
    }
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    report = audit(ws)
    out_json = ws.p("reports_dir") / "SUBJECT_COVERAGE_AUDIT.json"
    out_md = ws.p("reports_dir") / "SUBJECT_COVERAGE_AUDIT.md"
    write_json(out_json, report)

    sc = report["status_counts"]
    lines = [
        "# Subject Coverage Audit (Classes 1–10)",
        f"\nGenerated: {report['generated_at']}\n",
        f"Required combinations: **{report['total_required_combinations']}**",
        f"- COMPLETE: {sc['COMPLETE']}",
        f"- PARTIAL: {sc['PARTIAL']}",
        f"- MISSING: {sc['MISSING']}",
        f"- OUT_OF_SCOPE: {sc['OUT_OF_SCOPE_WITH_REASON']}",
        f"\n### Curriculum knowledge",
        f"- COMPLETE: {report['curriculum_status_counts'].get('COMPLETE', 0)}",
        f"- PARTIAL: {report['curriculum_status_counts'].get('PARTIAL', 0)}",
        f"- MISSING: {report['curriculum_status_counts'].get('MISSING', 0)}",
        f"\n### Assessment evidence",
        f"- COMPLETE: {report['assessment_status_counts'].get('COMPLETE', 0)}",
        f"- PARTIAL: {report['assessment_status_counts'].get('PARTIAL', 0)}",
        f"- MISSING: {report['assessment_status_counts'].get('MISSING', 0)}",
        f"\nKIE all ready: **{'YES' if report['kie_all_ready'] else 'NO'}**\n",
    ]
    out_md.write_text("\n".join(lines), encoding="utf-8")
    print(
        f"combinations={report['total_required_combinations']} "
        f"COMPLETE={sc['COMPLETE']} PARTIAL={sc['PARTIAL']} "
        f"MISSING={sc['MISSING']} OOS={sc['OUT_OF_SCOPE_WITH_REASON']} "
        f"KIE={'YES' if report['kie_all_ready'] else 'NO'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
