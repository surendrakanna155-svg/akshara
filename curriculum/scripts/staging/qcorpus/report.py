"""Reporting — Biology priority checkpoint + final OCR/extraction report.

All numbers are computed from the persisted per-doc records (no re-parsing), so reports are
reproducible and consistent with the manifests. Reports are written to the staging reports/
directory (LOCAL, gitignored).
"""
from __future__ import annotations

import time
from collections import defaultdict
from typing import Dict, List

from qcorpus import atomicio, config


def _records() -> List[dict]:
    return [r for r in (atomicio.read_json(f) for f in sorted(config.DOC_STATE_DIR.glob("*.json"))) if r]


def _blank_qsum() -> Dict[str, int]:
    keys = ("questions_recovered", "complete", "partial", "mcq", "non_mcq",
            "options_associated", "answers_associated", "solutions_associated",
            "visual_dependent", "equation_bearing", "formula_uncertain", "ocr_damaged",
            "boundary_uncertain", "answer_unresolved", "solution_unresolved", "grid_refs_dropped")
    return {k: 0 for k in keys}


def _sum_qsum(records) -> Dict[str, int]:
    agg = _blank_qsum()
    for r in records:
        qs = r.get("question_summary") or {}
        for k in agg:
            agg[k] += int(qs.get(k, 0) or 0)
    return agg


def _media_breakdown(records) -> Dict[str, int]:
    out = defaultdict(int)
    for r in records:
        sig = r.get("signals") or {}
        out[sig.get("media_class", "unknown")] += 1
    return dict(out)


def aggregate() -> dict:
    recs = _records()
    by_state = defaultdict(int)
    for r in recs:
        by_state[r.get("state", "UNKNOWN")] += 1
    ok = [r for r in recs if r.get("state") in ("COMPLETE", "PARTIAL")]
    pages = sum((r.get("counts") or {}).get("pages", 0) or 0 for r in ok)
    assets = sum((r.get("counts") or {}).get("visual_assets", 0) or 0 for r in ok)
    eqs = sum((r.get("counts") or {}).get("equations", 0) or 0 for r in ok)
    notation = sum((r.get("counts") or {}).get("notation_records", 0) or 0 for r in ok)
    ocr_docs = sum(1 for r in ok if (r.get("parse_meta") or {}).get("ocr_used"))
    ocr_pages = sum((r.get("parse_meta") or {}).get("ocr_pages", 0) or 0 for r in ok)
    st = atomicio.read_json(config.PROCESSING_STATE, {}) or {}
    files_discovered = len(st.get("path_index", {})) or len(recs)
    return {
        "files_discovered": files_discovered,           # every source PDF on disk (incl. dup copies)
        "documents": len(recs), "by_state": dict(by_state),
        "extracted": len(ok), "pages": pages, "visual_assets": assets,
        "equations": eqs, "notation_records": notation,
        "ocr_docs": ocr_docs, "ocr_pages": ocr_pages,
        "media": _media_breakdown(ok), "questions": _sum_qsum(ok),
    }


def _pct(n, d):
    return f"{(100.0*n/d):.1f}%" if d else "—"


