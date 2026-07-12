"""Resumable, manifest-driven, priority-ordered ingestion pipeline.

Every document has ONE stable processing identity = doc_id (sha256[:16]). State is persisted
after EVERY document with atomic writes, so a crash / terminal close / model-session end /
restart never re-processes a completed document — a resume simply skips any doc already in a
terminal state. Failures are logged per-document and NEVER abort the corpus.

Per-document state machine (recorded in state/docs/<doc_id>.json):
  DISCOVERED -> FINGERPRINTED -> {DUPLICATE_EXACT | CLASSIFIED -> EXTRACTED ->
  STRUCTURE_RECOVERED -> COMPLETE} ; terminal-error states: FAILED, PARTIAL.
Derived JSONL manifests are REBUILT (atomically) from the per-doc records at each checkpoint,
so they are never left half-written.
"""
from __future__ import annotations

import time
from pathlib import Path
from typing import Callable, Dict, List, Optional

from qcorpus import atomicio, classify, config, extract, fingerprint, provenance

TERMINAL = {"COMPLETE", "DUPLICATE_EXACT", "FAILED", "PARTIAL"}


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# ── discovery ─────────────────────────────────────────────────────────────────────
def discover() -> List[dict]:
    """Filesystem inventory of every source PDF, priority-tagged. Reproduced from disk."""
    out = []
    for p in sorted(config.SOURCE_ROOT.rglob("*.pdf")):
        rel = p.relative_to(config.SOURCE_ROOT)
        parts = rel.parts
        group = parts[0] if parts else "UNKNOWN"
        st = p.stat()
        out.append({
            "rel_path": str(rel), "abs_path": str(p), "source_group": group,
            "original_filename": p.name, "rel_parts": list(parts),
            "file_size": st.st_size, "mtime_ns": st.st_mtime_ns,
            "priority": config.priority_for(parts),
        })
    return out


# ── state ──────────────────────────────────────────────────────────────────────────
def _load_state() -> dict:
    st = atomicio.read_json(config.PROCESSING_STATE, default=None)
    if st is None:
        st = {"created_at": _now(), "path_index": {}, "doc_index": {},
              "exact_dup_groups": {}, "counters": {}, "runs": []}
    return st


def _save_state(st: dict) -> None:
    atomicio.write_json_atomic(config.PROCESSING_STATE, st)


def _doc_record_path(doc_id: str) -> Path:
    return config.DOC_STATE_DIR / f"{doc_id}.json"


def _write_doc_record(rec: dict) -> None:
    atomicio.write_json_atomic(_doc_record_path(rec["doc_id"]), rec)


