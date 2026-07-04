# Akshara ERP — Strategic Master Index

**Status:** Strategy hub · **Author:** Fable · **Date:** 2026-07-03
**Purpose:** the single entry point to Akshara's strategic foundation. Summarizes each strategy document,
shows how they depend on each other, and maps each to the execution roadmap so it is clear **what to
build, in what order, and why.**

> **How this fits.** The **Fable Final Audit** (`docs/audits/00`–`11`) established *where we are*. The
> single authoritative roadmap **`docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`** (Phases 0–8) is
> *what to do*, with a complete finding-traceability ledger (`docs/audits/AUDIT_FINDINGS_LEDGER.md`).
> These five strategy documents are the *deep designs* behind the roadmap's biggest phases. Nothing here
> changes the implementation — they are the blueprints the roadmap phases execute against.

---

## 1. The strategy documents

| # | Document | What it defines | Roadmap phase it powers |
|---|---|---|---|
| 1 | [`ADAPTIVE_AI_MASTER_BLUEPRINT.md`](ADAPTIVE_AI_MASTER_BLUEPRINT.md) | The complete long-term Adaptive AI architecture — memory, context engine, per-persona AI, priority/recommendation/predictive engines, caching + API-minimization, event-driven updates, dynamic dashboards, automation. **Akshara's biggest moat.** | **Phase 3** (P3-AI-1 foundation → P3-AI-2 adaptive) |
| 2 | [`PILOT_SCHOOL_SIMULATION_MASTER.md`](PILOT_SCHOOL_SIMULATION_MASTER.md) | The full-year, every-role, every-workflow live simulation — day-by-day stages, success criteria, evidence, failure conditions. Passing = **PILOT-READY**. | **Phase 6** (P6-PILOT-1) |
| 3 | [`GLOBAL_RED_TEAM_FRAMEWORK.md`](GLOBAL_RED_TEAM_FRAMEWORK.md) | The 12-domain adversarial framework — severity matrix, execution process, adversarial verification, evidence requirements, EOS gates, reporting templates. | **Phase 4** (P4-RT-1) → **Phase 5** (P5-FIX-1) |
| 4 | [`PRODUCTION_CERTIFICATION_FRAMEWORK.md`](PRODUCTION_CERTIFICATION_FRAMEWORK.md) | Every GA gate (Technical, Security, Operational, UX, AI, Performance, Business, Docs) with the audit's **evidence-grade rule**, the Final Production Checklist, and the certification process. Passing = **GA**. | **Phase 7** (P7-CERT-1) |
| 5 | [`LONG_TERM_COMPETITIVE_STRATEGY.md`](LONG_TERM_COMPETITIVE_STRATEGY.md) | Landscape, advantages/weaknesses/gaps, and the 3-year & 5-year roadmap for sustainable differentiation (not feature parity). | **All phases** (the "why"); shapes Phase 3 + post-GA |

---

## 2. Dependency map

```
                 ┌──────────────────────────────────────────────┐
                 │  LONG_TERM_COMPETITIVE_STRATEGY (the "why")   │
                 │  — steers priorities across every phase —     │
                 └───────────────┬──────────────────────────────┘
                                 │ informs
        ┌────────────────────────┼───────────────────────────────┐
        ▼                        ▼                                ▼
 ADAPTIVE_AI_BLUEPRINT     (Master Execution Roadmap Phases 0–3)   (peripheral module finish)
   Phase 3 design                │                                
        │ its cost foundation    │  product + safety + UX ready    
        │ must precede the       ▼                                
        │ adaptive wave    ┌───────────────────────────┐          
        └─────────────────►│ GLOBAL_RED_TEAM_FRAMEWORK │ Phase 4→5 (attacks honest, finished product)
                           └─────────────┬─────────────┘          
                                         │ verdict PASS gates      
                                         ▼                         
                           ┌───────────────────────────┐          
                           │ PILOT_SCHOOL_SIMULATION    │ Phase 6 (live full-year proof)
                           └─────────────┬─────────────┘          
                                         │ PILOT-READY gates       
                                         ▼                         
                           ┌───────────────────────────┐          
                           │ PRODUCTION_CERTIFICATION   │ Phase 7 (GA gates + evidence)
                           └─────────────┬─────────────┘          
                                         ▼                         
                                    GA DECLARED                    
```

