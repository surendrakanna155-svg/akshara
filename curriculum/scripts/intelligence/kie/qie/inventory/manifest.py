"""Build + query the unified_inventory.db manifest (R4-1(b)).

`build()` reconciles all sources, de-duplicates by the factory `item_hash` (RI-9 key), assigns dedup groups,
writes the manifest, and records a DETERMINISTIC content fingerprint (independent of wall-clock created_at) so
two builds over the same source fingerprints reproduce byte-identically. READ-ONLY over every source store; the
only writes are to unified_inventory.db itself.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from typing import Dict, List, Optional

from kie import config
from kie.qie.inventory import crosswalk as XW
from kie.qie.inventory import reconcile as RC
from kie.qie.inventory import store as ST

# priority for choosing the representative row within an item_hash dedup group (higher wins).
_PRIORITY = {"promotable": 5, "practice_tier_eligible": 4, "eligible": 3, "held_trial": 2,
             "held_qualitative": 1, "held_low_quality": 1, "honest_null": 0, "quarantined": 0,
             "rejected_source": 0, "duplicate": -1}
# statuses that must never share an item_hash (the RI-9 invariant surface).
_PROMOTABLE_STATES = frozenset({"promotable", "practice_tier_eligible", "eligible"})

QIE_DB_PATH = config.KIE_HOME / "qie.db"
BANK_DB_PATH = config.KIE_HOME / "qpl_question_bank.db"
CORPUS_DB_PATH = config.KIE_HOME / "factory_corpus.db"


def _ro(path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _collect(qie, bank, corpus, xw) -> List[dict]:
    rows: List[dict] = []
    rows += list(RC.iter_pilot_items(qie, xw))
    rows += list(RC.iter_relations(qie, xw))
    rows += list(RC.iter_facts(qie, xw))
    rows += list(RC.iter_kvs(qie, xw))
    if bank is not None:
        rows += list(RC.iter_factory(bank, RC.BANK, xw))
    if corpus is not None:
        rows += list(RC.iter_factory(corpus, RC.CORPUS, xw))
    return rows


def _dedup(rows: List[dict]) -> Dict[str, int]:
    """In-place dedup of question_items. Two independent keys, both stored/used honestly:

      * dedup_group = norm_hash — the NEAR-DUP CLUSTER label (template families; the 33 shared pilot stems all
        collapse into their norm_hash group). Grouping only — near-dups with fresh numbers are legitimately
        distinct items and are NOT demoted.
      * item_hash — the EXACT-dup key (RI-9). Rows sharing an item_hash are true duplicates: keep the single
        highest-priority representative (ties broken by uid → deterministic), demote the rest to 'duplicate'.

    Returns {exact_dups_collapsed, near_dup_clusters}."""
    for r in rows:
        if r["asset_class"] == "question_item" and r.get("norm_hash"):
            r["dedup_group"] = r["norm_hash"]
    exact: Dict[str, List[dict]] = {}
    near: Dict[str, int] = {}
    for r in rows:
        if r["asset_class"] != "question_item":
            continue
        if r.get("item_hash"):
            exact.setdefault(r["item_hash"], []).append(r)
        if r.get("norm_hash"):
            near[r["norm_hash"]] = near.get(r["norm_hash"], 0) + 1
    collapsed = 0
    for ih, members in exact.items():
        if len(members) == 1:
            continue
        members.sort(key=lambda m: (-_PRIORITY.get(m["promotion_status"], 0), m["uid"]))
        for m in members[1:]:
            if m["promotion_status"] in _PROMOTABLE_STATES:
                m["promotion_status"] = "duplicate"
                collapsed += 1
    return {"exact_dups_collapsed": collapsed,
            "near_dup_clusters": sum(1 for v in near.values() if v > 1)}


def _content_fingerprint(rows: List[dict]) -> str:
    """Deterministic sha256 over the manifest's decisive fields (NOT created_at). Reproducible across builds."""
    keyed = sorted(
        "|".join(str(r.get(k)) for k in ("uid", "asset_class", "concept_kc", "compose_concept", "item_hash",
                                         "norm_hash", "dedup_group", "promotion_status", "is_deterministic",
                                         "reverify_ok"))
        for r in rows)
    return hashlib.sha256("\n".join(keyed).encode()).hexdigest()


def _governed_fingerprint(qie) -> str:
    """Content fingerprint of the GOVERNED scope assets (governed_relation + governed_fact) over the DECISIVE
    fields qp_bridge's product boundary depends on — status, name/equation, subject, topic, concept. Unlike a
    COUNT(*) signal, this detects a count-PRESERVING in-place mutation (a `certified→rejected` status flip, an
    equation edit that breaks re-derivation, a topic rename), so a stale governed boundary is never served
    silently (verifier finding #4). Scoped to governed tables: pilot/kvs churn that the boundary does not read
    does NOT trip it. Deterministic (ORDER BY id)."""
    parts = []
    try:
        for r in qie.execute("SELECT relation_id, status, name, subject, equation, concept_candidate "
                             "FROM governed_relation ORDER BY relation_id"):
            parts.append("R|" + "|".join("" if v is None else str(v) for v in tuple(r)))
    except sqlite3.OperationalError:
        pass
    try:
        for r in qie.execute("SELECT fact_id, status, subject, topic, concept_candidate "
                             "FROM governed_fact ORDER BY fact_id"):
            parts.append("F|" + "|".join("" if v is None else str(v) for v in tuple(r)))
    except sqlite3.OperationalError:
        pass
    return hashlib.sha256("\n".join(parts).encode()).hexdigest()


