"""Hermetic unit tests for the staging lane (no PDFs; synthetic page dicts).

Run: PYTHONPATH=scripts/staging curriculum/.venv/bin/python -m pytest scripts/staging/qcorpus/tests
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

from qcorpus import atomicio, classify, fingerprint, notation, questions


# ── notation: preservation-first + additive search_text + uncertainty flags ────────
def test_search_text_expands_super_subscripts_additively():
    text = "The mass is 10⁻³¹ kg and H₂SO₄ with x²"
    search, repairs = notation.build_search_text(text)
    assert "10^-31" in search or "10^{-31}" in search
    assert "H_2SO_4" in search
    assert "x^2" in search
    # raw text is untouched (preservation-first) — repairs only build the search form
    assert "10⁻³¹" in text and text == "The mass is 10⁻³¹ kg and H₂SO₄ with x²"
    assert all(r["repair_confidence"] >= 0.99 for r in repairs)


def test_native_text_not_flagged_but_ocr_flattening_is():
    native = "The atomic number is 6 and radius r"
    assert notation.flag_uncertain(native, is_ocr=False) == []
    # OCR page with flattened chemical formula + lost superscript -> flagged, NOT repaired
    ocr = "Compound H2SO4 reacts and x2 term"
    flags = notation.flag_uncertain(ocr, is_ocr=True)
    reasons = {f["reason"] for f in flags}
    assert "possible_flattened_subscript" in reasons or "possible_lost_superscript" in reasons
    for f in flags:
        assert f["flag"] == "FORMULA_UNCERTAIN"


def test_flattened_exponent_flagged_even_native():
    flags = notation.flag_uncertain("value 10-31 joule", is_ocr=False)
    assert any(f["reason"] == "possible_flattened_exponent" for f in flags)


# ── fingerprint: content identity + dedup signals ──────────────────────────────────
def test_doc_id_is_content_prefix():
    assert fingerprint.doc_id_for("a" * 64) == "a" * 16


def test_normalized_filename_collapses_separators():
    a = fingerprint.normalized_filename("NEET_Biology_DPP_Animal-Kingdom.pdf")
    b = fingerprint.normalized_filename("neet biology dpp animal kingdom.PDF")
    assert a == b == "neet_biology_dpp_animal_kingdom"


def test_text_fingerprint_stable_and_ignores_whitespace():
    t1 = fingerprint.text_fingerprint("The quick brown fox jumps over the lazy dog again")
    t2 = fingerprint.text_fingerprint("The  quick\nbrown FOX jumps over the lazy dog again")
    assert t1 == t2 and t1 is not None
    assert fingerprint.text_fingerprint("short") is None


# ── atomic I/O + jsonl ─────────────────────────────────────────────────────────────
def test_atomic_write_and_jsonl_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "sub" / "state.json"
        atomicio.write_json_atomic(p, {"a": 1})
        assert atomicio.read_json(p) == {"a": 1}
        assert not list(Path(d).rglob("*.tmp"))          # no temp left behind
        jp = Path(d) / "m.jsonl"
        with atomicio.JsonlWriter(jp) as w:
            w.write({"x": 1}); w.write({"x": 2})
        assert [r["x"] for r in atomicio.read_jsonl(jp)] == [1, 2]


def test_jsonl_writer_preserves_prior_on_failure():
    with tempfile.TemporaryDirectory() as d:
        jp = Path(d) / "m.jsonl"
        with atomicio.JsonlWriter(jp) as w:
            w.write({"ok": True})
        try:
            with atomicio.JsonlWriter(jp) as w:
                w.write({"bad": 1})
                raise RuntimeError("boom")
        except RuntimeError:
            pass
        assert [r for r in atomicio.read_jsonl(jp)] == [{"ok": True}]   # unchanged
        assert not list(Path(d).glob("*.tmp"))


# ── classification confidence ──────────────────────────────────────────────────────
def test_classify_uses_provenance_as_authoritative():
    prov = {"subject": "Biology", "chapter": "Animal Kingdom", "source_url": "http://x/y.pdf"}
    c = classify.classify_static("studentbro_neet_dpps",
                                 ["studentbro_neet_dpps", "NEET", "Biology", "f.pdf"],
                                 "NEET_Biology_DPP_Animal_Kingdom.pdf", prov)
    assert c["subject_candidate"] == "Biology" and c["subject_confidence"] >= 0.95
    assert c["chapter_candidate"] == "Animal Kingdom"
    assert c["exam_profile"] == "NEET" and c["document_type"] == "DPP"


def test_classify_unknown_when_no_evidence():
    c = classify.classify_static("jeebooks_dpp", ["jeebooks_dpp", "x.pdf"], "x.pdf", None)
    assert c["subject_candidate"] == "UNKNOWN" and c["subject_confidence"] == 0.0


# ── question recovery: StudentBro format ────────────────────────────────────────────
def _page(n, text, ocr=False):
    return {"page": n, "text": text, "images": [], "equations": [], "tables": [],
            "blocks": [], "ocr": ocr}


STUDENTBRO_P1 = """Max. Marks : 180
RESPONSE GRID
1.
2.
3.
SYLLABUS : Anatomy
1.
During formation of leaves, some cells left behind constitute
(a)
Lateral meristem
(b)
Axillary bud
(c)
Cork cambium
(d)
Fascicular cambium
2.
Function of companion cells is
(a)
providing energy
(b)
providing water
(c)
loading sucrose
(d)
none
www.studentbro.in
"""

STUDENTBRO_ANS = """ANSWER KEY
1. (a) 2. (a)
"""


def test_studentbro_recovery_drops_grid_and_links_answers():
    pages = [_page(1, STUDENTBRO_P1), _page(2, STUDENTBRO_ANS)]
    out = questions.recover_questions("doc123456789abc", pages, assets=[])
    qs = out["questions"]
    # exactly two real questions recovered; response-grid bare numbers dropped
    assert [q["number"] for q in qs] == [1, 2]
    assert out["summary"]["grid_refs_dropped"] >= 3
    q1 = qs[0]
    assert len(q1["options"]) == 4 and q1["option_label_style"] == "alpha"
    assert q1["answer_ref"] == "a" and q1["answer_associated"] is True
    assert q1["status"] == "COMPLETE"          # 4 opts + answer + no blockers
    assert "Lateral meristem" in q1["options"][0]["text"]


MATHONGO = """Q1. JEE Main 2026 (23 January Shift 1)
The correct sequence for the conversion is
(1) first
(2) second
(3) third
(4) fourth
Q2. JEE Main 2026 (24 January Shift 2)
From the following, how many compounds as shown above
(1) Three
(2) Five
(3) Four
(4) Two
www.mathongo.com
"""


def test_mathongo_numeric_options_and_visual_flag():
    # Q2 references "as shown above" and its page has an asset -> VISUAL_DEPENDENT
    assets = [{"asset_id": "d:a1", "page_number": 1}]
    out = questions.recover_questions("mathongodoc1234", [_page(1, MATHONGO)], assets=assets)
    qs = out["questions"]
    assert [q["number"] for q in qs] == [1, 2]
    assert qs[0]["option_label_style"] == "numeric" and len(qs[0]["options"]) == 4
    assert qs[1]["visual_dependent"] is True
    assert "VISUAL_DEPENDENT" in qs[1]["statuses"]
    # no answer key present -> honestly unresolved, never fabricated
    assert all(q["answer_ref"] is None for q in qs)
    assert out["summary"]["answers_associated"] == 0


STUDENTBRO_HINTS = """1.
During formation of leaves, some cells left behind constitute
(a)
Lateral meristem
(b)
Axillary bud
(c)
Cork cambium
(d)
Fascicular cambium
HINTS & SOLUTIONS
1.
(a)
The lateral meristem is left behind and constitutes axillary regions.
"""


def test_studentbro_hints_and_solutions_mines_answer_and_solution():
    # StudentBro puts the correct option + worked solution in a trailing HINTS & SOLUTIONS
    # section as `N.` -> `(x)` -> prose. Answer + solution must be mined from real source.
    out = questions.recover_questions("hintsdoc0000abc", [_page(1, STUDENTBRO_HINTS)], assets=[])
    qs = out["questions"]
    assert len(qs) == 1                                    # solution entry not double-counted
    q = qs[0]
    assert q["answer_ref"] == "a" and q["answer_associated"] is True
    assert q["solution_present"] is True
    assert q["solution_ref"] and "lateral meristem" in q["solution_ref"].lower()
    assert q["status"] == "COMPLETE"                        # structural; answer/solution present


def test_options_incomplete_flagged():
    txt = "1.\nA question stem here\n(a)\nonly one option\n"
    out = questions.recover_questions("docz", [_page(1, txt)], assets=[])
    q = out["questions"][0]
    assert "OPTIONS_INCOMPLETE" in q["statuses"] and q["status"] != "COMPLETE"
