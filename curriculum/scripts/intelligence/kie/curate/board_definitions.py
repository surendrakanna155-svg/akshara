"""Knowledge Layer — definition-FIRST extraction over promoted board documents (content lane).

The KIE concept extractor yields *heading-level* concepts ("Chemical Bonding", "Acids, Bases and
Salts") while a textbook's definitions are *term-level* ("An acid is …", "Alloying is a method
of …"). So the concept-driven definition miner (enrich) matches almost nothing on board content,
even though the definitions are present. This pass inverts the flow: it scans the CLEAN
(words-mode) text of already-promoted board PDFs for definitional sentences and, for each, creates
(or backfills) a term-level concept carrying that GROUNDED, verbatim definition + full provenance.

Governance: operates ONLY on documents already promoted through the Intake Center (source_documents
rows with a board category). It re-reads their raw text with pymupdf's word-level extraction (which
avoids the default extractor's word-merging), NOT re-ingesting new documents. Deterministic,
idempotent, recovery-safe. No AI. No fabrication — every definition is a verbatim source sentence,
retained only if it passes the same precision gates the engine uses (usable_definition, clean
concept title, no OCR merge, definitional predicate). Precision-first: a sentence that is not
clearly a clean, complete, term-level definition is skipped (fail closed).

Subject attribution comes from the source document (Biological Science → Biology, Mathematics →
Mathematics); combined-science docs (Physical Science / NCERT Science) attribute per-term via a
deterministic subject lexicon, and SKIP a term whose subject cannot be resolved (never guessed).
"""
from __future__ import annotations

import hashlib
import json
import re
from itertools import groupby
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from kie import ledger, store
from kie.curate import enrich
from kie.qpgen import chapters, sanitize
from kie.qpgen.materialize import usable_definition

STAGE = "board_definitions"
DOC = "__knowledge__"

BOARD_CATEGORIES = ("TS_SCERT", "CBSE_NCERT")

# ── subject resolution ───────────────────────────────────────────────────────────────
# unambiguous per-document subject from the filename; None ⇒ combined-science ⇒ per-term lexicon
def _doc_subject(rel_path: str) -> Optional[str]:
    p = rel_path.lower()
    if "biological_science" in p:
        return "Biology"
    if "mathematics" in p:
        return "Mathematics"
    if "physical_science" in p:
        return None            # Physics + Chemistry combined → per-term lexicon
    return None                # NCERT jesc* combined science → per-term lexicon


# deterministic per-term subject lexicon (only high-signal terms; else the term is SKIPPED)
_SUBJECT_LEXICON = (
    ("Physics", ("force", "velocit", "accelerat", "current", "voltage", "resist", "magnet",
                 "electr", "lens", "mirror", "refract", "reflect", "light", "wave", "energy",
                 "power", "circuit", "charge", "field", "momentum", "friction", "pressure",
                 "motion", "gravit", "optic", "conductor", "ampere", "ohm", "flux", "spectrum")),
    ("Chemistry", ("acid", "base", "salt", "metal", "atom", "molecul", "element", "compound",
                   "reaction", "bond", "valenc", "oxid", "reduc", "electroly", "ion", "solution",
                   "periodic", "alloy", "corros", "combustion", "ester", "carbon", "gas", "mole")),
    ("Biology", ("cell", "organ", "tissue", "photosynth", "respirat", "digest", "reproduc",
                 "gene", "hormone", "blood", "neuron", "enzyme", "plant", "animal", "species",
                 "nutrition", "excret", "circulat", "chromosom", "protein", "nerve", "iris")),
)


def _term_subject(term: str, definition: str) -> Optional[str]:
    blob = f"{term} {definition}".lower()
    hits = {subj: sum(1 for k in keys if k in blob) for subj, keys in _SUBJECT_LEXICON}
    best = max(hits, key=hits.get)
    return best if hits[best] >= 1 else None


# ── definition-first sentence extraction ───────────────────────────────────────────────
# subject openers that are NOT a concept name (sentence fragments / pronouns / adverbs)
_BAD_SUBJECT_LEAD = re.compile(
    r"^(the|a|an|this|that|these|those|it|they|we|as|now|here|there|usually|thus|hence|"
    r"when|where|if|so|such|then|therefore|however|in|on|at|for|by|from|its|their|"
    r"each|every|some|most|all|both|either|neither|any|since|what|which|who|his|her|our|"
    r"my|your|once|though|while|because|also|being|having|given)\b", re.I)