def _source_fingerprints(qie, bank, corpus) -> Dict[str, str]:
    def counts(conn, tables):
        parts = []
        for t in tables:
            try:
                n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            except sqlite3.OperationalError:
                n = "NA"
            parts.append(f"{t}={n}")
        return ";".join(parts)
    fp = {"qie.db": counts(qie, ("pilot_verified_item", "governed_relation", "governed_fact", "kvs_assertion"))}
    if bank is not None:
        fp["qpl_question_bank.db"] = counts(bank, ("candidate",))
    if corpus is not None:
        fp["factory_corpus.db"] = counts(corpus, ("candidate",))
    return fp


_COLS = ("uid", "source_store", "source_table", "source_id", "source_status", "asset_class", "subject",
         "exam", "concept_code_src", "compose_concept", "concept_kc", "verification_methods",
         "is_deterministic", "evidence_class", "evidence_refs", "item_hash", "norm_hash", "dedup_group",
         "promotion_status", "qualitative_grounding", "promotion_target", "reverified_at", "reverify_method",
         "reverify_ok", "created_at")


def build(unified_path=None, qie_path=QIE_DB_PATH, bank_path=BANK_DB_PATH,
          corpus_path=CORPUS_DB_PATH, crosswalk=None) -> dict:
    """Reconcile every source into the manifest store. Returns a build summary. Idempotent (rebuilds fresh).

    `crosswalk` may be injected (a `crosswalk.Crosswalk`) so a fixture-only build can run without the frozen
    index present; by default it is built read-only from knowledge_index.db."""
    xw = crosswalk if crosswalk is not None else XW.build()
    qie = _ro(qie_path)
    bank = _ro(bank_path) if bank_path and __import__("pathlib").Path(bank_path).exists() else None
    corpus = _ro(corpus_path) if corpus_path and __import__("pathlib").Path(corpus_path).exists() else None
    try:
        rows = _collect(qie, bank, corpus, xw)
        dedup_stats = _dedup(rows)
        fp = _content_fingerprint(rows)
        now = datetime.now(timezone.utc).isoformat(timespec="seconds")
        conn = ST.open_store(unified_path, writable=True)
        try:
            conn.execute("DELETE FROM unified_inventory")
            conn.execute("DELETE FROM crosswalk")
            for r in rows:
                r.setdefault("dedup_group", None)
                r["reverified_at"] = now
                r["created_at"] = now
                conn.execute(
                    f"INSERT INTO unified_inventory ({','.join(_COLS)}) "
                    f"VALUES ({','.join('?' * len(_COLS))})", tuple(r.get(c) for c in _COLS))
            # crosswalk rows: distinct (src_code, subject) with resolution outcome
            seen = set()
            for r in rows:
                sc = r.get("concept_code_src")
                if not sc or (sc, r.get("subject")) in seen:
                    continue
                seen.add((sc, r.get("subject")))
                resolved = 1 if r.get("concept_kc") else 0
                conn.execute("INSERT OR REPLACE INTO crosswalk (src_code, subject, kc_id, method, resolved) "
                             "VALUES (?,?,?,?,?)",
                             (sc, r.get("subject"), r.get("concept_kc"),
                              "name_match" if resolved else "unresolved", resolved))
            meta = {
                "build_fingerprint": fp, "built_at": now, "total_assets": str(len(rows)),
                "crosswalk_version": xw.version, "crosswalk_stats": json.dumps(xw.stats()),
                "source_fingerprints": json.dumps(_source_fingerprints(qie, bank, corpus)),
                "governed_fingerprint": _governed_fingerprint(qie),   # content-sensitive governed-scope drift
                "frozen_index_fingerprint_v1.5": xw.version,
                "dedup_stats": json.dumps(dedup_stats),
            }
            for k, v in meta.items():
                conn.execute("INSERT INTO unified_meta(key,value) VALUES (?,?) "
                             "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (k, v))
            conn.commit()
        finally:
            conn.close()
    finally:
        qie.close()
        if bank:
            bank.close()
        if corpus:
            corpus.close()
    return {"total": len(rows), "build_fingerprint": fp, "crosswalk": xw.stats(), "dedup": dedup_stats,
            "promotion_counts": _tally(rows), "asset_counts": _tally(rows, "asset_class")}


def _tally(rows, field="promotion_status") -> Dict[str, int]:
    out: Dict[str, int] = {}
    for r in rows:
        out[r[field]] = out.get(r[field], 0) + 1
    return dict(sorted(out.items(), key=lambda kv: -kv[1]))


# ── query helpers (read-only) ─────────────────────────────────────────────────────────────────────────
def open_ro(unified_path=None) -> sqlite3.Connection:
    return ST.open_store(unified_path, writable=False)


# RI-6 re-point: the ONLY manifest promotion_status a governed asset may carry to define a product paper's
# in-scope boundary. Relations must be `promotable` (deterministically RE-certified by notation_recovery —
# a relation that no longer re-derives is `quarantined` and thereby excluded). Facts are `held_qualitative`
# (model examiner, is_deterministic=0): admitted for curriculum MEMBERSHIP only, honestly non-deterministic,
# never certified-as-truth here — R4-3 supplies the non-model re-derivation that can lift them.
GOVERNED_SCOPE_STATUS = {"relation": ("promotable",), "fact": ("held_qualitative",)}


def governed_scope_rows(subjects, unified_path=None) -> List[dict]:
    """RI-6 (BS-1/6): the SINGLE product-boundary surface for governed relations/facts.

    Returns [{asset_class, subject, compose_concept, promotion_status, source_id}, ...] for the requested
    subjects — ONLY assets registered in the manifest with an admitted status (see GOVERNED_SCOPE_STATUS).
    A governed asset that is quarantined / rejected_source / duplicate / held for R4-3-only can NEVER appear
    here, so a product paper's syllabus boundary is defined exclusively by manifest-verified, registered
    assets. qp_bridge calls this instead of reading qie.db directly — qie.db is no longer a product surface.
    """
    subj = set(subjects)
    conn = open_ro(unified_path)
    try:
        out: List[dict] = []
        for asset_class, statuses in GOVERNED_SCOPE_STATUS.items():
            q = (f"SELECT subject, compose_concept, promotion_status, source_id FROM unified_inventory "
                 f"WHERE asset_class=? AND compose_concept IS NOT NULL AND promotion_status IN "
                 f"({','.join('?' * len(statuses))})")
            for row in conn.execute(q, (asset_class, *statuses)):
                if row["subject"] in subj:
                    out.append({"asset_class": asset_class, "subject": row["subject"],
                                "compose_concept": row["compose_concept"],
                                "promotion_status": row["promotion_status"], "source_id": row["source_id"]})
        return out
    finally:
        conn.close()


def governed_scope_freshness(qie_path=QIE_DB_PATH, unified_path=None) -> dict:
    """Compare the governed-scope content fingerprint the manifest was BUILT from against live qie.db.

    The manifest is a verified snapshot; product reads it, never live qie.db. This integrity check compares a
    CONTENT fingerprint over the decisive governed_relation/governed_fact fields (`_governed_fingerprint`), so
    it catches a count-preserving in-place mutation — a status flip, an equation edit, a topic rename — that a
    COUNT(*) signal would miss (verifier finding #4). Returns {fresh, recorded, live, counts, reason}. Missing
    manifest/qie.db -> fresh=None (honest-unknown).
    """
    from pathlib import Path
    try:
        conn = open_ro(unified_path)
    except sqlite3.OperationalError:
        return {"fresh": None, "recorded": None, "live": None, "reason": "manifest absent"}
    try:
        gf = conn.execute("SELECT value FROM unified_meta WHERE key='governed_fingerprint'").fetchone()
        recorded = gf[0] if gf else None
    finally:
        conn.close()
    if not Path(qie_path).exists():
        return {"fresh": None, "recorded": recorded, "live": None, "reason": "qie.db absent"}
    qie = _ro(qie_path)
    try:
        live = _governed_fingerprint(qie)
        counts = _source_fingerprints(qie, None, None).get("qie.db")
    finally:
        qie.close()
    if recorded is None:
        return {"fresh": None, "recorded": None, "live": live, "counts": counts,
                "reason": "no recorded governed fingerprint (rebuild the manifest)"}
    fresh = (recorded == live)
    return {"fresh": fresh, "recorded": recorded, "live": live, "counts": counts,
            "reason": ("in sync" if fresh else
                       "governed relations/facts drifted since manifest build — rebuild unified_inventory.db")}


def promotion_counts(unified_path=None) -> Dict[str, int]:
    conn = open_ro(unified_path)
    try:
        return {r["promotion_status"]: r["n"] for r in conn.execute(
            "SELECT promotion_status, COUNT(*) n FROM unified_inventory GROUP BY promotion_status "
            "ORDER BY n DESC")}
    finally:
        conn.close()


def build_fingerprint(unified_path=None) -> Optional[str]:
    conn = open_ro(unified_path)
    try:
        r = conn.execute("SELECT value FROM unified_meta WHERE key='build_fingerprint'").fetchone()
        return r[0] if r else None
    finally:
        conn.close()
