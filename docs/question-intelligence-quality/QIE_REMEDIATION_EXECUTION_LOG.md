# QIE/QDI Remediation — Execution Log

**Session:** dedicated QIE/QDI remediation · **Started:** 2026-07-21 · **Branch:**
`feature/qie-question-planning-layer`

**SSOT:** [`QIE_REMEDIATION_ROADMAP.md`](QIE_REMEDIATION_ROADMAP.md) (the audit is permanently
closed; this log records execution only, it never re-plans). **Certification checkpoints:**
[`QIE_REMEDIATION_CERTIFICATION_HISTORY.md`](QIE_REMEDIATION_CERTIFICATION_HISTORY.md).

**Phase status:** ✅ R0 · ✅ R1 (checkpoint) · ✅ R2 (checkpoint) · ✅ R3-3 · 🔵 rest of R3 in progress ·
⛔ R4-1/R4-2/R5-3/R6 owner/external-gated.

This log is the running record of what has actually been implemented, verified, tested,
certified, documented, and committed — one row per roadmap item.

---

## ✅ R1 GOVERNANCE HALT — LIFTED (R1 exit, 2026-07-21)

The R0-3 halt is **lifted**: every R1 item (R1-1…R1-5) has landed, the R1 permanent
invariants (RI-1, RI-2, RI-4, RI-5, RI-7, RI-10) are green, and the certification machinery
the audit disproved has been repaired and independently adversarially verified. The four P0s
(C0, C1, C2, C3) and the freeze P0 (C6) are closed. Full suite **815 green** against the
newly-promoted **v1.5** index.

**Still gated (NOT lifted by R1 exit):**
- ⛔ **Scaling generation** waits for **Phase R2** (proposer/certifier independence R2-1;
  mandatory solution stage + distractor verification R2-2; real model/actor provenance R2-3).
  RI-3 (full certified-row invariant incl. `solution_verified=1`) and RI-8 (independent
  same-family audit rejection) complete only with R2.
- ⏸ **Recall of the 22 factory questions + 7 QDI patterns** (R0-2) remains an OWNER decision.
  The R1 machinery already REFUSES them on any re-run (grounding + provenance invariants);
  the explicit `certified → quarantined` flip is owner-gated.
- ⏸ **Re-certification** of the 14 v1.5-quarantined concepts + the 22 + the 7 needs the model
  proposer (deterministic gates certify; the proposer is downstream of controlled R2 runs).

A single controlled certification run is now permissible on the repaired machinery; a
bank-growth / scaling program is not, until R2.

---

## Progress ledger

Legend: ✅ done (committed) · 🔵 in progress · ⏸ owner-gated (prepared, not executed) ·
⏳ blocked (external dep) · ⬜ not started

### Phase R0 — Immediate safeguards

| Item | State | Commit | Notes |
|---|---|---|---|
| R0-1 Off-machine backup | ✅ / ⏳ owner tail | `00508275` | Encrypted, restore-verified backup tooling built + proven (fingerprint EXACT MATCH `e3a146f3…`). 3 previously-unbacked DBs now copied into the archive. **Owner/external tail:** provide an off-machine `AKSHARA_BACKUP_DEST` + passphrase and install the LaunchAgent (README). |
| R0-2 Quarantine 22 + 7 | ⏸ owner-gated | — | Guarded quarantine script prepared + dry-run-verified; **execution is an explicit OWNER decision** (roadmap tags it so). Not flipped. |
| R0-3 Halt cert runs | ✅ | (this doc) | Halt recorded above + handoff banner. |
| R0-4 Directory hygiene | ✅ | `d45a03f9` | Stray qie.db deleted; backups relocated + chmod a-w; wal/shm gitignored; `assert_under_kie_home()` added. |

### Phase R1 — Certification integrity (closes the 4 P0s + freeze) — ✅ COMPLETE

3 parallel file-disjoint lanes → 5 independent read-only briefs → 3 impl agents → 3 adversarial
verifiers (Lane A **REFUTED** a lane-agnostic-grounding hole → fixed + regression-locked + re-verified;
Lane B **CONFIRMED** + a P2 hardening; Lane C verifier stalled on a 206MB copy → **self-verified**).

