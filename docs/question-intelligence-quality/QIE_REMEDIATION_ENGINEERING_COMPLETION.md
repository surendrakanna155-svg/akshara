# QIE/QDI Remediation — Engineering Completion Checkpoint

**Date:** 2026-07-22 · **Branch:** `feature/qie-question-planning-layer` (local, not pushed) ·
**Suite:** 1109 tests, OK (skipped=1) · **Status:** 🏁 **ENGINEERING COMPLETE for all cleanly-buildable scope.**

This document records the engineering-completion boundary of the QIE/QDI remediation program (source audit
`INDEPENDENT_CERTIFICATION_AUDIT_2026-07-21.md`, permanently closed). It is written to the project's
**Honest-Null principle**: where something is not complete, the reason is stated explicitly. It does not
re-audit completed work — the per-item evidence lives in
[`QIE_REMEDIATION_EXECUTION_LOG.md`](QIE_REMEDIATION_EXECUTION_LOG.md) and
[`QIE_REMEDIATION_CERTIFICATION_HISTORY.md`](QIE_REMEDIATION_CERTIFICATION_HISTORY.md).

---

## 1. Roadmap completeness verification (Phase 1)

Every roadmap item + every audit defect cluster has a disposition. Nothing buildable is unaddressed.

| Phase | Items | Disposition |
|---|---|---|
| **R0** immediate safeguards | R0-1, R0-2, R0-3, R0-4 | R0-2/R0-3/R0-4 ✅ done; R0-1 tooling ✅ built + restore-verified, off-machine target **owner-deferred** |
| **R1** certification integrity (4 P0s + freeze) | R1-1…R1-5 | ✅ ALL — index promoted **v1.4 → v1.5** |
| **R2** trust, independence, provenance | R2-1…R2-5 | ✅ ALL — stores **factory-4**; RI-3 + RI-8 complete |
| **R3** store governance & hygiene | R3-1…R3-8 | ✅ ALL — stores **factory-5**; RI-6 + RI-9 hold. R3-4 FTS5/chunks-index deferred to a **freeze-hatch** rebuild |
| **R4** reconciliation, automation, yield | R4-1, R4-2, R4-3, R4-4 | ✅ ALL implemented. R4-2 live generation tail = **external key** |
| **R5** knowledge graph & product | R5-1, R5-2, R5-3, R5-4, R5-5, R5-6 | R5-1/R5-2/R5-6 ✅; R5-3 **design ✅ / impl owner-gated**; R5-5 fragment ✅ / remainder pilot-gated; **R5-4 not cleanly buildable** (§5) |
| **R6** architecture & owner hygiene | R6-1…R6-4 | ⛔ **ALL owner-gated** — Tier-1 freeze applies |
| **RI** permanent invariants | RI-1…RI-10 | ✅ ALL covered (RI-7 exam-subject partition pre-existing, verified: NEET⊄Math, JEE⊄Biology) |

**Defect-cluster traceability (17 clusters + 6 blind spots, 0 refuted at audit close):** C0–C6, C8, C10–C16,
BS-1…BS-6 → all remediated. C7 → R0-1 (owner-deferred). C9 → R5-3 (design done / impl owner-gated).

---

## 2. Engineering Complete ✅ (implemented + independently verified, this program)

Landed this session on `feature/qie-question-planning-layer` (9 commits, `f665bb5d`…`d29dd6c9`):

