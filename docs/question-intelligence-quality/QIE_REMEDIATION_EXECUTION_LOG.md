# QIE/QDI Remediation — Execution Log

**Session:** dedicated QIE/QDI remediation · **Started:** 2026-07-21 · **Branch:**
`feature/qie-question-planning-layer`

**SSOT:** [`QIE_REMEDIATION_ROADMAP.md`](QIE_REMEDIATION_ROADMAP.md) (the audit is permanently
closed; this log records execution only, it never re-plans). **Certification checkpoints:**
[`QIE_REMEDIATION_CERTIFICATION_HISTORY.md`](QIE_REMEDIATION_CERTIFICATION_HISTORY.md).

**Phase status:** ✅ R0 · ✅ R1 · ✅ R2 · ✅ R3 · ✅ R4-1 · ✅ R4-2 · ✅ R0-2 recall · ✅ RI-6 re-point ·
✅ R4-3 · ✅ R4-4 · ✅ R5-1 · ✅ R5-2 · ✅ R5-3 DESIGN · ✅ R5-6 · 🔵 R5-5 cross-class-revisits fragment (next) ·
⛔ R5-3 impl / R5-4 / R5-5 calibration (PYQ+pilot) / R6 / live-key owner/external-gated.

**R5-3 design (doc-only):** `docs/question-intelligence-quality/R5-3_ERP_PROMOTION_CONTRACT_DESIGN.md` — the ERP
promotion contract (D1 platform bank + RLS · D2 KC_↔UUID map · D3 enum alignment · D4 freeze-pinned export
manifest · D5 content-addressed ids · D6 LaTeX authoring contract). Implementation owner-gated (ERP lane).

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
| R0-2 Quarantine 22 + 7 | ✅ EXECUTED (owner-approved 2026-07-21) | `quarantine_audited_estate.py --apply` | **Recall done:** 22 factory questions + 7 QDI patterns flipped certified→quarantined via guarded transitions; 29 `status_audit` rows (reason='audit-2026-07-21', prior state preserved). certified now 0 in both stores. |
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

### Phase R4 (partial: owner-approved R4-1 + R4-2 + R0-2) — ✅

| Item | State | Commit | Notes |
|---|---|---|---|
| R0-2 recall | ✅ EXECUTED | `da446fe7` | 22 questions + 7 QDI patterns certified→quarantined (audit-preserved) |
| R4-1 adopt qie.db [BS-1/5/6] | ✅ | `5ff82c37` | 7-method verifier battery + relation certifier → `kie/qie/verifiers/`; `unified_inventory.db` (4250 assets, dedup + KC_ crosswalk + provenance); qie.db registered evidence-only; **promotable-to-product now = 0** (honest — pilot items lack R2 evidence); model-agreement structurally cannot certify |
| R4-2 model execution layer [C11] | ✅ | `1a729d6d` | provider-agnostic `kie/qie/execution/`: queue/retry/crash-resume, cache + **family-scoped** judge cache, deterministic replay, R2-3 provenance, telemetry + cost + budget, OpenAI adapter (stdlib). Verifier REFUTED an independence-laundering hole → fixed + locked |

Full suite **1022 green**. RI-6 preserved.

**Follow-ons surfaced:** ~~qp_bridge RI-6 re-point~~ **DONE (see below)**;
R4-2 live tail = `OPENAI_API_KEY` (external); re-certification of recalled/held assets now has the layer + verifiers (needs a key + R4-3).

### RI-6 re-point — qp_bridge governed boundary → unified manifest (owner-approved, 2026-07-21) — ✅

The `promote.ri6_followon()` closure. Impl → **independent adversarial verifier (CONFIRMED)** → finding #4 fixed + regression-locked → tests → EOS PASS → committed.

