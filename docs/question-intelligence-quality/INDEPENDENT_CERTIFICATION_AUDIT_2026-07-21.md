# QIE/QDI — Independent Comprehensive Certification Audit

**Date:** 2026-07-21 · **Branch:** `feature/qie-question-planning-layer` · **Method:** 11 independent
specialist review agents (isolated contexts, evidence-first, read-only), findings clustered across
reviewers, every P0 adversarially verified by independent skeptic agents instructed to refute.
**Spend:** ~3.2M subagent tokens · 34 agents · ~1,200 tool calls against live code and databases.

> Process transparency (FINAL — all stages complete): 110 raw findings → 17 distinct P0/P1 defect
> clusters + 64 P2/P3 pass-through. **All 17 clusters were adversarially verified and ALL 17 were
> CONFIRMED** (zero refuted; P0s by two skeptics each, two via live execution of the real modules).
> Skeptics issued severity corrections on 3 clusters (see §14). The blind-spot critic completed and
> found a material board-wide SCOPE gap (§14.3) that narrows two conclusions without changing the
> verdict. 34/34 agents finished; nothing in this audit remains unverified.

---

## 1. Scores

| Dimension | Score /100 | Basis |
|---|---|---|
| Architecture | **76** | Right skeleton, unidirectional layering held under grep; missing production organs, not wrong design |
| Knowledge Foundation | **70** | Fingerprint reproduces bit-for-bit (verified 3× independently); but evidence substrate mutated post-freeze (P0-3) |
| Engineering | **66** | 766 tests green, reproducible, side-effect-free — but proven replay bypass (P0-1), unguarded status writes, no CI |
| AI Design | **68** | Placement fundamentally right; enforcement lags architecture (advisory grounding, same-family judge) |
| Governance | **57** | Certification claims exceed mechanisms; independence and freeze are convention, not code |
| Scalability | **62** | Verification core is fast and portable; execution layer is a human-shepherded laptop lab |
| Product Readiness | **56** | 22 chapter-1 items, NEET Biology unreachable, no promotion path to the ERP, no rendering contract |
| Maintainability | **71** | Exceptional in-code rationale; store sprawl, 4 question-form vocabularies, legacy namespace residue |
| Future-proof (10-year) | **65** | Epistemic spine is durable; identity namespaces, language slot, and promotion seam need design now |

## 2. Certification Verdict

# **CERTIFIED — Continue with moderate redesign**

No reviewer — including the Red Team, which attacked six surfaces with live probes — called for a
rebuild. Every reviewer independently converged on the same shape: **the architecture is the correct
long-term foundation; the certification-enforcement and storage-governance layers must be redesigned
before any further certification runs.** The redesign is enforcement work (blocking gates,
content-addressed evidence, append-only records, freeze verification), not architectural rework.

**Mandatory conditions attached to this verdict:**
1. **Quarantine the 22 production questions and the 7 certified QDI patterns** until re-certified
   under enforced gates (P0-1/2/3 below). They audit clean on manual review, but the guards that
   established them are demonstrably bypassable and the QDI provenance is false.
2. Fix the four P0 mechanisms before the next certification batch.
3. Off-machine backup of the certified estate **immediately** (single 85%-full laptop disk today).

---

## 3. Executive Summary

The board independently verified the system's flagship claims rather than trusting its
certifications — and the results split cleanly in two.

**The foundation layers are real.** The v1.4 freeze fingerprint (`e3a146f3…`, 2,023 certified
concepts) was independently recomputed from live rows by three separate reviewers and matched
bit-for-bit. The full 766-test suite passed twice under the board's own runs with proven store
isolation. The QPL planner is genuinely deterministic under cross-process, hash-seed, and permutation
attack. Exam-subject isolation holds in data, not just in the RCA document. Subject bindings are
honest under direct reading of 45 random certified rows. The honesty culture — curated-vs-certified
provenance classes, honest nulls, `independent=0` disclosed per row, quarantine-not-promote — is
enforced in code and confirmed in data.

