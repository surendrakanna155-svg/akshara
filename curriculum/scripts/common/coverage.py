"""Coverage computation (spec Part 07) — shared by reports + the D-5 certifier.

Compares the EXPECTED resource matrix (in-scope boards × classes × subjects ×
priority categories, from the config) against what is actually VERIFIED in the
master index, plus documented gaps (NOT_PUBLICLY_AVAILABLE / MISSING). This is
deliberately honest: an empty or single-file repository scores ~0% Priority-A,
so the certification gate stays closed until real coverage exists.

A "cell" = (board_code, class_label, subject_display, category). A cell is
COVERED when a VERIFIED resource of that category exists; ACCOUNTED when covered
OR documented as a gap (policy-controlled).
"""

from __future__ import annotations

from pathlib import Path

from workspace import Workspace, load_json


def _cat_priority(ws: Workspace) -> dict[str, str]:
    out: dict[str, str] = {}
    for prio, cats in ws.config("quality_rules")["priority_categories"].items():
        for c in cats:
            out[c] = prio
    return out


def expected_cells(ws: Workspace, priorities=("A", "B")) -> set[tuple]:
    boards = ws.config("boards")["boards"]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    qr = ws.config("quality_rules")
    cells: set[tuple] = set()
    for b in boards.values():
        if not b.get("in_scope"):
            continue
        for ckey, subj_list in b["subjects_by_class"].items():
            clabel = classes[ckey]["class_label"]
            for skey in subj_list:
                sdisp = subjects[skey]["display"]
                for prio in priorities:
                    for category in qr["priority_categories"][prio]:
                        cells.add((b["code"], clabel, sdisp, category))
    return cells


def verified_cells(ws: Workspace) -> set[tuple]:
    master = load_json(ws.index("master"), {}) or {}
    dt2cat = ws.config("download_rules")["document_type_to_category"]
    out: set[tuple] = set()
    for e in master.values():
        if e.get("verification_status") != "VERIFIED":
            continue
        cat = dt2cat.get(e.get("document_type", ""))
        if cat:
            out.add((e.get("board"), e.get("class_label"), e.get("subject"), cat))
    return out


def documented_gap_cells(ws: Workspace) -> set[tuple]:
    """Cells explicitly documented unavailable (queue NOT_PUBLICLY_AVAILABLE)."""
    dt2cat = ws.config("download_rules")["document_type_to_category"]
    queue = load_json(ws.pm("download_queue"), []) or []
    out: set[tuple] = set()
    for e in queue:
        if e.get("status") == "NOT_PUBLICLY_AVAILABLE":
            cat = e.get("resource_category") or dt2cat.get(e.get("document_type", ""))
            if cat:
                out.add((e.get("board"), e.get("class_label"), e.get("subject"), cat))
    return out


def compute(ws: Workspace) -> dict:
    cat_prio = _cat_priority(ws)
    exp_all = expected_cells(ws, priorities=("A", "B"))
    verified = verified_cells(ws)
    documented = documented_gap_cells(ws)
    count_docs = ws.config("quality_rules")["certification_policy"].get("count_documented_gaps_as_covered", True)

    per_board: dict[str, dict] = {}
    for (board, clabel, subj, cat) in exp_all:
        prio = cat_prio.get(cat, "C")
        bd = per_board.setdefault(board, {"A": {"expected": 0, "covered": 0, "documented": 0},
                                          "B": {"expected": 0, "covered": 0, "documented": 0}})
        slot = bd[prio]
        slot["expected"] += 1
        cell = (board, clabel, subj, cat)
        if cell in verified:
            slot["covered"] += 1
        elif cell in documented:
            slot["documented"] += 1

    def pct(slot):
        acc = slot["covered"] + (slot["documented"] if count_docs else 0)
        return (acc / slot["expected"]) if slot["expected"] else 0.0

    for board, bd in per_board.items():
        for prio in ("A", "B"):
            bd[prio]["accounted"] = bd[prio]["covered"] + (bd[prio]["documented"] if count_docs else 0)
            bd[prio]["coverage"] = pct(bd[prio])

    total_exp = len(exp_all)
    total_cov = len(verified & exp_all)
    total_doc = len(documented & exp_all) if count_docs else 0
    overall = {
        "expected_cells": total_exp,
        "covered_cells": total_cov,
        "documented_cells": total_doc,
        "coverage_completeness": ((total_cov + total_doc) / total_exp) if total_exp else 0.0,
        "verified_resources": sum(1 for e in (load_json(ws.index("master"), {}) or {}).values()
                                  if e.get("verification_status") == "VERIFIED"),
    }
    return {"per_board": per_board, "overall": overall}
