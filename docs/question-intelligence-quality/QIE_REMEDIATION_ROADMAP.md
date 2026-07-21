# QIE/QDI REMEDIATION ROADMAP — Single Source of Truth

**Date:** 2026-07-21 · **Status:** PLANNING ONLY — nothing here is implemented; execution happens in a
dedicated QIE remediation session. · **Source of every item:** the completed Independent Certification
Audit — `INDEPENDENT_CERTIFICATION_AUDIT_2026-07-21.md` (34 agents, 17/17 defect clusters
adversarially CONFIRMED, 0 refuted, blind-spot analysis complete; audit permanently closed).

**Audit verdict being remediated:** CERTIFIED — Continue with moderate redesign. Conditions: close the
four P0s before any new certification run; quarantine the 22 production questions + 7 QDI patterns
until re-certified; off-machine backup immediately.

**Traceability legend:**
- `[C0]…[C16]` — verified defect clusters (audit §4–§6, §14.1, all CONFIRMED)
- `[BS-1]…[BS-6]` — blind-spot critic findings (audit §14.3)
- `#reviewer-N` — individual P2/P3 findings from named reviewers (full text preserved in the audit
  workflow journal; claims/evidence summarized inline here so no re-investigation is needed)

**Standing laws (from audit §11 — must NEVER be weakened by any remediation):**
certification requires non-model re-derivation; the judge may reject but never solely certify;
freeze-as-versioning (never mutate); honest-null / provenance-class discipline; adversarial controls
before every batch, abort on breach; quarantine as a first-class state; planner determinism;
"wrong knowledge is worse than missing knowledge — never weaken a gate for yield"; rejected evidence
is preserved.

---

## Phase overview

| Phase | Theme | Gate |
|---|---|---|
| R0 | Immediate safeguards (hours) | Before anything else, incl. any owner demo |
| R1 | Certification integrity — closes the 4 P0s | **Before ANY new certification run** |
| R2 | Trust, independence & provenance | Before scaling generation |
| R3 | Store governance & engineering hygiene | Before scaling generation |
| R4 | Lane reconciliation, automation & yield | Before bank-growth program |
| R5 | Knowledge graph & product integration | Before product wiring |
| R6 | Architecture & owner-gated hygiene | After owner unfreezes Tier-1 |
| RI | Permanent invariant test suite | Built alongside R1–R3 |

---

## Phase R0 — Immediate safeguards

### R0-1 · Off-machine backup of the certified estate — **P0 (operational)** · Governance/Reliability · [C7] #security-governance-9
The entire certified estate (kie.db ~197MB, knowledge_index.db, qdi.db, examdna.db, both question
banks, snapshots) is gitignored and lives on one 85%-full laptop volume (`/dev/disk3s5`, 67Gi free).
The existing archive `~/Documents/Akshara_foundation_backup_v1.4_20260720` is on the SAME volume and
**excludes examdna.db, qdi.db, qpl_question_bank.db — those three have NO backup copy of any kind.**
**Do:** rsync/restic (encrypted) of `curriculum/knowledge/kie/` + `qie.db` to an off-machine target;
include ALL live DBs; verify restore against the freeze fingerprints; get owner sign-off to extend the
local-storage decision (owner lock forbids git/prod promotion, NOT off-machine copies — audit
confirmed this reading). Then schedule it (cron/LaunchAgent).
**Done when:** a restore on another machine reproduces fingerprint `e3a146f3…` and all row counts.

### R0-2 · Quarantine the 22 certified questions + 7 certified QDI patterns — **P0** · Certification · [C0][C1][C2][C5] (OWNER decision to execute)
They audit clean on manual review but were promoted by bypassable guards, with the solution stage
skipped, and (patterns) with false provenance. **Do:** one-off script flipping status
certified→quarantined via guarded transitions (`AND status='certified'`, rowcount==1) writing an
audit row (reason='audit-2026-07-21', prior state preserved — do NOT overwrite reject_reason
history). Re-certification happens automatically when R1/R2 gates re-run them.
**Done when:** `product_inventory()` returns 0 rows; prior state queryable.

### R0-3 · Halt new certification runs until R1 exit — **P0 (process)** · Governance
No `certify_run`, no `--register`/`--apply` conversions, no QDI certification until R1 items land.
Record the halt in the session handoff doc.

### R0-4 · Directory hygiene quick pass — **P2** · Database · #knowledge-ia-11 #database-8 #security-governance-10 #red-team-11
Delete the two zero-byte stray `qie.db` files (repo root + `curriculum/`, Jul 15 — artifacts of
wrong-cwd sqlite opens); `chmod a-w` all `.bak`/snapshot files; move the 4 kie.db backups (~840MB) and
2 `*_candidate.db` files under `snapshots/` with a one-line manifest; add `*.db-wal`/`*.db-shm` to the
root .gitignore. Every store opener should assert its resolved path is under `KIE_HOME`.

