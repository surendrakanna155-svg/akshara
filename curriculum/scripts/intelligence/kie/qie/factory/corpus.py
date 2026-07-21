"""Candidate Corpus store — open, ingest, and enforce the quarantine boundary.

The boundary is the point of this module. `candidate` and `quarantined` rows are NOT inventory: nothing here is
visible to qpgen, DPP composition, or any student/teacher surface. Promotion to `certified` is a separate,
explicit act that requires the full evidence chain, and it is never a side effect of generation.

Deliberately a SEPARATE database from qie.db, so a generator's proposal can never be mistaken for — or silently
merge into — certified evidence. A model's own prior output is not truth merely because it was stored.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional

from kie import config
from kie.qie import store_open as SO
from kie.qie.factory.gates import item_hash, norm_hash

SCHEMA_PATH = Path(__file__).resolve().parent / "corpus_schema.sql"
SCHEMA_VERSION = "factory-5"          # R3-1/R3-2: store-role governance + bank-level dedup ([C8]/[C12], RI-6/RI-9)
                                      # — additive over factory-4 (R2-3 provenance/telemetry, [C10]/RI-8), which
                                      # is additive over factory-3 (R2-1/2/4), which is additive over factory-2
                                      # (R1-2 append-only, content-bound).
CORPUS_DB_PATH = config.KIE_HOME / "factory_corpus.db"          # the TRIAL corpus (discredited 1.5%-yield trial)
PRODUCTION_BANK_DB_PATH = config.KIE_HOME / "qpl_question_bank.db"   # the ONE authoritative production bank (R3-1)

# ── R3-1 store-role governance ([C8], RI-6) ──────────────────────────────────────────────────────────
# The audit found two factory stores sharing a schema_version with NO way to tell which is product: the
# TRIAL corpus (factory_corpus.db — 15 discredited 'certified' + 456 forever-'candidate' rows) and the bank
# (qpl_question_bank.db). A role STAMP in factory_meta names each store's purpose, and product_inventory()
# refuses to serve any store that is not the production bank — un-stamped or trial stores fail CLOSED.
META_ROLE = "role"
ROLE_PRODUCTION = "production_bank"    # the ONE store product surfaces may read
ROLE_TRIAL = "trial_corpus"           # a trial/experiment store; can NEVER satisfy product_inventory()

# Placeholder model/actor ids that are NOT real provenance (R2-3, [C10]). These were the code defaults the audit
# found stamped on every row (run_generation.py:51/:71). Ingest through the model-stage paths REFUSES them
# fail-closed so a certified item can never again be attributed to an anonymous 'agent'. Compared case-folded.
BANNED_PROVENANCE_IDS = frozenset({
    "generator-agent", "judge-agent", "generator-model", "judge-model", "examiner-model",
    "examiner-agent", "agent", "model", "unknown", "none", "null", "placeholder", "orchestrator-review",
    # adversarial-verifier hardening: obvious placeholder-ish ids a real actor/model would never be.
    "generator", "judge", "examiner", "test", "example", "tbd", "todo", "n/a", "na", "-", ".", "?", "x",
})
# The provenance a model stage MUST record (RI-8). `payload_sha256` is deliberately NOT in this set: it is
# COMPUTED inside ingest from the exact bytes stored, never accepted from the caller, so it cannot be forged.
_PROVENANCE_FIELDS = ("model", "model_version", "prompt_sha256", "actor", "contract_version")
_JUDGE_PROVENANCE_FIELDS = ("model", "model_version", "prompt_sha256", "actor")


def provenance_complete(d, fields=_PROVENANCE_FIELDS) -> bool:
    """Boolean form of `_require_provenance` for callers that GATE rather than raise — the per-candidate RI-8
    precondition in certify_run. True iff every field is present and neither model nor actor is a placeholder id."""
    try:
        _require_provenance(d, fields=fields)
        return True
    except CorpusIntegrityError:
        return False

# The lifecycle. Only CERTIFIED may ever be promoted to product inventory.
CANDIDATE, QUARANTINED, REJECTED, CERTIFIED = "candidate", "quarantined", "rejected", "certified"
# R3-1 terminal status for run-closure of a trial store's forever-'candidate' rows (the 456 that a discredited
# trial never judged to a terminal state). Terminal like rejected/certified — it is NOT a candidate any more,
# so it can never be picked up by a later gate/certify pass. Set ONLY by the explicit factory-5 run-closure.
EXPIRED_UNJUDGED = "expired_unjudged"

# The certification CLASS (factory-3, R2-1) is orthogonal to the lifecycle STATUS: it records HOW a certified
# row earned its promotion, so a same-actor review can be labelled provisional without inventing a new status
# (which would disturb R1's guarded transitions). Only status=CERTIFIED + certification_class=CERT_CERTIFIED is
# product-visible; CERT_PROVISIONAL (same-actor review) is deliberately invisible until a cross-family reviewer
# disposes it in a fresh run.
CERT_CERTIFIED, CERT_PROVISIONAL = "certified", "provisional"
# R3-1: a certified row that lives in a TRIAL store. It keeps status=CERTIFIED (its evidence chain is real) but
# is demoted to this certification_class so it can NEVER be product-visible — a trial corpus holds no product.
CERT_TRIAL = "trial_certified"
# evidence_class values. The factory lane ALWAYS earns 'sympy_rederived' (a non-model re-derivation via
# independent_solve); the other two are reserved for the knowledge/OCR lane and are never stamped here.
EVIDENCE_SYMPY, EVIDENCE_MODEL_OWNED, EVIDENCE_SOURCE = (
    "sympy_rederived", "model_agreed_on_owned_evidence", "source_proven")
PRODUCT_VISIBLE = (CERTIFIED,)


def actor_family(model: str) -> str:
    """The ACTOR FAMILY behind a model/role label — the unit of proposer/certifier independence (R2-1).

    Independence is a property of WHO produced the artifact, not of the role name it was given. Absent an
    explicit family, we fall back to the model string itself, and — critically — a judge with no declared family
    defaults to the CANDIDATE'S generator family (see judge.ingest), so 'generator-agent' and 'judge-agent'
    (today's code defaults, the SAME orchestrator wearing two hats) are treated as one family and can never
    satisfy the cross-family certification gate. A genuinely different actor must assert its family explicitly.
    """
    return (str(model or "").strip()) or "unknown"


class CorpusIntegrityError(Exception):
    """A write would have violated the append-only / immutability contract (R1-2, [C1]).

    Raised, never swallowed: re-ingesting over a certified row, a duplicate (run_id, spec_id), or a guarded
    status transition that matched zero rows are all integrity breaches. The factory fails CLOSED rather than
    silently overwriting certified evidence or promoting on stale evidence.
    """


def _now() -> str:
    # Millisecond resolution (R1-2): evidence recorded in the same wall-clock second as candidate creation must
    # still satisfy the `checked_at >= created_at` certification precondition on fast runs and in tests.
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def _canonical_payload(raw_items) -> str:
    """A deterministic, order-stable JSON serialization of a model payload, so its sha256 is reproducible on
    re-ingest and cannot silently drift (R2-3). sort_keys makes it independent of dict insertion order."""
    return json.dumps(raw_items, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def payload_sha256(raw_items) -> str:
    """sha256 of the exact model payload as stored. COMPUTED here, never caller-supplied — the whole point of
    RI-8 is that provenance is verifiable, so the one field a caller could fake is the one we recompute."""
    return hashlib.sha256(_canonical_payload(raw_items).encode("utf-8")).hexdigest()


def _require_provenance(d: Optional[dict], fields=_PROVENANCE_FIELDS, kind: str = "generation") -> None:
    """Fail-closed provenance gate (R2-3, [C10], RI-8) for the model-stage ingest paths.

    Refuses (raises CorpusIntegrityError, never swallowed) when a model stage tries to persist without a real
    model id + version + prompt sha256 + actor (+ contract_version for generation), OR when the model/actor is a
    BANNED placeholder id (the old 'generator-agent'/'judge-agent' code defaults). This is what makes it
    impossible to ever again certify an item attributed to an anonymous 'agent'. `payload_sha256` is not checked
    here — it is computed inside ingest from the stored bytes and so cannot be missing or forged."""
    if not isinstance(d, dict):
        raise CorpusIntegrityError(f"refuse {kind} ingest: no provenance supplied (RI-8 requires real "
                                   f"model id + version + prompt sha256 + actor)")
    missing = [f for f in fields if not str(d.get(f) or "").strip()]
    if missing:
        raise CorpusIntegrityError(f"refuse {kind} ingest: missing provenance {missing} (RI-8)")
    for f in ("model", "actor"):
        v = str(d.get(f) or "").strip().lower()
        if v in BANNED_PROVENANCE_IDS:
            raise CorpusIntegrityError(
                f"refuse {kind} ingest: {f}={d.get(f)!r} is a placeholder id, not real provenance (RI-8)")


def store_role(conn: sqlite3.Connection) -> Optional[str]:
    """The role stamp this store carries in factory_meta (R3-1), or None if un-stamped."""
    if not _table_exists(conn, "factory_meta"):
        return None
    r = conn.execute("SELECT value FROM factory_meta WHERE key=?", (META_ROLE,)).fetchone()
    return r[0] if r else None


def _resolve_role(db_path, role):
    """Decide which role (if any) open_store should stamp, and whether the caller asked EXPLICITLY.

    Returns (role_or_None, explicit). A real FILE store is left un-stamped here — it is role-stamped only by
    the explicit factory-5 migration (`kie.qie.remediation.migrate_factory_r3`) or by `open_production_bank`,
    so an un-migrated store stays honestly un-stamped and product_inventory refuses it fail-closed. A `:memory:`
    store (a test/consumer fixture that models the certify→product pipeline) defaults to the production role so
    the product-inventory gate is exercised without an explicit stamp on every call."""
    if role is not None:
        return role, True
    if str(db_path) == ":memory:":
        return ROLE_PRODUCTION, False
    return None, False


def _stamp_role(conn: sqlite3.Connection, role: str, explicit: bool = False) -> bool:
    """Idempotently stamp the store's role. NEVER silently flips an existing explicit stamp: a caller that
    explicitly asks to re-stamp a store to a DIFFERENT role is refused fail-closed (a trial corpus must never be
    quietly promoted to a production bank). An auto-default (explicit=False) never overrides an existing stamp."""
    if role is None:
        return False
    cur = store_role(conn)
    if cur == role:
        return False
    if cur is not None:
        if explicit:
            raise CorpusIntegrityError(
                f"refuse role stamp: store already marked role={cur!r}; refusing to re-stamp as {role!r} "
                f"(RI-6 — a trial corpus must never be silently promoted to a production bank)")
        return False
    conn.execute("INSERT INTO factory_meta(key, value) VALUES (?, ?) "
                 "ON CONFLICT(key) DO UPDATE SET value = excluded.value", (META_ROLE, role))
    return True


def open_store(db_path=None, role: str = None) -> sqlite3.Connection:
    path = db_path or CORPUS_DB_PATH
    resolved_role, explicit = _resolve_role(path, role)
    # R3-4 (#database-9): the shared derived-store opener supplies row_factory, the R0-4 path guard, and the
    # standardized WAL journal_mode (foreign_keys is (re)asserted below after the table-rebuild migrations,
    # which toggle it off/on internally). Writable open — this is the factory's authoritative write path.
    conn = SO.open_store(path, read_only=False)
    # Upgrade an existing factory-1 store to the append-only shape BEFORE the schema script runs: the _latest
    # views reference the new id/item_hash columns, so the evidence tables must already be new-shape when the
    # view DDL validates. On a fresh DB this is a no-op (no tables yet) and the schema creates everything.
    migrate_appendonly(conn)                      # factory-1 -> factory-2 (table rebuild)
    migrate_r2(conn)                              # factory-2 -> factory-3 (additive ADD COLUMN; R2-1/2/4)
    migrate_r2_3(conn)                            # factory-3 -> factory-4 (additive ADD COLUMN; R2-3 provenance)
    migrate_r3(conn)                              # factory-4 -> factory-5 (bank-dedup UNIQUE; R3-2 — NO data
                                                  # demotion/closure at open, only additive schema)
    conn.executescript(SCHEMA_PATH.read_text())
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("INSERT INTO factory_meta(key, value) VALUES ('schema_version', ?) "
                 "ON CONFLICT(key) DO UPDATE SET value = excluded.value", (SCHEMA_VERSION,))
    _stamp_role(conn, resolved_role, explicit)
    conn.commit()
    return conn


def open_production_bank(read_only: bool = False) -> sqlite3.Connection:
    """Open THE one authoritative production bank (R3-1). The committed writer/consumer path: it opens
    qpl_question_bank.db, stamps it role='production_bank', and is the store product surfaces read via
    product_inventory / certified_bank. `read_only` opens it mode=ro for a pure consumer (no schema writes)."""
    config.assert_under_kie_home(PRODUCTION_BANK_DB_PATH)
    if read_only:
        conn = sqlite3.connect(f"file:{PRODUCTION_BANK_DB_PATH}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        if store_role(conn) != ROLE_PRODUCTION:
            conn.close()
            raise CorpusIntegrityError(
                f"refuse read-only production-bank open: {PRODUCTION_BANK_DB_PATH.name} is not stamped "
                f"role={ROLE_PRODUCTION!r} (run the factory-5 migration first)")
        return conn
    return open_store(PRODUCTION_BANK_DB_PATH, role=ROLE_PRODUCTION)


def save_specs(conn: sqlite3.Connection, specs: List[dict]) -> int:
    cols = ("spec_id", "run_id", "lane", "board", "exam_profile", "class_level", "subject", "concept_code",
            "concept_title", "concept_codes_all", "composition", "archetype", "question_type",
            "intended_depth", "intended_difficulty", "visual_required", "boundary", "planner_evidence",
            "created_at")
    rows = [tuple(s.get(c) for c in cols) for s in specs]
    conn.executemany(f"INSERT OR REPLACE INTO generation_spec ({','.join(cols)}) "
                     f"VALUES ({','.join('?' * len(cols))})", rows)
    conn.commit()
    return len(rows)


def _cid(run_id: str, spec_id: str) -> str:
    # Collision-free deterministic identity (R1-2). The old truncated form (run_id[-6:]+spec_id[-12:]) collided
    # whenever two run ids shared their last 6 chars ('prod_jm_math'/'gen_jm_math'), letting a second run's
    # ingest silently overwrite the first. A full sha256 of run|spec cannot collide across runs. Kept a pure
    # deterministic function of its inputs so callers/tests can reproduce a candidate_id without a DB read.
    return "CAND_" + hashlib.sha256(f"{run_id}|{spec_id}".encode()).hexdigest()[:16]


def _guard_ingest(conn: sqlite3.Connection, run_id: str, sid: str) -> None:
    """Immutability + no-overwrite guard (R1-2). A certified row is immutable; any (run_id, spec_id) already
    ingested must not be re-written. Re-ingesting new content belongs in a FRESH run, never over an existing
    candidate — that is the replay bypass the audit proved."""
    prior = conn.execute("SELECT candidate_id, status FROM candidate WHERE run_id=? AND spec_id=?",
                         (run_id, sid)).fetchone()
    if prior is None:
        return
    if prior["status"] == CERTIFIED:
        raise CorpusIntegrityError(
            f"refuse ingest: certified {prior['candidate_id']} is immutable; ingest into a fresh run")
    raise CorpusIntegrityError(
        f"refuse ingest: {prior['candidate_id']} already ingested for ({run_id},{sid}); "
        f"re-ingest into a fresh run")


def ingest(conn: sqlite3.Connection, run_id: str, raw_items: Iterable[dict], generator_model: str,
           batch: str, generator_family: str = None, provenance: dict = None) -> dict:
    """Ingest raw generator output. Records EVERYTHING — including refusals and malformed payloads — because
    the trial must measure the generator's real behaviour, not a cleaned-up version of it.

    Fails CLOSED (R1-2): a plain INSERT, guarded by _guard_ingest, so re-ingesting different content over an
    existing candidate (certified or otherwise) raises CorpusIntegrityError instead of silently overwriting.

    `generator_family` (R2-1) is the proposer's actor family, stamped now so certification can structurally
    reject a same-actor audit later. When a caller does not declare one (the current run_generation default), it
    falls back to the generator_model — so an independence claim later requires a DIFFERENT family to be
    asserted explicitly, never inferred.

    `provenance` (R2-3, RI-8) is the model-stage provenance bundle {model, model_version, prompt_sha256, actor,
    contract_version}. When supplied (the production path, run_generation.ingest_candidates), it is checked
    fail-closed by _require_provenance and its fields — plus a `payload_sha256` COMPUTED here over the exact
    stored payload — are persisted on every candidate. Legacy/low-level callers that pass no provenance leave
    those columns NULL; such rows are product-invisible (certification_class is NULL) and are surfaced by the
    RI-8 placeholder scan. The DB-wide scan runs post-re-certification, never as a retro-fail of legacy rows.
    """
    gen_family = actor_family(generator_family or generator_model)
    prov = None
    p_sha = None
    if provenance is not None:
        _require_provenance(provenance, kind="generation")
        raw_items = list(raw_items)          # materialize so the sha covers the exact batch we store
        p_sha = payload_sha256(raw_items)
        prov = provenance
    m = {"ingested": 0, "refused": 0, "malformed": 0, "unknown_spec": 0}
    known = {r["spec_id"] for r in conn.execute("SELECT spec_id FROM generation_spec WHERE run_id=?", (run_id,))}
    # factory-4 provenance quintet, bound identically to every row in the batch (or NULL for legacy callers).
    pv = (prov["model_version"], prov["prompt_sha256"], p_sha, prov["actor"], prov["contract_version"]) \
        if prov else (None, None, None, None, None)
    for it in raw_items:
        if not isinstance(it, dict) or not it.get("spec_id"):
            m["malformed"] += 1
            continue
        sid = it["spec_id"]
        if sid not in known:
            m["unknown_spec"] += 1
            continue
        cid = _cid(run_id, sid)
        _guard_ingest(conn, run_id, sid)
        if it.get("refuse"):
            conn.execute(
                "INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, generator_family, "
                "generator_batch, stem, options, answer_label, status, reject_reason, raw, "
                "model_version, prompt_sha256, payload_sha256, generator_actor, contract_version, created_at) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (cid, run_id, sid, generator_model, gen_family, batch, "", "{}", None, REJECTED,
                 f"generator_refused: {it.get('reason', '')}"[:400], json.dumps(it), *pv, _now()))
            m["refused"] += 1
            continue
        stem = (it.get("stem") or "").strip()
        options = it.get("options") or {}
        ans = it.get("answer_label")
        conn.execute(
            "INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, generator_family, "
            "generator_batch, stem, options, answer_label, answer_value, claimed, structure, solution, "
            "distractor_rationale, visual_spec, raw, status, item_hash, stem_norm_hash, "
            "model_version, prompt_sha256, payload_sha256, generator_actor, contract_version, created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (cid, run_id, sid, generator_model, gen_family, batch, stem, json.dumps(options), ans,
             str(it.get("answer_value") or ""), json.dumps(it.get("claimed") or {}),
             json.dumps(it.get("structure") or {}), json.dumps(it.get("solution") or {}),
             json.dumps(it.get("distractor_rationale") or {}),
             json.dumps(it.get("visual_spec")) if it.get("visual_spec") else None,
             json.dumps(it), CANDIDATE, item_hash(stem, options, str(ans)), norm_hash(stem), *pv, _now()))
        m["ingested"] += 1
    conn.commit()
    return m


def _current_item_hash(conn: sqlite3.Connection, candidate_id: str) -> str:
    """The candidate's CURRENT item_hash — stamped onto every evidence row so certification can bind evidence
    to the exact content it was computed against (R1-2). Evidence whose item_hash != the candidate's current
    item_hash (the replay case) can never certify."""
    r = conn.execute("SELECT item_hash FROM candidate WHERE candidate_id=?", (candidate_id,)).fetchone()
    if r is None:
        raise CorpusIntegrityError(f"no candidate {candidate_id} to bind evidence to")
    return r["item_hash"] or ""


def record_gates(conn: sqlite3.Connection, candidate_id: str, results: List[dict]) -> None:
    ih = _current_item_hash(conn, candidate_id)
    ts = _now()
    conn.executemany(
        "INSERT INTO gate_result (candidate_id, item_hash, gate, ok, severity, detail, checked_at) "
        "VALUES (?,?,?,?,?,?,?)",
        [(candidate_id, ih, g["gate"], int(g["ok"]), g["severity"], g["detail"], ts) for g in results])


def set_status(conn: sqlite3.Connection, candidate_id: str, status: str, reason: str = "",
               expected: str = CANDIDATE) -> None:
    """Guarded lifecycle transition (R1-2 — the project's documented money-integrity race pattern). The UPDATE
    is conditioned on the row still being in `expected` state and MUST touch exactly one row; a certified or
    already-moved row therefore throws instead of being silently flipped. Every current caller transitions
    from `candidate`, so the default `expected=CANDIDATE` needs no call-site changes."""
    cur = conn.execute("UPDATE candidate SET status=?, reject_reason=? WHERE candidate_id=? AND status=?",
                       (status, reason[:400], candidate_id, expected))
    if cur.rowcount != 1:
        raise CorpusIntegrityError(
            f"set_status blocked: {candidate_id} not in expected state {expected!r} "
            f"(rowcount={cur.rowcount}) — refusing to overwrite a moved/certified row")


def mark_certified(conn: sqlite3.Connection, candidate_id: str, evidence_class: str, certification_class: str,
                   reason: str = "", earned_depth: int = None, computed_archetype: str = None,
                   expected: str = CANDIDATE) -> None:
    """Promote a candidate to status=CERTIFIED and stamp the R2 certification metadata in ONE guarded write.

    Keeps R1's money-integrity contract: the UPDATE is conditioned on the row still being `expected`
    (default CANDIDATE) and MUST touch exactly one row, so a certified/already-moved row throws instead of being
    silently re-stamped. `certification_class` is CERT_CERTIFIED (product-visible) or CERT_PROVISIONAL
    (same-actor review — deliberately product-invisible). `earned_depth`/`computed_archetype` are the values the
    factory EARNED by executing the DAG and classifying the stem (R2-4), stored so downstream reads the honest
    number/label, never a refuted generator claim."""
    try:
        cur = conn.execute(
            "UPDATE candidate SET status=?, reject_reason=?, evidence_class=?, certification_class=?, "
            "earned_depth=?, computed_archetype=? WHERE candidate_id=? AND status=?",
            (CERTIFIED, reason[:400], evidence_class, certification_class,
             earned_depth, computed_archetype, candidate_id, expected))
    except sqlite3.IntegrityError as e:
        # R3-2 (RI-9) hard backstop: the partial UNIQUE index over certified item_hash / stem_norm_hash rejects
        # a promotion that would create a second certified row duplicating content already in the bank. Surface
        # it as the module's own integrity error rather than a raw sqlite error.
        raise CorpusIntegrityError(
            f"mark_certified blocked: {candidate_id} would duplicate content already certified in this bank "
            f"(RI-9 — bank-level dedup UNIQUE): {e}")
    if cur.rowcount != 1:
        raise CorpusIntegrityError(
            f"mark_certified blocked: {candidate_id} not in expected state {expected!r} "
            f"(rowcount={cur.rowcount}) — refusing to overwrite a moved/certified row")


def record_independent(conn: sqlite3.Connection, candidate_id: str, method: str, solver_answer,
                       generator_answer, verdict: str, detail: str) -> None:
    ih = _current_item_hash(conn, candidate_id)
    conn.execute(
        "INSERT INTO independent_answer (candidate_id, item_hash, method, solver_answer, generator_answer, "
        "verdict, detail, checked_at) VALUES (?,?,?,?,?,?,?,?)",
        (candidate_id, ih, method, str(solver_answer), str(generator_answer), verdict, detail[:500], _now()))


def record_judge(conn: sqlite3.Connection, candidate_id: str, judge_model: str, independent: bool,
                 v: dict, judge_family: str = None, provenance: dict = None) -> None:
    """Append a judge verdict. `judge_family` (R2-1) records the disposing reviewer's actor family so
    certification can RE-DERIVE independence (judge_family != generator_family) rather than trust the stored
    `independent` flag alone. judge.ingest computes `independent` from the families and passes both here; direct
    callers that pass only `independent` leave judge_family NULL (which certify treats as NOT cross-family).

    `provenance` (R2-3, RI-8) is the judge-stage bundle {model, model_version, prompt_sha256, payload_sha256,
    actor}. When supplied (via judge.ingest from run_generation.ingest_judgements) it is checked fail-closed and
    persisted; the judge payload_sha256 is computed by judge.ingest over the raw verdict array. Legacy/low-level
    callers leave the judge-provenance columns NULL."""
    ih = _current_item_hash(conn, candidate_id)
    if provenance is not None:
        _require_provenance(provenance, fields=_JUDGE_PROVENANCE_FIELDS, kind="judge")
    p = provenance or {}
    conn.execute(
        "INSERT INTO judge_verdict (candidate_id, item_hash, judge_model, judge_family, independent, verdict, "
        "well_posed, curriculum_ok, answer_correct, unique_answer, concepts_real, composition_real, "
        "difficulty_plausible, distractors_plausible, visual_judgement, reasons, "
        "model_version, prompt_sha256, payload_sha256, judge_actor, checked_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (candidate_id, ih, judge_model, judge_family, int(independent), v.get("verdict", "quarantine"),
         _b(v.get("well_posed")), _b(v.get("curriculum_ok")), _b(v.get("answer_correct")),
         _b(v.get("unique_answer")), _b(v.get("concepts_real")), _b(v.get("composition_real")),
         _b(v.get("difficulty_plausible")), _b(v.get("distractors_plausible")),
         v.get("visual_judgement"), json.dumps(v.get("reasons") or v.get("reason") or ""),
         p.get("model_version"), p.get("prompt_sha256"), p.get("payload_sha256"), p.get("actor"), _now()))


def _b(x) -> Optional[int]:
    return None if x is None else int(bool(x))


def telemetry(conn: sqlite3.Connection, run_id: str, stage: str, model: str, **kw) -> None:
    """Record a per-stage telemetry row (cost/throughput evidence). `actor` (R2-3) is WHO ran the stage,
    distinct from the model. Token columns stay nullable — real per-call token/latency capture arrives with the
    automated model-execution layer (R4-2); until then a stage records its real model + actor + wall time."""
    conn.execute(
        "INSERT OR REPLACE INTO run_telemetry (run_id, stage, model, actor, batches, items, input_tokens, "
        "output_tokens, wall_seconds, note, recorded_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (run_id, stage, model, kw.get("actor"), kw.get("batches"), kw.get("items"), kw.get("input_tokens"),
         kw.get("output_tokens"), kw.get("wall_seconds"), kw.get("note"), _now()))
    conn.commit()


def require_stage_telemetry(conn: sqlite3.Connection, run_id: str, stages=("generation", "judge")) -> None:
    """Mandatory-telemetry precondition (R2-3, RI-8): a run cannot be certified without a real model-stage
    telemetry row for each named stage — one that records an actual model id AND an actor. Fails CLOSED
    (CorpusIntegrityError) when a stage row is absent or carries no real model/actor, so a certification can
    never be claimed for generation/judge work that left no accountable execution trail.

    (Token/latency columns are recorded when available but are not required here — they depend on the automated
    model-execution layer, R4-2. WHO and WHAT ran the stage are provable today and are what RI-8 demands.)"""
    for stage in stages:
        row = conn.execute(
            "SELECT model, actor FROM run_telemetry WHERE run_id=? AND stage=? "
            "AND model IS NOT NULL AND TRIM(model)!='' AND actor IS NOT NULL AND TRIM(actor)!='' "
            "ORDER BY recorded_at DESC LIMIT 1", (run_id, stage)).fetchone()
        if row is None:
            raise CorpusIntegrityError(
                f"refuse certify: run {run_id!r} has no '{stage}' telemetry row with a real model id + actor "
                f"(RI-8 — every model stage must leave an accountable execution trail)")
        m = str(row["model"]).strip().lower()
        a = str(row["actor"]).strip().lower()
        if m in BANNED_PROVENANCE_IDS or a in BANNED_PROVENANCE_IDS:
            raise CorpusIntegrityError(
                f"refuse certify: run {run_id!r} '{stage}' telemetry records a placeholder model/actor "
                f"({row['model']!r}/{row['actor']!r}) — not real provenance (RI-8)")


def _assert_production_store(conn: sqlite3.Connection, fn: str) -> None:
    """R3-1 / RI-6 fail-closed store-role gate. A product read is refused unless THIS store is stamped the one
    authoritative production bank. An un-stamped store (no migration ran) and a trial store both raise — a
    student surface can never be served the discredited trial corpus, nor an un-governed store, by accident."""
    role = store_role(conn)
    if role != ROLE_PRODUCTION:
        raise CorpusIntegrityError(
            f"{fn} refused: store role is {role!r}, not {ROLE_PRODUCTION!r} (RI-6 — exactly one product-visible "
            f"certified store; un-stamped / trial stores are refused fail-closed)")


def product_inventory(conn: sqlite3.Connection, run_id: str) -> List[sqlite3.Row]:
    """The ONLY function any product surface may ever call. Certified rows exclusively — the quarantine
    boundary expressed as code rather than as a convention someone has to remember.

    R3-1 (RI-6): FIRST refuses any store that is not the one authoritative production bank — un-stamped or
    trial stores fail CLOSED (see _assert_production_store). A trial corpus can therefore never satisfy this
    function even if it holds status='certified' rows.

    R2-1 tightens the row gate: a row is product-visible only when status=CERTIFIED AND certification_class marks
    it a full (cross-family) certification. A CERT_PROVISIONAL row (same-actor review), a CERT_TRIAL row (trial
    store), and any legacy row that predates the R2 gates (certification_class NULL) are STRUCTURALLY excluded
    here — they can never reach a student surface, no matter their lifecycle status."""
    _assert_production_store(conn, "product_inventory")
    return conn.execute(
        "SELECT * FROM candidate WHERE run_id=? AND status=? AND certification_class=?",
        (run_id, CERTIFIED, CERT_CERTIFIED)).fetchall()


def certified_bank(conn: sqlite3.Connection) -> List[sqlite3.Row]:
    """The bank-wide product consumer (R3-1): every product-visible certified row across ALL runs in the one
    authoritative production bank. Same fail-closed store-role gate as product_inventory (RI-6). This is the
    committed CONSUMER a downstream surface uses to read the whole bank rather than a single run."""
    _assert_production_store(conn, "certified_bank")
    return conn.execute(
        "SELECT * FROM candidate WHERE status=? AND certification_class=? ORDER BY run_id, candidate_id",
        (CERTIFIED, CERT_CERTIFIED)).fetchall()


def read_production_bank() -> List[sqlite3.Row]:
    """Open the production bank read-only and return its full product-visible inventory (R3-1 consumer)."""
    conn = open_production_bank(read_only=True)
    try:
        return certified_bank(conn)
    finally:
        conn.close()


# ── in-place schema migration: factory-1 → factory-2 (append-only, content-bound) ────────────────────
# Idempotent. Called by open_store on every open, and runnable standalone against an EXISTING factory DB via
# kie.qie.remediation.migrate_factory_appendonly. Adds candidate.relation_waiver, rebuilds the three evidence
# tables into append-only shape (id AUTOINCREMENT + item_hash), and backfills item_hash from each candidate's
# CURRENT item_hash — correct because, pre-migration, each candidate has had exactly one attempt, so its
# current item_hash IS the content the stored evidence was computed against. Never re-promotes or re-quarantines;
# candidate_id is left untouched so all evidence linkage stays intact.
def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)).fetchone() is not None


def _has_col(conn: sqlite3.Connection, table: str, col: str) -> bool:
    return any(r["name"] == col for r in conn.execute(f"PRAGMA table_info({table})"))


_APPENDONLY_REBUILD = {
    "gate_result": (
        """CREATE TABLE gate_result_new (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
             item_hash TEXT NOT NULL, gate TEXT NOT NULL, ok INTEGER NOT NULL,
             severity TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL)""",
        """INSERT INTO gate_result_new (candidate_id, item_hash, gate, ok, severity, detail, checked_at)
             SELECT g.candidate_id,
                    COALESCE((SELECT c.item_hash FROM candidate c WHERE c.candidate_id=g.candidate_id), ''),
                    g.gate, g.ok, g.severity, g.detail, g.checked_at
             FROM gate_result g""",
    ),
    "independent_answer": (
        """CREATE TABLE independent_answer_new (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
             item_hash TEXT NOT NULL, method TEXT NOT NULL, solver_answer TEXT,
             generator_answer TEXT, verdict TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL)""",
        """INSERT INTO independent_answer_new
             (candidate_id, item_hash, method, solver_answer, generator_answer, verdict, detail, checked_at)
             SELECT i.candidate_id,
                    COALESCE((SELECT c.item_hash FROM candidate c WHERE c.candidate_id=i.candidate_id), ''),
                    i.method, i.solver_answer, i.generator_answer, i.verdict, i.detail, i.checked_at
             FROM independent_answer i""",
    ),
    "judge_verdict": (
        """CREATE TABLE judge_verdict_new (
             id INTEGER PRIMARY KEY AUTOINCREMENT,
             candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
             item_hash TEXT NOT NULL, judge_model TEXT NOT NULL, independent INTEGER NOT NULL,
             verdict TEXT NOT NULL, well_posed INTEGER, curriculum_ok INTEGER, answer_correct INTEGER,
             unique_answer INTEGER, concepts_real INTEGER, composition_real INTEGER,
             difficulty_plausible INTEGER, distractors_plausible INTEGER, visual_judgement TEXT,
             reasons TEXT, checked_at TEXT NOT NULL)""",
        """INSERT INTO judge_verdict_new
             (candidate_id, item_hash, judge_model, independent, verdict, well_posed, curriculum_ok,
              answer_correct, unique_answer, concepts_real, composition_real, difficulty_plausible,
              distractors_plausible, visual_judgement, reasons, checked_at)
             SELECT j.candidate_id,
                    COALESCE((SELECT c.item_hash FROM candidate c WHERE c.candidate_id=j.candidate_id), ''),
                    j.judge_model, j.independent, j.verdict, j.well_posed, j.curriculum_ok, j.answer_correct,
                    j.unique_answer, j.concepts_real, j.composition_real, j.difficulty_plausible,
                    j.distractors_plausible, j.visual_judgement, j.reasons, j.checked_at
             FROM judge_verdict j""",
    ),
}


def _rebuild_appendonly(conn: sqlite3.Connection, table: str) -> None:
    create_sql, copy_sql = _APPENDONLY_REBUILD[table]
    conn.execute(f"DROP TABLE IF EXISTS {table}_new")
    conn.execute(create_sql)
    conn.execute(copy_sql)
    conn.execute(f"DROP TABLE {table}")
    conn.execute(f"ALTER TABLE {table}_new RENAME TO {table}")


def migrate_appendonly(conn: sqlite3.Connection) -> bool:
    """Idempotent factory-1 → factory-2 in-place upgrade. Returns True if anything changed. No-op on a fresh DB
    (tables not yet created) and on an already-migrated DB."""
    changed = False

    if _table_exists(conn, "candidate"):
        if not _has_col(conn, "candidate", "relation_waiver"):
            conn.execute("ALTER TABLE candidate ADD COLUMN relation_waiver TEXT")
            conn.commit()
            changed = True
        # Fail CLOSED before the schema tries to add UNIQUE(run_id, spec_id): a clear diagnostic beats a raw
        # integrity error from executescript.
        dupes = conn.execute(
            "SELECT run_id, spec_id, COUNT(*) c FROM candidate GROUP BY run_id, spec_id HAVING c>1"
        ).fetchall()
        if dupes:
            raise CorpusIntegrityError(
                f"cannot enforce UNIQUE(run_id, spec_id): {len(dupes)} duplicate pair(s) already present; "
                f"resolve before migrating (e.g. {tuple(dupes[0])[:2]})")

    needs = [t for t in ("gate_result", "independent_answer", "judge_verdict")
             if _table_exists(conn, t) and not _has_col(conn, t, "item_hash")]
    if needs:
        prior_fk = conn.execute("PRAGMA foreign_keys").fetchone()[0]
        conn.commit()
        conn.execute("PRAGMA foreign_keys=OFF")
        try:
            for t in needs:
                _rebuild_appendonly(conn, t)
            conn.commit()
            changed = True
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.execute(f"PRAGMA foreign_keys={'ON' if prior_fk else 'OFF'}")
    return changed


# ── in-place schema migration: factory-2 → factory-3 (R2 certification hardening) ─────────────────────
# PURELY ADDITIVE columns — no table rebuild, no AUTOINCREMENT disturbance, no view change. Idempotent (each
# ALTER guarded by _has_col). Called by open_store right after migrate_appendonly, and standalone via
# kie.qie.remediation.migrate_factory_r2 against an existing DB. NEVER promotes/demotes: a legacy certified row
# simply acquires NULL evidence_class/certification_class and therefore falls OUT of product_inventory until it
# is re-certified under the R2 gates — the intended R0-2 quarantine-by-construction, not a status change.
_R2_CANDIDATE_COLS = (
    ("generator_family", "ALTER TABLE candidate ADD COLUMN generator_family TEXT"),
    ("evidence_class", "ALTER TABLE candidate ADD COLUMN evidence_class TEXT"),
    ("certification_class", "ALTER TABLE candidate ADD COLUMN certification_class TEXT"),
    ("earned_depth", "ALTER TABLE candidate ADD COLUMN earned_depth INTEGER"),
    ("computed_archetype", "ALTER TABLE candidate ADD COLUMN computed_archetype TEXT"),
)


def migrate_r2(conn: sqlite3.Connection) -> bool:
    """Idempotent factory-2 → factory-3 additive upgrade. Returns True if anything changed. No-op on a fresh DB
    (tables not yet created — the schema script births them factory-3) and on an already-migrated DB."""
    changed = False
    if _table_exists(conn, "candidate"):
        for col, ddl in _R2_CANDIDATE_COLS:
            if not _has_col(conn, "candidate", col):
                conn.execute(ddl)
                changed = True
        # Backfill the proposer's actor family from the recorded generator_model where absent — so an existing
        # row has a family to compare a future cross-family judge against. Never touches evidence/certification
        # class (those stay NULL => product-invisible until re-certified).
        if _has_col(conn, "candidate", "generator_family") and _has_col(conn, "candidate", "generator_model"):
            conn.execute("UPDATE candidate SET generator_family = generator_model "
                         "WHERE (generator_family IS NULL OR generator_family='') "
                         "AND generator_model IS NOT NULL")
    if _table_exists(conn, "judge_verdict") and not _has_col(conn, "judge_verdict", "judge_family"):
        conn.execute("ALTER TABLE judge_verdict ADD COLUMN judge_family TEXT")
        changed = True
    if changed:
        conn.commit()
    return changed


# ── in-place schema migration: factory-3 → factory-4 (R2-3 real model/actor provenance + telemetry) ──────
# PURELY ADDITIVE columns — no table rebuild, no view change, no AUTOINCREMENT disturbance. Idempotent (each
# ALTER guarded by _has_col). Called by open_store right after migrate_r2, and standalone via
# kie.qie.remediation.migrate_factory_r2_3 against an existing DB. NEVER promotes/demotes: the new columns are
# born NULL on legacy rows, which stay product-invisible (certification_class NULL, R2-1) and are surfaced by
# the RI-8 placeholder scan — the scan runs post-re-certification, never as a retro-fail of legacy rows.
_R2_3_CANDIDATE_COLS = (
    ("model_version", "ALTER TABLE candidate ADD COLUMN model_version TEXT"),
    ("prompt_sha256", "ALTER TABLE candidate ADD COLUMN prompt_sha256 TEXT"),
    ("payload_sha256", "ALTER TABLE candidate ADD COLUMN payload_sha256 TEXT"),
    ("generator_actor", "ALTER TABLE candidate ADD COLUMN generator_actor TEXT"),
    ("contract_version", "ALTER TABLE candidate ADD COLUMN contract_version TEXT"),
)
_R2_3_JUDGE_COLS = (
    ("model_version", "ALTER TABLE judge_verdict ADD COLUMN model_version TEXT"),
    ("prompt_sha256", "ALTER TABLE judge_verdict ADD COLUMN prompt_sha256 TEXT"),
    ("payload_sha256", "ALTER TABLE judge_verdict ADD COLUMN payload_sha256 TEXT"),
    ("judge_actor", "ALTER TABLE judge_verdict ADD COLUMN judge_actor TEXT"),
)


def migrate_r2_3(conn: sqlite3.Connection) -> bool:
    """Idempotent factory-3 → factory-4 additive upgrade. Returns True if anything changed. No-op on a fresh DB
    (tables not yet created — the schema script births them factory-4) and on an already-migrated DB.

    Adds the real-provenance columns to the two MODEL stages (candidate = generation, judge_verdict = judge),
    an `actor` column to the deterministic-stage evidence tables (gate_result / independent_answer) so no table
    is left without an actor column, and `actor` to run_telemetry. Nothing is backfilled: absence of provenance
    is an HONEST NULL, not a fabricated value (RI-8 / honest-null discipline)."""
    changed = False
    for table, cols in (("candidate", _R2_3_CANDIDATE_COLS), ("judge_verdict", _R2_3_JUDGE_COLS)):
        if _table_exists(conn, table):
            for col, ddl in cols:
                if not _has_col(conn, table, col):
                    conn.execute(ddl)
                    changed = True
    for table in ("gate_result", "independent_answer", "run_telemetry"):
        if _table_exists(conn, table) and not _has_col(conn, table, "actor"):
            conn.execute(f"ALTER TABLE {table} ADD COLUMN actor TEXT")
            changed = True
    if changed:
        conn.commit()
    return changed


# ── in-place schema migration: factory-4 → factory-5 (R3-1/R3-2 store-role governance + bank dedup) ──────
# TWO parts, both idempotent:
#   * ADDITIVE SCHEMA (safe on every open): the bank-level partial UNIQUE indexes over CERTIFIED item_hash /
#     stem_norm_hash — the RI-9 hard backstop that no two certified rows in a store share content. Created only
#     once the store is verified free of pre-existing certified duplicates (fails CLOSED with a diagnostic).
#   * DATA GOVERNANCE (explicit only — never at open): the role stamp, the trial_certified demotion, and the
#     forever-'candidate' run-closure. Run via kie.qie.remediation.migrate_factory_r3 against a COPY first.
# The status-audit ledger records every closure flip so prior state stays queryable (never overwrites
# reject_reason history) — the same table kie.qie.remediation.excise_run appends recall rows to.
STATUS_AUDIT_DDL = """
CREATE TABLE IF NOT EXISTS status_audit (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_table TEXT NOT NULL,
  entity_id    TEXT NOT NULL,
  from_status  TEXT NOT NULL,
  to_status    TEXT NOT NULL,
  reason       TEXT NOT NULL,
  at           TEXT NOT NULL DEFAULT (datetime('now'))
);
"""

# partial UNIQUE indexes (index name -> DDL). Scoped to PRODUCT-VISIBLE certified rows
# (status='certified' AND certification_class='certified') — the actual bank product surfaces read (RI-6/RI-9).
# Excluding provisional (same-actor, product-invisible) and trial_certified rows keeps a harmless invisible
# duplicate from tripping the index, while still forbidding two PRODUCT rows to share content. Duplicate
# rejected/quarantined candidates (many NULL-hashed) are irrelevant.
_CERT_VISIBLE_PRED = "status='certified' AND certification_class='certified'"
_R3_UNIQUE_INDEXES = (
    ("ux_cert_item_hash",
     f"CREATE UNIQUE INDEX IF NOT EXISTS ux_cert_item_hash ON candidate(item_hash) WHERE {_CERT_VISIBLE_PRED}"),
    ("ux_cert_norm_hash",
     f"CREATE UNIQUE INDEX IF NOT EXISTS ux_cert_norm_hash ON candidate(stem_norm_hash) WHERE {_CERT_VISIBLE_PRED}"),
)


def _assert_no_certified_dupes(conn: sqlite3.Connection) -> None:
    """Fail CLOSED before enforcing the bank UNIQUE if the store ALREADY holds two PRODUCT-visible certified
    rows sharing content — a clear diagnostic beats a raw integrity error from CREATE UNIQUE INDEX. Excise the
    duplicates (kie.qie.remediation.excise_run) before migrating."""
    for col in ("item_hash", "stem_norm_hash"):
        dupes = conn.execute(
            f"SELECT {col}, COUNT(*) c FROM candidate WHERE {_CERT_VISIBLE_PRED} AND {col} IS NOT NULL "
            f"GROUP BY {col} HAVING c>1").fetchall()
        if dupes:
            raise CorpusIntegrityError(
                f"cannot enforce bank UNIQUE on product-certified {col}: {len(dupes)} duplicated value(s) "
                f"already certified (e.g. {dupes[0][0]!r} x{dupes[0][1]}); excise them before migrating (RI-9)")


def _ensure_status_audit(conn: sqlite3.Connection) -> None:
    conn.executescript(STATUS_AUDIT_DDL)


def _demote_trial_certified(conn: sqlite3.Connection) -> bool:
    """A TRIAL store can hold no product-visible row: every certified row's certification_class becomes
    'trial_certified' (status untouched — the certified STATUS count is preserved; only product-visibility
    changes). Idempotent."""
    if not _table_exists(conn, "candidate") or not _has_col(conn, "candidate", "certification_class"):
        return False
    cur = conn.execute(
        "UPDATE candidate SET certification_class=? WHERE status=? "
        "AND (certification_class IS NULL OR certification_class!=?)", (CERT_TRIAL, CERTIFIED, CERT_TRIAL))
    return cur.rowcount > 0


def _close_forever_candidates(conn: sqlite3.Connection) -> bool:
    """Run-closure of a trial store's forever-'candidate' rows -> terminal 'expired_unjudged'. GUARDED per row
    (AND status='candidate', rowcount==1) with a status_audit row preserving prior state. Idempotent (a
    re-run finds nothing in 'candidate')."""
    if not _table_exists(conn, "candidate"):
        return False
    ids = [r["candidate_id"] for r in conn.execute(
        "SELECT candidate_id FROM candidate WHERE status=?", (CANDIDATE,))]
    if not ids:
        return False
    _ensure_status_audit(conn)
    for cid in ids:
        cur = conn.execute("UPDATE candidate SET status=? WHERE candidate_id=? AND status=?",
                           (EXPIRED_UNJUDGED, cid, CANDIDATE))
        if cur.rowcount != 1:
            raise CorpusIntegrityError(
                f"run-closure guard failed for {cid}: rowcount={cur.rowcount} (expected 1) — aborting")
        conn.execute("INSERT INTO status_audit(entity_table, entity_id, from_status, to_status, reason) "
                     "VALUES('candidate',?,?,?,?)", (cid, CANDIDATE, EXPIRED_UNJUDGED, "run-closure-r3-1"))
    return True


def migrate_r3(conn: sqlite3.Connection, role: str = None, explicit_role: bool = False,
               demote_trial: bool = False) -> bool:
    """Idempotent factory-4 → factory-5 upgrade. Returns True if anything changed.

    Default (open_store) does ONLY the additive schema: the bank-level partial UNIQUE indexes (RI-9 backstop).
    The DATA-governance work runs only when explicitly requested by the standalone migration:
      * role       — stamp factory_meta.role (production_bank | trial_corpus).
      * demote_trial — trial store: demote certified rows to 'trial_certified' AND close forever-candidates to
                       'expired_unjudged'. Use ONLY on a trial store; never a production bank."""
    changed = False
    if _table_exists(conn, "candidate"):
        have = {r["name"] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='index'")}
        need = [ddl for name, ddl in _R3_UNIQUE_INDEXES if name not in have]
        if need:
            _assert_no_certified_dupes(conn)
            for ddl in need:
                conn.execute(ddl)
            changed = True
    if role is not None:
        changed = _stamp_role(conn, role, explicit_role) or changed
    if demote_trial:
        changed = _demote_trial_certified(conn) or changed
        changed = _close_forever_candidates(conn) or changed
    if changed:
        conn.commit()
    return changed


def prior_certified_dedup(conn: sqlite3.Connection):
    """Seed structures for cross-run / bank-level dedup (R3-2, RI-9): every PRIOR certified row in THIS store,
    so the duplicate gates in validate_run see the WHOLE bank, not just the current run. Returns
    (seen_norm {norm_hash: candidate_id}, corpus_by_cell {(class,subject): [(candidate_id, stem)]}).

    A new candidate whose normalized stem collides with any certified row FATAL-fails `duplicate_exact`; a
    near-duplicate is QUARANTINEd by `near_duplicate` — so no run can re-certify a question the bank already
    holds. Trial-certified rows count too (they are real questions in the store); only status matters here."""
    seen_norm: Dict[str, str] = {}
    corpus_by_cell: Dict[tuple, list] = {}
    for r in conn.execute(
            "SELECT c.candidate_id, c.stem, c.stem_norm_hash, s.class_level, s.subject "
            "FROM candidate c LEFT JOIN generation_spec s ON s.spec_id=c.spec_id WHERE c.status=?",
            (CERTIFIED,)):
        nh = r["stem_norm_hash"]
        if nh:
            seen_norm.setdefault(nh, r["candidate_id"])
        corpus_by_cell.setdefault((r["class_level"], r["subject"]), []).append((r["candidate_id"], r["stem"]))
    return seen_norm, corpus_by_cell


def _status_counts(conn: sqlite3.Connection) -> Dict[str, int]:
    if not _table_exists(conn, "candidate"):
        return {}
    return {str(r[0]): r[1] for r in conn.execute("SELECT status, COUNT(*) FROM candidate GROUP BY status")}


def migrate_db(db_path, role: str = None, demote_trial: bool = False) -> dict:
    """Standalone, idempotent in-place migration of an EXISTING factory DB to the latest shape (R1-2 → R3).

    Asserts the certified STATUS count is UNCHANGED (no re-promotion, no re-quarantine) and returns a summary —
    the trial demotion changes product-VISIBILITY (certification_class), never the certified STATUS count; the
    run-closure moves 'candidate' rows to 'expired_unjudged' but never touches certified rows. Safe to run
    repeatedly. Path must live under KIE_HOME. This never runs the certify_run promotion.

    `role` (R3-1) stamps factory_meta.role. `demote_trial` (R3-1, trial store ONLY) demotes certified rows to
    'trial_certified' and closes forever-'candidate' rows to 'expired_unjudged'."""
    if str(db_path) != ":memory:":
        config.assert_under_kie_home(db_path)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    try:
        before = _status_counts(conn)
        changed = migrate_appendonly(conn)                    # factory-1 -> factory-2 (table rebuild)
        changed = migrate_r2(conn) or changed                 # factory-2 -> factory-3 (additive; R2-1/2/4)
        changed = migrate_r2_3(conn) or changed               # factory-3 -> factory-4 (additive; R2-3)
        changed = migrate_r3(conn, role=role, explicit_role=(role is not None),
                             demote_trial=demote_trial) or changed   # factory-4 -> factory-5 (R3-1/R3-2)
        conn.executescript(SCHEMA_PATH.read_text())           # create views/indexes; bump nothing it already has
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("INSERT INTO factory_meta(key, value) VALUES ('schema_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value = excluded.value", (SCHEMA_VERSION,))
        conn.commit()
        after = _status_counts(conn)
        if before.get(CERTIFIED, 0) != after.get(CERTIFIED, 0):
            raise CorpusIntegrityError(
                f"migration altered certified count {before.get(CERTIFIED, 0)} -> {after.get(CERTIFIED, 0)} "
                f"— aborting (a migration must never promote or demote a certified STATUS)")
        return {"changed": changed, "schema_version": SCHEMA_VERSION, "role": store_role(conn),
                "before": before, "after": after}
    finally:
        conn.close()
