# Pilot School Checklist

**Version:** 1.0  
**Last updated:** June 2026  
**Target:** Single-school pilot (2 weeks)

---

## Pre-Pilot

| # | Item | Owner | Status |
|---|------|-------|--------|
| P1 | Staging backend deployed | Backend | [ ] |
| P2 | Auth API live (login, OTP, refresh) | Backend | [ ] |
| P3 | Admissions + Finance + SIS APIs live | Backend | [ ] |
| P4 | `enableApiMode` + module flags enabled | DevOps | [ ] |
| P5 | Tenant configured for pilot school | Admin | [ ] |
| P6 | `flutter analyze` = 0 issues | CI | [x] |
| P7 | `flutter test` all passing | CI | [x] |
| P8 | Pilot workflow certification tests pass | QA | [x] |

## Week 1 — Read Workflows

| # | Workflow | Verified |
|---|----------|:--------:|
| W1 | Admin login → Admissions dashboard | [ ] |
| W2 | Lead → Application → Approval queue | [ ] |
| W3 | Approved → Fee handoff → Finance assignment | [ ] |
| W4 | SIS student registry + profile | [ ] |
| W5 | Parent app: fees, attendance, leave | [ ] |
| W6 | Teacher app: attendance, homework, exams | [ ] |

## Week 2 — Write Workflows

| # | Workflow | Verified |
|---|----------|:--------:|
| W7 | Create lead + submit application | [ ] |
| W8 | Approve application + send to finance | [ ] |
| W9 | Parent leave submission | [ ] |
| W10 | Parent payment flow | [ ] |
| W11 | Teacher attendance submission | [ ] |
| W12 | Teacher exam mark entry | [ ] |

## Go/No-Go Criteria

- [ ] All P0 technical debt resolved or accepted with sign-off
- [ ] Server RBAC enforced on staging
- [ ] Audit events ingested server-side
- [ ] Zero P0 bugs in pilot week 1
- [ ] School admin sign-off