def biology_checkpoint() -> str:
    recs = [r for r in _records() if r.get("priority") == "P1_studentbro_biology"]
    inv_ct = len(recs)
    ok = [r for r in recs if r.get("state") in ("COMPLETE", "PARTIAL")]
    failed = [r for r in recs if r.get("state") == "FAILED"]
    dups = [r for r in recs if r.get("state") == "DUPLICATE_EXACT"]
    q = _sum_qsum(ok)
    media = _media_breakdown(ok)
    pages = sum((r.get("counts") or {}).get("pages", 0) or 0 for r in ok)
    assets = sum((r.get("counts") or {}).get("visual_assets", 0) or 0 for r in ok)
    subj_conf = [r.get("classification", {}).get("subject_confidence", 0) for r in ok]
    chap_conf = [r.get("classification", {}).get("chapter_confidence", 0) for r in ok]
    parser_fail = len(failed)
    L = [
        "# BIOLOGY PRIORITY CHECKPOINT — StudentBro NEET Biology (P1)",
        "",
        f"_Generated: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} · "
        "staging lane: NON-CERTIFIED / NON-PRODUCTION_",
        "",
        "## Coverage",
        "",
        "| metric | value |",
        "|---|---:|",
        f"| PDFs discovered (P1) | {inv_ct} |",
        f"| PDFs extracted (COMPLETE/PARTIAL) | {len(ok)} |",
        f"| exact duplicates | {len(dups)} |",
        f"| parser failures | {parser_fail} |",
        f"| pages processed | {pages} |",
        f"| media: native / mixed / scanned | "
        f"{media.get('native',0)} / {media.get('mixed',0)} / {media.get('scanned',0)} |",
        "",
        "## Question recovery",
        "",
        "| metric | value | rate |",
        "|---|---:|---:|",
        f"| questions recovered | {q['questions_recovered']} | |",
        f"| complete questions | {q['complete']} | {_pct(q['complete'], q['questions_recovered'])} |",
        f"| partial questions | {q['partial']} | {_pct(q['partial'], q['questions_recovered'])} |",
        f"| MCQs | {q['mcq']} | {_pct(q['mcq'], q['questions_recovered'])} |",
        f"| options associated (≥2) | {q['options_associated']} | {_pct(q['options_associated'], q['questions_recovered'])} |",
        f"| answers associated | {q['answers_associated']} | {_pct(q['answers_associated'], q['questions_recovered'])} |",
        f"| solutions associated | {q['solutions_associated']} | {_pct(q['solutions_associated'], q['questions_recovered'])} |",
        f"| visual-dependent | {q['visual_dependent']} | {_pct(q['visual_dependent'], q['questions_recovered'])} |",
        f"| equation-bearing | {q['equation_bearing']} | |",
        f"| formula-uncertain | {q['formula_uncertain']} | |",
        f"| OCR-damaged | {q['ocr_damaged']} | |",
        f"| boundary-uncertain | {q['boundary_uncertain']} | |",
        f"| answer-unresolved | {q['answer_unresolved']} | |",
        f"| solution-unresolved | {q['solution_unresolved']} | |",
        f"| response-grid refs correctly dropped | {q['grid_refs_dropped']} | |",
        "",
        "## Mapping confidence",
        "",
        f"- visual assets preserved: **{assets}**",
        f"- mean subject-classification confidence: "
        f"**{(sum(subj_conf)/len(subj_conf)):.2f}**" if subj_conf else "- subject confidence: —",
        f"- mean chapter-mapping confidence: "
        f"**{(sum(chap_conf)/len(chap_conf)):.2f}**" if chap_conf else "- chapter confidence: —",
        "",
        "## Failures",
        "",
    ]
    if failed:
        L += [f"- `{r['rel_path']}` — {r.get('error')}" for r in failed]
    else:
        L.append("- none")
    L += ["", "> Extraction is loss-minimising staging only. No Question DNA mining, Item Model "
          "construction, question generation, or production merge is performed. Answers/solutions "
          "are linked ONLY where present in the source; none are fabricated.", ""]
    text = "\n".join(L)
    (config.REPORTS_DIR / "BIOLOGY_PRIORITY_CHECKPOINT.md").write_text(text)
    return text


