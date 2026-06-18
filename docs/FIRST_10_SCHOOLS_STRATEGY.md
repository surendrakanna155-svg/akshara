# FIRST 10 SCHOOLS STRATEGY — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Premise:** We are launching to our first 10 real schools. What is *mandatory*, what is *optional*, what *adds complexity without value*, what to *postpone*, what to *remove*.
> **Headline:** You do **not** have a feature problem — you have a **depth and focus** problem. The fastest path to 10 happy, paying schools is to **cut ~30% of the surface area** and make **~8 workflows genuinely real** (durable + server-backed).

---

## The strategic reframe

Today the product is ~30% non-school surface area (verticals, SaaS/franchise/white-label) sitting on a mock backend. For first 10 schools, **breadth is a liability** — every extra screen is something to test, secure, translate, theme, and explain. The winning move is **subtraction + depth**.

> A simple ERP with 300 excellent features beats a complicated ERP with 1000 features. Right now Akshara has ~1000 mock features; the goal is ~150 *real* ones.

---

## A. MUST-HAVE (no school will pay without these)

These must be **real (durable data + server-backed)**, not mock:

1. **Login + roles that work on a real backend** (production auth, server RBAC) — turn on API mode for pilot tenants.
2. **Student information (SIS)** — admit, enroll, class/section, profile. *(Mostly there; needs real backend.)*
3. **Attendance** — teacher marks; durable school record; parent sees it. *(Flow is excellent; needs persistence.)*
4. **Fees** — invoice, collect, receipt (real PDF), basic concessions/refunds posting to a ledger. *(Strongest module; finish concession→ledger.)*
5. **Exams (basic, end-to-end)** — create exam → enter marks → publish → parent/student see results + a real report card. **This is the #1 gap and the #1 priority.**
6. **Approvals that persist** — leave, corrections, concessions land in a durable, auditable inbox. *(UI exists; make durable.)*
7. **Notifications parents actually receive** — push + **SMS/WhatsApp** (not just in-app).
8. **Homework** — teacher assigns, student/parent see. *(Mostly there.)*

**Plus the supporting admin a school office needs day one:** admissions/front-office, basic HR (staff directory + leave), and *whichever* of transport/hostel/library that specific school uses (feature-flag per school).

## B. NICE-TO-HAVE (valuable, but a school can start without them)

- Student 360 dossier · timetable optimization · intelligence/analytics dashboards · copilot (as a helper, clearly labeled "assistant") · advanced finance reports · alumni · PTM scheduling · certificates.
- Multi-language UI (important for India — prioritize right after must-haves; framework is 65% done).

## C. ADD COMPLEXITY WITHOUT ENOUGH VALUE (cut from the school build)

Remove or hide behind disabled flags — **not** because they're bad, but because they cost focus:

- **Multi-industry verticals** — salon, restaurant, healthcare, accommodation (20 screens). Zero school relevance.
- **White-label / franchise / multi-school SaaS / platform-ops / organization-builder / evolution / dynamic-widgets / memories / resource-optimization** (~40+ screens). No customer needs these yet.
- **`phase4`/`phase5` shells** — delete (cruft).
- **Live AI inference** — keep the scaffold; defer real LLM until Question Intelligence is funded (Phase 3).

## D. POST-LAUNCH (build after the first cohort is live and happy)

- **Question Intelligence Platform** (the differentiator — see its audit). Build deterministic pieces first.
- Director/trust multi-school comparison (real, not demo IDs).
- Foundation/competitive-exam programs.
- Backup/restore hardening, observability, pen-testing.
- Selective re-introduction of SaaS/multi-industry **only when a paying customer demands it.**

## E. REMOVE ENTIRELY (candidates — owner confirms)

- `phase4`, `phase5` (delete).
- Duplicate/stray screens: stray inventory copilot, one of the two "promotion" screens (rename), timetable duplicates (consolidate).
- The ~28 dead `onPressed:(){}` buttons (wire or hide).

---

## Fastest path to customer satisfaction

1. **Pick the 1–2 most common journeys per persona and make them flawless and real:** teacher→attendance, parent→fees+results, principal→approvals, office→admissions. These create daily "this just works" moments.
2. **Make data durable + send real notifications.** Nothing erodes trust like a vanished approval or a fee reminder the parent never sees.
3. **Hide everything irrelevant.** A principal who never sees "Salon" trusts the product more.

## Fastest path to revenue

- Fees + attendance + notifications are the features schools pay for *immediately* (they replace paper + WhatsApp groups). Get these production-real first; they justify the subscription on their own.
- Exams/report cards are the features that make a school **switch** from a competitor — the #1 differentiator-and-blocker. Second priority.

## Simplest ERP experience

- **Workspace model:** each user sees only their job (`WORKSPACE_ARCHITECTURE_AUDIT.md`).
- **≤5 primary nav items** per surface; everything else under "More."
- **Per-school feature flags:** a small school enables Fees+Attendance+Exams+Homework; turn on Transport/Hostel/Library only if used.

---

## The 90-day shape (illustrative, not a commitment)

| Weeks | Focus | Outcome |
|-------|-------|---------|
| 1–2 | Cut scope (shelve verticals/SaaS, delete phase4/5), strip role over-grants | Clean, school-only build |
| 3–6 | Real backend for SIS/attendance/fees + production auth/RBAC (finish F1 enforcement) | Durable core |
| 5–9 | **Exam chain end-to-end** (assign owner) + report cards | The big gap closed |
| 7–10 | Durable governance (F6/F7) + notifications (push/SMS/WhatsApp) + fix B02b-ATT-01 | Trustworthy ops |
| 9–12 | Workspace model + nav cleanup + dead-button fixes + per-school flags | "Feels simple" |
| 12+ | Pilot 1–2 schools, then scale to 10; begin Question Intelligence track | Live + differentiating |

---

## What "ready for 10 schools" looks like (GO checklist)

- [ ] API mode ON for pilot tenants; production auth; server RBAC enforced.
- [ ] SIS, attendance, fees, exams, approvals all **durable + server-backed**.
- [ ] Report cards + receipts as real PDFs.
- [ ] Push + SMS/WhatsApp notifications live.
- [ ] Non-school modules hidden; roles least-privilege.
- [ ] Workspace nav; ≤5 items; no dead buttons; no QA chrome.
- [ ] Per-school feature flags.
- [ ] Backup/restore + a support runbook.

**Bottom line:** Don't build more. **Cut, deepen, and make real.** Eight rock-solid workflows on a real backend, with the noise removed, will delight 10 schools far more than 1000 mock features ever could — and Question Intelligence then becomes the reason schools choose you over everyone else.
