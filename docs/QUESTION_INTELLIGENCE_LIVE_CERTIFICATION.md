# Question Intelligence — Live Certification

**Status:** ✅ PRODUCTION CERTIFIED (2026-06-25)
**Live cert:** `scripts/qa/live_cert_question_intelligence.py` — **20/20** against the VPS pilot (real auth, real DB, real RBAC, real AI).

## Scope

The bank-first question-paper subsystem built across Batches 8b/8c + the
single-question correction batch: question bank → deterministic blueprint solver →
constrained AI gap-fill (candidates only, never auto-published) → submit / review /
approve governance → publish gate → single-question corrections, with **principal-only
validation** (`approveEducation`). It was built, unit-tested, and deployed live, but had
never been put through a B-series end-to-end live certification (the correction batch
explicitly never completed an authenticated round-trip live, blocked by OTP cooldown).
This certification closes that gap using edge-minted JWTs (no OTP friction).

## Defect found & fixed (the only change this batch)

**`permission denied for table subject_templates` → 500 instead of 422.**
The hard syllabus boundary (`education_syllabus_boundary.ts`) falls back to the global
`subject_templates` catalogue when a school has not yet materialised its own
`syllabus_chapters` for a class + subject. The edge runs as the non-bypass `erp_tenant`
role, which had **no SELECT grant** on `subject_templates`, so that fallback raised a
permission error surfaced as a generic `EDUCATION_ERROR` 500 — meaning **any school
relying on the global catalogue (i.e. freshly onboarded, no materialised syllabus) would
get a 500 on paper generation**, not a clean 422 / on-catalogue validation.

- **Fix:** migration `20260728000000_subject_templates_tenant_read.sql` —
  `GRANT SELECT ON subject_templates TO erp_tenant`. `subject_templates` is a global,
  board-agnostic, RLS-off reference catalogue (no tenant data), so a plain read grant is
  correct and safe — mirrors how other reference catalogues (e.g. `widget_registry`) are
  exposed to tenants. Applied live as `supabase_admin` + ledgered. No code/edge change.

## Live cert — 20/20

Real VPS, real prod DB, edge-minted school-scope JWTs (a `teacher` with
view+manageEducation and a `principal` with +approveEducation):

- **RBAC:** unauth 401 · read needs `viewEducation` (403) · school scope required (org-scope 403).
- **Question bank:** create 5 items (source=teacher, status=active, reviewStatus=approved) · list persists 5.
- **Syllabus boundary:** an off-syllabus chapter is rejected **422 OFF_SYLLABUS** (the fixed path).
- **Deterministic solver:** bank-first paper, `bankReuseCount=5`, `unfilledGapCount=0`, item marks sum **exactly** to 10, all items `source=bank`, paper opens `draft` (no stub text).
- **Governance:** submit → `submitted`; publish-before-approval blocked **409 PAPER_NOT_APPROVED**; teacher cannot review **403** (principal-only); principal approves → `approved`; principal publishes → `published`.
- **Corrections:** editing a published paper is locked **409 PAPER_NOT_EDITABLE**; editing an *approved* paper resets it to `draft` (must be re-approved).
- **AI gap-fill (real):** a long-answer slot the bank cannot fill yields a real AI candidate (`aiCandidateCount=1`, pending moderation); the pending candidate **blocks publish 409 PAPER_HAS_PENDING_ITEMS**; moderating it clears the block. (Safe-by-default: if AI were unavailable the gap is reported honestly with no stub — the harness records that as BLOCKED, never a fabricated question.)
- **Audit:** education events recorded against the paper entity ids.
- **Teardown:** all cert papers / items / reviews / bank items / audit rows removed via `supabase_admin` (bypasses RLS + the missing `erp_tenant` DELETE grant). Clean.

## Roles in the certified flow

Subject teacher (`manageEducation`) creates/edits/fixes/moderates AI candidates and
submits → principal-level reviewer (`approveEducation`) validates (approve or request
changes) and publishes. Teachers cannot sign off their own paper.
