# Akshara ERP — Patrol QA Orchestrator

**Version:** 1.1  
**Created:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Freeze:** 🔒 **PRE-CLAUDE** — Batch 03 not authorized; see [`CLAUDE_HANDOFF.md`](./CLAUDE_HANDOFF.md)  
**Authority:** Single source of truth for continuous QA coverage alongside backend phases F3–F7.  
**Program:** AUDIT → FIX → TEST → CERTIFY → UPDATE TRACKER → CONTINUE

**Companion docs:**

| Doc | Purpose |
|-----|---------|
| [`PATROL_COVERAGE_AUDIT.md`](./PATROL_COVERAGE_AUDIT.md) | Module-level inventory |
| [`PATROL_EXPANSION_ROADMAP.md`](./PATROL_EXPANSION_ROADMAP.md) | Phase targets & priorities |
| [`UI_UX_AUDIT_BACKLOG.md`](./UI_UX_AUDIT_BACKLOG.md) | Visual / UX defect register |
| [`PATROL_BATCH_01_CERTIFICATION.md`](./PATROL_BATCH_01_CERTIFICATION.md) | Batch 01 certification |
| [`PATROL_BATCH_02_CERTIFICATION.md`](./PATROL_BATCH_02_CERTIFICATION.md) | Batch 02 certification |
| [`PATROL_BATCH_02B_CERTIFICATION.md`](./PATROL_BATCH_02B_CERTIFICATION.md) | Batch 02b (cross-persona — pending cert) |

---

## Program status (live)

| Metric | Value | Target (Phase 1) | Target (Phase 3) |
|--------|-------|------------------|------------------|
| **Overall QA coverage %** | **46%** | 100 journeys (foundational) | 500+ journeys (production-grade) |
| **Operational readiness (product)** | ~72% | — | — |
| **Certified Patrol journeys** | **116** | 100 | 500 |
| **Patrol `patrolTest()` count** | **362** | — | — |
| **Patrol suite files** | **106** | — | — |
| **Maestro YAML journeys** | **128** | — | — |
| **Maestro shared flows** | **7** | — | — |
| **Flutter widget/feature tests** | **151** | — | — |
| **Flutter integration tests** | **52** | — | — |
| **Golden test suites** | **5** | — | — |
| **Route coverage %** | **~78%** | 90% | 98% |
| **Persona coverage %** | **~71%** (5/7 QA personas) | 100% | 100% |
| **Module coverage % (avg)** | **~48%** | 75% | 95% |

*Coverage % = weighted average of module classifications (COVERED=100, PARTIAL=50, NOT TESTED=0) — see audit doc.*

---

## Test inventory

| Layer | Count | Notes |
|-------|-------|-------|
| Patrol suites (`patrol_test/`) | 106 files · 362 tests | Includes 81 generated manifest journeys |
| Journey manifest (`qa/patrol/journey_manifest.json`) | 81 entries | Nav-anchor smoke per persona |
| Workflow YAML (`qa/journeys/workflow_*.yaml`) | 22 | Maestro/Patrol spec stubs |
| Biz YAML (`qa/journeys/biz_*.yaml`) | 97 | Persona/module navigation |
| Maestro flows (`qa/maestro/flows/`) | 7 shared | Login, module open helpers |
| `flutter test` total | 397 files | 1949+ assertions at last gate |
| Golden masters | 24 images · 5 suites | Persona + ERP dashboards |

---

## Defect tracker (summary)

| Category | Open UI | Open QA | Fixed | Total logged |
|----------|---------|---------|-------|--------------|
| **Critical** | 0 | 0 | 0 | 0 |
| **High** | 0 | 0 | 3 | 3 |
| **Medium** | 0 | 1 | 1 | 2 |
| **Low** | 0 | 1 | 4 | 5 |
| **By design** | — | — | 1 | 1 |

Detail: [`UI_UX_AUDIT_BACKLOG.md`](./UI_UX_AUDIT_BACKLOG.md) · legacy: `qa/patrol/reports/bugs.json`

---

## Execution loop (permanent)

```
1. Select highest-risk uncovered P0 workflow
2. Search existing coverage (reuse first — Step 4)
3. Extend or create Patrol suite + widget/integration support
4. flutter analyze → affected tests → Patrol
5. Fix failures + UI/UX defects discovered
6. Re-run until green
7. Certify batch → update this file + audit + backlog
8. Continue (do not stop after audit)
```

**Stop conditions:**

- All P0 journeys covered at PARTIAL or COVERED
- Phase milestone reached (100 / 250 / 500 journeys)
- Explicit Program Director stop instruction

---

## Certification history

| Batch | Date | New journeys | Coverage Δ | Patrol result | Doc |
|-------|------|--------------|------------|---------------|-----|
| Pilot closure | 2026-06-18 | 9 | +9 P0 | 9/9 green | [`FINAL_PILOT_CLOSURE_REPORT.md`](./FINAL_PILOT_CLOSURE_REPORT.md) |
| **Batch 01** | **2026-06-18** | **12** | **+12 P0 depth** | **12/12 green** | [`PATROL_BATCH_01_CERTIFICATION.md`](./PATROL_BATCH_01_CERTIFICATION.md) |
| **Batch 02** | **2026-06-18** | **14** | **+14 approval writes** | **14/14 green** | [`PATROL_BATCH_02_CERTIFICATION.md`](./PATROL_BATCH_02_CERTIFICATION.md) |
| **Batch 02b** | **2026-06-18** | **4** | **+4 cross-persona** | **Pending emulator** | [`PATROL_BATCH_02B_CERTIFICATION.md`](./PATROL_BATCH_02B_CERTIFICATION.md) |

---

## Run commands

```bash
# Unit + analyze gate
flutter analyze && flutter test

# Fast Patrol smoke (~2 min)
ERP_COVERAGE_MODE=fast qa/patrol/run_erp_coverage.sh

# Pilot + Batch 01 + Batch 02 + Batch 02b
patrol test -t patrol_test/workflows/pilot_closure_workflows_e2e_test.dart \
            -t patrol_test/workflows/patrol_batch1_p0_expansion_e2e_test.dart \
            -t patrol_test/workflows/patrol_batch2_approval_write_e2e_test.dart \
            -t patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart \
            -t patrol_test/auth/qa_persona_switch_test.dart

# Full ERP coverage (~60+ min)
ERP_COVERAGE_MODE=full qa/patrol/run_erp_coverage.sh
```

---

## Parallel backend program alignment

| Backend phase | QA stream focus |
|---------------|-----------------|
| F3 (SIS + 360) ✅ | Student 360 tabs, SIS export, dossier PDF |
| F4 (Exams) | Exam admin lifecycle Patrol, publish approval |
| F5 (Attendance) | Correction lock, parent dispute, admin screen |
| F6 (Audit upload) | Finance audit register, compliance exports |
| F7 (Remaining APIs) | API-mode Patrol on staging |

---

## Next batch (03) — queued

1. Director portal navigation depth
2. Tablet breakpoint spot checks (parent attendance, S360)
3. RBAC deny journeys for finance on admissions routes
4. Transport route allocation smoke
5. Fee structure principal approve → activate (cross-persona)
6. Login OTP path (production profile — mitigated)

**Batch 02b:** Suite implemented — certify when emulator stable (see [`PATROL_BATCH_02B_CERTIFICATION.md`](./PATROL_BATCH_02B_CERTIFICATION.md)).

---

*Last updated: 2026-06-18 — Batch 02b implemented; cert pending emulator.*
