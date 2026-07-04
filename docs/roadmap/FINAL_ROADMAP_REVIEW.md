# Akshara ERP — FINAL INDEPENDENT ROADMAP REVIEW

**Status:** ✅ Review complete · **Reviewer:** Fable (independent planning review) · **Date:** 2026-07-04
**Scope:** the entire frozen planning system — `docs/roadmap/` · `docs/audits/` · `docs/design/` (incl. `adaptive-ai/`) · `docs/strategy/` · `docs/execution/` — reviewed as a system, Phase 0 → Phase 8. Planning only; no code, no live verification.
**Method:** full read of the roadmap system, all 12 audit reports + findings ledger, all 5 strategy docs, the adaptive-AI suite 00–09, the UX planning set, and the execution journal; mechanical finding-ID traceability check (93 IDs across 11 families); three independent verification passes (superseded-roadmap diff · orphan-recommendation sweep · design-doc consistency sweep); referenced-artifact existence check (backlog, Constitution, EOS skill, harnesses, targets — all present).
**Result:** the plan is sound. **Nine defects were found and all nine were fixed in place during this review** (§4). No parallel roadmap was created; every task ID is preserved.

---

## 1. Executive Verdict

The planning system is **genuinely execution-ready**. It has the four properties an autonomous executor needs and that most planning corpora lack:

1. **One roadmap, really.** `FINAL_EXECUTION_MASTER_ROADMAP.md` is the only forward plan; all three prior roadmaps carry verified redirect banners; the finalization pass merged duplicates to single authoritative tasks. (The one true competing system this review found — the stale Future Vision index/audit pair with its own archived roadmap chain and non-EOS gates — has now been bannered as superseded-for-execution.)
2. **Bidirectional traceability that survives a mechanical audit.** All 93 finding IDs (ENG 10 · DB 10 · SEC 11 · QA 8 · REL 9 · AI 6 · MOD 6 · UX 6 · OPS 8 · DOC 8 · LV 11) appear in the ledger; every ledger row maps to exactly one roadmap task or an explicit Already-Fixed / Owner / Future / Out-of-scope disposition; every roadmap task cites its findings. An independent orphan sweep over the audit prose found only one truly homeless action item (now homed — §4.3).
3. **A deterministic execution protocol.** The wave loop (plan → implement → validate → regression → document → `/eos` → gate → roadmap flip → journal → commit-only-on-PASS) plus the `NEXT_ACTIVE_WAVE.md` single-entry-point plus the journal/dashboard reconciliation invariant make drift detectable by inspection.
4. **Correct macro-ordering.** P0 truth/safety gates everything; build phases (P1/P2/P3) precede the Red Team so it attacks honest claims and a finished product; Red Team → fixes → Pilot → Production Cert → GA are strictly sequential. This matches the owner's frozen ordering and the audit's own "re-scope before Red Team" recommendation.

The defects found were real but narrow: one missing task (the staff Face ID Must-Before-GA track), one missing dependency edge (Pilot ← P3-AI-1), a normative wave table stranded inside a superseded document, a stale competing planning pair, stale pointers, six wave-tag contradictions in the AI design suite, and small numeric drift. All are fixed. Nothing required re-sequencing, new phases, or a redesign.

## 2. Planning Strengths

