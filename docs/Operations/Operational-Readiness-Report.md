# Operational Readiness Report — First Real-School Onboarding

**Date:** 2026-06-10  
**Release baseline:** `v1.0-rc1`  
**Mode:** Feature freeze — operational readiness only  
**Automated gates:** 1087 Flutter tests pass · 213/213 tenant probes · Demo School 31/31 · Production validation PASS · 0 open pilot issues

---

## Operational Readiness Status

**Overall: READY WITH CONDITIONS**

Akshara ERP is operationally ready to onboard the first real school for **manual UAT** and a **limited production pilot**, provided the conditions below are executed before go-live. No blocking code defects were found in onboarding flows validated on staging. Remaining gaps are **process documentation** (now closed), **operator awareness** of known limitations, and **production OTP/SMS verification** on real handsets.

| Area | Status |
|------|--------|
| Onboarding API (import, invite, OTP) | ✅ Validated on staging |
| Import templates & checklists | ✅ Created (this pass) |
| Ops runbooks | ✅ Updated |
| UAT checklist | ✅ Critical ONB-* scenarios added |
| New school self-service UI | ⚠️ SQL/ops provisioning still required |
| Teacher import rollback | ⚠️ Partial — document only |
| Live SMS OTP on production | ⏳ Must verify at cutover |

---

## Onboarding Review

### Student import

| Topic | Finding |
|-------|---------|
| **Entry point** | ERP → SIS → School Onboarding (`/sis/onboarding`) or `POST /onboarding/imports` |
| **Required columns** | `studentName`, `admissionNumber`, `classLabel`, `sectionLabel`, `academicYear`, `parentName`, `parentPhone` |
| **Optional columns** | `studentPhone`, `gender`, `dateOfBirth`, `rollNumber` (snake_case aliases accepted) |
| **Preview → commit** | Invalid rows flagged; duplicates marked `duplicate` and skipped on commit |
| **Batch size** | Use ≤50 rows/job; long runs need token refresh between batches |
| **Academic catalog** | `classLabel` / `sectionLabel` / `academicYear` must match existing catalog exactly |

### Teacher import

| Topic | Finding |
|-------|---------|
| **Required columns** | `displayName`, `phone` |
| **Role column** | `teacher` (default), `principal`, `schoolAdmin` |
| **Optional** | `email` |
| **Login** | Phone OTP → school scope after commit |

### Parent provisioning

| Topic | Finding |
|-------|---------|
| **Primary guardian** | Via student import (`parentName`, `parentPhone`) |
| **Secondary guardians** | No bulk CSV — use `POST /onboarding/invites` (`inviteType: parent`, `recipientPhone`, `recipientLabel`, optional `studentId`, `channel`) |
| **Duplicate phone** | Same `parentPhone` on multiple students → one user, multiple `student_guardians` links (siblings) |
| **Missing parent** | Cannot commit student row without `parentName` + `parentPhone` (required in parser) |

### OTP login

| Role | Mechanism | Staging | Production requirement |
|------|-----------|---------|------------------------|
| School staff | Phone OTP | OTP in API message if dev mode | Real SMS; `AUTH_OTP_DEV_MODE=false` |
| Parent | Phone OTP | Same | Same |
| Student | Student ID (`admissionNumber` or `student_code`) + OTP to linked `studentPhone` user | Probe account `9876543212` | Requires `studentPhone` on import row |

### Role assignment

- Teachers/principal/schoolAdmin assigned via teacher import `role` column → school membership created on commit.
- Finance admin / custom RBAC may still need manual role assignment post-import (documented in UAT Accountant section).

### Bulk onboarding

- Demo School validated 500 students + 35 teachers + 750 parent links on staging.
- Pattern: teachers first, then student batches, then invites for secondary guardians.
- Re-import of same `admissionNumber` → preview `duplicate`; no double commit.

### Rollback behavior

| Import type | `POST /onboarding/imports/:id/rollback` effect |
|-------------|------------------------------------------------|
| **Student** | Deletes student, profile, enrollment, guardian links for committed rows |
| **Teacher** | Job status `rolled_back`; **membership and user records remain** — manual cleanup if needed |
| **Time limit** | None in API (runbook previously said 24h — corrected) |

---

## Import Template Status

| Asset | Status | Location |
|-------|--------|----------|
| Student Import Template (CSV) | ✅ Created | [`templates/student_import_template.csv`](./templates/student_import_template.csv) |
| Teacher Import Template (CSV) | ✅ Created | [`templates/teacher_import_template.csv`](./templates/teacher_import_template.csv) |
| Parent Import Template | ✅ N/A — by design | [`templates/parent_guardian_guide.md`](./templates/parent_guardian_guide.md) |
| School Setup Checklist | ✅ Created | [`School-Setup-Checklist.md`](./School-Setup-Checklist.md) |
| First-Day Go-Live Checklist | ✅ Created | [`First-Day-Go-Live-Checklist.md`](./First-Day-Go-Live-Checklist.md) |
| XLSX variants | ⚠️ Not created | Schools may save CSV as `.xlsx`; columns identical. Optional ops task only. |
| Quoted CSV fields | ✅ Hardened | Names with commas: wrap in `"double quotes"`; UTF-8 BOM stripped |

---

## UAT Coverage Gaps