# ── per-document processing ─────────────────────────────────────────────────────────
def _process_one(item: dict, st: dict) -> str:
    """Fingerprint -> dedup -> classify -> extract -> persist. Returns terminal state."""
    path = Path(item["abs_path"])
    sha, size = fingerprint.sha256_file(path)
    doc_id = fingerprint.doc_id_for(sha)
    probe = fingerprint.probe_pdf(path)

    idx_entry = {"sha256": sha, "doc_id": doc_id, "size": size,
                 "mtime_ns": item["mtime_ns"], "page_count": probe.get("page_count"),
                 "priority": item["priority"], "group": item["source_group"]}

    # ── exact-duplicate detection (content-addressed) ─────────────────────────
    canonical = st["doc_index"].get(doc_id)
    if canonical and canonical != item["rel_path"]:
        st["exact_dup_groups"].setdefault(doc_id, [canonical])
        if item["rel_path"] not in st["exact_dup_groups"][doc_id]:
            st["exact_dup_groups"][doc_id].append(item["rel_path"])
        # attach to canonical record's duplicate_paths
        crec = atomicio.read_json(_doc_record_path(doc_id))
        if crec is not None:
            dups = set(crec.get("duplicate_paths", []))
            dups.add(item["rel_path"])
            crec["duplicate_paths"] = sorted(dups)
            _write_doc_record(crec)
        idx_entry.update({"state": "DUPLICATE_EXACT", "is_duplicate": True,
                          "duplicate_of": canonical})
        st["path_index"][item["rel_path"]] = idx_entry
        return "DUPLICATE_EXACT"

    # ── integrity gate ────────────────────────────────────────────────────────
    if not probe.get("integrity_ok"):
        rec = _base_record(item, sha, doc_id, size, probe)
        rec.update({"state": "FAILED", "error": probe.get("corruption_reason") or "integrity_failed",
                    "failed_at": _now()})
        _write_doc_record(rec)
        idx_entry["state"] = "FAILED"
        st["path_index"][item["rel_path"]] = idx_entry
        st["doc_index"][doc_id] = item["rel_path"]
        return "FAILED"

    # ── classification (static) ───────────────────────────────────────────────
    prov = provenance.lookup(item["source_group"], item["original_filename"])
    static = classify.classify_static(item["source_group"], item["rel_parts"],
                                      item["original_filename"], prov)

    # ── extraction (reused proven parser) ─────────────────────────────────────
    bundle = extract.run_extraction(path, doc_id, "single")

    # persist RAW (once) + NORMALIZED derived payload
    raw_path = config.RAW_DIR / f"{doc_id}.json"
    if not raw_path.exists():
        atomicio.write_json_atomic(raw_path, bundle["raw"])
    norm_payload = dict(bundle["normalized"])
    norm_payload["visual_assets"] = bundle["visual_assets"]
    norm_payload["equation_records"] = bundle["equation_records"]
    norm_payload["notation_records"] = bundle["notation_records"]
    atomicio.write_json_atomic(config.NORMALIZED_DIR / f"{doc_id}.json", norm_payload)

    qs = bundle["question_summary"]
    signals = bundle["signals"]
    # doc-level text fingerprint for probable-duplicate detection (post pass)
    sample = " ".join(p.get("normalized_text", "") for p in bundle["normalized"]["pages"][:3])[:6000]
    tfp = fingerprint.text_fingerprint(sample)

    complete_q = qs["complete"]
    state = "COMPLETE" if bundle["parse_meta"]["page_count"] else "PARTIAL"

    rec = _base_record(item, sha, doc_id, size, probe)
    rec.update({
        "state": state, "completed_at": _now(),
        "classification": static, "language": bundle["language"],
        "signals": signals, "parse_meta": bundle["parse_meta"],
        "question_summary": qs, "text_fingerprint": tfp,
        "normalized_filename": fingerprint.normalized_filename(item["original_filename"]),
        "counts": {
            "pages": bundle["parse_meta"]["page_count"],
            "questions": qs["questions_recovered"], "complete_questions": complete_q,
            "visual_assets": len(bundle["visual_assets"]),
            "equations": len(bundle["equation_records"]),
            "notation_records": len(bundle["notation_records"]),
        },
        "duplicate_paths": [],
    })
    _write_doc_record(rec)

    idx_entry["state"] = state
    st["path_index"][item["rel_path"]] = idx_entry
    st["doc_index"][doc_id] = item["rel_path"]
    return state


def _base_record(item, sha, doc_id, size, probe) -> dict:
    return {
        "doc_id": doc_id, "sha256": sha, "file_size": size,
        "source_group": item["source_group"], "rel_path": item["rel_path"],
        "original_filename": item["original_filename"], "priority": item["priority"],
        "page_count": probe.get("page_count"), "encrypted": probe.get("encrypted"),
        "discovered_at": _now(),
    }