- **Evidence-grade discipline as a first-class concept.** The LIVE / LOCAL-LOGIC / CONTRACT / RENDER-MOCK / STAGED taxonomy runs from P0-DOC-4 through the Production Certification gates ("a Critical gate below LIVE is not passed"). This directly repairs the project's historical failure mode (Theme A: claims one grade above evidence).
- **The already-done baseline is protected.** Ledger §A + journal §3 enumerate what the audit live-verified (RLS isolation, `erp_tenant`, entitlement ON, backups+restore drill, watchdog, rotated password) and mark it "must not be restarted" — with the subtle and correct distinction that *regression-guarding* those facts (P0-TEST-2, P0-INFRA-6) remains scheduled work.
- **Cross-phase dependencies are explicit, not tribal.** Doc 09 §0's preconditions (XCT-1/2, HWK-1, FIN-6, TRN-2, MOD-1 👤, COM-1, Principal-hub, live AI key) were lifted into the roadmap's P3 section and the Autonomous Plan, so specific P1/P2 items are sequenced before the AI sub-waves that consume them.
- **Adaptive AI integrates without duplicating anything.** One design suite (docs 00–09) with one wave contract (doc 09); W1 = the audit's cost/safety findings (AI-1…5), W2 = the adaptive vision (owner-timed 👤, honoring the "DO NOT build yet" freeze), W3 → post-GA register. AI attack scenarios fold into Red-Team Domain 4; AI metrics fold into Gate A; the pilot checks AI cost controls — **no second Red Team, no second Pilot, no second certification.**
- **Owner sovereignty is engineered in.** Every 👤 decision gates only its own task, is batched (never pauses the pipeline per-item), and frozen decisions (O1–O10, identity, attendance-auth, English-first, maker-checker, backlog rev 5) are restated at every layer — the design docs even self-police ("this suite re-scopes nothing").
- **The strategy layer knows its place.** All five strategy docs and the four UX planning docs explicitly declare themselves blueprints, not plans, and defer to the single roadmap and the EOS-only gate.
- **No circular dependencies.** The dependency graph is a clean DAG: P0 → (P1 ∥ P2 ∥ P3-W1) → P3-W2 → P4 → P5 → P6 → P7 → P8, with the only cross-links (P1-CODE-1→P2-UX-2, P1-PROD-0→P3-W1.4, P2-hub→W2.4, P3-AI-1→P6) all pointing forward.

## 3. Planning Weaknesses (found by this review; all repaired — see §4)

1. **A GA blocker had no task.** The staff-attendance Face ID track (GA-1 geofence+anti-mock+live-camera-face re-implementation per the frozen attendance-auth decision, GA-2 manual flows, GA-3 principal summary) is a Must-Before-GA blocker and is exercised by Pilot Stage 12 — but its old homes (Track-B B4, wave C3's dependency) lived only in superseded documents, and no final-roadmap task named it. The pilot would have failed Stage 12 with no upstream task to build the thing it tests.
2. **The P1-PROD wave decomposition was stranded.** P1-PROD-1..21 pointed at "per-wave completion criteria in the backlog," but the backlog is organized by module; the actual C0–C21 wave table (composition, dependencies, completion criteria) lives in `FINAL_QA_ROADMAP.md` §Phase C — a section whose banner said "superseded, retained for history." An obedient executor could have skipped the very table it needed.
3. **A missing dependency edge.** P6-PILOT-1's done-when requires "AI cost controls," but its dependency list (Phase 0 + Phase 1 + Phase 5) omitted P3-AI-1.
4. **One genuinely competing planning system.** `FUTURE_VISION_MASTER_INDEX.md` + `FUTURE_VISION_PRESERVATION_AUDIT.md` still presented as an active governing chain — their SSOT pointing at *archived* roadmaps (`AKSHARA_FINAL_ROADMAP.md` et al.), their own M1–M13 milestones, non-EOS "Agent G release gates," and %-complete tracking of surfaces the roadmap classes as Future/out-of-scope.
5. **Wave-tag contradictions inside the AI suite.** Six `Pri` tags in design docs 05/06 contradicted the doc-09 wave contract: two module surfaces and the AI-6 rename tagged **W1** (W1 is plumbing-only; naming is W2.9), and four P1 preconditions (HWK-1, FIN-6, TRN-2, MOD-1 👤) tagged as if they were AI-wave work.
6. **Stale pointers at strategy entry points.** `STRATEGIC_MASTER_INDEX.md` (twice) and `ADAPTIVE_AI_MASTER_BLUEPRINT.md` still named the superseded `docs/audits/MASTER_EXECUTION_ROADMAP.md` as the execution plan; `PROJECT_CONTEXT.md` (the session entry-point) still routed readers to the QA program with no mention of the final roadmap.
7. **Small factual drift.** Pilot stage-count stated three ways ("16 stages" / stages 0–16 / "~22 stage types"); the FABLE_FINAL_ROADMAP banner omitted W5 from its mapping; journal progress counts were off (P0 has 19 tasks, not 18; P3 has 15 sub-waves, not 11); two SEC cross-tags (SEC-6/SEC-11) and the DB-10 tag were dropped/garbled in P1-CODE-3/-4's finding columns.
8. **One orphaned audit recommendation.** Audit 03 §5's "apply Google-Cloud API-key app restrictions to the committed Firebase Android key" carried no finding ID and appeared in no task. (Other suspected orphans checked out as covered: the desktop-clerk gap → C-ISS-11 → P2-UX-2 + 👤 candidates; per-module live-verify → P1-TEST-1 + pilot stages 9/10/15; N+1 conversion → P1-TEST-2's description; per-school AI config → W1 `platform_provider_configs` extension; the UX-drift trio → B5/C-OPP-6 👤 candidates.)
9. **Owner-decision register was missing the UX candidate batch.** The Product Excellence Master Plan §6 mints six owner decisions (B5 premium wave, Approvals-Inbox read-model, exam-workspace slice, C-candidates, PAR-D4, Student/HR AI) that the roadmap's 👤 register didn't list — risking a stalled P2 sub-item with no surfaced decision.