# a connective/verb INSIDE the subject means a run-on clause, not a concept name
_SUBJECT_CONNECTIVE = re.compile(r"\b(though|because|since|while|and|or|but|that|which|when)\b", re.I)
# option-list / exam-artifact body ("… because of ( ) A) … B) …")
_OPTION_BODY = re.compile(r"\b[A-D]\s*\)|\(\s*\)|\bA\)\s|\boption\b", re.I)
_DEF_SENT = re.compile(
    r"^([A-Z][A-Za-z][A-Za-z '\-]{2,40}?)\s+(is|are)\s+(a\s|an\s|the\s)?(.{15,190}?[.])")


# function-word glue ("thecombining" = "the"+"combining") — an OCR merge the length/vowel gates
# miss. High precision: a small prefix set + a whitelist of real words with those prefixes.
_GLUE_PREFIX = ("the", "and", "that", "this", "with", "was", "are", "were", "has", "have")
_GLUE_WHITELIST = frozenset((
    "therefore", "thereby", "therein", "thereof", "thereafter", "thermal", "thermometer",
    "thermodynamics", "thermodynamic", "theorem", "theory", "thesis", "thermosphere", "thence",
    "android", "withstand", "without", "within", "withdraw", "withdrawn", "hardness", "harvest",
    "hasten", "wavelength", "wavelengths",
))
_GLUE_RE = re.compile(r"^(?:%s)[a-z]{5,}$" % "|".join(_GLUE_PREFIX))


def _word_glue(text: str) -> bool:
    for tok in re.findall(r"[a-z]+", text.lower()):
        if len(tok) >= 8 and _GLUE_RE.match(tok) and tok not in _GLUE_WHITELIST:
            return True
    return False


def _bad_term(term: str) -> bool:
    """Reject a candidate 'subject' that is not a clean concept NAME (fragment / run-on / dup)."""
    words = term.split()
    if len(words) > 4:                                   # a concept name is short
        return True
    if _SUBJECT_CONNECTIVE.search(term):                 # "Oxidation reactions Though combustion"
        return True
    lw = [w.lower() for w in words]
    if any(lw[i] == lw[i + 1] for i in range(len(lw) - 1)):   # doubled token "ATP ATP"
        return True
    return False


def _clean_text(pdf_path: Path) -> str:
    """Word-level extraction (avoids the default extractor's word-merging), reconstructed by line."""
    import fitz
    doc = fitz.open(str(pdf_path))
    out: List[str] = []
    for pg in doc:
        words = pg.get_text("words")            # (x0,y0,x1,y1,word,block,line,wordno)
        words.sort(key=lambda w: (w[5], w[6], w[7]))
        for _, grp in groupby(words, key=lambda w: (w[5], w[6])):
            out.append(" ".join(w[4] for w in grp))
    doc.close()
    return re.sub(r"\s+", " ", " ".join(out))


def extract_pairs(text: str, doc_subject: Optional[str]) -> List[Tuple[str, str, str]]:
    """Return clean (term, definition, subject) triples. Precision-first: only complete, clean,
    term-level definitions with a resolvable subject survive."""
    out: List[Tuple[str, str, str]] = []
    seen: set = set()
    for raw in re.split(r"(?<=[.!?])\s+", text):
        s = raw.strip()
        m = _DEF_SENT.match(s + (" " if not s.endswith((".", "!", "?")) else ""))
        if not m:
            continue
        term = m.group(1).strip()
        low = term.lower()
        if low in seen:
            continue
        if _BAD_SUBJECT_LEAD.match(term) or _bad_term(term):    # fragment / pronoun / run-on subject
            continue
        if not sanitize.is_clean_concept(term):
            continue
        pred = (m.group(3) or "") + m.group(4)
        head = re.findall(r"[a-z]+", pred.lower())[:3]
        if not any(h in enrich._DEF_HEADS for h in head):      # predicate must NAME what it is
            continue
        defn = f"{term} {m.group(2)} {pred}".strip()
        if not defn.endswith("."):
            defn += "."
        if not (15 <= len(defn) <= 240):
            continue
        if enrich._BAD_BODY.search(defn) or enrich._PUNCT_ARTIFACT.search(defn):
            continue
        if _OPTION_BODY.search(defn):                          # exam option-list, not a definition
            continue
        if enrich._looks_merged(defn) or enrich._sentence_ocr_garbage(defn) or _word_glue(defn):
            continue
        if len(enrich._MULTI_DIGIT.findall(defn)) > 2:
            continue
        if not usable_definition(defn):
            continue
        subject = doc_subject or _term_subject(term, defn)
        if not subject:                                        # unresolved subject → skip (no guess)
            continue
        seen.add(low)
        out.append((term, defn[0].upper() + defn[1:], subject))
    return out