| Item | State | Commit | Notes |
|---|---|---|---|
| R1-1 Blocking grounding gates [C0] | ✅ | `f6db2803` | relation_grounded BLOCKING + waiver; sympy equivalence; stem↔structure gate; **truth gates key on structure not lane** (verifier fix) |
| R1-2 Append-only cert records [C1] | ✅ | `f6db2803` | collision-free id; immutability guard; append-only evidence + item_hash binding; guarded set_status; live migration (15+22 preserved) |
| R1-3 QDI provenance truth [C2][BS-4] | ✅ | `99679f2a` | provenance invariant recalls all 7; fail-closed floor; evidence floor computed from refs; qdi_source populated; RCA corrected |
| R1-4 Content-addressed evidence [C3] | ✅ | `842c472d` | evidence_sha256; substrate fingerprint + fail-closed guard; un-waivable evidence gate; **v1.5 live (2023→2009, 14 quarantined)** |
| R1-5 Enforce the freeze [C6] | ✅ | `842c472d` | freeze guard + mode=ro + chmod a-w (index+kie.db); RI-1 fingerprint recompute; RI-10 |
| RI  Invariant suite (R1 slice) | ✅ | (above) | RI-1,2,4,5,7,10 green. RI-3 partial (solution stage = R2-2); RI-6/8/9 = R2/R3 scope |

**v1.5 promotion (live):** frozen_version=v1.5, certified 2009, RI-2 = 0 violations, substrate
match; v1.4 retained as `snapshots/knowledge_index_v1.5_frozen.db` sibling + v1.4 snapshot (never
mutated). kie.db + index chmod a-w. Rollback copies + off-repo backup in place.

### Phase R2 — Trust, independence & provenance — ✅ COMPLETE

Each item: impl → independent **adversarial verifier** (the cluster verifier REFUTED → 4 holes fixed+locked;
the R2-3 verifier REFUTED → per-candidate-provenance hole fixed+locked) → live migration → committed.

| Item | State | Commit | Notes |
|---|---|---|---|
| R2-1 Proposer/certifier independence [C4] | ✅ | `04265407` `7fca9c20` | judge blind (no proposed_key leak); `independent` COMPUTED from actor families; same-actor ⇒ provisional + product-invisible; seeded judge controls (dropped-all now caught); `evidence_class` stamped |
| R2-2 Solution stage + distractor verification [C5] | ✅ | `04265407` `7fca9c20` | certify requires content-bound `solution_verified=1` + `distractor_verified=1`; sympy-executed `mis_relation`; all-uncertifiable no longer vacuous |
| R2-3 Real model/actor provenance + telemetry [C10] | ✅ | `e03b1471` | factory-4; fail-closed ingest + placeholder ban; computed payload_sha256; mandatory telemetry; **per-candidate provenance a certify precondition** (RI-8); append-only ledger; ki_run |
| R2-4 No self-refuted metadata (step replay) | ✅ | `04265407` `7fca9c20` | `replay_steps` executes the DAG; depth EARNED; `depth_agreement` BLOCKING (string-typed claim now coerced); earned_depth/computed_archetype on certified rows |
| R2-5 Honest difficulty/exam labeling (P2) | ✅ | `e53b1522` | `difficulty_calibration='predicted_uncalibrated'`; ADVISORY method-leak gate (practice-tier vs exam-novel). NCERT-originality + empirical calibration deferred (R5 — need PYQ/exercise corpus) |

**Live migrations applied** (factory-2 → factory-3 → factory-4): factory_corpus 15 + qpl_question_bank 22
certified counts preserved; **product_visible ⇒ 0** — the 22 production questions + 15 trial rows are
recalled-by-construction (invisible to any product surface until re-certified under the R2 gates). This
automatically enforces the audit's "quarantine the 22" condition; R0-2's status flip is belt-and-suspenders.
Full suite **868 green**.

RI status: **RI-3 COMPLETE** (full certified-row conjunction: gates + independent + judge-accept +
solution_verified + distractor_verified, bound to item_hash). **RI-8 COMPLETE** (same-actor cannot promote;
every certified row carries real per-candidate model+actor+prompt_sha256 provenance).