## 4. Required Changes — **all applied during this review**

| # | Change | File(s) edited | Status |
|---|---|---|---|
| 1 | **New task `P1-PROD-22`** — staff-attendance (Face ID) Must-Before-GA track: GA-1 re-implementation per `ATTENDANCE_AUTH_DESIGN_DECISION.md` (never device-biometric) + GA-2 + GA-3 (+TCH-9/HR-6), frozen GA-D1..D4 config, flagged as the pilot-Stage-12 prerequisite | `FINAL_EXECUTION_MASTER_ROADMAP.md` | ✅ Applied |
| 2 | **P1-PROD-1..21 wave decomposition made normative** — roadmap row now cites the `FINAL_QA_ROADMAP.md` §Phase-C C0–C21 table as authoritative grouping; that file's banner now carries the matching carve-out | `FINAL_EXECUTION_MASTER_ROADMAP.md` · `FINAL_QA_ROADMAP.md` | ✅ Applied |
| 3 | **P6 dependency fixed** — P3-AI-1 added to P6-PILOT-1's depends + the Hard-gates line ("P3-AI-1 gates P3-AI-2 and P6") | `FINAL_EXECUTION_MASTER_ROADMAP.md` | ✅ Applied |
| 4 | **Future Vision pair superseded-for-execution** — banners added repointing to the single roadmap, retiring the archived SSOT chain, M1–M13 milestones, and non-EOS "Agent G" gates | `FUTURE_VISION_MASTER_INDEX.md` · `FUTURE_VISION_PRESERVATION_AUDIT.md` | ✅ Applied |
| 5 | **AI-suite wave tags corrected** — six mis-tags fixed (insight-card re-serve → W2.1 · AI-6 rename → W2.9 · attrition split → W2.7 · HWK-1/FIN-6/TRN-2/MOD-1 → "P1 precondition") + a "doc 09 governs" precedence note added to both module-design headers | `adaptive-ai/05_…` · `adaptive-ai/06_…` | ✅ Applied |
| 6 | **Stale pointers updated** — strategy index (×2) and AI blueprint now point at `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`; `PROJECT_CONTEXT.md` reading order now names the roadmap system as item 3 | `STRATEGIC_MASTER_INDEX.md` · `ADAPTIVE_AI_MASTER_BLUEPRINT.md` · `PROJECT_CONTEXT.md` | ✅ Applied |
| 7 | **Numeric/traceability drift fixed** — pilot wording harmonized to "stages 0–16" in roadmap + autonomous plan; W5→Phase-6 added to the FABLE banner (with the deliberate re-sequencing noted); journal counts corrected (P0=19, P3=15 sub-waves, P1 +22 waves); P1-CODE-3 refs now carry `=SEC-6`/`=SEC-11`; P1-CODE-4 refs disambiguated to `DB-3,5,7,8,10, DB-4(=SEC-7)` | roadmap · plan · `FABLE_FINAL_ROADMAP.md` · `IMPLEMENTATION_PROGRESS.md` | ✅ Applied |
| 8 | **Orphan homed** — Firebase/Google-Cloud API-key restriction hardening added to P1-SEC-1's scope and done-when | `FINAL_EXECUTION_MASTER_ROADMAP.md` | ✅ Applied |
| 9 | **Owner register completed** — the Product-Excellence §6 UX candidate batch added to the roadmap's 👤 register | `FINAL_EXECUTION_MASTER_ROADMAP.md` | ✅ Applied |