**Reading the dependencies:**
- **Competitive Strategy** is the compass — it decides *which* gaps to close and *which* to leave (North-Star discipline). It touches every phase but builds nothing itself.
- **Adaptive AI Blueprint** designs Phase 3; its **cost/safety foundation (P3-AI-1) must be built before the adaptive wave (P3-AI-2)**, and both ride the Phase-1 module completion + XCT foundations.
- **Red Team** (Phase 4) must run **after** Phases 0–3 (honest claims + finished product) and **feeds** Phase 5 fixes.
- **Pilot Simulation** (Phase 6) requires Red-Team PASS + Phase-0 safety + Phase-1 modules; passing it = PILOT-READY.
- **Production Certification** (Phase 7) requires Pilot PASS; passing it = GA.

---

## 3. When to implement each (against the Master Execution Roadmap)

| Roadmap phase | Strategy doc in play | Entry condition | Exit |
|---|---|---|---|
| **Phase 0** — Truth · Safety · Live Proof | Competitive (steer) | owner approval | docs truthful, safety P0s closed, CI green, off-site+WAL+alerts, RLS-suite in CI |
| **Phase 1** — Remaining implementations | Competitive (scope decisions) | Phase 0 | reliability/identity/modules finished; test coverage real |
| **Phase 2** — UI/UX | Competitive (adoption wedge) | Phase 1 (overlap OK) | UX rubric ≥8/10; a11y + DS enforcement |
| **Phase 3** — Adaptive AI | **Adaptive AI Blueprint** | Phase 0 (foundation) + Phase 1 (adaptive) | AI cost foundation live; per-persona adaptive surfaces |
| **Phase 4** — Global Red Team | **Red Team Framework** | Phases 0–3 substantially done | verdict PASS (no open P0/blocking-P1) |
| **Phase 5** — Red Team fixes | **Red Team Framework** | Phase 4 findings | every finding closed + re-verified live |
| **Phase 6** — Pilot Simulation | **Pilot Simulation Master** | Phase 5 + Phase 0 safety | unattended full-year PASS → **PILOT-READY** |
| **Phase 7** — Production Certification | **Production Cert Framework** | Phase 6 PASS | Final Checklist PASS → **GA** |

---

## 4. Governance

- **One standard, one gate.** All strategy execution is governed by the Engineering Constitution and the EOS (`/eos`). These documents design *what* to build; the EOS decides *whether it's done*.
- **Evidence-grade discipline** (from the audit) applies everywhere: LIVE evidence for Critical gates; no local/contract/mock proof passes a production gate.
- **Frozen owner decisions** (O1–O10, identity freeze, attendance-auth, English-first) are respected by every strategy doc.
- **These are design artifacts, not execution.** No code or implementation changes are made by them; each roadmap phase executes against its blueprint, wave by wave, on owner approval.

---

## 5. Quick links

- Audit reports: [`docs/audits/00_FABLE_MASTER_AUDIT_REPORT.md`](../audits/00_FABLE_MASTER_AUDIT_REPORT.md) (+ `01`–`11`)
- Execution plan: [`docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md`](../roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md) · executed per [`docs/roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../roadmap/AUTONOMOUS_EXECUTION_PLAN.md)
- Findings ledger: [`docs/audits/AUDIT_FINDINGS_LEDGER.md`](../audits/AUDIT_FINDINGS_LEDGER.md)
- Engineering standard: [`docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`](../engineering/AKSHARA_ENGINEERING_CONSTITUTION.md) · EOS ledger: [`docs/engineering/eos/EOS_RUN_LEDGER.md`](../engineering/eos/EOS_RUN_LEDGER.md)
- This strategy set: `docs/strategy/` (1 Adaptive AI · 2 Pilot Simulation · 3 Red Team · 4 Production Certification · 5 Competitive Strategy · this index)

---

*Strategic foundation complete. Together with the audit and the Master Execution Roadmap, these documents
define where Akshara is, where it's going, how it gets there safely, and why it wins — the authoritative
reference for the remainder of the project.*