| Item | Commit | Adversarial verifier |
|---|---|---|
| RI-6 re-point — qp_bridge boundary → unified manifest | `f665bb5d` | **CONFIRMED** (fixed finding #4: count-only freshness) |
| R4-3 — qualitative certification lane + dimensional-gate yield recovery | `f6db181e` | **REFUTED ×2 → fixed + locked** |
| R4-4 — deferred audit passes (BS-3/5/6) | `6d4749c9` | tests |
| R5-1 — prerequisite edge table | `bcaac614` | **CONFIRMED** |
| R5-2 — KC_ namespace convergence | `3e2d8484` | **REFUTED → fixed + locked** |
| R5-3 — ERP promotion contract (design) | `26339cbb` | design-only |
| R5-6 — evidence-substrate cleaning | `cd44ec1e` | **REFUTED → fixed + locked** |
| R5-5 fragment — cross-class revisits edges + retire dead ki_mention | `5c8b0f3c` | tests |
| Sweep-complete owner boundary record | `d29dd6c9` | docs |

**Previously landed (owner-approved, prior to this session):** R0–R3, R4-1 (adopt qie.db as evidence), R4-2
(provider-agnostic execution layer), R0-2 recall.

## 3. Implemented owner decisions ✅

- **R4-1** — adopt qie.db as an **evidence source** (not retire): 7-method verifier battery + `unified_inventory.db`.
- **R4-2** — build the provider-agnostic model-execution layer (`kie/qie/execution/`).
- **R0-2** — execute the recall (22 factory questions + 7 QDI patterns `certified → quarantined`).
- **RI-6 re-point** — owner-approved closure of the `promote.ri6_followon()` flag.

## 4. Deferred owner decisions ⛔ (require an owner choice before work can proceed)

- **R5-3 implementation** — platform bank table + RLS, exporter, KC_↔UUID map, `numerical` CHECK extension,
  LaTeX authoring contract. Sequenced by the **ERP lane** (migration numbering). Design is done.
- **R6 (all)** — the owner must **unfreeze Tier-1** before R6-1 (engine relocation), R6-2 (one canonical
  question vocabulary), R6-3 (truthful qpgen seam), R6-4 (namespace hygiene).
- **R0-1 off-machine backup** — owner-deferred; needs an off-machine `AKSHARA_BACKUP_DEST` + passphrase.

## 5. External dependencies ⛔ (blocked on something outside this engine)

- **R4-2 live re-certification** — a live `OPENAI_API_KEY`. The provider-agnostic layer is built and proven
  against Fake/Replay providers; re-certifying the recalled/held artifacts (22 + 15 + 14 + 7) and R4-3's
  held-128 qualitative facts needs a real provider.
- **R5-5 calibration / response spine** — the ERP response spine (`edu_student_item_responses`, mig 20260853) is
  seeded at **first pilot use** and cannot be backfilled; PYQ calibration needs measured pilot signal.

## 6. Remaining integration work (buildable *later*, but not a clean derived pass now)

- **R5-4 — Exam DNA v2 (measured weights): NOT cleanly buildable — needs a re-mining sub-project.** The PYQ
  corpus **is owned** (226 `previous_paper` + 704 `dpp` + 9 `mock_test` in `source_documents`), and there are
  4853 mined `question_patterns`. But their attribution is **degenerate**: `exam='foundation'` on all 4853,
  `subject=NULL` on all, and the `concept_code` subject prefixes are **mislabelled** (`BIO_MOTION`,
  `CHE_NUMBERS`, `BIO_POWER`). Measured per-exam/per-subject weights cannot be computed honestly from this —
  building on it would either propagate mislabels or be mostly honest-null, violating the standing law
  ("wrong knowledge is worse than missing knowledge"). It requires a focused **re-attribution/re-mining pass**
  (link each PYQ question to its `source_documents` exam/subject) with its own decisions → this is Program B.
- **R3-4 FTS5 + `chunks(doc_id,ordinal)` index** — a **freeze-hatch** kie.db rebuild under
  `KIE_ALLOW_FROZEN_WRITE` at the next version boundary (mutates frozen v1.5 substrate).

## 7. Production blockers 🚫 (nothing from this program may ship to product yet)

- **Product bank is empty by construction.** `qpl_question_bank` holds **0 product-certified rows** (post-R0-2
  recall); `promote.assess()` reports **promotable-to-product-bank = 0**. No QIE-generated question reaches a
  student until it clears the full R2 chain (solution stage + distractor verification + cross-family judge +
  RI-8 provenance) — which needs the **R4-2 live key** (§5).
- **R5-3 not implemented** — there is no exporter and no platform-scoped ERP bank; the promotion path is
  design-only.
- These are **honest, intended** blockers: the remediation restored the *gates*; it did not (and must not)
  manufacture certified content without the independent evidence the gates require.

## 8. Known honest limitations (stated, not hidden)

- **R4-3 qualitative yield = 0 certifiable / 128 held.** The machinery is correct; the owned substrate has **no
  genuinely-independent** non-model corroboration (the governed-fact and KVS lanes read the same corpus answer
  keys). Lifting this needs acquired independent evidence (Program B) or a cross-family judge (Program C).
- **R5-1 prerequisite resolution = 65.5%** (1183/1805); 552 unresolved + 70 ambiguous are **honest-null**, never
  guessed. Full resolution needs richer alias data or R5-4's measured graph.
- **R5-2 governed-fact→KC_ topic resolution = ~14%** (4 topic + 14 chapter of 128); the rest honest-null pending
  R5-4/finer alias coverage.
- **R5-6** flags 19 dense-numeric chunks as an *advisory* (may include legitimate dense-math answer keys, not
  only OCR garble) — a conservative, non-deleting signal.

---

## 9. Next independent workstreams (Phase 4 — NOT implemented; prepared for owner sequencing)

Each is a **separate** program; none is started. Scope estimates are engineering + verification effort, not
calendar.

### Program A — ERP Promotion Contract (R5-3 implementation)
- **Objective:** stand up the platform-scoped certified question bank in the ERP and the exporter from
  `qpl_question_bank`, so a certified item can reach a school.
- **Dependencies:** the R5-3 design (done); R5-2 `concept_namespace` (done, seeds the KC_↔UUID map); a
  non-empty product bank (blocked on Program C).
- **Owner decisions required:** approve the platform bank table + RLS model (read-all / platform-write);
  approve the ERP migration + its numbering in the ERP band; approve the LaTeX authoring contract (D6) *before*
  any bank-growth program.
- **Estimated implementation scope:** medium — 1 platform bank migration + RLS, `edu_concept_vocabulary`
  migration + seed, `numerical` CHECK extension, an exporter (bank → platform bank + versioned manifest),
  `stem_format`/dual-stem columns. Cross-lane (ERP engineering owns the migrations).
- **Estimated verification scope:** high — live RLS/tenant-isolation tests, idempotent-re-export + recall
  propagation, freeze-fingerprint pinning, KC_↔UUID round-trip, adversarial "school reads platform items it
  must not write."

### Program B — PYQ Re-attribution / Re-mining (unblocks R5-4, R5-5, and lifts R4-3/R5-1/R5-2)
- **Objective:** re-mine the owned PYQ corpus with **correct exam/subject/concept attribution** so exam-DNA v2
  can be *measured* (not self-referential), and independent cross-source corroboration becomes available.
- **Dependencies:** the owned `source_documents` (exam/subject/category present) + the parsers; the frozen index
  (read-only) for concept crosswalk (R5-2).
- **Owner decisions required:** the attribution method (how to classify difficulty; how to handle the 861
  uncategorised `Cursor_Downloads` + 126 `unknown` doc_type); whether measured DNA supersedes or versions the
  current examdna (freeze-as-versioning implies a v2, not a mutate).
- **Estimated implementation scope:** large — a re-attribution pass linking each mined question/pattern to its
  source doc's exam/subject, then a measured `exam_dna_v2` derived layer (per-exam/subject/concept/difficulty
  distributions + marking schemes + provenance_class). Derived on the mode=ro frozen index.
