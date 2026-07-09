"""Phase 3 — Metadata Engine. Deterministic document + section metadata.

From each parsed document (Phase 2 output) this derives, with NO AI:
  * a section outline (chapters/topics) via font-size heading detection over the
    block structure PyMuPDF captured — this is the concrete, extracted form of the
    reserved `knowledge_base_prep.chapters/topics` metadata seam;
  * the STEM subject (Physics/Chemistry/Mathematics/Biology) via deterministic
    keyword scoring — the axis JEE/NEET concept extraction (Phase 5) branches on.

Only documents that have been parsed proceed. Idempotent via the stage ledger.
"""
from __future__ import annotations

import json
import re
from typing import Dict, List, Optional, Tuple

from kie import config, ledger, store

# Deterministic STEM subject signatures (word-boundary, case-insensitive counts).
SUBJECT_TERMS: Dict[str, Tuple[str, ...]] = {
    "Physics": (
        "force", "velocity", "acceleration", "momentum", "energy", "electric", "magnetic",
        "current", "voltage", "resistance", "wave", "optics", "refraction", "capacitor",
        "friction", "gravitation", "kinetic", "potential", "newton", "joule", "kinematics",
    ),
    "Chemistry": (
        "mole", "reaction", "acid", "base", "atom", "molecule", "bond", "organic", "oxidation",
        "reduction", "electron", "valence", "compound", "isotope", "hydrocarbon", "enthalpy",
        "equilibrium", "catalyst", "salt", "ion", "periodic",
    ),
    "Mathematics": (
        "theorem", "integral", "derivative", "matrix", "probability", "equation", "function",
        "polynomial", "trigonometry", "vector", "logarithm", "algebra", "geometry", "calculus",
        "quadratic", "determinant", "sequence", "series", "limit",
    ),
    "Biology": (
        "cell", "organism", "tissue", "gene", "species", "enzyme", "protein", "chromosome",
        "photosynthesis", "respiration", "reproduction", "ecosystem", "hormone", "neuron",
        "bacteria", "virus", "membrane", "digestion", "genetics",
    ),
}

_WORD = re.compile(r"[A-Za-z]+")


def infer_subject(text: str) -> Tuple[Optional[str], Dict[str, int]]:
    """Return (best_subject|None, per-subject scores) by deterministic keyword counting."""
    tokens = [t.lower() for t in _WORD.findall(text)]
    counts: Dict[str, int] = {}
    for word in tokens:
        counts[word] = counts.get(word, 0) + 1
    scores = {
        subject: sum(counts.get(term, 0) for term in terms)
        for subject, terms in SUBJECT_TERMS.items()
    }
    best = max(scores, key=lambda s: scores[s]) if scores else None
    if best is None or scores[best] == 0:
        return None, scores
    return best, scores


def _looks_like_heading(text: str) -> bool:
    t = text.strip()
    if not (2 <= len(t) <= 120):
        return False
    if t.endswith((".", ":", ";", ",")) and not re.match(r"^\d+(\.\d+)*\s", t):
        # allow "3.2 Something" but reject full sentences ending in a period
        if len(t.split()) > 12:
            return False
    return bool(re.search(r"[A-Za-z]", t))


def detect_sections(pages: List[dict]) -> List[dict]:
    """Deterministic heading detection: blocks whose font size stands out become
    section titles; sizes bucket into levels. Returns ordered section dicts."""
    blocks = []
    for p in pages:
        for b in p.get("blocks", []):
            if b.get("text") and b.get("size"):
                blocks.append((p["page"], round(float(b["size"]), 1), b["text"].strip(), bool(b.get("bold"))))
    if not blocks:
        return []
    sizes = sorted({s for _, s, _, _ in blocks})
    body = _median([s for _, s, _, _ in blocks])
    # heading sizes = distinct sizes clearly above the body text size
    heading_sizes = [s for s in sizes if s >= body * 1.15]
    if not heading_sizes:
        return []
    # map each heading size to a level (largest size = level 1)
    level_of = {s: i + 1 for i, s in enumerate(sorted(heading_sizes, reverse=True))}
    sections, ordinal, crumb = [], 0, []
    for page, size, text, bold in blocks:
        if size in level_of and _looks_like_heading(text):
            level = level_of[size]
            crumb = crumb[: level - 1] + [text]
            ordinal += 1
            sections.append({
                "ordinal": ordinal, "level": level, "title": text,
                "page": page, "path": " > ".join(crumb),
            })
    return sections


def _median(values: List[float]) -> float:
    s = sorted(values)
    n = len(s)
    if n == 0:
        return 0.0
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def _parsed_text(parsed: dict, cap: int = 200_000) -> str:
    out, total = [], 0
    for p in parsed.get("pages", []):
        t = p.get("text", "")
        out.append(t)
        total += len(t)
        if total >= cap:
            break
    return "\n".join(out)


def process_document(conn, doc_row) -> dict:
    did = doc_row["doc_id"]
    parsed_path = config.PARSED_DIR / f"{did}.json"
    parsed = json.loads(parsed_path.read_text())
    sections = detect_sections(parsed.get("pages", []))
    subject, _scores = infer_subject(_parsed_text(parsed))

    with store.txn(conn):
        conn.execute("DELETE FROM document_sections WHERE doc_id = ?", (did,))
        for s in sections:
            conn.execute(
                """INSERT INTO document_sections(section_id, doc_id, ordinal, level, title, page, path)
                   VALUES (?,?,?,?,?,?,?)""",
                (f"{did}#s{s['ordinal']}", did, s["ordinal"], s["level"], s["title"], s["page"], s["path"]),
            )
        if subject and not doc_row["subject"]:
            conn.execute("UPDATE source_documents SET subject = ? WHERE doc_id = ?", (subject, did))
        ledger.record(conn, did, "metadata", "done", input_sha256=doc_row["sha256"],
                      output_ref=f"sections:{len(sections)}")
    return {"sections": len(sections), "subject": subject}


def run(conn, limit: Optional[int] = None, force: bool = False) -> dict:
    summary = {"processed": 0, "skipped": 0, "failed": 0, "sections": 0, "subjects": {}}
    rows = conn.execute(
        "SELECT s.* FROM source_documents s JOIN parsed_documents p ON p.doc_id = s.doc_id "
        "WHERE s.certify_status = 'certified' ORDER BY s.doc_id"
    ).fetchall()
    for doc_row in rows:
        if limit and summary["processed"] >= limit:
            break
        did = doc_row["doc_id"]
        if not ledger.needs_run(conn, did, "metadata", doc_row["sha256"], force=force):
            summary["skipped"] += 1
            continue
        try:
            r = process_document(conn, doc_row)
        except Exception as exc:
            ledger.record(conn, did, "metadata", "failed", input_sha256=doc_row["sha256"],
                          error=f"{type(exc).__name__}: {exc}")
            conn.commit()
            summary["failed"] += 1
            continue
        summary["processed"] += 1
        summary["sections"] += r["sections"]
        if r["subject"]:
            summary["subjects"][r["subject"]] = summary["subjects"].get(r["subject"], 0) + 1
    return summary