**The certification enforcement layer over-claims.** Four P0 defects, all adversarially confirmed:
the deterministic gates verify *self-consistency, not truth* (a physically wrong KE=mv² item passed
the entire battery with sympy "agreeing"); certification records are *mutable and content-unbound*
(a probe promoted never-gated replacement content to `certified` on stale evidence); all 7 certified
QDI patterns carry *false exam/subject provenance* which the RCA falsely cleared; and the evidence
substrate was *re-chunked after the freeze*, leaving dangling and silently-changed references inside
the "permanently frozen" artifact that no invariant detects.

**And it is a lab, not yet a platform.** No model-invocation layer exists (generation round-trips
scratchpad files through interactive sessions; provenance says `generator-agent`); the production
bank is referenced by zero lines of committed code; no promotion path reaches the ERP's Postgres
(whose schema structurally cannot host a platform bank); qualitative certification is architecturally
absent from the factory lane, leaving NEET Biology (90 of 180 questions) unreachable **in that lane**
(the blind-spot critic later found a parallel legacy lane with 98 pilot-verified Biology items and a
qualitative substrate — low quality, unreconciled; see §14.3); and throughput is ~24 human-shepherded
items per day at ~1.5% trial yield.

---

## 4. Confirmed P0 Defects (adversarially verified)

**P0-1 · Deterministic layer verifies self-consistency, not truth.** `sympy` re-solves only the
generator's own declared structure, never the prose stem; `relation_grounded` — the only check that
the declared relation is real curriculum physics/math — is coded ADVISORY (its own comment says
quarantine) and failed on **all 22 certified items**; the dimensional gate auto-passes when units are
omitted (13/22). A wrong-but-consistent item (KE=mv², key 18 J, true answer 9 J) passed the full
battery in a live read-only demo. Real correctness rests entirely on one same-family judge that is
shown the proposed key (`independent=0` on all 22).
*Evidence:* `kie/qie/factory/gates.py:127-137, 423-433`. Reproduced end-to-end by both skeptics.

