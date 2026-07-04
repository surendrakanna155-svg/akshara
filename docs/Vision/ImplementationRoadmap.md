# Akshara Evolution — Implementation Roadmap

**Version:** 1.0  
**Parent:** [`FutureVision.md`](./FutureVision.md)  
**Rule:** Implement in dependency order; v1.0 production paths remain stable.

---

## Priority legend

| Tier | Meaning |
|------|---------|
| **P1** | Core school revenue drivers |
| **P2** | School differentiators |
| **P3** | Platform expansion |
| **P4** | Multi-industry foundation |

---

## Foundational architecture (P1 · precedes feature waves)

> Cross-cutting foundations that other capabilities build on. Frozen product-architecture decisions; **design
> only** — implementation begins when the owner promotes them out of the backlog.

| # | Capability | Priority | Business value | Dependencies | Architecture impact | Data model | Rollout | Target | Source |
|---|------------|:--------:|----------------|--------------|---------------------|------------|---------|--------|--------|
| F1 | **Public Student ID — permanent human identity** (`<SCHOOL_CODE>-<RUNNING_NUMBER>`, e.g. `DPSKKP-0001`; running number 4-digit zero-padded, sequential per school, **never reused**; UUID stays canonical PK; School Code **globally unique**, set-once → editable-before-confirm → **locked forever**; **coexists with — does not replace — the school-configurable Admission Number**; **no student phone required**; future student login = Login ID + OTP to **parent**) | **P1** | Standard human identifier across the whole ERP; safe multi-school disambiguation; parent-authenticated student login | Schools/`code`, SIS `student_profiles`, admissions/onboarding provisioning | Add `public_student_id` (alongside `admission_number`) + per-school running-number sequence; make `schools.code` **globally unique + locked**; make the id **immutable**; backfill existing students | `public_student_id`, per-school sequence, global `schools.code` lock | High (touches nearly every module) | **Foundation — before feature waves** | 🔒 Frozen 2026-07-01 — [`PRODUCT_ENHANCEMENT_BACKLOG.md` § Public Student ID](../PRODUCT_ENHANCEMENT_BACKLOG.md#public-student-id-foundational-identity-architecture) |
| F2 | **Akshara Identity Platform — all person types** (generalizes F1 to Students + Parents + Teachers + Staff + Employees + Directors + every future user type; 4 frozen principles: UUID = only canonical identity · permanent Public IDs · **phone = login credential only, never identity** · **Identity-Permanence Invariant** — a phone change never creates a new identity / changes any UUID or Public ID / breaks relationships, history, attendance, finance, exams, payroll, audit, permissions) | **P1** | One consistent, permanent human identity per person; phone becomes a swappable credential, not an identity | F1; `users`, `employees`, `student_guardians`, `organization_memberships` | New Public Guardian ID + standardized Public Employee ID; **change-phone flow** preserving UUID + Public ID + all links; stop treating phone as the identity/upsert key | `public_guardian_id`, `public_employee_id`, phone-as-credential | High | **Foundation — after F1** | 🔒 Principles + Identity-Permanence Invariant frozen 2026-07-01; Parent/Teacher/Staff Public-ID formats = future model — [`PRODUCT_ENHANCEMENT_BACKLOG.md` § Identity Platform](../PRODUCT_ENHANCEMENT_BACKLOG.md#akshara-identity-platform-unified-identity-architecture) |

> **Scope & conflicts:** F1's per-module impact matrix, ordered checklist, and conflicts **C1–C9** (owner has
> resolved C1/C4/C8) live in the backlog; F2's per-persona model, `PLAT-*` items, and platform conflicts
> **IC-1…IC-6** (e.g. `users.phone` is `NOT NULL UNIQUE` and used as the identity/upsert key today; no
> change-phone flow; parents/directors have no Public ID) live in the backlog Identity-Platform section. These
> roadmap rows are **pointers** — they do not re-specify. **Documentation-only; no code, migration, or commit.**

---

## Master capability matrix

| # | Capability | Priority | Business value | Dependencies | Architecture impact | Data model | AI | Rollout | Target |
|---|------------|:--------:|----------------|--------------|---------------------|------------|-----|---------|--------|
| 21 | Academic Year Transition | P1 | Critical — annual ops | Academic catalog, SIS enrollments | New transition service | `academic_year_transitions` | No | Medium | **v8.0** |
| 1 | AI Communication Assistant | P1 | Fee reminders, comms efficiency | Communication hub, Copilot | Copilot context expansion | None | LLM | Low | **v8.1** |
| 4 | Parent Guidance Assistant | P2 | Parent satisfaction | v8.1, SIS read | New copilot persona | None | LLM | Low | **v8.2** |
| 6 | Teacher Copilot | P2 | Teacher adoption | Timetable, attendance | New copilot persona | None | LLM | Low | **v8.3** |
| 5 | Principal Copilot Expansion | P2 | Leadership decisions | Analytics v7.6 | Copilot persona split | None | LLM | Low | **v8.4** |
| 23 | Question Paper Generator | P2 | Academic differentiation | Question bank, syllabus | New education module | `edu_question_papers` | LLM+RAG | High | v8.5 |
| 24 | Question Bank | P2 | Reuse, quality | Academic catalog | CRUD module | `edu_question_bank` | Optional | Medium | v8.6 |
| 25 | Homework Generator | P2 | Teacher time save | v8.6, syllabus | Content service | `edu_content_jobs` | LLM | Medium | v8.7 |
| 26 | Worksheet Generator | P2 | Teacher time save | v8.7 | Shared content service | Same | LLM | Medium | v8.7 |
| 27 | Report Card Remarks | P2 | Report season | SIS, academics | Content service | Same | LLM | Medium | v8.8 |
| 28 | Parent Meeting Summary | P2 | PTM prep | Analytics, SIS | Content service | Same | LLM | Low | v8.8 |
| 3 | Student Risk Intelligence | P2 | Retention | Attendance, finance, analytics | Risk scoring service | `student_risk_scores` | Rules+ML | Medium | v8.9 |
| 18 | Akshara Growth Platform | P2 | School acquisition | Analytics, CRM patterns | Growth module | `growth_campaigns` | Optional | High | v9.0 |
| 19 | Achievement Promotion Engine | P2 | Engagement | SIS, comms | Gamification layer | `achievements` | No | Medium | v9.1 |
| 20 | School Branding | P2 | White label | Tenant config | Theme service | `school_branding` | No | Low | v9.2 |
| 29 | Universal AI Assistant | P3 | Platform moat | v8.1–v8.4 copilots | NL router + tools | None | LLM | High | v9.3 |
| 30 | Universal Organization Builder | P3 | Multi-vertical GTM | v9.3, provisioning saga | Config generator | `org_profiles` | LLM interview | High | v9.4 |
| 31 | Dynamic Widget Platform | P3 | Setup UX | v9.4 | Widget graph engine | `widget_layouts` | LLM | High | v9.5 |
| 32 | Multi-Industry Foundation | P4 | New markets | v9.4, v9.5 | Vertical packs | Pack registry | No | Very high | v10.0 |
| 2 | Communication Hub Expansion | P1 | Parent reach | v8.1, WA integration | Channel adapters | Template tables | Optional | Medium | v8.1+ |
| 13 | Unified Payment Request Engine | P1 | Revenue | v7.0 payments | Payment orchestrator | Extend intents | No | Medium | Post-v8 |
| 14 | Online Payment Enhancements | P1 | Conversion | #13 | Parent payment UX | None | No | Low | Post-v8 |
| 15 | QR Payment Support | P1 | Counter speed | #13, Razorpay | QR intent type | `payment_qr_sessions` | No | Medium | Post-v8 |
| 16 | Offline Payment Tracking | P1 | India reality | Finance collections | Offline receipt flow | Extend collections | No | Low | Post-v8 |
| 7 | Multi-Role Employee System | P3 | Real schools | RBAC v6.1 | Multi-membership | `user_role_assignments` | No | Medium | v9.x |
| 8 | Smart Timetable Expansion | P2 | Daily ops | v7.5 timetable | Engine rules | Extend timetable | Advisor | Medium | v8.x |
| 9 | Workload Engine Expansion | P2 | Fair scheduling | v7.5 | Workload service | None | Rules | Low | v8.x |
| 10 | Inventory & Asset Expansion | P3 | Ops schools | v7.2 inventory | Asset module | `assets` | No | High | v9.x |
| 11 | Book Distribution System | P3 | Textbook ops | Inventory, SIS | Distribution workflow | `book_issues` | No | Medium | v9.x |
| 12 | Inventory Replacement Workflow | P3 | Asset lifecycle | #10 | RMA workflow | `inventory_rma` | No | Medium | v9.x |
| 17 | School Memories | P2 | Engagement | Storage, comms | Media gallery | `school_memories` | Optional | Medium | v9.x |
| 33 | Salon ERP Foundation | P4 | New vertical | v10.0 kernel | Velora pack | Vertical schema | Optional | Very high | v10+ |
| 34 | Hospital ERP Foundation | P4 | New vertical | v10.0 | Hospital pack | Vertical schema | Optional | Very high | v10+ |
| 35 | Restaurant ERP Foundation | P4 | New vertical | v10.0 | Restaurant pack | Vertical schema | No | Very high | v10+ |
| 36 | Hostel ERP Foundation | P4 | Education extension | Hostel read v6.2 | Full write path | Extend hostel | No | High | v10+ |

---

## Cross-cutting tracks (P3/P4)

| Track | Priority | Dependencies | Doc |
|-------|----------|--------------|-----|
| Security & Pen Testing | P3 | v1.0 GA | [`design/Security-Pen-Testing.md`](./design/Security-Pen-Testing.md) |
| Observability & Monitoring | P3 | Production traffic | [`design/Observability-Monitoring.md`](./design/Observability-Monitoring.md) |
| Multi-School SaaS Operations | P3 | First school success | [`design/Multi-School-SaaS-Operations.md`](./design/Multi-School-SaaS-Operations.md) |
| WhatsApp Business Integration | P1/P2 | Communication hub | [`design/WhatsApp-Business-Integration.md`](./design/WhatsApp-Business-Integration.md) |
| Franchise Management | P3 | Multi-school | [`design/Franchise-Management.md`](./design/Franchise-Management.md) |
| Multi-Branch Management | P3 | Branch RLS | [`design/Multi-Branch-Management.md`](./design/Multi-Branch-Management.md) |

---

## v8.0–v8.4 implementation gate (each milestone)

Before code:

1. Architecture review (`docs/ArchitectureReview/v8.x-*.md`)
2. Release plan (`docs/Releases/v8.x-*.md`)
3. Migration plan (SQL file when schema changes)
4. Security review (RBAC + tenant scope)
5. RBAC plan (route inventory update)

After code:

- `deno test` + `flutter test`
- Roadmap + BackendRoadmap update
- Git tag `v8.x-*`

---

## Dependency graph (v8 wave)

```mermaid
flowchart LR
  v80[v8.0 Year Transition]
  v81[v8.1 AI Comms]
  v82[v8.2 Parent Guidance]
  v83[v8.3 Teacher Copilot]
  v84[v8.4 Principal Copilot]
  v85[v8.5 Question Papers]
  v80 --> v81
  v81 --> v82
  v81 --> v83
  v83 --> v84
  v84 --> v85
```

---

## Risk register (evolution)

| Risk | Mitigation |
|------|------------|
| Breaking v1.0 pilot | Contract tests + probe CI on every v8 tag |
| AI cost at scale | Stub mode + per-school token budgets |
| Scope creep | One capability per minor release |
| Year transition data loss | Preview + rollback audit; dry-run required |
