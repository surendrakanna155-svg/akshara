# Customer Readiness Report — First Real School

**Date:** 2026-06-10  
**Release:** `v1.0-rc1` · tags `v1.0-ops-ready` · `v1.0-customer-ready`  
**Mode:** Release candidate — customer onboarding execution only  
**Baseline:** Operational Readiness COMPLETE · Production Validation PASS · Demo School 31/31 · 1087 tests · 213 probes · 0 open pilot issues · Feature freeze ACTIVE

---

## Customer Readiness Status

**READY WITH CONDITIONS — execute Phases 0–6 before parent-wide access**

Akshara is ready to onboard the **first real school** using documented operational playbooks. Product onboarding APIs are validated at scale (500 students / 35 teachers on staging). Remaining work is **execution**: platform provisions tenant, school completes catalog + CSV imports, live SMS verified on production handsets, ONB-* UAT signed, then First-Day go-live.

| Dimension | Status |
|-----------|--------|
| End-to-end onboarding flow documented | ✅ |
| Customer-facing quick-start guides | ✅ (this pass) |
| Import templates & ops checklists | ✅ |
| Production cutover path documented | ✅ |
| School self-service provisioning UI | ❌ Platform SQL/ops (Phase 1) |
| Live production SMS proof | ⏳ Cutover gate |
| Real-school tenant provisioned | ⏳ Per school |

---

## Onboarding Risks

Real-world risks only — no speculative product gaps.

| Risk | Likelihood | Impact | Mitigation |
|------|:----------:|:------:|------------|
| **CSV column mismatch** (class/section/year ≠ catalog) | High | High | Phase 2 catalog first; always Preview before Commit; [`Real-School-Onboarding-Guide.md`](./guides/Real-School-Onboarding-Guide.md) CSV rules |
| **Commas inside name fields** | Medium | Low | Wrap names in double quotes, e.g. `"Kumar, Ravi"`; UTF-8 CSV export |
| **Import timeout (>50 rows)** | Medium | Medium | Batch ≤50 rows/job; re-login between large runs |
| **Wrong import order** (students before teachers) | Medium | Low | Staff import first (documented in runbook) |
| **OTP not delivered (production)** | Medium | High | Go-Live §2 + ONB-11 before parent access; verify Twilio + `AUTH_OTP_DEV_MODE=false` |
| **Parent uses wrong login scope** | Medium | Medium | Parent Activation Guide — must select **Parent** scope |
| **Student app expected but no `studentPhone`** | High | Medium | Set expectations: parent app is default; student phone only for student-app cohort |
| **Duplicate admission numbers** | Low | Low | Preview marks `duplicate`; skipped on commit — fix source file |
| **Sibling same phone** | Low | Low | **Expected** — one parent, multiple children; verify in ONB-03 |
| **Teacher phone duplicate across staff** | Low | Medium | Second import may link wrong user — unique phones per teacher |
| **Bad student commit** | Low | High | Student job rollback API works; test ONB-10 once |
| **Bad teacher commit** | Low | Medium | **No automated membership rollback** — avoid teacher rollback; manual ops |
| **Finance admin not assigned** | Medium | Low | Assign `financeAdmin` manually if accountant role needed |
| **Excel saves as wrong encoding** | Medium | Medium | Export “CSV UTF-8”; avoid `.xls` with wrong headers |
| **JWT expiry during long seed** | Low | Medium | Refresh session between batches (demo_school pattern) |
| **School provisioning delay** | Medium | High | Schedule Phase 1 with platform team before school training date |

### End-to-end flow validation (code + staging)

| Step | Validated | Notes |
|------|:---------:|-------|
| School provisioning | Staging seed | Production = ops INSERT pattern in Real-School guide |
| Teacher import → OTP | ✅ | `9000000001` demo principal |
| Student import → parent OTP | ✅ | `9000100001` demo parent |
| Secondary guardian invite | ✅ | WhatsApp deep-link returned |
| Student ID login | ✅ | Requires `studentPhone` + `user_id` link |
| Re-import duplicates | ✅ | Admission # dedup |
| Student rollback | ✅ | Deletes student graph |
| Teacher rollback | ⚠️ | Status only — memberships remain |

---

## Documentation Gaps

| Gap | Severity | Resolution |
|-----|----------|------------|
| Real-school master onboarding timeline | Was missing | ✅ [`guides/Real-School-Onboarding-Guide.md`](./guides/Real-School-Onboarding-Guide.md) |
| School admin quick-start | Was missing | ✅ [`guides/School-Admin-Quick-Start.md`](./guides/School-Admin-Quick-Start.md) |
| Teacher quick-start | Was missing | ✅ [`guides/Teacher-Quick-Start.md`](./guides/Teacher-Quick-Start.md) |
| Parent activation guide | Was partial (`parent_guardian_guide` = ops) | ✅ [`guides/Parent-Activation-Guide.md`](./guides/Parent-Activation-Guide.md) |
| Platform school provisioning SQL steps | Was vague | ✅ Documented in Real-School guide Phase 1 |
| Teacher rollback manual procedure | Low | Documented as risk + runbook warning; full SOP deferred post-pilot |
| XLSX template files | Low | CSV sufficient; schools save-as XLSX if needed |
| Production Customer Readiness Report | Was missing | ✅ This document |

