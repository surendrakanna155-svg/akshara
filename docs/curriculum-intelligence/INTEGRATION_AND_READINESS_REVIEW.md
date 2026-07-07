# Curriculum Intelligence — Integration & Readiness Review

**Date:** 2026-07-07 · **Session:** final planning/integration (pre-implementation handoff)
**Method:** repository-inspected, not report-trusted — every claim below re-verified against the working tree at HEAD `3c924756`.
**Companion:** [`OPUS_IMPLEMENTATION_HANDOFF.md`](OPUS_IMPLEMENTATION_HANDOFF.md) (the implementation handoff package).

---

## 1. Deliverable verification (Step 1) — ✅ all present, one nuance

| Reported | Verified state |
|---|---|
| 3 spec docs (`spec/`) | ✅ present; the two originals committed (`3c924756`); engine addendum untracked |
| 3 audit docs (`audits/`) | ✅ present (architecture audit, gap analysis, backcompat plan) |
| 13 planning docs (`planning/`) | ✅ present, count exact |
| Initiative `README.md` | ✅ present, indexes all of the above |
| `docs/README.md` + `PROJECT_INDEX.md` updates | ✅ **committed** (README section swept into `6588c771`, index line into `3c924756` by the concurrent roadmap-executor session) |
| Verification engine (4 Python files) | ✅ present at `curriculum/scripts/verification/` |
| Tests | ✅ present; **re-run this session: 13/13 OK** |
| External configuration | ✅ `curriculum/configs/paths.json` + `verification_rules.json` (all thresholds/weights/backoffs external) |
| `.gitignore` guard + initial report | ✅ present; guard re-verified (binary trees invisible to git) |

**Nuance (not a gap):** everything except the two original spec docs and the index-file edits is **still uncommitted** (20 untracked files: 18 program docs + engine tree). Consistent with "awaiting approval," but the concurrent executor session sweeps untracked files at wave boundaries — recommend an explicit program commit on approval so provenance stays clean.

## 2. Engine verification (Step 2) — ✅ matches specification

