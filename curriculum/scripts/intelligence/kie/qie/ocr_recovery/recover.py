"""The recovery pipeline — the owner's six steps, made deterministic and honest.

  (1) DETECT low-quality docs                    -> detect.scan / detect.build
  (2) RE-OCR each candidate page (improved)      -> engine.ocr_page(pdf, page, IMPROVED)
  (3) COMPARE old vs new deterministically       -> quality.score (pure)
  (4) KEEP only if new STRICTLY beats old by a margin AND passes the NO-FABRICATION gate
  (5) PRESERVE BOTH texts + both scores + settings + verdict (idempotent-upsert audit in ocr_recovery.db)
  (6) EMIT a verified-improvement manifest (the kept subset) — but DO NOT apply it to kie.db (gated).

THE "OBJECTIVELY IMPROVED" GATE (step 4a) — deterministic, no judgement calls:
    improved := recovered_score - original_score >= IMPROVE_MARGIN
A page is only a keeper if the improved re-OCR STRICTLY beats the frozen text by at least IMPROVE_MARGIN on
the quality metric. Equal or worse → verdict 'kept_original' (the frozen text stands; we never regress it).

THE NO-FABRICATION / CONSISTENCY GATE (step 4b) — recovered text must be a faithful RE-READ of the page, not
an invention. Three deterministic checks, each defensible:

  NF-A (number preservation): a genuine re-OCR keeps most numbers the baseline already read; wholesale number
    replacement is the signature of a hallucination. If the original has >= MIN_ANCHOR_NUMS numeric tokens,
    then |orig_nums ∩ recov_nums| / |orig_nums| must be >= NUM_KEEP. (Higher DPI may ADD numbers — that is
    fine; erasing-and-replacing the numbers the baseline saw is not.)

  NF-B (anchored token overlap): if the original is itself coherent (original_score >= ANCHOR_FLOOR), the
    recovered text must not diverge wildly from it — token containment of the shorter text in the longer must
    be >= OVERLAP_FLOOR. This rejects a "recovery" that shares almost nothing with a readable original.

  NF-C (independent grounding): when the original is TOO GARBLED to anchor to (original_score < ANCHOR_FLOOR),
    we cannot trust it as a reference — so we require an INDEPENDENT second OCR read of the SAME pixels (a
    different psm, engine.GROUNDCHECK). Two independent reads of the same page agreeing (token containment >=
    GROUND_FLOOR) grounds the recovered text in the actual source render; disagreement (or a missing grounding
    read) → reject as ungrounded. This is the direct implementation of "must not invent content absent from
    the source render." NF-C is skipped only when NF-B already anchored the text to a coherent original.

The whole gate is a PURE function `fabrication_check(...)` so it is unit-testable without any OCR: feed it a
divergent recovered text and it rejects; feed it a grounded one and it passes.
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from kie.qie.ocr_recovery import detect as DE
from kie.qie.ocr_recovery import engine as EN
from kie.qie.ocr_recovery import quality as Q
from kie.qie.ocr_recovery import store as ST

# ── gate thresholds (documented above; kept as module constants so tests pin them) ──────────────────────────
IMPROVE_MARGIN = 0.05     # step 4a: strict improvement margin on the quality score
MIN_ANCHOR_NUMS = 3       # NF-A: need at least this many original numbers before number-preservation is meaningful
NUM_KEEP = 0.5            # NF-A: fraction of original numbers the recovery must retain
MAX_NEW_NUMS = 4          # NF-A: cap on numbers the recovery may INTRODUCE beyond the original's count (anti-invention)
ANCHOR_FLOOR = 0.55       # NF-B/NF-C boundary: at/above this the original is "coherent enough" to anchor to
OVERLAP_FLOOR = 0.30      # NF-B: min fraction of RECOVERED content that must be grounded in a coherent original
GROUND_FLOOR = 0.30       # NF-C: min fraction of RECOVERED content that must be grounded in the second read

_NUM_RE = re.compile(r"\d+(?:\.\d+)?")
_WORD_RE = re.compile(r"[A-Za-z]{2,}")
# Stopwords are dropped from the overlap anchor so shared function words ("the", "of", "is") cannot manufacture
# false overlap between two divergent texts — the anchor is on CONTENT words, which is what a faithful re-read
# must preserve. (A genuine improvement corrects a few misspellings but keeps the coherent original's content
# words, so a lenient content-word containment floor still passes it.)
_STOP = frozenset(
    "the of and a to in is was for it with as his on be at by this are or an that from but not we you he she "
    "they i had has have will would can could may then them there their which who what when where how all any "
    "each its our your do does did so if no more most such only other into than these those been being were".split()
)


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _sha(s: Optional[str]) -> str:
    return hashlib.sha256((s or "").encode()).hexdigest()


def _nums(text: str) -> set:
    return set(_NUM_RE.findall(text or ""))


def _words(text: str) -> set:
    return {w.lower() for w in _WORD_RE.findall(text or "")}


def _content_words(text: str) -> set:
    """Content words (len>=3, non-stopword) — the anchor for divergence checks. A faithful re-read preserves
    these even while correcting a few misspellings; a hallucination replaces them."""
    return {w.lower() for w in _WORD_RE.findall(text or "") if len(w) >= 3 and w.lower() not in _STOP}


def _grounded_recall(recovered: set, reference: set) -> float:
    """Fraction of the RECOVERED content that is grounded in the reference: |recovered ∩ reference| / |recovered|.

    This is the CORRECT direction for a no-fabrication check: it measures how much of what the recovery CLAIMS
    is actually supported by the reference. Content present in the recovery but ABSENT from the reference (an
    invented addition — the signature of hallucination) drives this DOWN. (A containment that divided by the
    smaller set would score a recovery that merely CONTAINS the reference as perfect, making invented additions
    invisible — the defect this replaces.)"""
    if not recovered:
        return 0.0
    return len(recovered & reference) / len(recovered)


def fabrication_check(
    original_text: str,
    recovered_text: str,
    original_score: float,
    groundcheck_text: Optional[str],
) -> Tuple[bool, str]:
    """PURE no-fabrication gate. Returns (ok, reason). See module header for NF-A/NF-B/NF-C."""
    if not recovered_text or not recovered_text.strip():
        return False, "nf_empty_recovered"

    # NF-A — numbers: keep most the baseline read AND do not INVENT a flood of new ones (both directions).
    onums, rnums = _nums(original_text), _nums(recovered_text)
    if len(onums) >= MIN_ANCHOR_NUMS:
        keep = len(onums & rnums) / len(onums)
        if keep < NUM_KEEP:
            return False, f"nf_a_numbers_replaced(keep={keep:.2f})"
    if len(rnums - onums) > len(onums) + MAX_NEW_NUMS:
        return False, f"nf_a_numbers_invented(new={len(rnums - onums)})"

    rec_cw = _content_words(recovered_text)
    if original_score >= ANCHOR_FLOOR:
        # NF-B — the original is coherent; the RECOVERED content must be grounded in it (recall of recovered).
        rec = _grounded_recall(rec_cw, _content_words(original_text))
        if rec < OVERLAP_FLOOR:
            return False, f"nf_b_recovered_diverges(recall={rec:.2f})"
        return True, "nf_ok_anchored_to_original"

    # NF-C — original too garbled to anchor to; require independent grounding by a second, differently-configured
    # read of the SAME pixels. The RECOVERED content must be grounded in that second read (recall of recovered) —
    # so invented additions absent from the independent read are rejected as ungrounded.
    if not groundcheck_text or not groundcheck_text.strip():
        return False, "nf_c_ungrounded_no_second_read"
    rec = _grounded_recall(rec_cw, _content_words(groundcheck_text))
    if rec < GROUND_FLOOR:
        return False, f"nf_c_ungrounded(recall={rec:.2f})"
    return True, "nf_ok_grounded_second_read"


def evaluate_page(
    original_text: Optional[str],
    recovered_text: Optional[str],
    groundcheck_text: Optional[str],
) -> dict:
    """PURE evaluation of one page: scores, improvement gate, no-fabrication gate → verdict. No I/O, no OCR."""
    original_text = original_text or ""
    orig_score = Q.score(original_text)
    if recovered_text is None:
        return {"original_score": orig_score, "recovered_score": None, "improved": 0,
                "verdict": "ocr_failed", "reason": "recovered_null_honest"}
    rec_score = Q.score(recovered_text)
    improved = (rec_score - orig_score) >= IMPROVE_MARGIN
    if not improved:
        return {"original_score": orig_score, "recovered_score": rec_score, "improved": 0,
                "verdict": "kept_original", "reason": f"no_gain(delta={rec_score - orig_score:.3f})"}
    ok, reason = fabrication_check(original_text, recovered_text, orig_score, groundcheck_text)
    verdict = "kept_recovered" if ok else "rejected_fabrication"
    return {"original_score": orig_score, "recovered_score": rec_score, "improved": 1,
            "verdict": verdict, "reason": reason}


def _persist(conn, doc_id, page, improved_settings, ground_settings, original_text, recovered_text, ev):
    result_id = hashlib.sha256(
        f"{doc_id}|{page}|{improved_settings.settings_hash()}|{_sha(original_text)}|{_sha(recovered_text)}".encode()
    ).hexdigest()[:16]
    conn.execute(
        "INSERT INTO recovery_result(result_id, doc_id, page, engine_settings_hash, ground_settings_hash, "
        "original_text, recovered_text, original_score, recovered_score, improved, verdict, reason, checked_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?) "
        "ON CONFLICT(doc_id, page, engine_settings_hash) DO UPDATE SET "
        "original_text=excluded.original_text, recovered_text=excluded.recovered_text, "
        "original_score=excluded.original_score, recovered_score=excluded.recovered_score, "
        "improved=excluded.improved, verdict=excluded.verdict, reason=excluded.reason, "
        "checked_at=excluded.checked_at, result_id=excluded.result_id",
        (result_id, doc_id, page, improved_settings.settings_hash(), ground_settings.settings_hash(),
         original_text, recovered_text, ev["original_score"], ev["recovered_score"], ev["improved"],
         ev["verdict"], ev["reason"], _now()),
    )


def recover_document(
    doc_id: str,
    *,
    kie=None,
    conn=None,
    ocr_engine: Optional[EN.OcrEngine] = None,
    improved_settings: EN.OcrSettings = EN.IMPROVED,
    ground_settings: EN.OcrSettings = EN.GROUNDCHECK,
    max_pages: int = 6,
    kie_db_path=None,
    out_db_path=None,
) -> dict:
    """Run the full pipeline for ONE document over its worst pages. Verifies the local PDF sha256 == the frozen
    source_documents.sha256 before OCR (honest-null the whole doc if missing/mismatched — never trust a wrong
    file). Persists a recovery_result row per page. Returns a per-doc summary. Opens kie.db READ-ONLY only."""
    from kie import config

    own_kie = kie is None
    own_conn = conn is None
    if own_kie:
        kie = ST.open_kie_ro(kie_db_path)
    if own_conn:
        conn = ST.open_store(out_db_path, writable=True)
    if ocr_engine is None:
        ocr_engine = EN.TesseractEngine(tesseract_cmd="/opt/homebrew/bin/tesseract")

    summary = {"doc_id": doc_id, "pages_checked": 0, "kept_recovered": 0, "kept_original": 0,
               "rejected_fabrication": 0, "ocr_failed": 0, "verdicts": [], "skipped_reason": None}
    try:
        d = kie.execute(
            "SELECT corpus, rel_path, sha256, pages FROM source_documents WHERE doc_id=?", (doc_id,)
        ).fetchone()
        if not d:
            summary["skipped_reason"] = "doc_not_found"
            return summary
        pdf_path = config.WORKSPACE / config.CORPORA[d["corpus"]] / d["rel_path"]
        if not pdf_path.exists():
            summary["skipped_reason"] = "source_pdf_missing"
            return summary
        if _file_sha256(pdf_path) != d["sha256"]:
            summary["skipped_reason"] = "source_sha256_mismatch"    # honest-null: never OCR the wrong file
            return summary

        page_texts, _ = DE._page_texts(kie, doc_id)
        worst = sorted(((p, Q.score(t)) for p, t in page_texts.items() if t.strip()), key=lambda x: (x[1], x[0]))
        targets = [p for p, _ in worst[:max_pages]]

        for page in targets:
            original_text = page_texts.get(page, "")
            recovered_text = ocr_engine.ocr_page(pdf_path, page - 1, improved_settings)  # page_index is 0-based
            ground_text = None
            if recovered_text is not None and Q.score(original_text) < ANCHOR_FLOOR:
                ground_text = ocr_engine.ocr_page(pdf_path, page - 1, ground_settings)   # only pay for it when NF-C needs it
            ev = evaluate_page(original_text, recovered_text, ground_text)
            _persist(conn, doc_id, page, improved_settings, ground_settings, original_text, recovered_text, ev)
            summary["pages_checked"] += 1
            summary[ev["verdict"]] += 1
            summary["verdicts"].append({"page": page, **ev})
        if own_conn:
            conn.commit()
    finally:
        if own_conn:
            conn.commit()
            conn.close()
        if own_kie:
            kie.close()
    return summary


def _file_sha256(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def run_sample(doc_ids: List[str], *, max_pages: int = 4, out_db_path=None, kie_db_path=None,
               ocr_engine: Optional[EN.OcrEngine] = None) -> dict:
    """Bounded end-to-end run over an explicit, SMALL list of doc_ids (never the whole 89 — tesseract is slow).
    Detects candidates first (so the store is populated), then recovers each doc. Returns an aggregate report."""
    kie = ST.open_kie_ro(kie_db_path)
    conn = ST.open_store(out_db_path, writable=True)
    try:
        # populate recovery_candidate rows for the sampled docs (idempotent).
        cands = {c["doc_id"]: c for c in DE.scan(kie)}
        now = _now()
        for did in doc_ids:
            c = cands.get(did)
            if not c:
                continue
            conn.execute(
                "INSERT INTO recovery_candidate(doc_id, corpus, rel_path, sha256, pages, parser_class, trigger, "
                "current_score, worst_pages, n_chunks, detected_at) VALUES (?,?,?,?,?,?,?,?,?,?,?) "
                "ON CONFLICT(doc_id) DO UPDATE SET current_score=excluded.current_score, "
                "worst_pages=excluded.worst_pages, detected_at=excluded.detected_at",
                (c["doc_id"], c["corpus"], c["rel_path"], c["sha256"], c["pages"], c["parser_class"],
                 c["trigger"], c["current_score"], json.dumps(c["worst_pages"]), c["n_chunks"], now),
            )
        conn.commit()
        agg = {"docs": [], "pages_checked": 0, "kept_recovered": 0, "kept_original": 0,
               "rejected_fabrication": 0, "ocr_failed": 0, "skipped": 0}
        for did in doc_ids:
            s = recover_document(did, kie=kie, conn=conn, ocr_engine=ocr_engine, max_pages=max_pages)
            agg["docs"].append(s)
            if s["skipped_reason"]:
                agg["skipped"] += 1
                continue
            for k in ("pages_checked", "kept_recovered", "kept_original", "rejected_fabrication", "ocr_failed"):
                agg[k] += s[k]
        conn.commit()
    finally:
        conn.close()
        kie.close()
    return agg


def write_manifest(path, *, out_db_path=None) -> int:
    """Emit the verified-improvement manifest (the kept subset) as JSON a FUTURE gated rebuild could consume.
    This does NOT apply anything to kie.db — it is a proposal, nothing more. Returns the number of kept pages."""
    conn = ST.open_store(out_db_path, writable=False)
    try:
        rows = conn.execute(
            "SELECT doc_id, page, engine_settings_hash, original_score, recovered_score, score_delta, checked_at "
            "FROM recovery_manifest ORDER BY doc_id, page"
        ).fetchall()
    finally:
        conn.close()
    manifest = {
        "kind": "ocr_recovery_verified_improvement_manifest",
        "note": "PROPOSAL ONLY — a future, version-bumped, independently-gated kie.db rebuild MAY consume these "
                "recovered pages. This lane does NOT apply them. kie.db is left byte-identical.",
        "improve_margin": IMPROVE_MARGIN,
        "generated_at": _now(),
        "kept_pages": [dict(r) for r in rows],
    }
    from pathlib import Path
    Path(path).write_text(json.dumps(manifest, indent=2, sort_keys=True))
    return len(rows)
