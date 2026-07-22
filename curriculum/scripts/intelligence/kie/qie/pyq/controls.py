"""Program B — adversarial controls for the B1 corpus classifier (same governance mechanic as
examdna_controls / factory.controls). Construct deliberately-BROKEN inputs and assert the classifier REFUSES to
over-attribute; also assert it SUCCEEDS on genuinely-signalled inputs. A classifier that cannot fail the D5
folder-trust attack is not evidence, and any measured DNA built on it would be theatre.

Run before any B1 output is trusted (wired into the B1 test).
"""
from __future__ import annotations

from typing import List, Tuple

from kie.qie.pyq import source_class as SC


class PyqClassifierControlBreach(Exception):
    """A known-bad classification survived (over-attribution) or a known-good one was refused."""


def _row(**kw) -> dict:
    """A minimal source_documents-shaped row (classify reads it via [] access)."""
    base = {"doc_id": "d", "rel_path": "", "category": None, "subject": None, "doc_type": None, "year": None}
    base.update(kw)
    return base


# (name, row, head_text, predicate(result)->bool, why) — predicate MUST hold or it's a breach.
def _cases() -> List[Tuple[str, dict, str, "callable", str]]:
    return [
        # ── NEGATIVE controls: the classifier MUST NOT over-attribute ──
        ("dump_folder_only_no_exam",
         _row(rel_path="Cursor_Downloads/some_paper.pdf", category="Cursor_Downloads", doc_type="previous_paper"),
         "", lambda r: r["exam_resolved"] is None and r["eligible_for_dna"] == 0,
         "a dump top-folder must NEVER assign an exam (defect D5); no exam ⇒ not DNA-eligible"),

        ("path_content_conflict_holds",
         _row(rel_path="Cursor_Downloads/x/JEE_Advanced/Previous_Papers/2010/JEE_Advanced_2010_Paper1.pdf",
              doc_type="previous_paper"),
         "This is the National Eligibility cum Entrance Test NEET 2010 booklet",
         lambda r: r["exam_resolved"] is None and r["exam_method"] == "ambiguous",
         "path says JEE_ADVANCED but content says NEET ⇒ honest-null (never trust the folder over content)"),

        ("bare_jee_unqualified_holds",
         _row(rel_path="Cursor_Downloads/archive/JEE/paper.pdf", doc_type="previous_paper"),
         "", lambda r: r["exam_resolved"] is None,
         "a bare 'JEE' with no main/advanced qualifier is ambiguous ⇒ honest-null (fail-closed)"),

        ("dpp_never_eligible",
         _row(rel_path="Cursor_Downloads/studentbro_neet_dpps/NEET/Biology/dpp_01.pdf", doc_type="dpp"),
         "", lambda r: r["source_role"] == "practice_dpp" and r["eligible_for_dna"] == 0,
         "a DPP is practice, not a past exam ⇒ separate dataset, never feeds exam DNA (OD-1)"),

        ("mock_never_eligible",
         _row(rel_path="Cursor_Downloads/allen_jee_main_mock/JEE_Main/Mock_2025/mock.pdf", doc_type="mock_test"),
         "", lambda r: r["source_role"] == "mock" and r["eligible_for_dna"] == 0,
         "a mock test is not a past exam ⇒ separate dataset (OD-1)"),

        ("previous_paper_under_dpp_archive_downgraded",
         _row(rel_path="Cursor_Downloads/physicsaholics_dpps/NEET/Physics/dpp_set.pdf", doc_type="previous_paper"),
         "", lambda r: r["source_role"] == "practice_dpp" and r["eligible_for_dna"] == 0,
         "a *_dpps archive is more specific than a stale doc_type ⇒ practice, not genuine_pyq"),

        ("answer_key_mislabelled_prev_paper_excluded",
         _row(rel_path="NEET/Previous_Papers/2018/NEET_2018_answer-ky_SetEE.pdf", category="NEET",
              doc_type="previous_paper", year=2018),
         "NEET-2018 KEY 1 1 46 3 91 1",   # even a NEET-corroborating answer table must NOT make it eligible
         lambda r: r["source_role"] == "solution_key" and r["eligible_for_dna"] == 0,
         "a pure answer key mislabelled previous_paper must NOT feed exam DNA (P0 leak); a key's own text "
         "naming the exam does not rescue it"),

        ("pure_solution_pdf_excluded",
         _row(rel_path="NEET/Previous_Papers/2024/NEET_2024_R4-paper-solution.pdf", doc_type="previous_paper"),
         "", lambda r: r["source_role"] == "solution_key" and r["eligible_for_dna"] == 0,
         "a standalone solution PDF is not a question paper (P0 leak)"),

        ("paper_with_solutions_kept",
         _row(rel_path="NEET/Previous_Papers/2022/NEET_2022_Final_Paper_with_Sol.pdf", category="NEET",
              doc_type="previous_paper", year=2022),
         "", lambda r: r["source_role"] == "genuine_pyq" and r["eligible_for_dna"] == 1,
         "a paper that CARRIES solutions still has real questions ⇒ kept (answers stripped at B3), not excluded"),

        ("dpp_question_bank_token_does_not_escape",
         _row(rel_path="Cursor_Downloads/allen_dpp/NEET/Physics/chapterwise_question_bank_dpp.pdf"),
         "", lambda r: r["source_role"] == "practice_dpp" and r["eligible_for_dna"] == 0,
         "a generic 'question bank' token must NOT rescue a DPP into genuine_pyq (P1 latent leak)"),

        ("bare_key_spelling_excluded",
         _row(rel_path="NEET/Previous_Papers/2019/NEET_2019_response_keys.pdf", category="NEET",
              doc_type="previous_paper", year=2019),
         "", lambda r: r["source_role"] == "solution_key" and r["eligible_for_dna"] == 0,
         "underscore-delimited answer-key spellings (`_keys`, `_answers`, `_soln`) must be caught for the re-mine "
         "(alnum boundaries, not \\b — the '_' trap); overfitting to two spellings would leak on new sources"),

        ("practice_archive_with_prevpaper_token_not_promoted",
         _row(rel_path="Cursor_Downloads/x_dpps/NEET/Physics/previous_paper_practice_set.pdf"),
         "", lambda r: r["source_role"] == "practice_dpp" and r["eligible_for_dna"] == 0,
         "a doc in a practice archive must NOT be promoted to genuine_pyq even if its filename carries a "
         "'previous_paper' token (P3 escape)"),

        ("zero_content_doc_not_eligible",
         _row(rel_path="Cursor_Downloads/jeeadv_ac_in_archive/JEE_Advanced/Previous_Papers/2017/"
                       "JEE_Advanced_2017_Paper1.pdf", doc_type="previous_paper"),
         "", lambda r: r["eligible_for_dna"] == 0,   # doc_has_chunks defaults False here → no content to mine
         "a genuine paper with NO content chunks cannot be mined ⇒ not DNA-eligible"),

        # ── POSITIVE controls: the classifier MUST succeed on a genuine signal ──
        ("real_category_neet_resolves",
         _row(rel_path="NEET/Previous_Papers/2016/NEET_2016.pdf", category="NEET", doc_type="previous_paper",
              year=2016),
         "", lambda r: r["exam_resolved"] == "NEET" and r["source_role"] == "genuine_pyq"
                       and r["eligible_for_dna"] == 1,
         "a real exam category token (NEET) with a previous_paper doc_type is a valid genuine PYQ"),

        ("official_archive_recovery",
         _row(rel_path="Cursor_Downloads/jeeadv_ac_in_archive/JEE_Advanced/Previous_Papers/2010/"
                       "JEE_Advanced_2010_Paper1.pdf", category="Cursor_Downloads", doc_type="previous_paper"),
         "", lambda r: r["exam_resolved"] == "JEE_ADVANCED" and r["source_authority"] == "official"
                       and r["year_resolved"] == 2010 and r["eligible_for_dna"] == 1,
         "the discarded provenance is reconstructed from the FULL path (official jeeadv archive, year 2010)"),
    ]


def check_controls() -> dict:
    """Run every control; raise PyqClassifierControlBreach on the first that fails. Returns a pass summary."""
    passed = []
    for name, row, head, pred, why in _cases():
        # the zero-content control models a doc with no minable chunks; every other case has content.
        res = SC.classify(row, head, doc_has_chunks=(name != "zero_content_doc_not_eligible"))
        if not pred(res):
            raise PyqClassifierControlBreach(
                f"control '{name}' FAILED — {why}. Got: role={res['source_role']} exam={res['exam_resolved']} "
                f"method={res['exam_method']} eligible={res['eligible_for_dna']} authority={res['source_authority']}")
        passed.append(name)
    return {"controls_passed": len(passed), "names": passed}


if __name__ == "__main__":
    import json
    print(json.dumps(check_controls(), indent=2))