**P0-2 · Certification replay bypass — proven by execution.** Candidate rows are `INSERT OR REPLACE`
keyed on a truncated deterministic id; gate/sympy/judge evidence is REPLACE-able, keyed by
`candidate_id` alone with no content hash; `certify_run` never checks `gate_result`; `set_status` is
an unguarded UPDATE (the project's own documented money-integrity race pattern). Probe: re-ingesting
a different stem over an existing id, then re-running certify, promoted the never-gated item to
`certified ('gates+sympy+judge')` on stale evidence. Reproduced independently by two skeptics with
the real unmodified modules.
*Evidence:* `kie/qie/factory/corpus.py:62-63, 93-103`, `certify.py:42-67`.

**P0-3 · Certified QDI patterns carry false exam/subject provenance; the RCA falsely cleared them.**
All 7 certified patterns claim JEE_Main Mathematics; none cites a JEE_Main document. Two rest solely
on JEE Advanced 2023 **physics** chunks (electric dipole / Young's modulus / Bohr orbits); five cite
`Practice_Resources` docs the post-RCA query can no longer select. Patterns were mined at 19:35, the
RCA fix landed 20:44, they were never re-derived — and `SOURCE_INDEXING_RCA.md:72` explicitly and
falsely certifies them "unaffected." One physics-evidenced pattern injected a physics solving path
into production-certified set-theory question `QBP_8061e8a12761a23e`.
*Evidence:* `qdi.db` evidence_refs joined to `kie.db` chunk text; verified by direct queries.

**P0-4 · Evidence references are unpinned and the substrate mutated after the freeze.** Evidence is
bare `doc_id#ordinal` with no content hash; certification's only deterministic evidence check is
JSON-non-emptiness. `kie.db` was re-chunked on Jul 18 (docs 179→146 and 356→347 chunks, proven
against the Jul-16 backup) **after** concepts were certified against the old chunks. The permanently
frozen v1.4 now contains 5 certified concepts citing chunks that don't exist, 68 whose text silently
changed, and 17 resting on garbage evidence ("Reprint 2026-27 3answerS", 1-char chunks) — and the
permanent invariant suite detects none of it. (Materiality note: the 22 production items avoid the
affected concepts; the defect is in the freeze *mechanism*, which is the product's central claim.)
*Evidence:* `kie/qie/knowledge/engineer.py:448-464`; live-vs-backup chunk diff; both skeptics reproduced.

## 5. Confirmed P1 Defects

- **P1-A · Independence is unenforced platform-wide.** opus-4.8 audited opus-4.8 for the 2,023-concept
  foundation; the judge's `independent` flag is a caller-supplied boolean (0 on every certified row);
  the 7 QDI patterns were audited by the orchestrating agent itself (`audit_model='orchestrator-review'`).
- **P1-B · The freeze is a convention.** Zero code anywhere recomputes the fingerprint; the
  immutability test checks only a row COUNT; committed code opens frozen DBs read-write
  (`build.py:33`, `reconcile.py:156`); live WAL activity on kie.db and even its backups.
- **P1-C · Model provenance is placeholder strings.** `generator-agent`/`judge-agent` are code
  defaults; `CONTRACT_VERSION` never persisted; token/cost telemetry NULL; `ki_run` has 0 rows across
  the entire v1.0→v1.4 history. Certified artifacts are unattributable and unreproducible.

## 6. Confirmed P1s (verification tail completed 2026-07-21 — ALL confirmed, none refuted)

Each was re-derived from primary sources by a dedicated skeptic agent instructed to refute; every one
survived. Corrections from the skeptics are folded into §14.2:

1. All 22 production items certified with the **mandatory solution stage skipped** (solutions and
   distractor rationales empty; 0 `solution_verified` gate rows; undisclosed in commit/roadmap —
   the trial DB proves the stage works when run: 70/70).
2. **Entire certified estate on one 85%-full laptop disk.** (Verified with one correction: an
   off-repo checksummed archive exists at `~/Documents/Akshara_foundation_backup_v1.4_20260720`, but
   it sits on the SAME physical volume and EXCLUDES examdna.db, qdi.db, and qpl_question_bank.db —
   those three have no backup of any kind.)
3. **The production bank is unowned:** zero committed code references `qpl_question_bank.db`; the
   default corpus path still serves `factory_corpus.db` with 15 retired trial-era 'certified' rows;
   no consumer reads the bank (qp_bridge sources the old compositional lane).
4. **No promotion path to the product**, and `edu_question_bank_items` structurally cannot host a
   platform bank (school-scoped NOT NULL + RLS, difficulty CHECK rejects 'moderate', no 'numerical'
   type, UUID vs `KC_` text ids).
5. **No automated model execution layer** — throughput is interactive-session-bound (~24 items/day;
   8 of 25 trial batches died on session limits).
6. **Deterministic planner + per-run-only dedup** re-issues identical specs across batches and would
   certify near-duplicates invisibly (no cross-run/bank-level UNIQUE or similarity check).
7. **Prerequisites are free-text with 30.2% dangling** (546/1,810 resolve to nothing) — the
   load-bearing structure for adaptive practice does not exist as a graph.
8. **Three disconnected concept-identity namespaces** in live certified use (KC_ ids, qpgen topic
   strings, legacy kie.db codes) — mastery cannot be joined across lanes.
9. **Bank content below exam grade with uncalibrated difficulty** — CONFIRMED but **downgraded to
   P2** on verification: chapters span 1–4 (not chapter-1 only), depths 2–5, 4/22 honestly labelled
   easy; the core holds — 100% single-concept items with self-referential non-PYQ difficulty tagged
   JEE/NEET.
10. **The certifiable domain of the FACTORY lane excludes qualitative items** — Biology unreachable
    in that lane; valid counting/geometry/unit-conversion numerics wrongly quarantined; ~1.5% trial
    yield. (Scope narrowed by §14.3: a legacy lane with Biology items and a qualitative substrate
    exists but is unreconciled and of low sampled quality.)

## 7. Top 10 Strengths (evidence-backed)

1. The v1.4 freeze fingerprint reproduces bit-for-bit from live rows — verified independently by
   three reviewers plus a skeptic.
2. Certification law in code: the judge can reject but never certify alone; sympy-agree is required;
   qualitative items are refused (quarantined), never LLM-certified.
3. Adversarial controls (must-catch + false-positive + magnitude) run before every batch and abort on
   breach — real engineering, not theater.
4. Honest-provenance culture enforced in data: curated vs certified never conflated, honest nulls,
   independence disclosed per row, no fabricated design DNA.
5. Unidirectional layering held under grep across 232 files; frozen stores opened `mode=ro`
   throughout the planning path.
6. 766-test suite green, reproducible, and proven side-effect-free by mtime experiment; test quality
   well above smoke level.
7. Genuine RCA discipline: the exam-isolation fix addressed the architecture (document-granularity
   subject modeling), is real at the production path, and is regression-locked.
8. The QPL planner is byte-deterministic under cross-process, PYTHONHASHSEED, and 200-permutation attack.
9. Negative space is modeled as data: rejected evidence, gaps, and quarantine are permanent queryable
   stores, not silence.
10. The data layer is small, FK-clean, and portable — the Postgres escape hatch is genuinely cheap;
    in-code rationale is good enough for a new senior to own the system in about a month.

## 8. Critical Risks

- **Scaling the bank under current gates ships wrong answers to students.** P0-1 + P0-2 compose: at
  volume, a wrong-but-consistent item WILL eventually pass the same-family judge.
- **Silent foundation corruption.** Freeze unenforced + substrate mutable + count-only invariant =
  the flagship "frozen certified" claim can rot without any test failing (it already has, at 3.6%).
- **Catastrophic single-disk loss** of every certified asset, its provenance, and all backups at once.
- **Certified-label dilution.** Two stores carry `status='certified'` with no authority marker; which
  inventory a product surface serves depends on which file a caller opens.
- **Trust collapse via false clearance.** The RCA's incorrect "patterns unaffected" claim is exactly
  the failure mode that voids certification programs; fix-forward-without-recall must become prohibited.

## 9. Hidden Risks

- **Exam DNA is self-referential:** 227/236 weights derive from the index's own concept density —
  planned papers mirror textbook density, not exam behavior, while the "DNA" name implies measurement.
- **Every certified item ships depth/archetype metadata its own deterministic checks refuted**
  (0/24 agreement, advisory) — downstream analytics will trust poisoned labels.
- **The prior red team's confirmed qpgen defect is still live:** the assertion-reason key remains
  hard-coded to option (a) in the frozen engine that qp_bridge still assembles papers from.
- **Safety suites skip silently off-machine:** `skipUnless(DB exists)` means CI or another laptop
  reports OK with the most safety-critical assertions vacuous; no CI runs this lane at all.
- **A stale, divergent copy of the qdi_* subsystem sits inside the frozen index artifact** (12
  'proposed' rows), and `run_planner.plan()` still reads pattern tables from the index path.
- **Missing stores degrade to empty results** ("honest null") in the planner — a mispathed qdi.db
  silently plans without design DNA rather than failing.
- **OCR boilerplate contaminates 54% of certified evidence text** — tolerable for humans, corrosive
  as generation substrate at scale.

## 10. Recommended Improvements (ordered)

**Phase A — before the next certification run (closes the P0s):**
1. Make `relation_grounded` blocking (certify/quarantine, never advisory); un-checkable dimensional
   analysis must quarantine, not pass.
2. Content-hash binding end-to-end: evidence rows carry and verify `item_hash`; `certify_run` refuses
   evidence whose hash ≠ the candidate's current content or that predates ingestion; assert the gate
   battery actually ran.
3. Append-only evidence: eliminate `INSERT OR REPLACE` on candidate/gate/judge/independent rows;
   status transitions guarded with `AND status='<expected>'` + throw-on-0-rows (the project's own
   standing race-pattern rule).
4. Content-address the knowledge substrate: evidence refs = `doc_id#ordinal` + chunk sha256; record
   kie.db's content fingerprint at freeze time; certification refuses to run against a drifted substrate.
   Re-audit the 17 garbage-evidenced and 73 dangling/changed-evidence concepts.
5. Permanent test that **recomputes** the freeze fingerprint (not the row count) — plus re-derive or
   relabel the 7 QDI patterns under the fixed exam-identity rule, and correct the RCA document.
6. Off-machine backup (rsync/restic to any remote) of `curriculum/knowledge/kie/` — tonight-level urgency.

**Phase B — before scaling generation:**
7. A real model-invocation layer: API integration, retries, queue, per-row model ID + prompt hash +
   token/cost telemetry; kill the scratchpad round-trip.
8. Enforced independence: cross-family (or human) judge for certification; seeded known-bad control
   items per judge worksheet; same-actor audit structurally rejected at ingest.
9. Mandatory solution stage before `certified`; complete it for the existing 22.
10. One authoritative bank: committed writer + consumer, role stamp in `factory_meta`, retired stores'
    'certified' rows marked superseded; bank-level cross-run dedup (UNIQUE on stem_norm_hash + similarity).
11. CI running the 766-test suite with the DBs present (fail loudly when absent, not skip).

**Phase C — before product integration:**
12. Promotion contract to the ERP: platform-scoped bank table, `KC_`↔UUID vocabulary mapping,
    difficulty enum alignment, LaTeX/rendering contract.
13. Exam DNA v2 measured from the owned PYQ corpus; PYQ-calibrated difficulty; reactivate the
    psychometric calibration spec before pilot telemetry starts flowing.
14. Prerequisite edge table (FK-resolved), concept-namespace convergence on the KC_ spine, and the
    qualitative-evidence certification lane design (NEET Biology is half of NEET).

## 11. Things that must NEVER change

- Certification requires non-model re-derivation; the judge may reject but never certify alone.
- Freeze-as-versioning: knowledge changes are new versions, never mutations.
- Honest-null / provenance-class discipline: estimates are never dressed as measurements.
- Adversarial controls run before every batch and a control breach aborts the run.
- Quarantine as a first-class lifecycle state; refusal is a respected outcome.
- "Wrong knowledge is worse than missing knowledge — never weaken a gate for yield."
- Planner determinism: same frozen inputs → byte-identical blueprints.
- Rejected evidence is preserved, never discarded.

## 12. Things that SHOULD be redesigned

- Evidence referencing (content-addressed, hash-verified) — P0-4.
- Certification record lifecycle (append-only, hash-bound, guarded transitions) — P0-2.
- Gate severity model (grounding blocking; dimensional honesty) — P0-1.
- QDI pattern provenance + re-derivation under the fixed exam-identity rule — P0-3.
- Store authority model (one bank, role stamps, backups out of the live directory).
- Independence enforcement (cross-family judging, structural rejection of self-audit).
- Exam DNA (v2 from PYQ measurement, drop the self-referential proxy).
- Concept identity (single KC_ spine; prerequisite edges as FKs).
- Physical home (out of `curriculum/scripts/`) and the ERP promotion seam — with the owner's Tier-1
  hygiene unlock, per the standing freeze on relocations.

## 13. Permanent Invariants → regression tests (consolidated from all 11 reviewers)

1. Recomputed content fingerprint over certified `ki_concept` rows == `ki_meta` value (not count).
2. Every certified evidence ref resolves to a live chunk whose sha256 matches the recorded hash.
3. No `certified` row without: zero fatal gates + `independent_answer='agree'` + judge accept with
   `independent=1` + `solution_verified=1` — enforced at certify time, per candidate content hash.
4. `gate_result`/`independent_answer`/`judge_verdict` are append-only; a certified row is immutable;
   re-ingest over a certified id hard-fails.
5. Certified QDI pattern evidence docs' canonical exam == the pattern's exam label.
6. Exactly one product-visible certified store; trial stores can never satisfy `product_inventory()`.
7. Exam-subject partition: NEET never plans Mathematics; JEE never plans Biology (already locked —
   keep).
8. Every model-stage row records real model ID + prompt sha256; same-actor audit cannot promote.
9. Bank-level dedup: no new certification whose stem_norm_hash matches any prior certified row.
10. Frozen stores open `mode=ro` everywhere outside a versioned rebuild; a fix-forward without
    quarantining affected certified artifacts is prohibited.

---

## 14. FINAL COMPLETION ADDENDUM (2026-07-21) — verification tail + blind-spot critic

### 14.1 Final verification ledger — 17/17 clusters CONFIRMED, 0 refuted

| # | Defect | Final status | Skeptic severity |
|---|---|---|---|
| 0 | Gates verify self-consistency, not truth | CONFIRMED | P0 + P1 (split — see 14.2a) |
| 1 | Certification replay bypass (executable) | CONFIRMED | **P0 + P0 (unanimous)** |
| 2 | QDI patterns false exam/subject provenance; RCA falsely cleared | CONFIRMED | P0 + P1 (scope narrowed — 14.2b) |
| 3 | Evidence refs unpinned; substrate re-chunked post-freeze | CONFIRMED | P0 + P1 (framing split — 14.2c) |
| 4 | Independence unenforced platform-wide | CONFIRMED | P1 |
| 5 | Solution stage skipped on all 22 certified items | CONFIRMED | P1 |
| 6 | Freeze unenforced (no fingerprint recompute anywhere) | CONFIRMED | P1 |
| 7 | Single-disk certified estate | CONFIRMED | P1 (correction — 14.2d) |
| 8 | Production bank unowned; default path serves stale trial rows | CONFIRMED | P1 |
| 9 | No ERP promotion path; schema structurally incompatible | CONFIRMED | P1 |
| 10 | Model provenance = placeholder strings | CONFIRMED | P1 |
| 11 | No automated model execution layer | CONFIRMED | P1 |
| 12 | Cross-run duplicate certification path | CONFIRMED | P1 |
| 13 | Prerequisites ~30% dangling (measured 542/1,810 + 95 ambiguous) | CONFIRMED | P1 |
| 14 | Three disconnected concept namespaces | CONFIRMED | P1 |
| 15 | Bank content below exam grade, self-referential difficulty | CONFIRMED | **downgraded P2** (14.2e) |
| 16 | Qualitative/non-structured items uncertifiable in the factory lane | CONFIRMED | P1 (claim narrowed — 14.3) |

### 14.2 Severity corrections issued by the skeptics (accepted by the chair)

- **(a) Cluster 0:** one skeptic re-ran the KE=mv² demo and confirmed everything, but argues P1: no
  *actually wrong* item has been certified yet; the defect is a latent single point of failure (the
  correlated, key-anchored judge is the only truth check). **Chair ruling: remains P0** — for a
  *certification* engine, "the only truth check is one same-family LLM shown the proposed key" is the
  definition of a certification-integrity defect; shipping luck is mitigation, not severity.
- **(b) Cluster 2 narrowed:** 2 of 7 certified patterns rest on JEE-Advanced *physics* chunks
  (false evidence); the other 5 cite `Practice_Resources` docs that ARE JEE Main mathematics papers
  by content — their defect is false canonical exam identity + post-fix irreproducibility, not wrong
  content. The blind-spot critic added a NEW violation the board missed: **2 of the 7 certified
  patterns have `evidence_count=1`, violating QDI's own ≥5-DNA-from-≥2-resources rule**
  (`mine.py:10`). The false RCA clearance stands as written. **Chair ruling: P0 for the 2
  physics-evidenced patterns + the false RCA clearance; P1 for the 5 mislabeled ones.**
- **(c) Cluster 3 framing:** the materiality skeptic verified all data (5 dangling / 68 sha-changed /
  ~21 short refs) but showed the refs were valid, substantive, and independently audited **at
  certification time** — so this is post-hoc provenance drift, not certification of unbacked
  knowledge. **Chair ruling: remains P0 against the FREEZE claim** (a "permanently frozen" artifact
  whose evidence chain no longer resolves is broken as an artifact), with the mitigation recorded.
  The evidence-skeptic also found a bonus defect: dangling refs make the QDI anti-copy floor
  **silently skip** (empty source ⇒ check skipped).
- **(d) Cluster 7 correction:** an off-repo checksummed archive DOES exist
  (`~/Documents/Akshara_foundation_backup_v1.4_20260720`) — but on the **same physical volume**, and
  it **excludes examdna.db, qdi.db, and qpl_question_bank.db entirely** (those three have no backup
  copy of any kind). The single-disk risk stands.
- **(e) Cluster 15 downgraded to P2:** core holds (100% single-concept Class-11 items, non-PYQ
  self-referential difficulty, NCERT-example-level stems tagged JEE/NEET), but the skeptic corrected
  the details: chapters span 1–4 (not chapter-1 only), depths 2–5 (not single-step), and 4/22 items
  are honestly labelled easy.

### 14.3 Blind-spot critic — the board's shared scope gap (material)

The critic independently re-verified spot-checks of the confirmed defects (all held) and adjudicated
the reviewer contradictions (P0s exist — the Principal Architect's "no P0" was wrong; "sympy agreed
24/24" is self-consistency, not truth; the 22-item "complete evidence chain" claim is wrong — the
solution stage is absent; the fingerprint proves concept-row identity, never evidence resolution).
Its central finding:

**All 11 reviewers ran the same opening ritual (reproduce the fingerprint, run the 766 tests) and it
routed every one of them into the factory lane + frozen index — and none into `qie.db`.** Consequences:

1. **An entire parallel question-intelligence lane was invisible to the whole board:** `qie.db`
   holds **1,496 pilot-verified items** (Math/JEE 715, Physics 291+167, Chem/NEET 110, **Biology/NEET
   98**), `question_dna` 2,996 across 6 lanes, and a **1,845-assertion KVS qualitative substrate**
   plus governed_fact=152 / governed_relation=49 with a Tier-2 verifier/refuter battery.
2. Therefore two board conclusions are **narrowed**: "NEET Biology architecturally unreachable" and
   "single-lane lab, 22 items total" are true **of the current factory lane only**, not of the
   system. (The critic sampled the Biology items: low quality — templated stems, weak distractors —
   so the practical conclusion barely moves, but the system model was wrong.)
3. **Un-asked regression question:** the retired qie.db lane had a *broader* verifier battery
   (symbolic_inverse, independent_second_method, per-step + independent e2e, two-way + KB-lookup
   refutation — 7 methods) than the new factory lane (sympy-of-own-relation + one same-family
   judge). No reviewer compared them. Porting that battery forward is an obvious Phase-B win.
4. **Five charter surfaces got zero evidence-based examination** (weakness intelligence, daily
   practice, adaptive practice, AI tutor, analytics readiness) — grep confirms no lane code exists
   for any of them; that absence is itself the finding, but it was asserted, not evidenced.
5. **The KIE build PROCESS (phase1–7, OCR/parse/chunk) was never audited** — only its outputs; and
   `ki_run` (the build ledger of the certified index) contains **0 rows**.
6. **No reconciled certified inventory exists:** at least three divergent "accepted" stores
   (qpl_question_bank 22 · factory_corpus 15+456 open · qie.db 1,496 pilot-verified) and no reviewer
   — or code — identifies the authoritative one.

Critic's overall judgment: *"Trustworthy on what it examined; incomplete on scope … adopt the
confirmed defects (they are verified), but treat the board's system model as under-scoped."*

### 14.4 Effect on scores and verdict

**The verdict is unchanged: CERTIFIED — Continue with moderate redesign**, same conditions. The
severity corrections trade roughly evenly (cluster 15 down; new QDI threshold violation and
anti-copy-skip defect up), and the blind-spot finding cuts both ways: the system has MORE assets
than the board modeled (a qualitative substrate and 1,496 pilot-verified items exist) and MORE
unreconciled governance surface (three divergent inventories, an unaudited legacy lane). Two scores
carry explicit caveats: Product Readiness (56) and Scalability (62) were scored against the factory
lane; a lane-reconciliation decision (adopt, mine, or formally retire qie.db and port its verifier
battery) is added to Phase B of §10 as a named workstream, and the deferred second pass (qie.db
lane, KIE build process, downstream surfaces) is recommended before any "this is the whole system"
claim is made again.

---

*Prepared by an independent multi-agent review board: 11 specialist reviewers, cross-reviewer
clustering, adversarial verification of all 17 P0/P1 clusters (17/17 confirmed, 0 refuted; P0s
double-verified, two by execution), and a blind-spot/cross-examination critic. 34 agents, ~3.7M
subagent tokens. This document supersedes no owner decision; quarantine, lane reconciliation, and
remediation sequencing are owner calls.*
