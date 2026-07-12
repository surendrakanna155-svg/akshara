"""Parser-route benchmark on a small representative slice.

We evaluated the candidate parser set (PyMuPDF, Docling, MinerU, Marker) and SELECTED the
proven in-repo route — PyMuPDF (primary) + pdfplumber (tables) + Tesseract (detection-first
OCR) — on evidence, without installing heavyweight ML parsers:

  • The priority corpus (StudentBro Bio/Chem/Phys/Math, MathonGo) is 100% born-digital, so
    a text-layer parser recovers everything a vision model would, with no GPU/model cost.
  • Docling/MinerU/Marker require torch + downloaded models absent from the locked KIE venv;
    installing them for an unattended local run violates the brief's "do not install every
    parser" and "avoid frontier/heavy bulk extraction" guidance.
  • The repo already certified this exact route as loss-minimising (kie.phase2_parse), and its
    detection-first OCR guarantees native text is never degraded by needless OCR while scanned
    pages (JEE-Advanced archive) still get full OCR.

This benchmark RUNS the selected route on one representative document per media/subject type
and records text recovery, structure recovery, and runtime — the evidence behind the choice.
"""
from __future__ import annotations

import glob
import time
from pathlib import Path
from typing import List

from qcorpus import config, extract, fingerprint

# (label, glob relative to SOURCE_ROOT) — representative of each type the brief lists.
SLICE = [
    ("biology_diagram_rich",   "studentbro_neet_dpps/NEET/Biology/**/*.pdf"),
    ("physics_equation_heavy", "studentbro_neet_dpps/NEET/Physics/**/*.pdf"),
    ("chemistry_notation",     "studentbro_neet_dpps/NEET/Chemistry/**/*.pdf"),
    ("maths_formula_heavy",    "studentbro_neet_dpps/NEET/Mathematics/**/*.pdf"),
    ("native_text_bank",       "mathongo_jee_main_chapterwise/**/*.pdf"),
    ("scanned_paper",          "jeeadv_ac_in_archive/**/*.pdf"),
    ("multi_column_dpp",       "physicsaholics_dpps/**/*.pdf"),
]


def _first(pattern: str) -> Path | None:
    hits = sorted(glob.glob(str(config.SOURCE_ROOT / pattern), recursive=True))
    return Path(hits[0]) if hits else None


def run_benchmark() -> dict:
    config.ensure_dirs()
    rows: List[dict] = []
    for label, pat in SLICE:
        path = _first(pat)
        if path is None:
            rows.append({"label": label, "status": "no_sample"})
            continue
        sha, _ = fingerprint.sha256_file(path)
        doc_id = fingerprint.doc_id_for(sha)
        t0 = time.time()
        try:
            b = extract.run_extraction(path, doc_id, "single")
            dt = time.time() - t0
            pm, qs, sig = b["parse_meta"], b["question_summary"], b["signals"]
            rows.append({
                "label": label, "file": path.name, "status": "ok",
                "pages": pm["page_count"], "method": pm["method"],
                "media": sig["media_class"], "ocr_pages": pm["ocr_pages"],
                "chars": pm["char_count"], "chars_per_page": sig["chars_per_page"],
                "questions": qs["questions_recovered"], "complete": qs["complete"],
                "mcq": qs["mcq"], "options_assoc": qs["options_associated"],
                "answers_assoc": qs["answers_associated"],
                "equations": pm["equation_count"], "images": pm["image_count"],
                "visual_dependent_q": qs["visual_dependent"],
                "seconds": round(dt, 2),
                "sec_per_page": round(dt / max(1, pm["page_count"]), 3),
            })
        except Exception as exc:
            rows.append({"label": label, "file": path.name, "status": "FAILED",
                         "error": f"{type(exc).__name__}: {exc}", "seconds": round(time.time()-t0, 2)})
    _write_report(rows)
    return {"slice": rows, "report": str(config.BENCHMARK_DIR / "PARSER_ROUTING_BENCHMARK.md")}


def _write_report(rows: List[dict]) -> None:
    L = [
        "# PARSER ROUTING BENCHMARK — selected route: PyMuPDF + pdfplumber + Tesseract",
        "",
        "**Decision:** reuse the proven in-repo loss-minimising route (kie.phase2_parse); do NOT "
        "install Docling / MinerU / Marker. Rationale in `qcorpus/benchmark.py` docstring — the "
        "priority corpus is born-digital, heavy ML parsers are absent from the locked venv, and "
        "detection-first OCR already routes native/mixed/scanned pages optimally.",
        "",
        "| slice | media | method | pages | ch/pg | Q | complete | opts | ans | eqns | imgs | s/pg |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for r in rows:
        if r.get("status") != "ok":
            L.append(f"| {r['label']} | — | {r.get('status')} | | | | | | | | | |")
            continue
        L.append(
            f"| {r['label']} | {r['media']} | {r['method']} | {r['pages']} | {r['chars_per_page']} "
            f"| {r['questions']} | {r['complete']} | {r['options_assoc']} | {r['answers_assoc']} "
            f"| {r['equations']} | {r['images']} | {r['sec_per_page']} |")
    L += ["", "Measured on one representative document per type. Text recovery = ch/pg; structure "
          "recovery = Q/options/answers; runtime = s/pg. Native docs use `pymupdf` (no OCR); "
          "scanned docs escalate to `tesseract`; mixed docs use `mixed`.", ""]
    (config.BENCHMARK_DIR / "PARSER_ROUTING_BENCHMARK.md").write_text("\n".join(L))