No task IDs were changed or removed; one ID (`P1-PROD-22`) was added. No parallel roadmap or competing plan was created.

## 5. Optional Improvements (recorded; none blocks execution)

1. **Expand shorthand finding refs** (e.g. `REL-1,2,3,4,5`) to full IDs in the roadmap's Finding column so a plain grep of any finding ID hits its task directly (today the ledger provides this guarantee; the roadmap's column is shorthand).
2. **Pilot blueprint "~22 stage types"** — reconcile the blueprint's own §1/§4 phrasing with its 17 enumerated stages (0–16) on the first P6-adjacent doc touch; the roadmap and plan now use the unambiguous "stages 0–16."
3. **Strategy-index §2/§3 diagrams** end at "Phase 7 → GA"; the final roadmap splits certification (P7) from launch (P8). Cosmetic — the roadmap governs — but worth a one-line touch-up on next edit.
4. **Backlog rev pointer in the C-wave table** — the Phase-C table header says "Rev 4"; rev 5 added only the (doc-only) identity architecture. Note it when P1-PROD-1 first executes.
5. **P0 W2 wave size** — `NEXT_ACTIVE_WAVE.md`'s planned second wave bundles 12 tasks (SEC ∥ INFRA ∥ CODE). Consider letting the executor split it into SEC / INFRA / CODE sub-waves at the boundary — the wave-loop and file-ownership rules already permit this without a plan change.
6. **Superseded-doc hygiene sweep at P0-DOC-2** — while committing the cleanup, consider moving the now-bannered Future Vision pair into `docs/archive/` beside the chain they reference.

## 6. Risks Remaining (accepted, tracked — not planning defects)

1. **The live lane is still the long pole.** P0-INFRA and everything LIVE-graded depends on owner-provisioned access (VPS/SSH, tenant DB, CI runner). The plan sequences and stages this correctly but cannot remove the dependency; the 7-day cron clock (P7 prerequisite) starts only when P0-TEST-3 runs for real.
2. **Owner-decision latency.** ~26 Appendix-A items + the hide-list + module-scope + W2-timing decisions gate large P1/P3 swaths. The batching rule prevents pipeline stalls, but a long-undecided batch will progressively narrow what the executor may touch.
3. **P1-PROD breadth.** 22 waves over ~90 backlog items is the largest, least-itemized phase; per-wave EOS gates and the C-table completion criteria bound it, but schedule variance concentrates here.
4. **Red-Team outcome is genuinely open.** P5 is sized "var" by design; a bad P4 verdict re-opens earlier phases. This is the plan working as intended, not a flaw — but it is the largest unbounded time risk after the live lane.
5. **Single-executor context discipline.** The system assumes the executor reads `NEXT_ACTIVE_WAVE.md` and honors the wave loop every session. The journal/dashboard reconciliation invariant (Autonomous Plan §9) makes drift detectable, but detection still requires someone to look; the owner should spot-check the journal against commits periodically.

## 7. Confidence Score

**9.2 / 10** that this planning system, executed as written (one wave → one `/eos` PASS → one commit → one journal row, owner decisions surfaced in batches), takes Akshara ERP from HEAD `68f15cb` to a defensible GA without requiring a new plan.

Deductions: −0.4 for the open owner-decision surface area (planning cannot close it), −0.3 for live-lane dependence on out-of-plan provisioning, −0.1 residual risk that further prose-level audit nuances exist below the three verification sweeps' detection threshold.

## 8. Final Recommendation

**No further planning work is recommended.** The nine required changes found by this review are already applied; the roadmap, execution plan, active-wave file, journal, ledger, strategy set, and design suites are now mutually consistent, fully traceable, and free of competing plans. Implementation should **begin immediately** with Opus 4.8 autonomous execution: start at `NEXT_ACTIVE_WAVE.md` (**P0 · W1 — Documentation Truth**, dependency-free), run the universal wave loop from `AUTONOMOUS_EXECUTION_PLAN.md`, gate every wave with `/eos`, commit only on PASS, journal every wave, and never advance past an open P0 or a BLOCKED gate.

---

# READY FOR AUTONOMOUS EXECUTION
