# Akshara ERP — Roadmap Finalization Report (PLANNING FREEZE)

**Status:** 🔒 **PLANNING FROZEN** · **Program Manager:** Fable (CPM) · **Date:** 2026-07-04
**Scope:** the final consolidation of every audit, strategy, design, EOS result, and owner decision into ONE
executable roadmap system. **No code, no VPS/SSH/security/production verification** — planning only.
**Result:** the roadmap is the single executable source of truth for Opus 4.8 autonomous execution via `/eos`.

> After this point, planning is complete. Future work only **updates implementation progress while executing
> the roadmap** — it does not create new plans.

---

## 1. The frozen roadmap system (5 files, each with one job)

| File | Role | Rule |
|---|---|---|
| [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) | **The only roadmap** — Phases 0–8, every task fully specified, status-flagged, EOS-gated | Update, never replace or fork |
| [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) | **How Opus 4.8 executes** — the wave loop + per-phase protocol + commit rules | Governs every wave |
| [`NEXT_ACTIVE_WAVE.md`](NEXT_ACTIVE_WAVE.md) | **The only file read before each wave** — current work only, small (56 lines) | Rewritten at each wave boundary |
| [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md) | **Permanent journal** — one row per completed wave | Append-only |
| **this report** | **The freeze record** | Written once |

**Inputs reconciled (all read, none ignored):** `docs/audits/00`–`11` + `AUDIT_FINDINGS_LEDGER.md` · `docs/strategy/*` (5 docs) · `docs/design/adaptive-ai/00`–`09` (10 docs) · `docs/design/*` (design system) · `docs/engineering/eos/*` · owner decisions O1–O10 + identity/attendance-auth/English-first freezes.

---

## 2. What changed in this finalization pass

- **Folded in the Adaptive AI implementation suite** (`docs/design/adaptive-ai/00`–`09`, created after the last consolidation). Phase 3 now carries the explicit sub-wave breakdown: **P3-AI-1 = W1.1–W1.5** (gateway hardening → memory+cache → context engine → Signal Refinery → fingerprint cache+cost panel) and **P3-AI-2 = W2.0–W2.9** (engines → Teacher → Parent → Principal → Director → Student → ops worklists → pgvector → truth-in-naming); **W3 → post-GA (P8-GA-5)**.
- **Added the cross-phase dependencies** doc 09 surfaced: W1.4 needs **XCT-2**; homework/fee/transport intelligence needs **HWK-1 / FIN-6 / TRN-2**; recovery CRM needs **MOD-1 (👤)**; delivery timing needs **COM-1**; Principal rollout needs the **P2 Principal-hub consolidation**; live T3 needs the **P0 live-AI-key**. These now pull specific P1/P2 items *before* their dependent P3 sub-wave.
- **Refreshed source-of-truth inputs** in the roadmap header to include `docs/design/adaptive-ai/`.
- **Closed traceability gaps:** AI-1…AI-6 all explicitly mapped in P3; `LONG_TERM_COMPETITIVE_STRATEGY.md` named in the strategy-mapping; novel ideas N1–N12 placed (N10 cost panel → W1.5; consent/post-GA N3/N5/N6/N7/N9 → W3/P8-GA-5).
- **Updated the Autonomous Execution Plan's Phase 3** with the sub-wave order + standing AI test assets + the metrics gate.
- **Created `NEXT_ACTIVE_WAVE.md`** and set the first wave to **P0 · W1 — Documentation Truth** (docs-only, dependency-free, safest entry).
- **Initialized the journal for autonomous execution:** planning recorded as "Wave 0"; **implementation history starts at Wave 1.**

## 3. What was merged (duplicates → one authoritative task)

- Backend duplicates: `ENG-7 = SEC-6` (error leak), `ENG-8 = SEC-11` (unbounded arrays), `DB-4 = SEC-7` (SECURITY DEFINER).
- Surface duplicates: `ENG-3 = MOD-4` (backend-less surfaces).
- Doc/DB duplicates: `DB-9 = DOC-5`, `DB-6 = DOC-6`.
- Ops/DB duplicates: `OPS-6 = DB-1`, `OPS-1 = LV-1`, `OPS-2 = LV-8`, `OPS-3 = LV-6`, `OPS-5 = ENG-2`.
- Roadmap duplicates: `FABLE_FINAL_ROADMAP` (W0–W9) + `MASTER_EXECUTION_ROADMAP` (P0–7) → folded into the ONE roadmap (P0–8); both carry redirect banners.
- Adaptive-AI overlap: the strategy blueprint (§12) and the design suite (doc 09) resolve to the **same** P3 waves — the suite is the executable layer, the blueprint the anchor; not two plans.

## 4. What was removed / excluded (recorded, not lost)

- **Already-fixed during the audit** (not tasks): tenant RLS isolation (verified), `erp_tenant` role (verified), entitlement enforcement ON, backups + tested restore, watchdog, AI-via-OpenRouter, live DB password rotated, `inventory_stock_valuations` fix. → journaled as the pre-execution baseline; **must not be restarted.**
- **Corrected false-positive:** the initial "no automated backup" (LV-2) — refuted; removed as a task.
- **Out of scope:** re-enabling deferred verticals/experimental surfaces (O1/O3); re-auditing certified-unchanged work; frozen QW1–QW8 history.