### Duplicate tests (no action — documented for testers)

| Overlap | IDs | Recommendation |
|---------|-----|----------------|
| Wrong OTP | SA-L04, PR-L04, TE-L04, ST-L04, AC-L04 | One wrong-OTP test per role is sufficient; others mark N/A if time-constrained |
| Automated vs manual smoke | G-05 vs many SA-D* onboarding checks | Run G-05 once via script; SA-D04–D07 are UI confirmation only |
| Go-Live OTP vs UAT login | Go-Live §2 vs *-L01 sections | Go-Live = production SMS proof; UAT = functional workflow |

### Critical scenarios added (section 7)

| ID | Scenario |
|----|----------|
| ONB-01 | Academic catalog before import |
| ONB-02 | First real-school student batch |
| ONB-03 | Sibling / shared parent phone |
| ONB-04 | Duplicate admission re-import |
| ONB-05–06 | Invalid class / missing teacher phone |
| ONB-07–08 | `studentPhone` vs parent-only access |
| ONB-09 | Secondary guardian invite |
| ONB-10 | Student rollback smoke |
| ONB-11 | Live SMS OTP (production) |

### Not expanded (out of scope per feature freeze)

- Multi-school org admin flows  
- Self-service school creation UI  
- Automated XLSX validator  
- Full teacher rollback automation  

---

## Operations Documentation Gaps

| Document | Prior state | Action taken |
|----------|-------------|--------------|
| Go-Live Checklist | Existed | Cross-links to setup, first-day, templates, UAT, this report |
| Production Validation Report | Existed | No change — evidence current for v1.0-rc1 |
| Pilot Onboarding Runbook | Existed | v2.1 — templates, batch size, rollback accuracy |
| Demo School Validation Plan | Existed | No change — still valid for regression |
| Pilot Issue Tracker | 0 open | No change |
| Import templates | **Missing** | Created |
| School setup / first-day checklists | **Missing** | Created |
| UAT onboarding section | **Partial** | ONB-* section added |
| Operational Readiness Report | **Missing** | This document |

---

## Recommended Fixes

**Priority — before first school (ops, not code):**

1. Execute [`School-Setup-Checklist.md`](./School-Setup-Checklist.md) with platform team for new school UUID / tenant row.
2. Verify live SMS OTP on production handsets (ONB-11 / Go-Live §2).
3. Import teachers before students; use ≤50 row batches.
4. Decide student-app pilot cohort — add `studentPhone` column for those rows only.
5. Run UAT section 7 (ONB-*) on the real school tenant before opening to all parents.

**Priority — post-pilot (non-blocking):**

1. Document manual teacher rollback procedure (or implement membership revocation in a future release — **not in v1.0-rc1 scope**).
2. Optional XLSX template copies for schools that refuse CSV.
3. Consolidate duplicate wrong-OTP UAT rows in a future doc revision.

---

## Blocking Issues

**None** for limited first-school pilot.

| Item | Severity | Notes |
|------|----------|-------|
| New school provisioning via SQL/ops | Operational | Known v7.15 limitation — schedule with platform team |
| Teacher rollback incomplete | Low | Avoid teacher rollback; use student rollback; manual cleanup if needed |
| Student login without `studentPhone` | Expected behavior | Parent app is primary; communicate to school |
| Live SMS not verified yet | Cutover gate | Block production parent access until Go-Live §2 pass |

---

## Ready For First School

| Criterion | Met? |
|-----------|:----:|
| Onboarding flows reviewed | ✅ |
| Import templates available | ✅ |
| Setup + first-day checklists | ✅ |
| UAT covers real-school onboarding | ✅ |
| Automated validation green | ✅ |
| 0 open pilot defects | ✅ |
| Production SMS OTP verified | ⏳ At cutover |
| School tenant provisioned | ⏳ Per school |

**Decision:** Proceed to **manual UAT** on the first real school tenant after platform provisioning and production SMS check. Proceed to **parent-facing go-live** only after ONB-11 and First-Day checklist sign-off.

---

## Files Created

| File |
|------|
| `docs/Operations/Operational-Readiness-Report.md` |
| `docs/Operations/School-Setup-Checklist.md` |
| `docs/Operations/First-Day-Go-Live-Checklist.md` |
| `docs/Operations/templates/student_import_template.csv` |
| `docs/Operations/templates/teacher_import_template.csv` |
| `docs/Operations/templates/parent_guardian_guide.md` |

## Files Updated

| File | Change |
|------|--------|
| `docs/Operations/UAT-Checklist-v1.0-rc1.md` | Section 7 ONB-* scenarios; related-doc links |
| `docs/Operations/Pilot-Onboarding-Runbook.md` | v2.1 templates, rollback accuracy, batch guidance |
| `docs/Operations/Go-Live-Checklist.md` | Quick-reference links to new ops assets |

---

## Related baseline evidence

| Evidence | Location |
|----------|----------|
| RC release notes | [`docs/Releases/v1.0-Release-Candidate.md`](../Releases/v1.0-Release-Candidate.md) |
| Production validation | [`Production-Validation-Report.md`](./Production-Validation-Report.md) |
| Demo school 31/31 | `python3 scripts/demo_school_validate.py` |
| Pilot defects | [`Pilot-Issue-Tracker.md`](./Pilot-Issue-Tracker.md) |