**Existing docs reviewed — no critical gaps remain:**

| Document | Review result |
|----------|---------------|
| [`Operational-Readiness-Report.md`](./Operational-Readiness-Report.md) | Current — internal ops view |
| [`School-Setup-Checklist.md`](./School-Setup-Checklist.md) | Current — pre-import gates |
| [`First-Day-Go-Live-Checklist.md`](./First-Day-Go-Live-Checklist.md) | Current — opening day |
| [`Pilot-Onboarding-Runbook.md`](./Pilot-Onboarding-Runbook.md) | Current v2.1 |
| [`Go-Live-Checklist.md`](./Go-Live-Checklist.md) | Current — secrets, OTP, backup, health |
| [`Production-Validation-Report.md`](./Production-Validation-Report.md) | Current — staging evidence |

---

## Operational Gaps

| Gap | Blocking? | Action |
|-----|:---------:|--------|
| Live SMS on production not yet proven for this school | **Cutover** | Go-Live §2 before parent rollout |
| School UUID not yet created for first customer | **Yes** | Platform Phase 1 |
| Manual teacher rollback SOP | No | Avoid; escalate to platform if needed |
| Accountant `financeAdmin` role | No | One-time RBAC if fees day-one |
| Backup drill on prod clone | No | Recommended per Go-Live §5 before go-live |
| Customer guides not yet branded (logo/URL) | No | Insert school-specific URLs before PDF/email |

### Production cutover path (validated in docs)

| Control | Reference | Status |
|---------|-----------|--------|
| Secrets (DB, JWT, health token, Twilio, Razorpay) | Go-Live §1, Production-Integrations | Documented |
| OTP providers | Go-Live §2, `AUTH_OTP_DEV_MODE=false` | ⏳ Execute at cutover |
| Health verification | `production_launch_verify.sh`, 213 probes | Documented |
| Rollback | Rollback-Checklist, tag `v1.0-rc1` | Documented |
| Backup / PITR | Backup-Runbook, Go-Live §5 | Documented |

---

## Assets Created

| Asset | Path |
|-------|------|
| Customer Readiness Report | `docs/Operations/Customer-Readiness-Report.md` |
| Real-School Onboarding Guide | `docs/Operations/guides/Real-School-Onboarding-Guide.md` |
| School Admin Quick-Start | `docs/Operations/guides/School-Admin-Quick-Start.md` |
| Teacher Quick-Start | `docs/Operations/guides/Teacher-Quick-Start.md` |
| Parent Activation Guide | `docs/Operations/guides/Parent-Activation-Guide.md` |

**Previously created (v1.0-ops-ready):** student/teacher CSV templates, parent guardian ops guide, School Setup + First-Day checklists, UAT ONB-* section, Operational Readiness Report.

---

## Assets Updated

| Asset | Change |
|-------|--------|
| `docs/Operations/School-Setup-Checklist.md` | Links to customer guides + Real-School guide |
| `docs/Operations/Pilot-Onboarding-Runbook.md` | Links to customer guides + Customer Readiness Report |

---

## Blocking Issues

**None at product level** for a limited first-school pilot.

| Condition | Type | Owner |
|-----------|------|-------|
| First school tenant provisioned (Phase 1) | Operational | Platform |
| Production live SMS verified (ONB-11) | Cutover gate | Platform + school admin phone |
| Academic catalog complete before CSV | Process | School admin |

Do **not** block internal UAT on a provisioned tenant — block **parent-wide** and **public** go-live until SMS + First-Day sign-off.

---

## Ready For First School

| Question | Answer |
|----------|--------|
| Can Akshara start onboarding the first real school? | **Yes** — begin Phase 0–1 (platform) immediately |
| Can school admin run imports and training? | **Yes** — after Phase 1 + guides distributed |
| Can all parents be told to log in today? | **No** — after ONB-11 + First-Day checklist |
| Is feature development required? | **No** |

**Recommended sequence:**

1. Platform: Go-Live + provision school + live SMS test  
2. School: Academic catalog → teacher CSV → student CSV (batched)  
3. Akshara: ONB-* UAT on real tenant  
4. Distribute Teacher + Parent guides  
5. First-Day Go-Live checklist → sign-off  

---

## Document index (customer onboarding)

| Role | Start here |
|------|------------|
| Platform / Akshara ops | [`guides/Real-School-Onboarding-Guide.md`](./guides/Real-School-Onboarding-Guide.md) |
| School admin | [`guides/School-Admin-Quick-Start.md`](./guides/School-Admin-Quick-Start.md) |
| Teacher | [`guides/Teacher-Quick-Start.md`](./guides/Teacher-Quick-Start.md) |
| Parent | [`guides/Parent-Activation-Guide.md`](./guides/Parent-Activation-Guide.md) |
| Release evidence | [`Production-Validation-Report.md`](./Production-Validation-Report.md) · [`v1.0-Release-Candidate.md`](../Releases/v1.0-Release-Candidate.md) |