## 5. What was reordered

- **P0 remains the gate for everything** (truth + safety + live proof before Red Team/Pilot/GA).
- **Cross-phase pulls:** specific P1 backlog items (XCT-2, HWK-1, FIN-6, TRN-2, COM-1) and the P2 Principal-hub consolidation are now explicit **prerequisites of P3 sub-waves** — so they are sequenced before the AI wave that consumes them, not left implicit.
- **Optimal order confirmed:** Backend/Code (P1) → UI/UX (P2) → Adaptive AI (P3) → Red Team (P4) → Red Team Fixes (P5) → Pilot (P6) → Production Cert (P7) → GA (P8); P4→P8 strictly sequential; P0 gates all.

## 6. Remaining owner decisions (👤 — batched; gate their tasks only, never the pipeline)

hide-list (P0-CODE-2) · RPO accept (P0-INFRA-2) · module scope Hostel/Alumni/Finance-posting (P1-CODE-6/7/8, and MOD-1 gates the AI recovery-CRM scope) · PLAT-0 non-student Public-ID (P1-CODE-4) · Appendix A ~26 items (P1-PROD-*) · Adaptive-AI W2 timing (P3-AI-2) · Consolidation wave DOC-8 (P8-GA-5) · `APP_ENV=staging` intent (LV-5) · shared-box strategy (LV-4/OPS-4) · peer-benchmark consent (N7, W3).

## 7. Final planning validation

| Check | Result |
|---|---|
| ✓ One roadmap only | **PASS** — `FINAL_EXECUTION_MASTER_ROADMAP.md`; 3 prior roadmaps carry redirect banners |
| ✓ One execution plan only | **PASS** — `AUTONOMOUS_EXECUTION_PLAN.md` |
| ✓ One active wave only | **PASS** — `NEXT_ACTIVE_WAVE.md` (P0 · W1), 56 lines |
| ✓ No duplicate work | **PASS** — merges listed §3; verified in the findings ledger |
| ✓ No conflicting phases | **PASS** — P0 gates all; P4–P8 sequential; deps recalculated |
| ✓ No missing audit findings | **PASS** — ledger families complete (ENG 10 · DB 10 · SEC 11 · QA 8 · REL 9 · AI 6 · MOD 6 · UX 6 · OPS 8 · DOC 8 · LV 11) → all mapped |
| ✓ No missing AI recommendations | **PASS** — AI-1…AI-6 mapped to W1/W2; suite docs 00–09 + N1–N12 placed |
| ✓ No missing UX recommendations | **PASS** — UX-1…6 + prior Tiers 1–4 + a11y → P2 |
| ✓ No missing owner decisions | **PASS** — O1–O10 + freezes respected; open 👤 items in §6 |
| ✓ No orphan roadmap tasks | **PASS** — every task cites a finding/strategy/decision; every strategy+design doc referenced |
| ✓ Complete audit traceability | **PASS** — Audit → Finding → Ledger → Roadmap task → Wave → EOS → Regression → Evidence → Completion |
| ✓ Complete implementation traceability | **PASS** — journal schema + baseline + Wave-1 entry initialized |
| ✓ Autonomous execution ready | **PASS** — wave loop + EOS-per-wave + commit-only-after-PASS + NEXT_ACTIVE_WAVE defined |

## 8. Readiness statement

- **Implementation readiness:** ✅ Ready. Every recommendation is an executable, EOS-gated task with scope, files, deps, evidence, and completion criteria. First wave defined and dependency-free.
- **Autonomous readiness:** ✅ Ready. Opus 4.8 reads `NEXT_ACTIVE_WAVE.md`, executes the wave loop (`AUTONOMOUS_EXECUTION_PLAN.md`), runs `/eos`, fixes findings, commits only on PASS, journals, and advances — no phase continues with an open P0 or BLOCKED gate.
- **EOS readiness:** ✅ Every wave names its EOS scope; the gate is the single arbiter of "done"; the run ledger + journal keep it honest.
- **Roadmap completeness:** ✅ Nothing floating; nothing duplicated; nothing orphaned; every finding, strategy doc, and owner decision mapped.

## 9. The traceability chain (every recommendation follows this)

```
Audit report → Finding (AUDIT_FINDINGS_LEDGER) → Roadmap task (FINAL_EXECUTION_MASTER_ROADMAP)
   → Implementation wave (NEXT_ACTIVE_WAVE) → EOS validation (/eos <scope>)
   → Regression (analyze/test/coverage/isolation) → Evidence (journal row) → Completion (status ✅)
```

---

**🔒 PLANNING FREEZE — 2026-07-04.** This is the last planning task. From here, execution proceeds one
wave at a time against the frozen roadmap, updating only the progress journal and the active-wave file.
The roadmap is the single executable source of truth for Opus 4.8 autonomous execution via the `/eos` skill.