# ── batch runner ─────────────────────────────────────────────────────────────────────
def run(only_priority: Optional[str] = None, limit: Optional[int] = None,
        force: bool = False, checkpoint_every: int = 10,
        progress: Optional[Callable[[str], None]] = None) -> dict:
    """Process the corpus in priority order, resumably. Returns a run summary.

    Pass only_priority to process a single priority (e.g. Biology first, then a checkpoint,
    then a full run for the rest). Resume is automatic: any doc already in a terminal state
    with unchanged bytes is skipped.
    """
    config.ensure_dirs()
    log = progress or (lambda m: None)
    st = _load_state()

    inventory = discover()
    # stable priority order, then group, then path
    prio_rank = {label: i for i, (label, _) in enumerate(config.PRIORITIES)}
    prio_rank[config.PRIORITY_UNRANKED] = len(prio_rank)
    inventory.sort(key=lambda it: (prio_rank.get(it["priority"], 99), it["rel_path"]))

    run_summary = {"started_at": _now(), "processed": 0, "skipped": 0, "failed": 0,
                   "exact_duplicates": 0, "by_state": {}, "by_priority": {}}
    processed_since_ckpt = 0
    seen_priorities: List[str] = []

    for item in inventory:
        prio = item["priority"]
        if only_priority and prio != only_priority:
            continue
        if prio not in seen_priorities:
            # crossing into a new priority — checkpoint the previous one first
            if seen_priorities:
                rebuild_manifests()
                _save_state(st)
            seen_priorities.append(prio)

        prev = st["path_index"].get(item["rel_path"])
        unchanged = (prev and prev.get("mtime_ns") == item["mtime_ns"]
                     and prev.get("size") == item["file_size"])
        if prev and prev.get("state") in TERMINAL and unchanged and not force:
            run_summary["skipped"] += 1
            continue

        t0 = time.time()
        try:
            state = _process_one(item, st)
        except Exception as exc:  # isolate per-doc; never abort the corpus
            sha, size = _safe_hash(Path(item["abs_path"]))
            doc_id = fingerprint.doc_id_for(sha) if sha else ("ERR" + item["rel_path"][:13])
            rec = _base_record(item, sha or "", doc_id, size, {"page_count": None})
            rec.update({"state": "FAILED", "error": f"{type(exc).__name__}: {exc}",
                        "failed_at": _now()})
            _write_doc_record(rec)
            st["path_index"][item["rel_path"]] = {
                "sha256": sha, "doc_id": doc_id, "size": size,
                "mtime_ns": item["mtime_ns"], "priority": prio,
                "group": item["source_group"], "state": "FAILED"}
            state = "FAILED"

        dt = time.time() - t0
        run_summary["by_state"][state] = run_summary["by_state"].get(state, 0) + 1
        run_summary["by_priority"].setdefault(prio, {"count": 0, "seconds": 0.0})
        run_summary["by_priority"][prio]["count"] += 1
        run_summary["by_priority"][prio]["seconds"] += round(dt, 2)
        if state == "DUPLICATE_EXACT":
            run_summary["exact_duplicates"] += 1
        elif state == "FAILED":
            run_summary["failed"] += 1
        else:
            run_summary["processed"] += 1
        log(f"[{prio}] {item['original_filename'][:52]:<52} -> {state} ({dt:.1f}s)")

        processed_since_ckpt += 1
        if processed_since_ckpt >= checkpoint_every:
            _save_state(st)
            rebuild_manifests()
            processed_since_ckpt = 0
        if limit and run_summary["processed"] >= limit:
            break

    _save_state(st)
    compute_probable_duplicates()
    rebuild_manifests()
    run_summary["finished_at"] = _now()
    st["runs"].append(run_summary)
    _save_state(st)
    return run_summary


def _safe_hash(path: Path):
    try:
        return fingerprint.sha256_file(path)
    except Exception:
        return None, 0


# ── probable-duplicate detection (post pass over canonical docs) ───────────────────
def compute_probable_duplicates() -> List[dict]:
    """Group canonical docs by shared text-fingerprint OR (normalized_filename+page_count).

    Exact duplicates are already collapsed by content hash; this catches re-encoded/re-saved
    copies. Nothing is deleted — both are preserved; the group is recorded for audit.
    """
    records = _iter_doc_records()
    by_tfp: Dict[str, list] = {}
    by_name: Dict[str, list] = {}
    for r in records:
        if r.get("state") not in ("COMPLETE", "PARTIAL"):
            continue
        tfp = r.get("text_fingerprint")
        if tfp:
            by_tfp.setdefault(tfp, []).append(r)
        key = (r.get("normalized_filename"), r.get("page_count"))
        if key[0]:
            by_name.setdefault(str(key), []).append(r)

    groups = []
    for tfp, rs in by_tfp.items():
        if len(rs) > 1:
            groups.append({"type": "probable", "signal": "text_fingerprint",
                           "confidence": 0.95, "key": tfp,
                           "doc_ids": sorted(x["doc_id"] for x in rs),
                           "paths": sorted(x["rel_path"] for x in rs)})
    seen_pairs = {frozenset(g["doc_ids"]) for g in groups}
    for key, rs in by_name.items():
        ids = frozenset(x["doc_id"] for x in rs)
        if len(rs) > 1 and ids not in seen_pairs:
            groups.append({"type": "probable", "signal": "filename+page_count",
                           "confidence": 0.6, "key": key,
                           "doc_ids": sorted(x["doc_id"] for x in rs),
                           "paths": sorted(x["rel_path"] for x in rs)})
    return groups


