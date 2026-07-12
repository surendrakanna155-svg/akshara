"""Question-structure recovery — deterministic, format-aware, honest status labelling.

Recovers question objects from the per-page text stream produced by the reused parser.
Tuned to the two dominant corpus formats (verified against real files):
  • StudentBro DPP  — bare `N.` question numbers, `(a)-(d)` options, a RESPONSE-GRID block
    of bare numbers that must NOT be mistaken for questions, `www.studentbro.in` footers.
  • MathonGo bank   — `Q1.` numbers with exam tags, `(1)-(4)` options, many chemistry
    structures rendered as images -> flagged VISUAL_DEPENDENT.

A single PDF holds many questions; questions and their options may span pages; answer keys
and solutions may live in trailing sections. We recover boundaries, stems, options, and link
answers/solutions/visuals/equations where evidence permits — and NEVER fabricate a missing
answer or solution. Every question carries explicit status labels:
  COMPLETE · PARTIAL · QUESTION_BOUNDARY_UNCERTAIN · OPTIONS_INCOMPLETE · ANSWER_UNRESOLVED
  · SOLUTION_UNRESOLVED · VISUAL_DEPENDENT · FORMULA_UNCERTAIN · OCR_DAMAGED
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional, Tuple

from qcorpus import notation

# ── line grammar ─────────────────────────────────────────────────────────────────
QNUM = re.compile(r"^\s*(?:Q\.?\s*)?(\d{1,3})\s*[.)]\s*(.*)$")          # 1.  / Q1. / 12)
OPT = re.compile(r"^\s*\(\s*([a-dA-D1-4])\s*\)\s*(.*)$")                # (a)/(A)/(1)
ANSWER_HDR = re.compile(r"^\s*(answer\s*key|answers?|answer\s*&?\s*solutions?|key)\s*:?\s*$", re.I)
SOLUTION_HDR = re.compile(r"^\s*(solutions?|hints?\s*&?\s*solutions?|detailed\s*solutions?|explanations?)\s*:?\s*$", re.I)
ANSWER_PAIR = re.compile(r"(\d{1,3})\s*[.)\-:]?\s*\(?\s*([a-dA-D1-4])\s*\)?")

# Genuine figure cues only. Deliberately EXCLUDES bare "following/above/below" — those fire on
# "which of the following" and "all of the above", which reference other OPTIONS, not a figure.
_VISUAL_REF = re.compile(
    r"\b(figure|fig\.?|diagram|graph|plotted|circuit|schematic|flow\s*chart|"
    r"as\s+shown|shown\s+(?:in|below|above|here|alongside)|"
    r"given\s+(?:figure|diagram|graph|circuit)|"
    r"in\s+the\s+(?:figure|diagram|graph|circuit|adjacent)|"
    r"following\s+(?:figure|diagram|graph|structure|circuit|reaction)|"
    r"structure\s+shown|(?:above|below)\s+(?:figure|diagram|graph|structure|reaction))\b", re.I)

# footer/header/boilerplate lines dropped during accumulation (never part of a stem/option).
_NOISE = re.compile(
    r"^\s*(www\.\w+\.\w+|#\w+|mathongo|response\s*grid|response|grid|space\s*for\s*rough\s*work|"
    r"syllabus\b.*|instructions\b.*|max\.?\s*marks.*|marking\s*scheme.*|time\s*:.*|"
    r"dpp\s*[-/].*|chapter-?wise\s*sheets|date\s*:.*|start\s*time.*|end\s*time.*|"
    r"questions?\s*with\s*answer\s*keys?|question\s*bank.*|"
    r"[A-Z]{1,3}\d{1,3}|[A-Z]-\d{1,3}|\d+\s*/\s*\d+)\s*$", re.I)

_EXPECTED_OPTS = 4


def _norm_label(lbl: str) -> str:
    return lbl.lower()


def _lines_with_pages(pages: List[dict]) -> List[Tuple[str, int, bool]]:
    """Flatten to (line, page_number, page_is_ocr) preserving reading order."""
    out: List[Tuple[str, int, bool]] = []
    for p in pages:
        pno = p.get("page")
        is_ocr = bool(p.get("ocr"))
        for raw in (p.get("text") or "").splitlines():
            line = raw.rstrip()
            if line.strip():
                out.append((line, pno, is_ocr))
    return out


def _find_section_boundaries(lines) -> Tuple[Optional[int], Optional[int]]:
    """Index of first ANSWER-KEY header and first SOLUTION header (or None)."""
    ans_idx = sol_idx = None
    for i, (line, _p, _o) in enumerate(lines):
        if ans_idx is None and ANSWER_HDR.match(line):
            ans_idx = i
        if sol_idx is None and SOLUTION_HDR.match(line):
            sol_idx = i
    return ans_idx, sol_idx


def _parse_answer_key(lines, start: int, end: int) -> Dict[int, str]:
    """Parse a compact ANSWER-KEY grid (e.g. `1. (a) 2. (c) ...`)."""
    text = " ".join(l for l, _p, _o in lines[start:end])
    out: Dict[int, str] = {}
    for m in ANSWER_PAIR.finditer(text):
        num = int(m.group(1))
        if 1 <= num <= 400:
            out.setdefault(num, _norm_label(m.group(2)))    # first mapping wins
    return out


_LEAD_OPT = re.compile(r"^\(\s*([a-dA-D1-4])\s*\)\s*(.*)$")


def _parse_solutions(lines, start: int, end: int) -> Dict[int, dict]:
    """Parse a HINTS & SOLUTIONS section: per question `N.` -> `(answer)` -> explanation.

    Returns {num: {"answer": letter|None, "text": solution_text}}. This is the StudentBro
    layout where the correct option AND worked solution live together after the questions —
    a real source answer, never fabricated. Robust to both `N.`/`(x)` on separate lines and
    `N. (x) prose` on one line.
    """
    out: Dict[int, dict] = {}
    cur: Optional[int] = None
    buf: List[str] = []

    def _flush():
        if cur is None:
            return
        text = " ".join(buf).strip()
        ans = None
        m = _LEAD_OPT.match(text)
        if m:
            ans, text = _norm_label(m.group(1)), m.group(2).strip()
        out.setdefault(cur, {"answer": ans, "text": text[:1200]})

    for line, _p, _o in lines[start + 1:end]:      # skip the header line itself
        if _NOISE.match(line):
            continue
        m = QNUM.match(line)
        if m:
            _flush()
            cur = int(m.group(1))
            buf = [m.group(2).strip()] if m.group(2).strip() else []
        elif cur is not None:
            buf.append(line)
    _flush()
    return out


def recover_questions(doc_id: str, pages: List[dict], assets: List[dict]) -> dict:
    """Recover question objects + a recovery summary for one document."""
    lines = _lines_with_pages(pages)
    ans_hdr, sol_hdr = _find_section_boundaries(lines)

    # Question scan runs only over the QUESTION region (before answer/solution sections).
    q_end = min([i for i in (ans_hdr, sol_hdr) if i is not None], default=len(lines))
    answer_key: Dict[int, str] = {}
    if ans_hdr is not None:
        answer_key.update(_parse_answer_key(lines, ans_hdr, sol_hdr or len(lines)))
    solutions: Dict[int, dict] = {}
    if sol_hdr is not None:
        solutions = _parse_solutions(lines, sol_hdr, len(lines))
        for num, sol in solutions.items():           # answers embedded in the solutions section
            if sol.get("answer"):
                answer_key.setdefault(num, sol["answer"])
    solution_nums = set(solutions)

    # Only CONTENT assets (exclude repeated watermarks/logos) can make a question visual-dependent.
    content_assets = [a for a in assets if not a.get("decorative")]
    pages_with_assets = {a["page_number"] for a in content_assets}
    assets_by_page: Dict[int, list] = {}
    for a in content_assets:
        assets_by_page.setdefault(a["page_number"], []).append(a["asset_id"])
    eq_pages = {p["page"]: len(p.get("equations") or []) for p in pages}
    lowconf_ocr_pages = {p["page"] for p in pages
                         if p.get("ocr") and (p.get("_ocr_conf") is not None and p["_ocr_conf"] < 60)}

    questions: List[dict] = []
    boundary_uncertain = 0
    grid_refs_dropped = 0

    cur: Optional[dict] = None

    def _finalize(q):
        nonlocal boundary_uncertain, grid_refs_dropped
        stem = " ".join(q["_stem_lines"]).strip()
        opts = q["_options"]
        if not stem and not opts:
            grid_refs_dropped += 1                       # bare number (response-grid ref)
            return
        if not opts and stem:
            boundary_uncertain += 1
        _emit(q, stem, opts)

    def _emit(q, stem, opts):
        pages_span = sorted(set(q["_pages"]))
        is_mcq = len(opts) >= 2
        labels = [o["label"] for o in opts]
        style = ("numeric" if all(c in "1234" for c in labels) else
                 "alpha" if labels else "none")
        # visual dependency
        combined = stem + " " + " ".join(o["text"] for o in opts)
        visual_ref = bool(_VISUAL_REF.search(combined))
        linked_assets = sorted({aid for pg in pages_span for aid in assets_by_page.get(pg, [])})
        visual_dependent = visual_ref and bool(linked_assets or any(p in pages_with_assets for p in pages_span))
        # equations
        linked_eq = sum(eq_pages.get(pg, 0) for pg in pages_span)
        # notation
        search_stem, _ = notation.build_search_text(stem)
        formula_uncertain = bool(notation.flag_uncertain(combined, q["_is_ocr"]))
        ocr_damaged = any(pg in lowconf_ocr_pages for pg in pages_span)

        num = q["number"]
        answer = answer_key.get(num)
        sol = solutions.get(num)
        has_solution = num in solution_nums

        statuses: List[str] = []
        if len(opts) >= _EXPECTED_OPTS:
            pass                                  # full 4-option MCQ set
        elif len(opts) >= 1:
            statuses.append("OPTIONS_INCOMPLETE")  # 1-3 options recovered
        else:
            statuses.append("QUESTION_BOUNDARY_UNCERTAIN")  # no options bounded
        if answer is None:
            statuses.append("ANSWER_UNRESOLVED")
        if not has_solution:
            statuses.append("SOLUTION_UNRESOLVED")
        if visual_dependent:
            statuses.append("VISUAL_DEPENDENT")
        if formula_uncertain:
            statuses.append("FORMULA_UNCERTAIN")
        if ocr_damaged:
            statuses.append("OCR_DAMAGED")

        # Structural completeness is INDEPENDENT of answer/solution association — a valid,
        # fully-bounded question can lack an in-source key (tracked separately as
        # ANSWER_UNRESOLVED, never fabricated). A visual-dependent question is never headline
        # COMPLETE (the required figure cannot be verified intact in a staging pass).
        blockers = {"OPTIONS_INCOMPLETE", "QUESTION_BOUNDARY_UNCERTAIN", "OCR_DAMAGED", "FORMULA_UNCERTAIN"}
        structural_ok = is_mcq and len(opts) >= _EXPECTED_OPTS and not (set(statuses) & blockers)
        if structural_ok and not visual_dependent:
            headline = "COMPLETE"
        elif structural_ok and visual_dependent:
            headline = "VISUAL_DEPENDENT"                 # fully bounded, but depends on a figure
        elif is_mcq and len(opts) >= 2 and "OCR_DAMAGED" not in statuses:
            headline = "PARTIAL"
        else:
            headline = statuses[0] if statuses else "PARTIAL"

        qid = f"{doc_id}:q{len(questions)+1:04d}"
        # back-link assets that this question depends on
        if visual_dependent:
            for a in assets:
                if a.get("asset_id") in linked_assets:
                    a.setdefault("linked_question_ids", []).append(qid)
                    a["association_confidence"] = max(a.get("association_confidence", 0.0), 0.5)

        questions.append({
            "question_id": qid, "doc_id": doc_id, "number": num,
            "stem": stem, "stem_search_text": search_stem if search_stem != stem else None,
            "options": opts, "option_label_style": style, "is_mcq": is_mcq,
            "answer_ref": answer, "answer_associated": answer is not None,
            "solution_present": has_solution,
            "solution_ref": (sol or {}).get("text") if sol else None,
            "linked_equation_count": linked_eq,
            "linked_asset_ids": linked_assets,
            "visual_dependent": visual_dependent,
            "pages": pages_span, "start_page": q["start_page"],
            "status": headline, "statuses": statuses or ["COMPLETE"],
        })

    i = 0
    while i < q_end:
        line, pno, is_ocr = lines[i]
        i += 1
        mq = QNUM.match(line)
        mo = OPT.match(line)
        # An option marker takes precedence over QNUM only when we're inside a question
        # (so `(1)` never opens a question, and a numeric option can't be a new stem).
        if mo and cur is not None:
            cur["_options"].append({"label": _norm_label(mo.group(1)),
                                    "text": mo.group(2).strip()})
            cur["_cursor"] = "option"
            cur["_pages"].append(pno)
            if is_ocr:
                cur["_is_ocr"] = True
            continue
        if mq and not (mo and cur is None):
            # close previous question
            if cur is not None:
                _finalize(cur)
            cur = {"number": int(mq.group(1)), "start_page": pno, "_pages": [pno],
                   "_stem_lines": [mq.group(2).strip()] if mq.group(2).strip() else [],
                   "_options": [], "_cursor": "stem", "_is_ocr": is_ocr}
            continue
        if cur is None:
            continue
        if _NOISE.match(line):
            continue                                     # drop footers/grid/boilerplate
        # accumulate onto stem or the current (last) option
        if cur["_cursor"] == "option" and cur["_options"]:
            cur["_options"][-1]["text"] = (cur["_options"][-1]["text"] + " " + line).strip()
        else:
            cur["_stem_lines"].append(line)
        cur["_pages"].append(pno)
        if is_ocr:
            cur["_is_ocr"] = True
    if cur is not None:
        _finalize(cur)

    # ── summary ──────────────────────────────────────────────────────────────
    def _count(pred):
        return sum(1 for q in questions if pred(q))

    summary = {
        "questions_recovered": len(questions),
        "complete": _count(lambda q: q["status"] == "COMPLETE"),
        "partial": _count(lambda q: q["status"] == "PARTIAL"),
        "mcq": _count(lambda q: q["is_mcq"]),
        "non_mcq": _count(lambda q: not q["is_mcq"]),
        "options_associated": _count(lambda q: len(q["options"]) >= 2),
        "answers_associated": _count(lambda q: q["answer_associated"]),
        "solutions_associated": _count(lambda q: q["solution_present"]),
        "visual_dependent": _count(lambda q: q["visual_dependent"]),
        "equation_bearing": _count(lambda q: q["linked_equation_count"] > 0),
        "formula_uncertain": _count(lambda q: "FORMULA_UNCERTAIN" in q["statuses"]),
        "ocr_damaged": _count(lambda q: "OCR_DAMAGED" in q["statuses"]),
        "boundary_uncertain": boundary_uncertain,
        "answer_unresolved": _count(lambda q: not q["answer_associated"]),
        "solution_unresolved": _count(lambda q: not q["solution_present"]),
        "grid_refs_dropped": grid_refs_dropped,
        "answer_key_found": ans_hdr is not None,
        "solutions_section_found": sol_hdr is not None,
    }
    return {"questions": questions, "summary": summary}