---

## Phase R1 — Certification integrity (closes the four P0s)

### R1-1 · Make truth-checking deterministic where possible; blocking grounding — **P0** · Certification/AI · [C0]
**Defect (proven by live demo):** sympy re-solves only the generator's own declared structure
(gates.py:127-137, never the prose stem); `relation_grounded` is ADVISORY (gates.py:426-433 — its own
comment says "a quarantine EVENT") and failed ok=0 on ALL 22 certified items; the dimensional gate
auto-passes `ok=True "not checkable"` on missing units (gates.py:423-424; 13/22). A wrong-but-consistent
item (KE=mv², key 18 J vs true 9 J) passed the entire battery.
**Do:**
1. `relation_grounded` becomes BLOCKING: relation absent from the governed_relation registry ⇒
   quarantine (never certify). An explicit owner-visible waiver may be recorded on the row; "advisory"
   is not a valid severity for factual grounding.
2. Dimensional "not checkable" ⇒ `ok=0` + quarantine, never pass.
3. New deterministic stem↔structure binding gate: every number/unit in the declared `givens` must
   appear in the stem (and vice versa for quantities), so the stem a student reads is bound to what
   sympy solved.
4. Add wrong-relation seeded controls (e.g. the KE=mv² item) to `controls.py` must-catch battery.
**Done when:** the KE=mv² demo item is refused by the deterministic layer alone; regression test locked.

### R1-2 · Append-only, content-bound certification records — **P0** · Engineering/Certification · [C1] + #perf-scale-5 #perf-scale-6 #qa-reliability-7
**Defect (proven executable, twice):** `INSERT OR REPLACE INTO candidate` (corpus.py:93-103) +
truncated `_cid = run_id[-6:]+spec_id[-12:]` (corpus.py:62-63 — 'prod_jm_math'/'gen_jm_math' collide) +
evidence tables REPLACE-able and keyed by candidate_id alone + `certify_run` (certify.py:42-67) never
checking gate_result or content hashes ⇒ re-ingest promotes never-gated content to certified on stale
evidence AND silently destroys the previously certified row.
**Do:**
1. Candidate identity: full spec_id in candidate_id or `UNIQUE(run_id, spec_id)` + plain INSERT.
2. A row with status='certified' is immutable — any ingest targeting it hard-fails.
3. gate_result / independent_answer / judge_verdict become append-only (attempt-sequenced PK or
   history table; corpus_schema.sql's own comment "nothing is overwritten" currently false —
   corpus.py:109-135 all use INSERT OR REPLACE).
4. `certify_run` preconditions: gate battery rows exist for THIS item_hash; every evidence row's
   recorded item_hash == candidate's current item_hash; evidence checked_at > candidate created_at.
5. `set_status` gains `AND status=<expected>` + throw-on-0-rows (the project's documented
   money-integrity race pattern — corpus.py:116-118, certify.py:52-66).
**Done when:** the audit's replay probe (re-ingest different stem → certify) fails loudly; two-skeptic
reproduction scripts become regression tests.

### R1-3 · QDI pattern re-derivation, provenance truth, RCA correction — **P0** · Knowledge/Governance · [C2] + [BS-4] #data-integrity-3 #security-governance-7
**Defect:** all 7 certified patterns claim JEE_Main Mathematics; 2 (QDP_57333bb83da55b,
QDP_e3842c9a9d9c70) cite ONLY JEE_Advanced 2023 physics chunks (electric dipole / Young's modulus /
Bohr orbits); 5 cite `Practice_Resources` docs (content-accurate JEE Main math papers, but false
canonical exam identity, irreproducible under the post-RCA `exam_sources()`); patterns predate fix
8fb31ac7 (mined 19:35, fix 20:44), never re-derived; `SOURCE_INDEXING_RCA.md:72` FALSELY clears them;
one physics pattern injected a physics `expected_solving_path` into certified set-theory spec
QBP_8061e8a12761a23e. **Plus [BS-4]:** 2 of 7 certified patterns have `evidence_count=1`, violating
QDI's own ≥5-DNA-from-≥2-resources rule (mine.py:10). **Plus:** `qdi_source` is 0 rows in both stores;
`ingest_qdi_audit` (qdi.py:445-451) certifies unconditionally with no check the deterministic floor
ran; the floor silently SKIPS anti-copy when evidence text can't be fetched (run_qdi.py:100-102).
**Do:** re-mine/re-derive all patterns under the fixed exam-identity rule; enforce the evidence-count
threshold at certification; populate qdi_source; add invariant: pattern.exam+subject == every evidence
doc's canonical exam+subject; floor fails CLOSED (unfetchable evidence ⇒ quarantine) and ingest
refuses rows without a floor_passed_at marker; correct RCA §"unaffected" claim in the doc; adopt the
standing rule: **fix-forward without recalling affected certified artifacts is prohibited.**

