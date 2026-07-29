# SIM — Real School Simulation (Workstream 3A)

**Workstream:** 3A (Real school simulation) · **Date:** 2026-07-29
**Repo:** `/Users/surendrakanna/Documents/Akshara_ERP-release` · **Branch:** `release/v1.0-playstore`
**Method:** static end-to-end trace of nine operational sequences through the
Flutter client, the Deno backend (`supabase/functions/_shared/**`) and the
migrations, read as *what a person has to do*. Read-only; nothing was changed.

**This builds on Workstream 4 and does not re-derive it.**
`docs/certification/findings/XMOD-cross-module-certification.md` already
established, with evidence: the domain-event outbox is structurally dead (368
write sites, 171 event types, an empty subscriber registry and a drain whose
result set is always empty); nine jobs are written as periodic work and exactly
three crons exist on the VPS (scheduled broadcasts, watchdog, nightly backup);
and 31 human steps are required for the product to produce correct outcomes.

Those are the *mechanics*. This workstream asks the human question: **what does
the office actually have to remember, and what breaks first on a busy morning?**

## The school

Sunrise Public School. 620 students, Classes 1–10, two sections each. 34
teachers, one principal, one vice principal, one accounts clerk, one office
clerk who also runs the front desk, a librarian, a transport in-charge with
6 buses, and a part-time nurse. One person — the office clerk — is the entire
back office. Everyone works from a phone; the accounts clerk has a laptop.

---

<!-- Sequences appended below, one at a time. -->
