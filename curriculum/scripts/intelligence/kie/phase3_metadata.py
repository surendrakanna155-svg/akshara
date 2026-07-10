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
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from kie import config, ledger, store


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

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


# ── document-level catalog metadata (deterministic: source path + provenance) ────
# doc_type / source authority / provider / language / session / stream from the file
# path; title from the parsed structure. No LLM, no network.
DOCTYPE_RULES = [
    ("answer_key", ("answer-key", "answer_key", "answerkey", "answer key", "answers")),
    ("solution", ("solution", "solutions", "solved-paper", "solved paper", "solved", "detailed-solution")),
    ("sample_paper", ("sample-paper", "sample paper", "sample")),
    ("mock_test", ("mock-test", "mock test", "mock")),
    ("dpp", ("dpp", "daily-practice", "daily practice")),
    ("formula_sheet", ("formula", "formulae")),
    ("syllabus", ("syllabus",)),
    ("notes", ("notes", "revision-notes")),
    ("collection", ("collection", "historical_collection")),
    ("previous_paper", ("question-paper", "question paper", "questionpaper", "previous", "paper", "exam")),
]
KNOWN_PROVIDERS = ["NTA", "Careers360", "Embibe", "AskIITians", "Aakash", "Allen", "Motion",
                   "Vedantu", "Byjus", "Physicswallah", "Toppr", "Selfstudys", "Oswaal",
                   "Shiksha", "Collegedunia", "Jagranjosh", "Examside", "Mathongo"]
LANGUAGES = ["Marathi", "Hindi", "Gujarati", "Tamil", "Telugu", "Bengali", "Kannada",
             "Urdu", "Odia", "Punjabi", "Assamese", "Malayalam"]
SESSION_RES = [
    re.compile(r"set[-_ ]?([a-z]{1,2}\d?)", re.I),
    re.compile(r"shift[-_ ]?([12])", re.I),
    re.compile(r"(morning|evening|afternoon)[-_ ]?shift", re.I),
    re.compile(r"paper[-_ ]?([12])", re.I),
    re.compile(r"\b([hpq][12])\b", re.I),
]
STREAM_BY_CATEGORY = {
    "NEET": "Medical", "AIIMS": "Medical", "AIPMT": "Medical",
    "JEE_Main": "Engineering", "JEE_Advanced": "Engineering",
    "NCERT": "Foundation", "NTA_Sample": "Both", "Practice_Resources": "Both",
}
PROFILE_BY_DOCTYPE = {
    "previous_paper": "question_paper", "sample_paper": "question_paper",
    "mock_test": "question_paper", "dpp": "question_paper",
    "answer_key": "solutions", "solution": "solutions",
    "textbook": "theory", "notes": "theory",
    "formula_sheet": "reference", "syllabus": "reference",
    "collection": "mixed", "unknown": "mixed",
}


def _basename(rel_path: str) -> str:
    return rel_path.replace("\\", "/").rsplit("/", 1)[-1]


def _tokens(text: str) -> List[str]:
    return [t for t in re.split(r"[_\-\s./]+", text) if t]


def classify_doctype(rel_path: str, kind: Optional[str]) -> str:
    hay = rel_path.lower()
    if (kind == "archive") and "ncert" in hay:
        return "textbook"
    for dtype, keys in DOCTYPE_RULES:
        if any(k in hay for k in keys):
            return dtype
    return "unknown"


def classify_source(rel_path: str) -> Tuple[str, Optional[str]]:
    toks = _tokens(_basename(rel_path))
    low = [t.lower() for t in toks]
    authority, provider = "unknown", None
    for i, t in enumerate(low):
        if t == "official":
            authority = "official"
            provider = toks[i + 1] if i + 1 < len(toks) else provider
        elif t == "mirror":
            authority = "mirror"
            provider = toks[i + 1] if i + 1 < len(toks) else provider
        elif t in ("thirdparty", "third"):
            authority = "third_party"
    if provider:
        for kp in KNOWN_PROVIDERS:
            if kp.lower() in provider.lower() or provider.lower() in kp.lower():
                provider = kp
                break
    else:
        low_all = rel_path.lower()
        for kp in KNOWN_PROVIDERS:
            if kp.lower() in low_all:
                provider = kp
                break
    if provider == "NTA":
        authority = "official"
    return authority, provider


def detect_language(rel_path: str) -> str:
    name = _basename(rel_path)
    for lang in LANGUAGES:
        if re.search(rf"\b{lang}", name, re.I):
            return lang
    return "English"


def classify_class_level(rel_path: str) -> Optional[str]:
    m = re.search(r"class[_\- ]?(\d{1,2})", rel_path, re.I)
    if m and 1 <= int(m.group(1)) <= 12:
        return f"Class {int(m.group(1))}"
    return None