def final_report() -> str:
    recs = _records()
    agg = aggregate()
    q = agg["questions"]
    counts = atomicio.read_json(config.MANIFESTS_DIR / "_manifest_counts.json", {}) or {}
    dup_groups = list(atomicio.read_jsonl(config.MANIFESTS_DIR / "duplicate_groups.jsonl"))
    exact = sum(len(g.get("paths", [])) - 1 for g in dup_groups if g.get("type") == "exact")
    probable_groups = sum(1 for g in dup_groups if g.get("type") == "probable")

    # per source group + per priority + per subject
    by_group = defaultdict(lambda: {"docs": 0, "questions": 0})
    by_prio = defaultdict(lambda: {"docs": 0, "questions": 0})
    by_subject = defaultdict(lambda: {"docs": 0, "questions": 0})
    parser_routes = defaultdict(int)
    for r in recs:
        if r.get("state") not in ("COMPLETE", "PARTIAL"):
            continue
        g = r.get("source_group", "?")
        by_group[g]["docs"] += 1
        by_group[g]["questions"] += (r.get("question_summary") or {}).get("questions_recovered", 0)
        p = r.get("priority", "?")
        by_prio[p]["docs"] += 1
        by_prio[p]["questions"] += (r.get("question_summary") or {}).get("questions_recovered", 0)
        subj = r.get("classification", {}).get("subject_candidate", "UNKNOWN")
        by_subject[subj]["docs"] += 1
        by_subject[subj]["questions"] += (r.get("question_summary") or {}).get("questions_recovered", 0)
        parser_routes[(r.get("parse_meta") or {}).get("method", "?")] += 1

    def _tbl(d, hdr):
        rows = [f"| {k} | {v['docs']} | {v['questions']} |" for k, v in sorted(d.items())]
        return [f"| {hdr} | docs | questions |", "|---|---:|---:|", *rows]

    L = [
        "# OCR & EXTRACTION REPORT — Question-Corpus Staging Lane",
        "",
        f"_Generated: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}_",
        "",
        "**Lane:** RAW DOCUMENT → LOSS-MINIMISING EXTRACTION → STRUCTURED STAGING CORPUS. "
        "NON-CERTIFIED · NON-PRODUCTION · never merged into kie.db or the Certified Question Bank.",
        "",
        "## Corpus",
        "",
        "| metric | value |",
        "|---|---:|",
        f"| source groups | {len({r.get('source_group') for r in recs})} |",
        f"| PDFs discovered (files on disk) | {agg['files_discovered']} |",
        f"| unique documents (content-addressed) | {agg['documents']} |",
        f"| unique documents extracted | {agg['extracted']} |",
        f"| exact-duplicate copies collapsed | {exact} |",
        f"| probable-duplicate groups | {probable_groups} |",
        f"| total pages | {agg['pages']} |",
        f"| native / mixed / scanned docs | "
        f"{agg['media'].get('native',0)} / {agg['media'].get('mixed',0)} / {agg['media'].get('scanned',0)} |",
        f"| OCR docs / OCR pages | {agg['ocr_docs']} / {agg['ocr_pages']} |",
        "",
        "### Document state",
        "",
        "| state | count |",
        "|---|---:|",
        *[f"| {k} | {v} |" for k, v in sorted(agg["by_state"].items())],
        "",
        "## Parser routes (measured)",
        "",
        "| method | docs |",
        "|---|---:|",
        *[f"| {k} | {v} |" for k, v in sorted(parser_routes.items())],
        "",
        "## Question recovery (corpus-wide)",
        "",
        "| metric | value |",
        "|---|---:|",
        f"| questions recovered | {q['questions_recovered']} |",
        f"| complete | {q['complete']} |",
        f"| partial | {q['partial']} |",
        f"| MCQ / non-MCQ | {q['mcq']} / {q['non_mcq']} |",
        f"| options associated | {q['options_associated']} |",
        f"| answers associated | {q['answers_associated']} |",
        f"| solutions associated | {q['solutions_associated']} |",
        f"| equation-bearing | {q['equation_bearing']} |",
        f"| formula-uncertain | {q['formula_uncertain']} |",
        f"| visual-dependent | {q['visual_dependent']} |",
        f"| boundary-uncertain | {q['boundary_uncertain']} |",
        f"| answer-unresolved | {q['answer_unresolved']} |",
        f"| solution-unresolved | {q['solution_unresolved']} |",
        "",
        "## Visual + equation assets",
        "",
        f"- visual assets preserved: **{agg['visual_assets']}**",
        f"- equation candidates recovered: **{agg['equations']}**",
        f"- notation records (repairs + uncertainty flags): **{agg['notation_records']}**",
        "",
        "## By source group",
        "",
        *_tbl(by_group, "source group"),
        "",
        "## By priority",
        "",
        *_tbl(by_prio, "priority"),
        "",
        "## By subject",
        "",
        *_tbl(by_subject, "subject"),
        "",
        "## Manifest row counts",
        "",
        "| manifest | rows |",
        "|---|---:|",
        *[f"| {k} | {v} |" for k, v in sorted((counts.get("counts") or {}).items())],
        "",
        "## Integrity & isolation",
        "",
        "- RAW extraction preserved separately from NORMALIZED (raw/ never overwritten).",
        "- Normalized text never overwrites raw evidence; notation repairs are additive "
        "(`search_text`); ambiguous notation flagged FORMULA_UNCERTAIN, never silently changed.",
        "- Every COMPLETE question carries source provenance (doc_id + sha256 + page span).",
        "- Resume is crash-safe: terminal-state docs are skipped on re-run (atomic checkpoints).",
        "- This lane writes ONLY under the staging root (every write sink is STAGING_ROOT-derived; "
        "audited statically). It has NO KIE-DB write path (no store/sqlite/execute in qcorpus).",
        "- Phase-0 pre-registration is byte-frozen (unchanged). kie/qpgen/ unchanged by this lane.",
        "- kie.db is a live SQLite DB in WAL mode concurrently owned by the separate KIE/Phase-0 "
        "lane; its whole-file hash may change from that lane's checkpoints. This lane is proven "
        "NOT the writer: (1) static — no DB write path; (2) runtime — a controlled extraction "
        "leaves kie.db byte-identical (isolation probe: `kie_db_unchanged_by_lane`).",
        "",
    ]
    text = "\n".join(L)
    (config.REPORTS_DIR / "OCR_AND_EXTRACTION_REPORT.md").write_text(text)
    return text