- **Files/tests/config:** verified above; suite re-run fresh: `Ran 13 tests … OK`.
- **Pipeline vs spec:** checks V1–V11 map 1:1 to the approved addendum (existence → name → extension+magic → size → SHA-256 → checksum store/read-back → open probe → PDF deep checks (header/EOF/startxref/pages/parse) → metadata → index read-back → move + post-move re-hash); duplicate diversion before store; recovery ladder retry→alternative→missing; report carries all nine required counters + weighted health score; `repository_audit.py` gates `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION` and demonstrably revokes it on corruption.
- **App isolation:** ✅ **zero modifications** under `lib/` or `supabase/` attributable to this program (working tree currently clean there; the only commits touching app code are the executor's own C16 wave).
- **Improvements documented, NOT implemented** (queue for CI-A0 remainder):
  1. `pypdf` not installed — page parsing is structural; install to upgrade V8d/V8e to full parsing (zero code change).
  2. The engine *directs* recovery; the downloader that obeys `next_recovery_action()` is CI-A0/A1 scope (by design).
  3. PM files (TODO/PROGRESS/SESSION_LOG/CHECKPOINTS) not yet scaffolded — CI-A0 remainder.
  4. `DOWNLOAD_QUEUE.json` entry shape is defined by usage (CLI + tests); add a JSON-schema file in CI-A0 for validation.
  5. Verification events append to no `logs/verification.log` yet (report + JSON queues carry the state); add file logging in CI-A0.

## 3. Architecture consistency review (Step 3)

| Standard | Verdict | Notes / corrections |
|---|---|---|
| **EOS Constitution / gate** | ✅ Consistent | No competing "is it ready" standard created. Clarified hierarchy: data-lane gates (AT-D/AT-V) are **subordinate data-quality checks**; EOS remains the only engineering gate; every code wave = one EOS-gated commit. |
| **v3.0 Master Plan (locked D1–D11)** | ✅ Consistent after C1–C7 resolutions | v3.0 governs on conflict (program law, stated in every doc). **One drift found & corrected:** original plan seeded *all* dormant tables in one wave (CI-E1); v3.0 §5.3 authorizes early seeding of the **response spine + trust columns** only. CI-E1 now splits: **E1a** (response spine, trust, exposure — early) / **E1b** (canonical concepts — after CI-B4 seed data). |
| **Certified paper-generation engine** | ✅ Untouched | Invariants I1–I8 defined; verified zero app-code deltas this program. |
| **Frozen FINAL_EXECUTION_MASTER_ROADMAP** | ⚠ → resolved by §4 | The program previously floated beside the roadmap (risk R5). §4 docks it: no separate roadmap. **One correction required:** `SPRINT_PLAN.md` S1–S9 interleaved code sprints from the start; under the recommended integration (Option A) the substantive code waves re-time to the v3.0 Phase-1 window — a re-timing banner has been added to that doc rather than regenerating it. |
| **Red Team framework + Fable audit set** | ✅ Consistent | See §5. Bonus consistency: adaptive-AI governance rails (P3-AI-1: rate-limit, spend-cap, timeout — audit findings AI-1..AI-3) land **before** CI's new AI surfaces (CI-C5/C6) under Option A, so those surfaces are born inside the governed AI runtime. |
| **Implementation standards** (repo pattern, migration ledger, additive-only, XCT-1 reuse) | ✅ Consistent | Encoded in the backcompat plan + dependency graph reuse matrix. |
| **Duplicate standards check** | ✅ None conflicting | Three AI-policy texts exist (MCIP Part 16, v3.0 D3/D7, adaptive-AI T0–T3 ladder) — same substance (never fabricate, HITL, token minimization). Hierarchy made explicit: v3.0 D3/D7 + Part 16 govern CI; the T0–T3 ladder governs P3 surfaces. |

## 4. Roadmap integration (Step 4) — ONE roadmap, three docking points

The program does **not** get its own roadmap. It docks into existing structures:

```
NOW ──────────────────────────────────────────────────────────────────► GA ─► post-pilot
 P1 (C17…C21) ─ P2 ─ P3 ─ P4 RED TEAM ─ P5 ─ P6 PILOT ─ P7 ─ P8      v3.0 Phase 1 ─ 2 ─ 3
      │                     ▲                                              ▲
      │                     │                                              │
 ①  CI-DATA parallel track (CI-A0 rest → A1..A6, B1..B4) — zero app surface,
     own data gates, never blocks or is blocked by P-waves                 │
      │                     │                                              │
 ②  P1-CI-0 (NEW small wave, before P4-RT-0, owner amendment):            │
     golden-test pinning of the solver · edu_exam_paper_links (CI-C8) ·   │
     dormant response-spine/trust/exposure seed (CI-E1a)                   │
     [optional rider: CI-C2 catalogue expansion IF CI-B1(CBSE) is ready    │
      and the pilot school needs boards/classes beyond the Grade-10 seed] │
      │                                                                    │
 ③  Everything substantive (CI-C1 solver+templates, C3 multi-set/PDF,     │
     C4 tagging, C5 AI validation, C6 cold-start ingestion, C7 profiles,  │
     C9 sync, E1b concepts) = THE implementation plan for v3.0 Phase 1 ───┘
     (already locked post module-completion → red-team → pilot)
```

| Classification (as requested) | Items |
|---|---|
| **Before the next production audit (P4)** | P1-CI-0 only: golden pinning, paper↔exam link, dormant E1a seed (+optional CI-C2 rider) |
| **After the audit / post-pilot** | CI-C1, C3, C4, C5, C6, C7, C9, E1b → executed as v3.0 Phase 1 |
| **Completely independent (start anytime on approval)** | The whole CI-DATA track (acquisition + knowledge datasets + verification engine operations) |
| **Blocks future AI features** | CI-E1a seed (response corpus cannot be backfilled — blocks v3.0 Phase 2 value) · CI-B3 blueprint transcriptions (block CI-C1) · CI-B4 concept seed (blocks E1b/Phase 2 concept layer) · data-lane corpus (blocks knowledge-base generation) |
| **Can safely wait for later releases** | DOCX/HTML exports (TD-CI-15), grade-band configurability (TD-CI-4), semantic dedup (Phase 3), continuous-sync v1 (needs A6 anyway) |

**Milestone that introduces the platform:** the pilot-facing roadmap introduces it at **P1-CI-0** (seed & pin); the *product* capability arrives at **v3.0 Phase 1** (post-pilot), for which this program's planning suite is the implementation plan.

## 5. Red Team position (Step 5) — hybrid, with reasoning

**Verdict: parallel initiative (data lane) + tiny prerequisite wave (P1-CI-0) + post-audit enhancement (engine waves).** Not a separate long-term roadmap.

- **Why not prerequisite-everything:** ~33–45 dev-days of new engine surface before P4 delays the red team and pilot, contradicts locked v3.0 D11 timing, and enlarges the assault scope with brand-new code — the red team should assault the *stable, certified* surface.
- **Why not post-everything:** the dormant schema (E1a) and paper↔exam link must exist before P4 so the red team's **isolation/RLS domain** probes the new tables and the **corruption/concurrency domains** exercise the link — dormant-but-probed is far cheaper than a scoped re-assault later. Golden pinning before P4 also hardens the engine's regression evidence for the audit itself.
- **Why the data lane is out of scope:** it's not app attack surface. Its risk is **legal/licensing**, gated by AT-D6/license audit — a compliance review, not a red-team domain. Its outputs enter the app only through migrations in future EOS-gated waves.
- **Post-pilot engine waves:** when v3.0 Phase 1 later ships CI-C5/C6/C7, re-run the AI-abuse + isolation playbooks **scoped to the new surfaces** (framework §2 playbooks are reusable) — a scoped regression assault, not a second global red team. This preserves the owner's ONE-global-red-team principle.

## 6. Final architecture decisions check (Step 6) — all verified ✅

| Owner requirement | Status |
|---|---|
| Certified engine untouched | ✅ zero app-code deltas; I1–I8 inviolable in every plan doc |
| CI extends (never replaces) the platform | ✅ v3.0-subordinate; reuse matrix in dependency graph §4 |
| Backward compatibility preserved | ✅ additive-only migrations, template-absent-⇒-legacy solver rule, B1–B10 mitigations |
| Question Lifecycle correctly defined | ✅ today: bank `review_status` + paper `draft→submitted→changes_requested→approved→published→archived`; future: trust pipeline `validated→probation→trusted→quarantined/retired` (v3.0 §10.2) — **defined now, activated only in Phase 2**; existing rows enter as `trusted` |
| Examination Profiles independent | ✅ profile ≠ exam type ≠ blueprint template (three separate entities in CI-C7 design); pre-generation compatibility report, never silent downgrade |
| Subscription architecture capability-based | ✅ rides `plan_entitlements` (B2-certified pattern); no plan names in code; paid tiers stay Phase-2 commercial (O6) |
| Download Verification mandatory | ✅ spec addendum §5: direct writes to `resources/` prohibited; `repository_audit.py` is the sole gate to `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION` |

**Outstanding owner decisions (the complete blocking set):**

| # | Decision | Recommendation |
|---|---|---|
| **D-1** (refined) | Approve the §4 integration: CI-DATA parallel track now + **P1-CI-0** wave inserted before P4 (one-line amendment to the frozen roadmap) + engine waves = v3.0 Phase 1 plan | Approve as specified (Option A). Alternative **Option B** — pull CI-C1/C3 pre-P4 for a stronger pilot QP experience — costs ~+3–4 weeks before red team; not recommended |
| **D-2** | Ratify `curriculum/` workspace location (engine already there, relocatable via one config value) | Ratify |
| **D-3** | Question-extraction scope (two-lane: pattern store vs bank) | Approve two-lane |
| **D-4** | Board order | CBSE → TS → AP → CISCE |

*(Adjacent-not-blocking: v3.0 §17 O-A…O-D, backlog Appendix-A items, adaptive-AI W2 timing — none gates this program.)*

## 7. Readiness assessment (Step 7)

| Dimension | State | Evidence / blocker |
|---|---|---|
| **Planning** | 🟢 **Ready** | 21 docs: spec(3) + audits(3) + planning(13) + README + this review; all cross-verified this session |
| **Architecture** | 🟢 **Ready** | Consistency review clean (§3); conflicts resolved on paper; E1 drift corrected |
| **Repository (curriculum workspace)** | 🟡 **Partially Ready** | Engine + configs + guard + report: done & tested. PM files, downloader, discovery scripts: not started (CI-A0 remainder). Content: zero resources acquired |
| **Knowledge Base** | ⚪ **Not Started** | By design — hard-gated on acquisition + `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION` (gate implemented & proven) |
| **Implementation (code lane)** | 🟡 **Partially Ready** | Contracts, wave scopes, golden-test plan, acceptance criteria all defined; **Blocked** on D-1 approval + P1-CI-0 roadmap slot |
| **Testing** | 🟡 **Partially Ready** | Engine 13/13 green; golden/AT catalogs written; live-cert extensions must stage locally while the live lane stays owner-deferred (R13) |
| **Deployment** | 🟡 **Partially Ready** | Established `/deploy` recipe + additive-only migrations + per-wave rollback levers documented; **Blocked** for live verification on the owner live lane |
| **Overall program** | 🟡 **Partially Ready — blocked exclusively on owner decisions D-1..D-4** | No technical blocker exists; the data lane can start the day D-1/D-2 are approved |

---

## 8. Amendment A1 addendum (2026-07-07) — AIMS synchronization

*(Appended after Baseline v1.0; §§1–7 above are the historical pre-approval record and are left unmodified.)*

- The owner dropped a second canonical spec, [`spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) (**AIMS**, Parts 1–12), superseding the earlier architectural enhancement notes. Per its own Part 1 it extends — never replaces — the Program Baseline; v3.0 still governs on conflict.
- **Synchronization performed 2026-07-07:** deltas identified and merged across the existing suite (no document regenerated, no parallel architecture created). Full delta record: [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §6 (items A1-1..A1-16 + owner items A1-O1..O3).
- **Docking (extends §4, changes nothing in it):** most AIMS content lands as scope extensions inside existing waves (CI-B4 concept graph · CI-C4/C5 boundary-v2 + metadata gate · CI-C7 profile enrichment + foundation depth-not-scope). Two genuinely new capabilities append as post-E1b waves — **CI-C10** Question Factory (item models, families, distractor library, offline batch generation) and **CI-C11** Diagram Intelligence (Certified Diagram Library) — at the v3.0 Phase-1→2 boundary. **P1-CI-0 scope is untouched; nothing new lands before P4.**
- **Red-Team position (§5) unchanged:** CI-C10/C11 simply join CI-C5/C6/C7 in the scoped post-ship playbook re-run set.
- **Goal lines unchanged:** G1/G2 definitions and critical paths hold; the factories sit beyond G2 (see CRITICAL_PATH_ANALYSIS).