# ── manifest rebuild (derived, atomic, crash-safe) ─────────────────────────────────
def _iter_doc_records() -> List[dict]:
    recs = []
    for f in sorted(config.DOC_STATE_DIR.glob("*.json")):
        r = atomicio.read_json(f)
        if r:
            recs.append(r)
    return recs


def rebuild_manifests() -> dict:
    """Regenerate all JSONL manifests from per-doc records + payloads. Atomic per file."""
    config.ensure_dirs()
    records = _iter_doc_records()
    st = _load_state()
    counts = {}

    # corpus_inventory — every discovered path (incl. exact dups + failures)
    with atomicio.JsonlWriter(config.MANIFESTS_DIR / "corpus_inventory.jsonl") as w:
        for rel_path, e in sorted(st.get("path_index", {}).items()):
            w.write({"rel_path": rel_path, **e})
        counts["corpus_inventory"] = w.count

    # document_extraction_manifest — doc-level classification + signals + counts + state
    with atomicio.JsonlWriter(config.MANIFESTS_DIR / "document_extraction_manifest.jsonl") as w:
        for r in records:
            w.write({k: r.get(k) for k in (
                "doc_id", "sha256", "rel_path", "source_group", "priority", "state",
                "page_count", "encrypted", "language", "classification", "signals",
                "parse_meta", "question_summary", "counts", "duplicate_paths",
                "text_fingerprint", "normalized_filename")})
        counts["document_extraction_manifest"] = w.count

    # page / question / asset / equation / notation manifests — stream normalized payloads
    pw = atomicio.JsonlWriter(config.MANIFESTS_DIR / "page_extraction_manifest.jsonl").__enter__()
    qw = atomicio.JsonlWriter(config.MANIFESTS_DIR / "extracted_questions.jsonl").__enter__()
    aw = atomicio.JsonlWriter(config.MANIFESTS_DIR / "visual_assets_manifest.jsonl").__enter__()
    ew = atomicio.JsonlWriter(config.MANIFESTS_DIR / "equation_recovery_manifest.jsonl").__enter__()
    nw = atomicio.JsonlWriter(config.MANIFESTS_DIR / "notation_repairs.jsonl").__enter__()
    try:
        for r in records:
            if r.get("state") not in ("COMPLETE", "PARTIAL"):
                continue
            payload = atomicio.read_json(config.NORMALIZED_DIR / f"{r['doc_id']}.json")
            if not payload:
                continue
            for p in payload.get("pages", []):
                pw.write(p)
            for q in payload.get("questions", []):
                qw.write(q)
            for a in payload.get("visual_assets", []):
                aw.write(a)
            for eq in payload.get("equation_records", []):
                ew.write(eq)
            for nrec in payload.get("notation_records", []):
                nw.write(nrec)
    finally:
        for w in (pw, qw, aw, ew, nw):
            w.__exit__(None, None, None)
    counts.update({"page_extraction_manifest": pw.count, "extracted_questions": qw.count,
                   "visual_assets_manifest": aw.count, "equation_recovery_manifest": ew.count,
                   "notation_repairs": nw.count})

    # duplicate_groups (exact + probable)
    with atomicio.JsonlWriter(config.MANIFESTS_DIR / "duplicate_groups.jsonl") as w:
        for doc_id, paths in st.get("exact_dup_groups", {}).items():
            w.write({"type": "exact", "signal": "sha256", "confidence": 1.0,
                     "doc_id": doc_id, "paths": paths})
        for g in compute_probable_duplicates():
            w.write(g)
        counts["duplicate_groups"] = w.count

    # extraction_failures
    with atomicio.JsonlWriter(config.MANIFESTS_DIR / "extraction_failures.jsonl") as w:
        for r in records:
            if r.get("state") == "FAILED":
                w.write({k: r.get(k) for k in ("doc_id", "rel_path", "source_group",
                                               "priority", "error", "encrypted", "page_count")})
        counts["extraction_failures"] = w.count

    atomicio.write_json_atomic(config.MANIFESTS_DIR / "_manifest_counts.json",
                               {"rebuilt_at": _now(), "counts": counts})
    return counts
