#!/usr/bin/env python3
"""Curriculum COVERAGE MATRIX report — CANONICAL progress indicator.

Progress is reported as CURRICULUM COVERAGE, never as a raw PDF count.

CELL STATES (owner-locked 2026-07-09) — for every canonical matrix cell
Board → Class → Subject → Document Type:

    VERIFIED         a verified resource of that category exists in the repo
    DOWNLOADING      has a resolved source; fetch/verify in progress (queued)
    RETRY_SCHEDULED  a source failed and is waiting on backoff to retry
    UNRESOLVED       expected, no source resolved yet — discovery ongoing.
                     NOT "Missing": a cell is never called Missing until official
                     sources + official mirrors + known official repositories are
                     all exhausted.
    DOCUMENTED_GAP   the evidenced "Missing" — sources exhausted, recorded
                     NOT_PUBLICLY_AVAILABLE with evidence (terminal fetch failures
                     fold in here).

RESOURCE METRICS (owner-locked 2026-07-09) — reported separately from coverage:
    Downloaded   files fetched over the network into verification
    Verified     files that passed V1-V11  ← THE SUCCESS CRITERION
    Rejected     files that were downloaded but failed verification

DENOMINATOR TRANSPARENCY: the report always prints the 8 Priority-A document types
and shows, per board, classes × subjects × doc-types → expected cells.

Outputs:
  reports/COVERAGE_MATRIX.md    human-readable
  reports/COVERAGE_MATRIX.json  machine-readable (drives the dashboard)

Usage:
  coverage_matrix.py [--priority A|AB] [--quiet]
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
COUNTERS_FILE = "acquisition/.counters.json"
EST_SECONDS_PER_SOURCE = 30.0   # fallback throughput when no measured rate yet

STATE_ORDER = ["VERIFIED", "DOWNLOADING", "RETRY_SCHEDULED", "UNRESOLVED", "DOCUMENTED_GAP"]
VERIFIED_STATES = {"VERIFIED"}
ACCOUNTED_STATES = {"VERIFIED", "DOCUMENTED_GAP"}
ICON = {"VERIFIED": "✅", "DOWNLOADING": "⏳", "RETRY_SCHEDULED": "🔁",
        "UNRESOLVED": "⬜", "DOCUMENTED_GAP": "📄"}
ACTIONABLE_QUEUE = {"PENDING", "DOWNLOADED", "SKIPPED", "RETRY_PENDING"}


def _priority_doc_types(ws: Workspace, priorities: tuple[str, ...]) -> list[str]:
    qr = ws.config("quality_rules")["priority_categories"]
    out: list[str] = []
    for p in priorities:
        out.extend(qr[p])
    return out


def _expected_cells(ws: Workspace, priorities: tuple[str, ...]) -> list[tuple]:
    boards = ws.config("boards")["boards"]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    board_order = ws.config("boards")["board_order"]
    class_order = ws.config("classes")["class_order"]
    doc_types = _priority_doc_types(ws, priorities)
    cells: list[tuple] = []
    for bkey in board_order:
        b = boards[bkey]
        if not b.get("in_scope"):
            continue
        for ckey in class_order:
            if ckey not in b["subjects_by_class"]:
                continue
            clabel = classes[ckey]["class_label"]
            for skey in b["subjects_by_class"][ckey]:
                sdisp = subjects[skey]["display"]
                for category in doc_types:
                    cells.append((b["code"], clabel, sdisp, category))
    return cells


def _denominator(ws: Workspace, priorities: tuple[str, ...]) -> dict:
    boards = ws.config("boards")["boards"]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    board_order = ws.config("boards")["board_order"]
    class_order = ws.config("classes")["class_order"]
    doc_types = _priority_doc_types(ws, priorities)
    per_board = {}
    grand = 0
    for bkey in board_order:
        b = boards[bkey]
        if not b.get("in_scope"):
            continue
        classes_present = [classes[c]["class_label"] for c in class_order if c in b["subjects_by_class"]]
        subj_by_class = {classes[c]["class_label"]: [subjects[s]["display"] for s in b["subjects_by_class"][c]]
                         for c in class_order if c in b["subjects_by_class"]}
        subject_cells = sum(len(v) for v in subj_by_class.values())
        expected = subject_cells * len(doc_types)
        grand += expected
        per_board[b["code"]] = {
            "classes": classes_present, "subjects_by_class": subj_by_class,
            "subject_class_pairs": subject_cells, "doc_types": doc_types,
            "num_doc_types": len(doc_types), "expected_cells": expected,
            "formula": f"Σ(subjects per class over {len(classes_present)} classes)={subject_cells} × {len(doc_types)} doc-types = {expected}",
        }
    return {"priority_doc_types": doc_types, "num_doc_types": len(doc_types),
            "per_board": per_board, "total_expected_cells": grand}


def _verified_cells(ws: Workspace) -> set[tuple]:
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


def _queue_by_cell(ws: Workspace) -> dict[tuple, list[dict]]:
    queue = load_json(ws.pm("download_queue"), []) or []
    out: dict[tuple, list[dict]] = {}
    for e in queue:
        key = (e.get("board"), e.get("class_label"), e.get("subject"), e.get("resource_category"))
        out.setdefault(key, []).append(e)
    return out


def _cell_state(cell: tuple, verified: set[tuple], q_entries: list[dict]) -> str:
    if cell in verified:
        return "VERIFIED"
    if not q_entries:
        return "UNRESOLVED"
    statuses = {e.get("status") for e in q_entries}
    if "VERIFIED" in statuses:
        return "VERIFIED"
    if "RETRY_PENDING" in statuses:
        return "RETRY_SCHEDULED"
    if statuses & {"PENDING", "DOWNLOADED", "SKIPPED"}:
        return "DOWNLOADING"
    if statuses & {"NOT_PUBLICLY_AVAILABLE", "FAILED"}:   # exhausted → evidenced gap
        return "DOCUMENTED_GAP"
    return "DOWNLOADING"


def _provenance_rollup(ws: Workspace) -> dict:
    queue = load_json(ws.pm("download_queue"), []) or []
    tiers = {"official": 0, "official_mirror": 0, "third_party": 0}
    awaiting = []
    for e in queue:
        prov = (e.get("provenance") or "").upper()
        if "THIRD_PARTY" in prov:
            tiers["third_party"] += 1
            awaiting.append(e.get("resource_id"))
        elif "MIRROR" in prov:
            tiers["official_mirror"] += 1
        else:
            tiers["official"] += 1
    return {"by_tier": tiers, "third_party_awaiting_official_replacement": awaiting}


def _resource_metrics(ws: Workspace) -> dict:
    """Downloaded / Verified / Rejected — separate from cell coverage. Verified = success."""
    master = load_json(ws.index("master"), {}) or {}
    verified = sum(1 for e in master.values() if e.get("verification_status") == "VERIFIED")
    counters = load_json(ws.root / COUNTERS_FILE, {}) or {}
    downloaded = counters.get("downloaded")
    rejected = counters.get("rejected")
    if downloaded is None:   # no service counters yet — derive a floor from current state
        failed = load_json(ws.pm("failed_downloads"), []) or []
        rejected = len(failed)
        downloaded = verified + rejected
    return {"downloaded": downloaded, "verified": verified, "rejected": rejected,
            "success_criterion": "verified",
            "counters_source": "service" if counters.get("downloaded") is not None else "derived"}


def _eta(ws: Workspace, rows: list[dict]) -> dict:
    """Board-wise + overall ETA from measured throughput (fallback to a constant)."""
    queue = load_json(ws.pm("download_queue"), []) or []
    remaining_by_board: dict[str, int] = {}
    for e in queue:
        if e.get("status") in ACTIONABLE_QUEUE:
            remaining_by_board[e.get("board")] = remaining_by_board.get(e.get("board"), 0) + 1
    # measured rate: downloaded files per second since the service started
    counters = load_json(ws.root / COUNTERS_FILE, {}) or {}
    rate = None
    started = counters.get("started_at")
    downloaded = counters.get("downloaded")
    if started and downloaded:
        try:
            t0 = datetime.strptime(started, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            elapsed = (datetime.now(timezone.utc) - t0).total_seconds()
            if elapsed > 0 and downloaded > 0:
                rate = downloaded / elapsed        # files/sec
        except ValueError:
            rate = None
    sec_per = (1.0 / rate) if rate else EST_SECONDS_PER_SOURCE
    per_board = {b: round(n * sec_per) for b, n in remaining_by_board.items()}
    overall = round(sum(remaining_by_board.values()) * sec_per)
    return {"remaining_sources_by_board": remaining_by_board,
            "seconds_per_source": round(sec_per, 1),
            "rate_basis": "measured" if rate else "estimate",
            "eta_seconds_by_board": per_board, "eta_seconds_overall": overall}


def _human(sec: int) -> str:
    if sec <= 0:
        return "—"
    h, rem = divmod(int(sec), 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"~{h}h {m}m"
    if m:
        return f"~{m}m"
    return f"~{s}s"


def compute(ws: Workspace, priorities: tuple[str, ...]) -> dict:
    expected = _expected_cells(ws, priorities)
    verified = _verified_cells(ws)
    qmap = _queue_by_cell(ws)

    rows = []
    for (board, clabel, subj, cat) in expected:
        entries = qmap.get((board, clabel, subj, cat), [])
        state = _cell_state((board, clabel, subj, cat), verified, entries)
        rows.append({"board": board, "class": clabel, "subject": subj,
                     "doc_type": cat, "state": state, "sources": len(entries)})

    def tally(items):
        t = {s: 0 for s in STATE_ORDER}
        for r in items:
            t[r["state"]] += 1
        total = len(items)
        vcov = sum(t[s] for s in VERIFIED_STATES)
        acc = sum(t[s] for s in ACCOUNTED_STATES)
        return {"total": total, "verified": vcov, "accounted": acc,
                "coverage_pct": round(100.0 * vcov / total, 1) if total else 0.0,
                "accounted_pct": round(100.0 * acc / total, 1) if total else 0.0,
                "by_state": t}

    per_board: dict[str, list] = {}
    per_type: dict[str, list] = {}
    for r in rows:
        per_board.setdefault(r["board"], []).append(r)
        per_type.setdefault(r["doc_type"], []).append(r)

    eta = _eta(ws, rows)
    board_rollup = {}
    for b, v in per_board.items():
        tb = tally(v)
        tb["eta_seconds"] = eta["eta_seconds_by_board"].get(b, 0)
        tb["eta_human"] = _human(tb["eta_seconds"])
        board_rollup[b] = tb

    return {"generated_at": utcnow(), "priority_scope": "".join(priorities),
            "denominator": _denominator(ws, priorities),
            "provenance": _provenance_rollup(ws),
            "resource_metrics": _resource_metrics(ws),
            "eta": eta,
            "overall": tally(rows),
            "per_board": board_rollup,
            "per_doc_type": {t: tally(v) for t, v in per_type.items()},
            "rows": rows}


def _bar(pct: float, width: int = 24) -> str:
    filled = int(round(pct / 100 * width))
    return "█" * filled + "·" * (width - filled)


def render_md(data: dict) -> str:
    o = data["overall"]
    den = data["denominator"]
    prov = data["provenance"]["by_tier"]
    rm = data["resource_metrics"]
    L = ["# Curriculum Coverage Matrix — CANONICAL progress indicator",
         "",
         f"_Generated: {data['generated_at']} · scope: Priority-{data['priority_scope']} "
         f"(curriculum content only; circulars/notifications/supplementary excluded)_",
         "",
         "**Progress = curriculum coverage (verified cells ÷ expected matrix cells). NOT a PDF count.**",
         "",
         f"## Overall coverage: {o['coverage_pct']}%  `{_bar(o['coverage_pct'])}`  · ETA {_human(data['eta']['eta_seconds_overall'])}",
         f"- **Verified: {o['verified']}/{o['total']} cells** ({o['coverage_pct']}%)",
         f"- Accounted (verified + evidenced gaps): {o['accounted']}/{o['total']} ({o['accounted_pct']}%)",
         "",
         "### Resource metrics (Verified = success criterion)",
         "",
         "| Downloaded | Verified ✅ | Rejected |",
         "|---|---|---|",
         f"| {rm['downloaded']} | **{rm['verified']}** | {rm['rejected']} |",
         f"_Downloaded = files fetched into verification · Verified = passed V1-V11 (success) · "
         f"Rejected = downloaded but failed verification · counters: {rm['counters_source']}_",
         "",
         "### Cell states",
         "",
         "| State | Cells | Meaning |",
         "|---|---|---|",
         f"| ✅ VERIFIED | {o['by_state']['VERIFIED']} | verified in repository |",
         f"| ⏳ DOWNLOADING | {o['by_state']['DOWNLOADING']} | resolved source, fetch/verify in progress |",
         f"| 🔁 RETRY_SCHEDULED | {o['by_state']['RETRY_SCHEDULED']} | source failed, waiting on backoff |",
         f"| ⬜ UNRESOLVED | {o['by_state']['UNRESOLVED']} | expected, no source resolved yet — discovery ongoing (NOT Missing) |",
         f"| 📄 DOCUMENTED_GAP | {o['by_state']['DOCUMENTED_GAP']} | evidenced Missing (official+mirror+repo exhausted) |",
         "",
         "## Matrix denominator (how the total is calculated)",
         "",
         f"**Priority-{data['priority_scope']} document types ({den['num_doc_types']}):** "
         + " · ".join(f"`{d}`" for d in den['priority_doc_types']),
         "",
         "| Board | Classes | Subject×Class pairs | × Doc-types | = Expected cells |",
         "|---|---|---|---|---|"]
    for board, d in den["per_board"].items():
        L.append(f"| {board} | {len(d['classes'])} ({', '.join(c.replace('Class_','') for c in d['classes'])}) "
                 f"| {d['subject_class_pairs']} | {d['num_doc_types']} | **{d['expected_cells']}** |")
    L.append(f"| **TOTAL** |  |  |  | **{den['total_expected_cells']}** |")
    L += ["",
          "## Source provenance (priority ladder: official → official mirror → third-party)",
          "",
          f"- Official: {prov['official']} · Official mirror: {prov['official_mirror']} · "
          f"Third-party (tagged, awaiting official replacement): {prov['third_party']}",
          "",
          "## Board-wise progress + ETA",
          "",
          "| Board | Coverage | ETA | Verified | Downloading | Retry | Unresolved | Gap | Expected |",
          "|---|---|---|---|---|---|---|---|---|"]
    labels = {"CBSE": "CBSE", "APSCERT": "AP SCERT", "TSSCERT": "TS SCERT", "CISCE": "CISCE"}
    order = ["CBSE", "APSCERT", "TSSCERT", "CISCE"]
    for board in [b for b in order if b in data["per_board"]]:
        t = data["per_board"][board]
        s = t["by_state"]
        L.append(f"| {labels.get(board, board)} | {t['coverage_pct']}% `{_bar(t['coverage_pct'], 10)}` | "
                 f"{t['eta_human']} | {s['VERIFIED']} | {s['DOWNLOADING']} | {s['RETRY_SCHEDULED']} | "
                 f"{s['UNRESOLVED']} | {s['DOCUMENTED_GAP']} | {t['total']} |")
    L += ["", "## By document type", "",
          "| Document Type | Coverage | Verified | Downloading | Retry | Unresolved | Gap |",
          "|---|---|---|---|---|---|---|"]
    for dt, t in sorted(data["per_doc_type"].items(), key=lambda kv: -kv[1]["coverage_pct"]):
        s = t["by_state"]
        L.append(f"| {dt} | {t['coverage_pct']}% `{_bar(t['coverage_pct'], 10)}` | "
                 f"{s['VERIFIED']} | {s['DOWNLOADING']} | {s['RETRY_SCHEDULED']} | "
                 f"{s['UNRESOLVED']} | {s['DOCUMENTED_GAP']} |")
    L += ["", "## Per-cell detail (Board → Class → Subject → Document Type)", "",
          "| Board | Class | Subject | Doc Type | State | Sources |",
          "|---|---|---|---|---|---|"]
    for r in data["rows"]:
        L.append(f"| {r['board']} | {r['class']} | {r['subject']} | {r['doc_type']} | "
                 f"{ICON.get(r['state'],'')} {r['state']} | {r['sources'] or '—'} |")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--priority", default="A", choices=["A", "AB"])
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    priorities = ("A",) if args.priority == "A" else ("A", "B")
    data = compute(ws, priorities)

    reports_dir = ws.p("reports_dir")
    reports_dir.mkdir(parents=True, exist_ok=True)
    (reports_dir / "COVERAGE_MATRIX.md").write_text(render_md(data), encoding="utf-8")
    write_json(reports_dir / "COVERAGE_MATRIX.json", data)

    o = data["overall"]
    rm = data["resource_metrics"]
    if not args.quiet:
        print(f"coverage {o['coverage_pct']}% verified ({o['verified']}/{o['total']} cells, denom={data['denominator']['total_expected_cells']}) · "
              f"downloaded={rm['downloaded']} verified={rm['verified']} rejected={rm['rejected']} · "
              f"ETA {_human(data['eta']['eta_seconds_overall'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