| Item | State | Notes |
|---|---|---|
| RI-6 re-point | ✅ | `qp_bridge._governed_concepts` no longer opens qie.db for the paper boundary; it reads governed relations (`promotable`) + facts (`held_qualitative`) from the unified manifest via `manifest.governed_scope_rows`, keyed on a new manifest column `compose_concept` (the EXACT generator concept key — `topics.concept_key` for facts, `"{subject} :: {name}"` for relations — so binding is identical). A quarantined / rejected_source / duplicate governed asset can never define an in-scope concept, so it can never reach a paper. Admitted set **identical** to the prior direct read (41 promotable relations + 128 held_qualitative facts = 169). Live `unified_inventory.db` rebuilt (counts unchanged: promotable 41 / held_qualitative 190 / eligible 77 / practice_tier 1434). |
| Freshness guard (finding #4) | ✅ | `manifest.governed_scope_freshness` compares a **content** fingerprint over the decisive governed_relation/governed_fact fields (`_governed_fingerprint`), not COUNT(*) — so a count-preserving in-place mutation (status flip / equation edit / topic rename) is detected and surfaced as a loud paper warning (no stale boundary served silently). Regression test exercises the exact count-preserving flip. |

**Adversarial verification:** verify-RI-6 returned **CONFIRMED** — the core guarantee survives (relations structurally immune: `_targets` returns `[]` for every `relnum_` frame so a quarantined relation's item is dropped, never re-bound; facts have no quarantine path and generation is lock-stepped to admission; 0 relation/fact items fall through `_bind`). It found the count-only freshness gap (#4), now fixed + locked. Chains stay code-defined (byte-identical, explicitly outside RI-6).

**Live outcome:** qp_bridge boundary sourced exclusively from the manifest; NEET paper still `boundary_ok=True, rejected_slots=0`, Biology reached; JEE `boundary_ok`, ≥6 printable. New `kie/tests/test_ri6_repoint.py` (9 tests). Full suite **1031 green** (skipped=1). RI-6 now enforced end-to-end: exactly ONE product surface for governed assets.

### R4-3 — qualitative certification lane + dimensional-gate yield recovery [C16][BS-2] — ✅

Two file-disjoint lanes. Certification-affecting Lane B ran **two** independent adversarial rounds (BOTH REFUTED — real holes fixed + regression-locked; self-verified against the re-verifier's own probes).

| Item | State | Notes |
|---|---|---|
| Lane A — dimensional yield recovery | ✅ | `factory/gates.py::_UNIT_BASE` extended: angle (rad/deg/sr), percentage (%), and count (beats/rev/cycles) map to dimensionless `1` — all genuinely dimensionless, so the dimensional gate now evaluates them correctly instead of false-quarantining on an unparseable unit. **Not a weakening:** every dimension-WRONG relation (length=time, dimensionless=length, energy=momentum) still fails. Live: of **87** dimensional-reason quarantined candidates with a complete structure, **26 now pass** the dimensional gate (recovered), **61 still fail** (genuinely wrong/incomplete). |
| Lane B — qualitative certification lane | ✅ | `kie/qie/verifiers/qualitative.py` + `kie/qie/qualitative_lane.py`: the NON-MODEL re-derivation for qualitative governed facts. A fact certifies ONLY on **independent ≥2-source KVS corroboration** — a `correct_answer_is` assertion (≥2 evidence bar) attesting the exact answer from ≥2 source docs that **EXCLUDE the fact's own source**, on a **fail-closed subject-consistent** concept (authoritative `subject_term` == fact subject, not contradicted by the concept_code). Model agreement is refused (`assert_not_model_agreement`); every ambiguity (unknown subject, missing source doc, disagreeing subject signals) HOLDS. **Honest live yield = 0 certifiable / 128 held** — the governed-fact and KVS lanes largely read the same corpus answer keys, so no genuinely-independent corroboration exists in the owned estate yet. Manifest records `qualitative_grounding` per fact (a NEW column) WITHOUT changing promotion_status, so RI-6 scope (169) + pinned counts (held_qualitative 190, promotable 41) are preserved. |

**Adversarial verification (two rounds, both earned their keep):**
- Round 1 **REFUTED** — (1) the "independent ≥2-source" bar counted the fact's OWN source doc; (2) matching was concept-blind (answer-string only); (4) the model-agreement guard was a no-op on the real schema. Fixed: exclude own doc + require ≥2 independent; subject-scope the match; honest guard + a structural "model verdict never certifies" test.
- Round 2 **REFUTED** — (D1) subject was derived from the concept_code prefix, which disagrees with the authoritative `subject_term` on **44%** of live rows; (D2/D3) `subject=None`/`fact_subject=None` failed OPEN; (D4) empty own-doc disabled the independence exclusion; (D5) "concept" scoping was overclaimed (subject-only). Fixed: read `subject_term` as authoritative + cross-check the concept_code, **fail-closed** on any missing/ambiguous/disagreeing signal; HOLD when the fact has no source doc; honestly label it subject-level (concept-identity alignment deferred to R5-2).

**Live outcome:** dimensional recovery landed (26 recoverable); the qualitative lane is correct + honest (0 certifiable is the true state of the substrate — a precise, valuable measurement of the independent-evidence gap that R5-4/R5-6 / R4-2 must close). New `kie/tests/test_r4_3_qualitative_and_dimensional.py` (16 tests). Full suite **1047 green** (skipped=1). RI-6 + all pinned counts preserved.

### R4-4 — deferred audit passes (scope debt) [BS-3][BS-5][BS-6] — ✅

Governance/interface tooling (no certification decision). New `kie/qie/scope_audit.py` closes three deferred passes:

| Item | State | Notes |
|---|---|---|
| (a) BS-5 build-process audit | ✅ | `build_process_audit()` reads the FROZEN index read-only and reports honestly: build OUTPUTS were audited (per-concept `audit_verdict` present) + the freeze was certified (ki_meta package), but the phase-1-7 build PROCESS has NO per-run trail (`ki_run`=0). Names the residual gap + the forward requirement (a sanctioned rebuild MUST populate ki_run per phase). Freeze-safe (mode=ro). |
| (b) BS-3 downstream contracts | ✅ | `downstream_surface_contracts()` + `assert_surface_read()`: the 4 absent surfaces (weakness-intelligence, adaptive-practice, AI-tutor, analytics) get DESIGNED read-contracts — exactly what each reads and from which SANCTIONED reader (product bank / manifest / frozen-index-ro). Fail-closed: a raw store is NEVER sanctioned (the RI-6 second-surface mistake can't recur). |
| (c) BS-6 reconciled-inventory guard | ✅ | `reconciled_inventory_guard()`: a "whole-system" completeness claim must be computed FROM the manifest across ALL source lanes (live: qie.db + qpl_question_bank.db + factory_corpus.db); a single-lane claim is refused (the blind spot that hid qie.db). Raises if no manifest exists. |

**Live outcome:** the three "we never looked" gaps are now examined + honestly reported + guarded. New `kie/tests/test_r4_4_scope_audit.py` (12 tests). Full suite **1059 green** (skipped=1).

### R5-1 — prerequisite edge table [C13] — ✅

New `kie/qie/graph/` package (schema.sql + store.py + prereq_edges.py): a DERIVED, versioned edge table
resolving the frozen index's `ki_concept.prerequisites` NAME strings to KC_ concept_ids, built ON TOP of the
frozen index (opened mode=ro — no foundation mutation). Resolution: subject-scoped unique match, then
cross-subject-unique; a name matching ≥2 concept_ids (in-subject or cross-subject) is **ambiguous → honest-null
(never guessed)**; 0 matches → unresolved (honest-null). Uses a MULTIMAP (not the crosswalk's collapsed
first-wins map) so ambiguity is surfaced, not hidden. Versioned to the frozen fingerprint (`v1.5:ba3f8b7c…`),
deterministic rebuild. Store `graph_edges.db` (gitignored derived).

**Live outcome:** **1805 edges — 1183 resolved (65.5%), 552 unresolved, 70 ambiguous** (matches the audit's
~30% unresolved + ~95 ambiguous; ambiguity now honest, not silently collapsed). `prerequisites_of()` drops
honest-null by default; adaptive traversal can now key off resolved edges. New `kie/tests/test_r5_1_prereq_edges.py`
(11 tests). Independently adversarially verified — **CONFIRMED** (no guessing, no inflation, frozen index
never written, deterministic); a P3 note (self-loop guard: a concept naming itself as a prereq → honest-null)
was applied + regression-locked. Full suite **1070 green** (skipped=1).

### R5-2 — concept-namespace convergence on the KC_ spine [C14] — ✅

New `kie/qie/graph/namespace.py` (+ `concept_namespace` table): converges the three live ontologies (KC_ ids,
authored "Subject :: topic" governed-fact codes, legacy factory codes) onto the KC_ spine. Governed-fact topics
resolve to a KC_ id (fine-grained **topic_name**, else coarser **chapter_fallback** — labelled distinctly);
legacy factory codes resolve via their name-tail, EXCEPT OCR-junk codes which are **retired** (never a concept).
Reuses R5-1's confirmed multimap resolver; honest-null on unresolved/ambiguous; **no source store mutated**
(qie.db/factory_corpus/frozen index all opened mode=ro — the backfill lives in the derived table, RI-6).

**Live outcome:** governed_fact_topic 128 → 4 topic_name + 14 chapter_fallback + 110 honest-null; factory_legacy_code
980 → 235 subject_name + 66 cross_subject_unique + 19 ambiguous + **4 OCR-junk retired** + 656 honest-null.
`certified_concept_code` is now derivable per fact WITHOUT mutating qie.db.

**Adversarial verification:** **REFUTED** → all fixed + regression-locked (mutation-safety, no-inflation,
uniqueness, determinism were CONFIRMED). Findings: (1) `topic_name` was stamped on chapter-fallbacks too (14/18
mislabelled) → now a distinct `chapter_fallback` method; (2) the OCR-junk detector stripped underscores and
over-retired legit `THE_THEORY_OF_EVOLUTION`-style codes → rewritten to never strip separators + only real
scaffolding-only tails retire (regression test locks it); (3) under-retire forms (`SOLUTIONS_SOLUTIONS`,
`ANSWER_KEY`) now caught; (4) a bogus `KC_` code passed through as resolved → now membership-checked against
certified `ki_concept` (`unknown_kc` honest-null). New `kie/tests/test_r5_2_namespace.py` (16 tests). Full suite
**1086 green** (skipped=1).

### R5-6 — evidence-substrate cleaning [#data-integrity-2] — ✅

New `kie/qie/graph/evidence_clean.py` + `cleaned_evidence` table: a deterministic pass over the chunks that
GROUND certified concepts (2034 `doc_id#ordinal` evidence refs), producing a cleaned evidence_text BESIDE the raw
pointer (the frozen kie.db chunk is NEVER mutated — opened mode=ro). Strips unambiguous whole-line boilerplate
(reprint/rationalised footers, running heads, copyright) anywhere, and standalone page numbers ONLY when sparse
(≤2 per chunk); flags near-prose-free / high-symbol chunks as advisory so mangled math never grounds a numeric
item.

**Live outcome:** 2034 chunks processed, **1220 boilerplate-removed (60%)**, 19 flagged mangled. Raw substrate
byte-identical (freeze intact).

**Adversarial verification:** **REFUTED → fixed + regression-locked** (freeze-safety CONFIRMED — full MD5
byte-identical over repeated builds; scope + determinism CONFIRMED). The load-bearing finding: `^\d{1,4}$`
deleted REAL data — 93 figure values from a math-activity chunk, 5–93 numbers from 92 chunks (they are data, not
page numbers). Fixed: standalone numbers are stripped ONLY when SPARSE (≤2/chunk); a numeric-dense chunk keeps
every digit (self-verified: **0** dense chunks now lose a number, was 92). Finding 2 (garble escaped the flag
because spaces counted as linguistic) → the flag now also fires on near prose-free number soup. New
`kie/tests/test_r5_6_evidence_clean.py` (14 tests). Full suite **1100 green** (skipped=1).

### R5-5 (fragment) — cross-class revisits/deepens edges [#knowledge-ia-8] — ✅

New `kie/qie/graph/revisits.py` + `revisits_edge` table: 18 certified concept names recur across classes as
disjoint nodes (e.g. "Area of a rectangle" in Class 6 AND Class 8); the dead `ki_mention` table (0 rows) never
captured this. This links the earlier node to the later (deepening) one — direction from the parsed
`taught_at_class` order; a pair whose order can't be established is an undirected co-occurrence (never guessed).
Derived on the mode=ro frozen index. Live: **18 edges, all directed** (6→8, 7→9, …), 0 co-occurrence, superseding
the dead ki_mention. New `kie/tests/test_r5_5_revisits.py` (9 tests). *(Remaining R5-5 — calibration, response
spine, predicted-time norms, per-concept difficulty mining — needs pilot data / PYQ corpus: owner/external-gated.)*

**Buildable roadmap sweep — COMPLETE (2026-07-21 → 07-22).** Every cleanly-buildable item is landed: RI-6 re-point,
R4-3, R4-4, R5-1, R5-2, R5-3 (design), R5-5 (cross-class fragment), R5-6. What remains is genuinely
owner/external-gated (see the queue below), including the R5-4 finding.

**Deferred-but-enforced across R2** (machinery fail-closed NOW; the ACTORS need an API layer — roadmap R4-2):
a real cross-family/human judge yielding `independent=1` (today's path is provisional-only), an Opus
solution-writer, and a generator emitting `mis_relation` per distractor. Re-certifying the 22+15+14+7
quarantined artifacts is downstream of that.

*(Remaining R3 items + R4–R6 tracked in the roadmap; rows added here as they are executed.)*

---

## Owner-decision / external-dependency queue (the remaining boundary — nothing here is cleanly buildable)

All R0–R5 cleanly-buildable work is DONE (R0-2 recall executed; R4-1/R4-2 owner-approved+built; RI-6, R4-3, R4-4,
R5-1, R5-2, R5-3-design, R5-5-fragment, R5-6 landed this program). What is left needs an owner decision, an
external dependency, or a substantial re-mining/unfreeze effort:

1. **R5-4 — Exam DNA v2 (measured weights)** *(re-mining sub-project + attribution decisions)* — the PYQ corpus
   IS owned (226 previous_paper + 704 dpp + 9 mock_test in `source_documents`), but the mined `question_patterns`
   attribution is DEGENERATE: `exam='foundation'` on all 4853, `subject=NULL` on all, and the `concept_code`
   subject prefixes are mislabelled (`BIO_MOTION`, `CHE_NUMBERS`, `BIO_POWER`). A measured PER-EXAM/PER-SUBJECT
   weight table cannot be computed honestly from this without RE-MINING the PYQ questions with correct
   exam/subject attribution (linking each to its `source_documents` exam/subject) — a focused mining pass with
   its own decisions, NOT a clean derived table. Building on the current data would violate the honest-null law.
2. **R5-3 implementation** *(owner + ERP lane)* — the design is done (`R5-3_ERP_PROMOTION_CONTRACT_DESIGN.md`);
   the platform bank migration + RLS + exporter + KC_↔UUID map + LaTeX authoring contract are owner-gated,
   sequenced by the ERP lane (migration numbering).
3. **R5-5 remainder** *(pilot data + model/key)* — calibration (PSYCHOMETRIC spec), the ERP response spine
   (`edu_student_item_responses`, seeded at first pilot use — cannot be backfilled), predicted-time norms,
   per-concept difficulty/misconception mining (needs R2 judge output at scale = a live key). Owner/external.
4. **R6 (all)** *(owner must unfreeze Tier-1)* — R6-1 relocate the engine, R6-2 one canonical question vocabulary,
   R6-3 truthful qpgen seam, R6-4 namespace hygiene. The Tier-1 freeze applies.
5. **R4-2 live tail** *(external)* — a live `OPENAI_API_KEY` to run real generation/judging/re-certification (the
   provider-agnostic layer is built; re-certifying the recalled/held 22+15+14+7 + the R4-3 held-128 needs it).
6. **R0-1 off-machine backup** *(owner-DEFERRED)* — provide `AKSHARA_BACKUP_DEST` + passphrase, install the
   LaunchAgent. Tooling built + restore-verified.
7. **R3-4 FTS5 + `chunks(doc_id,ordinal)` index** *(freeze hatch)* — a sanctioned kie.db rebuild under
   `KIE_ALLOW_FROZEN_WRITE` at the next version boundary (mutates the frozen v1.5 substrate).