def detect_session(rel_path: str) -> Optional[str]:
    name = _basename(rel_path)
    for rx in SESSION_RES:
        m = rx.search(name)
        if m:
            return m.group(0)
    return None


def stream_for(category: Optional[str], rel_path: str) -> str:
    s = STREAM_BY_CATEGORY.get(category or "", "Unknown")
    if category == "Practice_Resources":
        low = rel_path.lower()
        if "neet" in low:
            return "Medical"
        if "jee" in low:
            return "Engineering"
    return s


def derive_title(parsed: dict, sections: List[dict], rel_path: str) -> str:
    for c in parsed.get("chapter_boundaries", []) or []:
        t = (c.get("title") or "").strip()
        if c.get("source") == "toc" and len(t) >= 4 and not t.lower().startswith("pdf promo"):
            return t[:160]
    if sections:
        return sections[0]["title"][:160]
    for p in parsed.get("pages", []):
        for b in p.get("blocks", []):
            line = (b.get("text") or "").splitlines()[0].strip() if b.get("text") else ""
            if len(line) >= 6:
                return line[:160]
        break
    return _basename(rel_path).rsplit(".", 1)[0].replace("_", " ")[:160]


def build_catalog_metadata(doc_row, parsed: dict, sections: List[dict], subject: Optional[str]) -> dict:
    rel = doc_row["rel_path"]
    doc_type = classify_doctype(rel, doc_row["kind"])
    authority, provider = classify_source(rel)
    resolved = sum(bool(x) and x not in ("unknown",) for x in (
        doc_row["exam"], doc_type if doc_type != "unknown" else None, doc_row["year"],
        subject, authority if authority != "unknown" else None))
    return {
        "doc_type": doc_type,
        "language": detect_language(rel),
        "class_label": classify_class_level(rel),
        "stream": stream_for(doc_row["category"], rel),
        "source_authority": authority,
        "provider": provider,
        "session": detect_session(rel),
        "content_profile": PROFILE_BY_DOCTYPE.get(doc_type, "mixed"),
        "title": derive_title(parsed, sections, rel),
        "confidence": round(resolved / 5.0, 2),
    }


def process_document(conn, doc_row) -> dict:
    did = doc_row["doc_id"]
    parsed_path = config.PARSED_DIR / f"{did}.json"
    parsed = json.loads(parsed_path.read_text())
    sections = detect_sections(parsed.get("pages", []))
    subject, _scores = infer_subject(_parsed_text(parsed))
    cat = build_catalog_metadata(doc_row, parsed, sections, subject)

    with store.txn(conn):
        conn.execute("DELETE FROM document_sections WHERE doc_id = ?", (did,))
        for s in sections:
            conn.execute(
                """INSERT INTO document_sections(section_id, doc_id, ordinal, level, title, page, path)
                   VALUES (?,?,?,?,?,?,?)""",
                (f"{did}#s{s['ordinal']}", did, s["ordinal"], s["level"], s["title"], s["page"], s["path"]),
            )
        # populate the declared-but-empty document columns (deterministic, idempotent)
        conn.execute(
            "UPDATE source_documents SET doc_type = ?, language = ?, "
            "class_label = COALESCE(NULLIF(class_label, ''), ?), "
            "subject = COALESCE(NULLIF(subject, ''), ?) WHERE doc_id = ?",
            (cat["doc_type"], cat["language"], cat["class_label"], subject, did),
        )
        conn.execute(
            """INSERT INTO document_metadata
                 (doc_id, stream, source_authority, provider, session, content_profile, title, confidence, created_at)
               VALUES (?,?,?,?,?,?,?,?,?)
               ON CONFLICT(doc_id) DO UPDATE SET
                 stream=excluded.stream, source_authority=excluded.source_authority,
                 provider=excluded.provider, session=excluded.session,
                 content_profile=excluded.content_profile, title=excluded.title,
                 confidence=excluded.confidence""",
            (did, cat["stream"], cat["source_authority"], cat["provider"], cat["session"],
             cat["content_profile"], cat["title"], cat["confidence"], _now()),
        )
        ledger.record(conn, did, "metadata", "done", input_sha256=doc_row["sha256"],
                      output_ref=f"sections:{len(sections)},dtype:{cat['doc_type']}")
    return {"sections": len(sections), "subject": subject, "doc_type": cat["doc_type"]}


def run(conn, limit: Optional[int] = None, force: bool = False) -> dict:
    summary = {"processed": 0, "skipped": 0, "failed": 0, "sections": 0, "subjects": {}, "doc_types": {}}
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
        dt = r.get("doc_type", "unknown")
        summary["doc_types"][dt] = summary["doc_types"].get(dt, 0) + 1
    return summary