### Phase R3 — Store governance & engineering hygiene — ✅ COMPLETE (all buildable items)

4 parallel file-disjoint lanes + a sequential hygiene batch. Certification-affecting lanes (A bank/dedup,
C gate/leak) got independent adversarial verification (verify-R3-A **CONFIRMED**; verify-R3-C **REFUTED** →
crying-wolf boundary + prose section-regex leak fixed + regression-locked).

| Item | State | Commit | Notes |
|---|---|---|---|
| R3-1 Authoritative certified bank [C8] (RI-6) | ✅ | `ca568fab` | `factory_meta.role` stamp; `product_inventory`/`certified_bank` refuse un-stamped/trial stores fail-closed; trial→`trial_certified`; 456→`expired_unjudged` |
| R3-2 Cross-run/bank-level dedup [C12] (RI-9) | ✅ | `ca568fab` | 3 layers: gate-seed from ALL prior certified · certify duplicate quarantine · partial UNIQUE index over product-visible certified · no spec re-parenting |
| R3-3 CI + vacuous-green guard | ✅ | `66938d41` | kie-suite CI + `run_kie_suite.py` canonical guard + missing `sympy` dep |
| R3-4 Schema/engine hygiene | ✅ | `e7bb9adb` | shared `store_open.py` (WAL/FK/ro/path-guard, frozen openers untouched); run_planner fail-loud on missing store; concept_codes_all → ids; JSON-validity test (20 cols); qp_bridge engine cache. **Deferred:** FTS5 + chunks index (frozen kie.db) |
| R3-5 Concept-identity ingest safety | ✅ | `dea15b63` | `ingest_concept_safe` refuse-and-log on collision (never demote certified); alias audit |
| R3-6 Rollback/excision tooling | ✅ | `ca568fab` | `excise_run.py` guarded + audited + dry-run-default recall; preserves reject_reason |
| R3-7 Latent gate/leak paths | ✅ | `baed52fc` | boundary "checked 0"→advisory + derived tokens (concept-self dropped, no crying wolf); `certified_patterns` exam-scoped; anchored section regex |
| R3-8 Retire the AR path [#red-team-10] | ✅ | `4c229651` | reachability denylist honored by qp_bridge; qpgen 0 bytes changed |

**Live migration:** factory-4 → **factory-5** applied (bank role=production_bank; corpus role=trial_corpus,
15→trial_certified, 456→expired_unjudged); concept_codes_all backfilled live (bank 24/0-unresolved; corpus
1000 rewritten/99 honest-null). Full suite **957 green**. RI-6 + RI-9 hold.

**Next = the owner/external gates (PAUSED here):** R4-1 (adopt/mine/retire the hidden `qie.db` lane — OWNER),
R4-2 (automated model-execution layer — needs an API layer / external dep), R5-3 (ERP promotion — owner-gated),
R6 (owner must unfreeze Tier-1). R4-3/R4-4/R5-*/others are buildable but gated behind or dependent on these.

**Deferred-but-enforced across R2** (machinery fail-closed NOW; the ACTORS need an API layer — roadmap R4-2):
a real cross-family/human judge yielding `independent=1` (today's path is provisional-only), an Opus
solution-writer, and a generator emitting `mis_relation` per distractor. Re-certifying the 22+15+14+7
quarantined artifacts is downstream of that.

*(Remaining R3 items + R4–R6 tracked in the roadmap; rows added here as they are executed.)*

---

## Owner-decision / external-dependency queue (surfaced, not auto-run)

1. **R0-1 off-machine target** *(external)* — provide `AKSHARA_BACKUP_DEST` on an
   off-machine volume + passphrase; install the daily LaunchAgent.
2. **R0-2 quarantine execution** *(owner)* — approve flipping the 22 factory questions +
   7 QDI patterns `certified → quarantined`. Script is ready (`quarantine_audited_estate.py`,
   dry-run verified); it uses guarded transitions and preserves prior state.
3. Downstream owner-gated items (R4-1 lane reconciliation, R5-3 ERP promotion, all of R6)
   remain in the roadmap; not reached yet.