### R1-4 · Content-addressed evidence + substrate fingerprinting + re-audit — **P0** · Knowledge Foundation · [C3] + #data-integrity-0/1 (cluster members)
**Defect:** evidence refs are bare `doc_id#ordinal` (positional, no hash); kie.db (which records no
data fingerprint — schema_meta holds only schema_version) was re-chunked Jul 18 AFTER certification
(doc 0f9c03d266e6d0a8: 179→146 chunks; a18dd2a7457faa46: 356→347, proven vs Jul-16 backup) ⇒ frozen
v1.4 contains 5 dangling refs (e.g. KC_0c6600faae8924 'Preparation of Alkenes' cites ordinals
#167-175, live MAX=146), 68 sha-changed refs, ~21 refs under 40 chars incl. 1-char chunks
(KC_203f2f3de8dde9 'Aromaticity' rests on 'Reprint 2026-27 3answerS'). engineer.py:448-464 promotes
purely on audit verdict=='accept' — no chunk resolution or content check; invariant suite checks only
JSON-non-emptiness. Materiality (recorded): refs were valid and audited at certification time — this
is post-hoc provenance drift; the 22 bank items avoid affected concepts.
**Do:**
1. Evidence refs become `doc_id#ordinal` + chunk sha256 (chunks.sha256 already exists in kie.db).
2. Record kie.db's content fingerprint in ki_meta at every freeze; certification/planning refuses to
   run when the live substrate's fingerprint differs from the recorded one.
3. Deterministic evidence gate in engineer.py: every cited chunk must resolve AND contain substantive
   text (post-boilerplate-strip, shares a token with concept name or section heading) — the AI
   auditor cannot waive it.
4. Re-audit the affected certified concepts (5 dangling + 68 changed + ~17-21 garbage-evidenced);
   re-certify or quarantine each; new version bump (v1.5) — never mutate v1.4.
**Done when:** invariant RI-2 (below) passes over the whole index.

### R1-5 · Enforce the freeze mechanically — **P0/P1** · Governance · [C6] + #architect-6 #knowledge-ia-4
**Defect:** zero code anywhere recomputes `certified_knowledge_fingerprint`; the immutability test
(test_knowledge_foundation_integrity.py:124-130) checks only immutable=='true' + COUNT equality (a
content mutation or count-preserving swap passes all 766 tests); committed code opens frozen DBs RW
(build.py:33, reconcile.py:156; engineer.py:279/:462 INSERT OR REPLACE / UPDATE on certified rows);
kie.db shows live -wal/-shm activity; ki_meta's UNVERSIONED `certified_knowledge_fingerprint` key
still holds the v1.2 value (`cbe63d50…`) beside versioned v1.3/v1.4 keys — a naive consumer reads a
stale hash.
**Do:** fingerprint-recompute permanent test (the method string in ki_meta makes it ~10 lines);
`mode=ro` on every open outside a versioned rebuild; `chmod a-w` frozen files; repoint/remove the
stale unversioned key at the next sanctioned meta write; drop or tombstone (`ki_meta role=
'legacy_seed_read_only'`) the stale qdi_* tables inside knowledge_index.db (12 'proposed' rows
contradicting qdi.db's 7 certified/5 quarantined — #knowledge-ia-3 #database-4 #qa-reliability-5).

---

## Phase R2 — Trust, independence & provenance

### R2-1 · Enforce proposer/certifier independence — **P1** · AI/Governance · [C4]
Evidence: opus-4.8 is both engineer and auditor on 2,140+ ki_concept rows; judge independence is a
caller-supplied boolean (judge.py:115; independent=0 on ALL certified verdicts); the judge worksheet
leaks proposed_key (judge.py:92); the 7 QDI patterns were audited by the orchestrator itself
(audit_model='orchestrator-review…' on all 12 rows; roadmap ~471 admits it).
**Do:** cross-family (or human) judge lane required for certification; judge must produce its OWN
answer before seeing the proposed key; seeded known-bad control items per judge worksheet (extend the
controls-before-batch discipline to the AI judge); ingest code structurally rejects same-actor audits;
'certified' may only be claimed with a different-family disposing reviewer — same-actor review is
labeled provisional. Add machine-readable `evidence_class` on every certified artifact
('sympy_rederived' | 'model_agreed_on_owned_evidence' | 'source_proven') so the knowledge lane's
model-agreement 'certified' is never conflated with sympy-backed 'certified' (#ai-systems-6).

### R2-2 · Mandatory solution stage + deterministic distractor verification — **P1** · Certification · [C5] + #ai-systems-8 #assessment-4
Evidence: all 22 certified rows have solution='{}' and distractor_rationale='{}'; zero solution_*
gate rows; certify.py:42-67 never queries solutions — violating solutions.py:8-14's declared lifecycle
('LOCK CERTIFIED KEY → CONSTRUCT SOLUTION → VERIFY SOLUTION'); the trial DB proves the stage works
(70/70 solution_verified). **Do:** `status='certified'` requires solution_verified=1; complete the
stage for the existing 22 during re-certification; extend the generation contract so each distractor
declares its mis-relation (e.g. 'a = m/F') and a deterministic gate executes it via sympy and requires
the computed value to equal the option (machinery exists — gates.py:127-201); populated, verified
distractor_rationale (named misconception per wrong option) becomes a certification gate.

### R2-3 · Real model/actor provenance + full-stage telemetry — **P1** · Governance/Engineering · [C10] + #security-governance-8 #perf-scale-4 #qa-reliability-9
Evidence: generator_model='generator-agent'/judge_model='judge-agent' are code defaults
(run_generation.py:51/:71); CONTRACT_VERSION defined (plan.py:20) but never persisted; run_telemetry
holds only 'gates' stage rows with NULL token columns; ki_run = 0 rows across v1.0→v1.4; no actor
column anywhere; ledger.record upserts over its own history (ledger.py:26-36).
**Do:** every model-stage row records exact model ID + version, prompt sha256, payload sha256, actor;
ingest REJECTS payloads without them; telemetry rows mandatory for generation/judge stages (tokens,
latency); stage ledger becomes append-only with a latest-status view; populate ki_run on every index
build.

### R2-4 · Stop shipping self-refuted metadata — **P1** · AI/QA · #ai-systems-5 #qa-reliability-6
Evidence: ALL 24 gated production candidates failed depth_agreement (claimed 2–5 vs DAG-computed 1)
and archetype_agreement (0/24) — both advisory, so refuted labels ship on certified items;
`replay_steps` exists only as a docstring (gates.py:246); structure_depth reads the DAG without
executing it. **Do:** implement step replay (execute each DAG step with sympy; depth = steps needed to
reproduce the answer); until then strip claimed depth/archetype from certified rows or store computed
values alongside and block on disagreement; downstream paper/DPP composition must not consume refuted
labels.

### R2-5 · Honest difficulty/exam labeling until calibrated — **P2** · Product/Assessment · [C15↓P2] + #assessment-7
Evidence: 100% single-concept Class-11 items (chapters 1–4, depths 2–5, 4/22 easy) with
difficulty_basis='bounded driver model diff-v1' (fixed arbitrary weights, not PYQ-calibrated) tagged
JEE_MAIN/NEET. **Do:** product-facing metadata labels difficulty 'predicted (uncalibrated)' until
PYQ/pilot calibration exists (R5-4/R5-5); add stem-terseness/method-leak and NCERT-template
originality checks (several stems telegraph method or number-swap canonical NCERT exercises); such
items remain practice-tier, not exam-novel.

---

## Phase R3 — Store governance & engineering hygiene

### R3-1 · One authoritative certified bank, owned by code — **P1** · Database/Product · [C8] + #assessment-6 #product-6 #ai-systems-9
Evidence: `qpl_question_bank.db` is referenced by ZERO committed code (docs-only); corpus.py:23
defaults to factory_corpus.db which holds 15 RUN_TRIAL1 'certified' rows (from the discredited
1.5%-yield trial) + 456 forever-'candidate' rows; both stores share schema_version 'factory-1' with no
role marker; product_inventory() ("the ONLY function any product surface may ever call") is
per-connection with no notion of which store is product; no consumer reads the bank (qp_bridge sources
the OLD compositional lane).
**Do:** committed writer + consumer for the production bank; role stamp in factory_meta
(e.g. role='production_bank' / 'trial_corpus'); product_inventory() refuses un-stamped stores; demote
trial rows to 'trial_certified' (or archive the file); add terminal status 'expired_unjudged' for run
closure of the 456; permanent invariant test on the bank's evidence chains (currently none).

### R3-2 · Cross-run/bank-level dedup — **P1** · Engineering · [C12] + #qa-reliability-4
Evidence: spec_id = sha256(fingerprint|occurrence), run-independent (blueprint.py:95-98); planner
deterministically re-issues identical specs (run_planner.py:93-97, empirically confirmed);
validate_run.py:46-49 rebuilds seen_norm/corpus_by_cell empty per call from `WHERE run_id=?` only;
no UNIQUE on item_hash/stem_norm_hash (corpus_schema.sql:71-72 plain indexes);
blueprint_store.py:71-73 INSERT OR REPLACE re-parents prior generation_spec rows to the new run.
**Do:** seed dedup structures from ALL prior certified rows in the target store before gating; UNIQUE
constraint or pre-certify similarity check vs the whole bank; stop re-parenting spec provenance;
decide consumption-ledger vs run-salt semantics for repeat batches; two-run regression test.

### R3-3 · CI + loud test skipping — **P1** · Engineering/QA · #architect-9 #qa-reliability-3
Evidence: no GitHub workflow runs the kie suite (grep 'kie' in .github/workflows/: none); 10
skipUnless(DB-exists) guards across 9 safety-critical test files make the suite vacuously green on
any machine without the gitignored DBs. **Do:** CI job for the suite (stdlib+sympy, 48s; DB tests
self-skip → fixtures-only in CI); emit a loud summary counting skipped-for-missing-DB suites and FAIL
if >0 on the canonical machine.

### R3-4 · Schema/engine hygiene batch — **P2** · Database · #database-5 #database-6 #database-9 #perf-scale-7 #perf-scale-8 #perf-scale-9 #security-governance-10
- `generation_spec.concept_codes_all` stores TITLES not ids ('["Sets and their Representation"]') —
  backfill 24 specs with concept_ids; writer emits ids (#database-5).
- No `CHECK(json_valid(...))` anywhere; ~15 JSON-TEXT columns unvalidated; extend the JSON invariant
  test beyond ki_concept (#database-6).
- Journal-mode inconsistency (knowledge_index/qdi/examdna=delete vs others=WAL); one shared
  `open_store()` (row_factory, foreign_keys, journal_mode, mode=ro default) (#database-9, #perf-scale-7).
- Missing stores degrade silently to [] in run_planner (OperationalError→[] at :44-47, :77-89) —
  require explicit allow-missing flag + loud path warning (#perf-scale-8).
- FTS5 index over chunks before corpus expansion (QDI mining runs leading-wildcard LIKEs over 57,390
  chunks); cache/persist qp_bridge._engine_pool keyed by (registry version, seed) (#perf-scale-9).
- `chunks` index → (doc_id, ordinal) at next kie.db version (#database-9).

### R3-5 · Concept-identity ingest safety — **P2** · Knowledge Foundation · #knowledge-ia-5 #knowledge-ia-10
concept_id = sha(subject|class|name) EXCLUDES chapter; ingest INSERT OR REPLACE can silently collapse
same-named concepts from different chapters/parallel books and reset certified→proposed
(engineer.py:277-289; ki_gap cross_book_reattribution residue proves it). **Do:** refuse-and-log on
concept_id collision with different chapter or non-proposed status; explicit merge records; alias
uniqueness audit (5 certified aliases collide with other canonical names; 53–95 ambiguous prereq
refs); prefer id-based references everywhere.

### R3-6 · Rollback/excision tooling — **P2** · Governance · #security-governance-9
No batch-excision routine exists; status flips overwrite reject_reason history. **Do:** run-scoped
excision routine using guarded transitions that preserves prior state in audit rows; documented
recall procedure (pairs with the R1-3 no-fix-forward rule).

### R3-7 · Close latent gate/leak paths — **P2** · Certification/Knowledge · #red-team-7 #red-team-8
- Curriculum-boundary gate vacuous: 15/22 certified items had empty forbidden_terms ("checked 0" ⇒
  pass); non-empty ones are sentence-length strings that can't regex-match (gates.py:397-400). Derive
  short lexical forbidden tokens from out_of_scope evidence + class-banned technique lists; "checked
  0" becomes an advisory failure.
- Residual leak paths: qdi.py:460-466 `certified_patterns()` filters subject-only (no exam) and is
  wired into run_planner.plan() reading the INDEX's stale qdi tables; qdi_link.py:16/23 maps unknown
  exam → 'SCHOOL' instead of refusing; section-marker regex (qdi.py:237-239) matches prose and takes
  the LAST marker for the whole chunk. Exam-scope or delete certified_patterns(); unknown exam =
  validation error; anchored section-header regex + split multi-marker chunks.

### R3-8 · Retire the known-defective qpgen AR path — **P2** · Engineering · #red-team-10
The 2026-07-11 red team's confirmed defect is still live: assertion-reason answer hard-coded to
`_AR_OPTS[0]` (templates.py:541) in the frozen engine qp_bridge still assembles from. Dormant in the
bridge path, alive for any direct engine/template caller. **Do:** retire AR families from the
reachable registry or gate engine.py behind the bridge (respect the qpgen freeze — reuse-not-edit;
this is registry/reachability surgery, not an engine edit).

---

## Phase R4 — Lane reconciliation, automation & yield

### R4-1 · Reconcile the two question-intelligence lanes — **P1** · Architecture/Product · [BS-1][BS-5] + #product-6
The whole board missed `qie.db`: 1,496 pilot-verified items (Math/JEE 715, Physics 291+167, Chem/NEET
110, **Biology/NEET 98**), question_dna 2,996 across 6 lanes, KVS 1,845 assertions, governed_fact 152,
governed_relation 49 — with a BROADER verifier battery (7 methods: symbolic_inverse,
independent_second_method, per-step + independent e2e, two-way + KB-lookup refutation) than the new
factory lane (sympy-of-own-relation + same-family judge). Sampled quality is low (templated stems,
weak distractors). ≥3 divergent "accepted" stores exist with no authoritative inventory.
**Do (OWNER decision):** adopt / mine / formally retire the qie.db lane; either way (a) port the
7-method verifier battery into the factory lane, (b) produce ONE reconciled certified/verified
inventory manifest across qpl_question_bank.db, factory_corpus.db, qie.db, (c) mark retired stores'
statuses so they can never satisfy product reads.

### R4-2 · Automated model-execution layer — **P1** · AI/Scalability · [C11] + #ai-systems-7
No API integration anywhere in the tree (grep: no anthropic/openai/httpx/requests; generation/judging
round-trip scratchpad files — run_generation.py:90); observed capacity 24 items/day; 8/25 trial
batches died on session limits; MODEL_ROUTING_AND_COST_PLAN.md explicitly 'SPEC — not implemented';
no judge-verdict cache (examiner.py has the item_hash cache pattern; judge.py doesn't).
**Do:** real API client with queue, retries, scheduler; per-stage token/cost capture (feeds R2-3);
item_hash-keyed judge cache; then benchmark cheaper tiers for compact generation per the routing plan.
Bounded throughput/cost model for a thousands-per-exam bank.

### R4-3 · Qualitative certification lane + dimensional-gate yield recovery — **P1** · Certification/Product · [C16] + [BS-2]
certify.py:14-24: qualitative items cannot be certified in the factory lane ⇒ NEET Biology (90/180)
unreachable there; trial yield 15/1,000 (~1.5%); quarantine buckets show wrongful kills: 87
dimensional-involved (unit-conversion '72 beats/min→per day', percentage 'water tank 20% used,
1600 L', geometry-angle "unparseable 'rad'"), 48 no_independent_path (qualitative), 19 composition.
The qualitative substrate ALREADY EXISTS unexamined: qie/convert/ governed facts + KVS assertions +
Tier-2 verify/refute ([BS-2]).
**Do:** design the qualitative certification lane on the owned-evidence substrate (scale the
128→152-fact registry; KVS assertion checking as the non-model re-derivation analogue); fix the
dimensional gate's false-reject classes (dimensionless conversions, percentages, angle units);
target: Biology certifiable with an evidence-grounded, non-model verification step.

### R4-4 · Deferred audit passes (the board's own scope debt) — **P2** · Governance · [BS-3][BS-5][BS-6]
(a) KIE build-process audit: phase1–7 OCR/parse/chunk correctness was never audited (only outputs);
ki_run=0 means no build audit trail. (b) Downstream-surfaces evidence pass: weakness intelligence,
daily/adaptive practice, AI tutor, analytics have NO lane code (grep-confirmed) — turn that absence
into designed interfaces (what each needs from the bank/index). (c) Never again accept a
"whole-system" claim scoped to one lane — reconciled inventory (R4-1) is the guard.

---

## Phase R5 — Knowledge graph & product integration

### R5-1 · Prerequisite edge table — **P1** · Knowledge Foundation · [C13] + #product-9
prerequisites are unkeyed name strings (index_schema.sql:89); measured 542/1,810 (29.9%) resolve to
nothing + 95 ambiguous multi-target. **Do:** derived, versioned edge-resolution table
(name → concept_id, unresolved kept as honest nulls) on TOP of the frozen index — no foundation
mutation; roadmap already defers a relationship graph to "Phase 6"; adaptive traversal blocks on this.

### R5-2 · Concept-namespace convergence on the KC_ spine — **P1** · Knowledge/Product · [C14] + #knowledge-ia-9
Three live ontologies: KC_ ids (bank specs), authored 'Subject :: topic' strings (qpgen governed-fact
lane; certified_concept_code empty on all 128), legacy kie.db codes (factory_corpus specs, incl.
OCR-junk codes like MAT_ANSWERSANSWERS…). Mastery/coverage/dedup cannot join across lanes.
**Do:** map topics into the KC_ spine (most are sub-concepts of certified concepts); backfill
governed_fact.certified_concept_code; crosswalk or retire legacy codes with the R4-1 decision.

### R5-3 · ERP promotion contract — **P1** · Product/Database · [C9] + #database-7 #product-7
Zero exporter exists; `edu_question_bank_items` (mig 20260620000000) requires organization_id/school_id
NOT NULL + school-scoped RLS (no platform home), difficulty CHECK rejects 'moderate', question_type
lacks 'numerical', concept_id is UUID vs KC_ text ids. Math stems are ASCII prose ('sin-squared
theta') with no format field or renderer.
**Do (design now, implement owner-gated):** platform-scoped bank table + RLS; KC_↔UUID vocabulary
map; enum alignment; versioned export manifest pinned to freeze fingerprints; content-addressed ids
survive export; authoring contract requires LaTeX (dual plain/LaTeX stem + stem_format column) BEFORE
the bank grows — retrofitting notation onto thousands of prose stems is re-authoring; prototype the
Flutter/web math-render path early.

### R5-4 · Exam DNA v2 — measured, not self-referential — **P1** · Assessment/Knowledge · #architect-7 #assessment-5 #red-team-9
227/236 weights are evidence_proportional to the index's own concept density ("NOT PYQ-measured" in
their own basis strings); difficulty/depth mixes are uncited hardcoded priors (examdna.py:54-61); no
marking scheme stored. Planned papers mirror textbook density, and "distribution fidelity" certifies
fidelity to opinions. **Do:** mine the owned PYQ corpus (327 sources / 20,216 chunks) for measured
weights/difficulty; store marking schemes (+4/−1, partial); blueprints surface DNA provenance_class;
any "exam-representative" claim gates on v2.

### R5-5 · Calibration & product-signal layers — **P2** · Product · #product-4 #product-5 #knowledge-ia-7 #knowledge-ia-8 #knowledge-ia-6 #product-8
- Reactivate PSYCHOMETRIC_CALIBRATION_SPECIFICATION.md (currently filed "superseded") and bind to the
  QPL driver model (predicted_difficulty + calibration_status on promoted rows); seed the ERP response
  spine (edu_student_item_responses, mig 20260853) at first pilot use — it cannot be backfilled.
- predicted_time_seconds slot on blueprint/certified item; empirical time norms later (#product-5).
- Per-concept difficulty/misconception certified layer — mine from stored distractor evidence + judge
  verdicts; ki_concept has no difficulty column, misconceptions 0 rows everywhere (#knowledge-ia-7).
- Cross-class 'revisits/deepens' edges (15 certified names recur across classes as disjoint nodes);
  implement or drop the dead ki_mention table (0 rows, 0 code refs) (#knowledge-ia-8).
- Promote sub-concepts to identified rows before adaptive/tutor features; state the real hierarchy
  honestly (implemented tree is Source→Chapter→Concept + JSON blobs) (#knowledge-ia-6).
- Multi-language: record the re-entry cost honestly (language column on every content table + a
  verified-translation lane; deterministic checks do NOT transfer to translated stems). Board
  expansion = evidence acquisition, not engineering (#product-8).

### R5-6 · Evidence-substrate cleaning — **P2** · Knowledge Foundation · #data-integrity-2
54.3% (1,099/2,023) of certified concepts carry evidence matching reprint/footer boilerplate; math
evidence sometimes OCR-mangled ('P(BGG)+P(GBG)+P(GGB) = 83818181=++'). **Do:** deterministic
chunk-cleaning pass (strip footers/running heads/page numbers) producing a cleaned evidence_text
beside the raw pointer; flag chunks with >X% non-linguistic characters so mangled math never grounds
a generated numeric item.

---

## Phase R6 — Architecture & owner-gated hygiene (⛔ Tier-1 freeze applies — owner must unfreeze)

### R6-1 · Relocate the engine out of curriculum/scripts/ — **P2** · Architecture · #architect-4
The physical home already caused damage (gitignore 'knowledge/' collision left qie/knowledge/ +
qie/factory/ untracked for a period; hardcoded absolute user path in qcorpus_adapter.py:22). Promote
to a top-level package with a data dir whose name cannot collide with code dirs; config-driven paths.

### R6-2 · One canonical question-design vocabulary — **P2** · Architecture/AI · #architect-8
Four registries describe "what a question looks like": archetypes, qpgen templates (39KB),
compositional TEMPLATE_REGISTRY, QDI patterns. Declare QDI canonical; map archetypes into it;
template registries become generators-of-last-resort or migrate into QDI-conformant patterns.

### R6-3 · Truthful qpgen seam — **P2** · Architecture · #architect-5
qp_bridge is documented as the sole seam but gates.py:36, topics.py:118, kvs_compose.py:84 import
kie.qpgen.sanitize directly. Extract sanitize into a shared lib both import, or amend the boundary
statement. Truthful boundary > aspirational one.

### R6-4 · Namespace & naming hygiene — **P3** · Architecture · #architect-10 #architect-11
Move retired one-shot modules (autocompose, benchmark, capability*, kvs_seed/build, mine, dpp_stage,
elite_ingest, stranded_recover, doc_recover, concept_canon…) to qie/_history/; store renaming at next
version boundary ('kie.db' is NOT the frozen foundation — knowledge_index.db is; the audit's own
briefing repeated this error) + STORES.md map; separate live stores from backups by subdirectory.

---

## Phase RI — Permanent invariant test suite (build alongside R1–R3; from audit §13)

| # | Invariant (must hold forever) | Enforced by |
|---|---|---|
| RI-1 | Recomputed content fingerprint over certified ki_concept rows == newest versioned ki_meta value (never count-only) | R1-5 |
| RI-2 | Every certified evidence ref resolves to a live chunk whose sha256 matches the recorded hash | R1-4 |
| RI-3 | No 'certified' row without: zero fatal gates + independent_answer='agree' + judge accept with independent=1 + solution_verified=1, bound to the candidate's current item_hash | R1-1/2, R2-1/2 |
| RI-4 | Evidence tables append-only; certified rows immutable; re-ingest over certified id hard-fails | R1-2 |
| RI-5 | Certified QDI pattern evidence docs' canonical exam+subject == pattern label; evidence_count ≥ threshold | R1-3 |
| RI-6 | Exactly one product-visible certified store; trial stores can never satisfy product_inventory() | R3-1 |
| RI-7 | Exam-subject partition: NEET never plans Mathematics; JEE never plans Biology (already locked — keep) | existing tests |
| RI-8 | Every model-stage row records real model ID + prompt sha256 + actor; same-actor audit cannot promote | R2-1/3 |
| RI-9 | No new certification whose stem_norm_hash matches any prior certified row in the target bank | R3-2 |
| RI-10 | Frozen stores open mode=ro outside versioned rebuilds; fix-forward without quarantining affected certified artifacts is prohibited | R1-5, R3-6 |

---

## Traceability appendix — cluster → roadmap

| Audit finding | Status at audit close | Roadmap item(s) |
|---|---|---|
| C0 gates verify self-consistency | P0 CONFIRMED | R1-1 |
| C1 replay bypass | P0 CONFIRMED (unanimous, executed) | R1-2 |
| C2 QDI false provenance + false RCA clearance | P0 CONFIRMED (scope: 2/7 false evidence, 5/7 false identity) | R1-3 |
| C3 unpinned evidence / substrate re-chunk | P0 CONFIRMED (drift framing recorded) | R1-4 |
| C4 independence unenforced | P1 CONFIRMED | R2-1 |
| C5 solution stage skipped | P1 CONFIRMED | R2-2, R0-2 |
| C6 freeze unenforced | P1 CONFIRMED | R1-5 |
| C7 single-disk estate | P1 CONFIRMED (archive same-volume; 3 DBs no backup) | R0-1 |
| C8 bank unowned / stale default | P1 CONFIRMED | R3-1 |
| C9 no ERP promotion path | P1 CONFIRMED | R5-3 |
| C10 placeholder provenance | P1 CONFIRMED | R2-3 |
| C11 no automation layer | P1 CONFIRMED | R4-2 |
| C12 cross-run duplicates | P1 CONFIRMED | R3-2 |
| C13 dangling prerequisites | P1 CONFIRMED (542/1,810 + 95 ambiguous) | R5-1 |
| C14 three namespaces | P1 CONFIRMED | R5-2 |
| C15 bank below exam grade | CONFIRMED, downgraded P2 | R2-5 |
| C16 qualitative uncertifiable (factory lane) | P1 CONFIRMED (narrowed by BS-1/2) | R4-3 |
| BS-1 hidden qie.db lane | blind-spot | R4-1 |
| BS-2 unexamined qualitative substrate | blind-spot | R4-3 |
| BS-3 downstream surfaces unexamined | blind-spot | R4-4 |
| BS-4 QDI evidence-count violation | blind-spot | R1-3 |
| BS-5 build process unaudited / ki_run=0 | blind-spot | R2-3, R4-4 |
| BS-6 no reconciled inventory | blind-spot | R4-1 |
| 64 P2/P3 reviewer findings | pass-through (ids preserved per item above) | R0-4, R2-4/5, R3-*, R5-*, R6-* |

**Refuted findings: NONE** — 17/17 clusters survived adversarial verification.

*This roadmap is the single source of truth for QIE/QDI remediation. Execution order within a phase is
flexible; phase gates are not. R0-2, R4-1, R5-3 implementation, and all of R6 carry OWNER decisions.
No fixes were implemented in the session that produced this document.*