- **Estimated verification scope:** high — honest-null on unattributable questions, no-guess on ambiguous
  subject, measured-vs-opinion delta report, adversarial "does a mislabelled prefix leak into a weight."

### Program C — Live OpenAI Re-certification (activates R4-2 + re-certifies the held estate)
- **Objective:** run real generation/judging through the built execution layer to (a) supply the cross-family
  judge + solution/distractor stages, and (b) re-certify the recalled/held artifacts (22 + 15 + 14 + 7) and
  R4-3's 128 held qualitative facts.
- **Dependencies:** a live `OPENAI_API_KEY`; the R4-2 execution layer (done); the R2/R3 certify gates (done).
- **Owner decisions required:** provision + budget the key; approve the cost/throughput envelope; approve
  which held cohort to re-run first.
- **Estimated implementation scope:** small–medium — wire the key + PRICE_TABLE, run bounded batches; no new
  gate logic (the certify chain is already built and fail-closed).
- **Estimated verification scope:** high — provenance quintet (RI-8) on every certified row, cross-family
  independence actually holds live, telemetry/cost accounting, replay determinism, no self-confirmation.

### Program D — Tier-1 Unfreeze (R6 architecture hygiene)
- **Objective:** relocate the engine out of `curriculum/scripts/` (R6-1), converge on one canonical
  question-design vocabulary (R6-2), make the qpgen seam truthful (R6-3), namespace/naming hygiene (R6-4).
- **Dependencies:** none technical — gated purely on the **owner unfreezing Tier-1**.
- **Owner decisions required:** the unfreeze itself; the target package layout + data-dir naming; whether QDI is
  declared the canonical vocabulary.
- **Estimated implementation scope:** medium–large — a package move (config-driven paths), registry
  consolidation, `sanitize` extraction into a shared lib; mechanical but touches many imports.
- **Estimated verification scope:** medium — import-integrity + no-behaviour-change tests, the frozen stores
  stay untouched, the truthful-seam claim is asserted.

---

## 10. Standing-law compliance (held across the whole program)

Deterministic checks certify (model agreement may reject, never certify) · honest-null / never-guess ·
freeze-as-versioning (frozen index + kie.db never mutated — MD5 byte-identical) · no gate weakened for yield ·
quarantine/held is a first-class state · RI-6 (one product-visible bank) preserved end-to-end.

**Engineering-complete checkpoint reached. Awaiting the next owner decision (Program A/B/C/D).**