def _concept_code(term: str, subject: str) -> str:
    h = hashlib.sha1(f"{subject}|{term.lower()}".encode()).hexdigest()[:12]
    return f"BRD_{subject[:3].upper()}_{h}"


def run(conn, dry_run: bool = False) -> dict:
    docs = conn.execute(
        "SELECT doc_id, rel_path, category, class_label FROM source_documents "
        "WHERE category IN (%s) AND certify_status='certified'"
        % ",".join("?" * len(BOARD_CATEGORIES)),
        BOARD_CATEGORIES,
    ).fetchall()
    # existing active concept titles (normalized) → code, to backfill instead of duplicate
    existing = {}
    for r in conn.execute("SELECT concept_code, title, subject_domain FROM concepts WHERE status='active'"):
        existing[(sanitize.normalize_concept_title(r["title"]).lower(), r["subject_domain"])] = r["concept_code"]

    created = backfilled = scanned = 0
    by_subject: Dict[str, int] = {}
    intake_root = Path(store.__file__).resolve().parents[3] / "resources" / "intake"
    for d in docs:
        pdf = _resolve_pdf(d["rel_path"], intake_root)
        if not pdf or not pdf.exists():
            continue
        try:
            text = _clean_text(pdf)
        except Exception:
            continue
        for term, defn, subject in extract_pairs(text, _doc_subject(d["rel_path"])):
            scanned += 1
            key = (sanitize.normalize_concept_title(term).lower(), subject)
            evidence = json.dumps({"doc": d["doc_id"], "method": "definition_first",
                                   "definition_source": "board_verbatim"}, sort_keys=True)
            code = existing.get(key)
            if code:
                cur = conn.execute("SELECT definition FROM concepts WHERE concept_code=?",
                                   (code,)).fetchone()
                if not usable_definition(cur["definition"] or ""):
                    conn.execute("UPDATE concepts SET definition=? WHERE concept_code=?", (defn, code))
                    backfilled += 1
                    by_subject[subject] = by_subject.get(subject, 0) + 1
            else:
                code = _concept_code(term, subject)
                if conn.execute("SELECT 1 FROM concepts WHERE concept_code=?", (code,)).fetchone():
                    continue                                    # idempotent
                conn.execute(
                    "INSERT INTO concepts(concept_code, title, definition, subject_domain, "
                    "typical_grade_low, typical_grade_high, status, evidence, created_at) "
                    "VALUES (?,?,?,?,10,10,'active',?,datetime('now'))",
                    (code, term, defn, subject, evidence))
                existing[key] = code
                created += 1
                by_subject[subject] = by_subject.get(subject, 0) + 1

    summary = {"docs_scanned": len(docs), "definitions_extracted": scanned,
               "concepts_created": created, "concepts_backfilled": backfilled,
               "by_subject": by_subject}
    if dry_run:
        conn.rollback()
        summary["dry_run"] = True
        return summary
    ledger.record(conn, DOC, STAGE, "done",
                  output_ref=json.dumps({"created": created, "backfilled": backfilled}, sort_keys=True))
    conn.commit()
    return summary


def _resolve_pdf(rel_path: str, intake_root: Path) -> Optional[Path]:
    """Locate the promoted PDF by its content-addressed intake path or original name."""
    name = Path(rel_path).name
    # content-addressed under resources/intake/<doc_id>/<name> or a direct match
    for cand in intake_root.rglob(name):
        return cand
    return None


def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="kie.curate.board_definitions",
                                 description="definition-first extraction over promoted board docs")
    ap.add_argument("--db", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    conn = store.open_store(args.db)
    try:
        summary = run(conn, dry_run=args.dry_run)
    finally:
        conn.close()
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
