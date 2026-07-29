# nikshaos.in v1 — build record

**Date:** 2026-07-29 · **Branch:** `release/v1.0-playstore` · **Status:** built, verified locally, **awaiting owner review before deploy**
**Design SSOT:** [`NIKSHAOS_SITE_REDESIGN_PROPOSAL.md`](./NIKSHAOS_SITE_REDESIGN_PROPOSAL.md) (Rev 2)
**Predecessor:** [`WEBSITE_REDESIGN_HANDOVER.md`](./WEBSITE_REDESIGN_HANDOVER.md) — the state this session started from

The landing page is built. The three placeholder boxes and the copy admitting the site was
unfinished are gone; every pixel of product on the page is a real, provenance-tracked capture.

---

## 1. ★ The handover's asset inventory was stale — corrected before anything was built

The handover recorded **"4 of 5 captures publishable"**, three of them at phone tier. On disk there
was **one usable capture**. This was found by opening every file rather than trusting the list, and
it changed the whole plan, so it is recorded first.

| Handover said | Actually on disk (2026-07-29) |
|---|---|
| `teacher-dashboard` ✅ (phone) | **phone tier gone.** `build/marketing-capture/phone/` was empty — `build/` is git-ignored and had been cleaned. Only an unusable tablet capture survived |
| `student-dashboard` ✅ (phone) | same — gone |
| `sign-in` ✅ (phone) | same — gone |
| `principal-admin-hub` ✅ (tablet) | ✅ present, and genuinely excellent |
| `parent-dashboard` ⛔ blocked | still blocked at the time |

**Resolution:** the emulator was available and the capture pipeline worked exactly as documented, so
both tiers were re-captured (`scripts/marketing/capture_shots.sh phone`, then `tablet`). This did
more than restore the set:

- **`parent-dashboard` is UNBLOCKED.** Its summary tiles previously read `Attendance —`, `Fees due —`,
  `Grade —` while the same values rendered populated below (proposal §6.5b). They now read
  **`Present` / `1` / `₹4,200`**. The self-contradiction that blocked the shot is resolved, and the
  screen is the most on-brand capture we have — its header reads **"NIKSHA Demo School"**.
- **The D12 rename is confirmed landed** in the running app, not just in source.
- **The one ⚠ the proposal could not close is now closed.** §6.3 listed "phone-tier constants
  `1080x2160 @443` → logical 390" as *"not confirmed on device"*. The new manifest records
  `"logicalWidth": 390` **measured from the captured pixels**. Confirmed.

**Lesson worth keeping:** captures live in a git-ignored directory, so a capture inventory in a
document is a claim about a directory that may no longer exist. `deploy/nikshaos/src/product-shots/`
is committed precisely so the published set cannot evaporate this way again.

---

## 2. What is published, and what is not

Promotion is an explicit allow-list in `scripts/marketing/promote_shots.mjs`. Every entry carries
both reviews (§6.6 data hygiene, §10.1 depicted-state) and copies its provenance — commit, device,
build flags, UTC timestamp, measured pixels — into `product-shots/shots.json`.

**Published (4):**

| Shot | Tier | Why this tier |
|---|---|---|
| `principal-admin-hub` | **tablet** | The large-format story: navigation rail, 3-column module grid, 1,248 students / 86 staff / 96% attendance |
| `teacher-dashboard` | **phone** | 89% ring, honest amber "attendance not marked" nudge, real timetable |
| `parent-dashboard` | **phone** | Newly unblocked; carries the NIKSHA brand and real fee/attendance state |
| `student-dashboard` | **phone** | Timetable, submissions, honest attendance |

**Refused, with the reason recorded in `shots.json` rather than silently dropped:**

- **`sign-in` (both tiers)** — the demo-auth build renders *"Testing mode — choose a demo account"*,
  a *"Testing accounts"* persona row and *"Testing OTP: 123456 only"*. That is **QA/debug chrome,
  forbidden outright by §6.1.** The handover listed this shot as publishable; it is not, and this
  is a second correction to the inherited inventory. It becomes publishable only from a build
  without `ENABLE_DEMO_AUTH`.
- **`principal-admin-hub` (phone)** — decision **D11 confirmed by inspection**: every module card
  leaves its right half and lower area empty, three cards fill the viewport where thirteen fit on
  tablet, and the workspace header loses its stats row entirely. Tablet is used instead.
- **All persona dashboards (tablet)** — §6.5b confirmed: *"Mathematics"* breaks mid-word into
  *"Mathema / tics"*, content caps at ~63% of the canvas leaving a dead band, the docked AI
  affordance overlaps a row, the "Attendance not marked" row renders **twice**, and the student AI
  card still reads *"AKSHARA …"*.

Per **D2**, none of these were fixed for the website. They are reported below and the affected
sections use another tier or are omitted.

### Product defects this build surfaced (reported, not fixed)

1. **Teacher dashboard, phone** — the app-bar title truncates to **"Dashbo…"** and the period chip
   to "Period 3 · 1…" at logical 390. New; not previously recorded.
2. **Docked AI affordance overlaps content** on the teacher, parent and student dashboards at phone
   tier — the known UXR-G2 defect, still present.
3. **Admin Hub phone card layout** (D11) and **tablet persona layouts** (§6.5b), as above.

---

## 3. What was built

| Area | State |
|---|---|
| **Acts 0 / II / IV / V** | Built. Static composed state first, motion layered after |
| **Acts I / III** | **Omitted** — no Student 360, no AI Copilot capture. The build prints why |
| **Campus blueprint** | `src/blueprint/make_blueprint.mjs` → `blueprint.svg`, **22.2KB** (3.1KB gz), budget 40KB |
| **Inter** | **Vendored at last** — latin 48KB + latin-ext 85KB, variable, self-hosted, preloaded, OFL shipped. The site had never rendered in its own typeface |
| **Image pipeline** | manifest → AVIF/WebP/PNG at 4 widths, `<picture>` with explicit dimensions |
| **Act gating** | Mechanical in `build_site.mjs`; a missing capture omits its act and prints the omission |
| **nginx** | Added AVIF/WebP MIME types, `/shots/` 180d cache, fonts 1y immutable |

**Preserved verbatim, as required:** the four legal routes (`/privacy`, `/terms/user`,
`/terms/acceptable-use`, `/terms/institution` — all four verified present in the built DOM), the
pending-marker placeholder policy, `stripInternalNotes()`, and fail-loud brand asset copying.

`src/landing.html` is **deleted** — it was the source of the three grey placeholder boxes.

---

## 4. Decisions taken — the ones that need owner ratification are marked ★

### ★ D-A · The palette is the re-traced one, not the handover's

The handover §5 lists `#1E3A8A / #2563EB / #38BDF8 / #10B981`. `brand/BRAND_GUIDELINES.md §2` —
which the handover itself names as **the authority** — lists **`#022997 / #0234B8 / #013AC8 /
#0496F3 / #0AA565`**. The guideline values are *measured from the approved reference board* by
`trace_from_reference.js`; the handover's list is a stale copy predating the re-trace. **The site
uses the guideline values.** All contrast pairs re-verified (§6).

### ★ D-B · Act II is the four personas, not the five module journeys

The specified Act II needs admissions enrolment, marks entry, a fee receipt and the copilot — none
of which exist. Under §3.0 that act is omitted. Rather than lose the argument, Act II is built as
**"Four people. One version of the truth."** using the four captures that do exist. It carries the
identical product claim, degrades card by card, and disappears below two cards. **This is a new act
definition and is the main thing to accept or reject.** The original five-beat act remains recorded
in `DEFERRED_ACTS` and can be built when its captures land.

### ★ D-C · The AI framing is not carried into v1

Claim 16 (§10) makes the H1 *"The AI Operating System for Schools"* defensible **only if Act III
describes the boundary honestly**. Act III is omitted, and claim 10 (*"architecturally prevented
from writing"*) is still ⚠ — what exists is a system prompt and read-only quota checks, not a proven
architectural boundary. Per that condition the H1 is now **"The school, in one system."** and the
page makes **no AI capability claim at all**. This is a positioning change and needs owner sign-off.

### D-D · D6 (wordmark lockup): typeset, deliberately not drawn

The recommendation was "yes, draw it". **It must not be hand-drawn.** Every master is a traced
build-output of `brand/_reference/niksha-brand-board.png`, and hand-authored geometry is explicitly
barred — an earlier hand-drawn revision drifted from the reference and was replaced wholesale. The
name is therefore typeset to the §5 specification (Inter 700, `+0.14em`, "OS" in Inter 600 brand
primary) beside the approved symbol. Now that Inter is genuinely vendored this renders **as
specified** rather than as a fallback. To get a real lockup: add it to the board and re-trace.

### D-E · No GSAP in v1

GSAP + ScrollTrigger (~50KB gz) was budgeted for the pinned, scrubbed timelines of Acts I and II —
exactly the acts omitted for missing captures. What remains needs no timeline engine. **`site.js`
is 4.0KB gzipped against a 100KB budget**, with no dependency and no build step. If Act I or III is
ever built, vendor GSAP then; do not hand-roll pinning.

### Other decisions
- **D4** — mark-attendance omitted, as recommended. **D8** — no site dark mode in v1.
- **D11** — tablet Admin Hub used; phone defect confirmed and reported.
- Act 0 layer 5 sits **forward-right** rather than the spec's forward-left: layer 6 (the Copilot
  card) is omitted, and with five layers the composition only balances if the phones flank the
  dashboard.

---

## 5. Claims register — what changed on the page

| # | Register verdict | What the page now says |
|---|---|---|
| 11 | ⚠ + **D10** | *"in the database"* **removed**. Now: "Every request is authenticated and checked against the user's role and school before it is served." The live 9/9 checks (`521b7e57`) did not measure row-level enforcement. Restore only if that is separately verified |
| 13 | ⚠ on *"always"* | Now names the three domains it actually covers: "Corrections to money, marks and attendance…" |
| 14 | ⚠ plural present tense | Now "Currently in pilot with schools in India" — no implied installed base |
| 16 | ⚠ positioning | H1 and `<title>` no longer front-load AI (see D-C) |
| 10 | ⚠ unresolved | **The claim does not appear.** Act III is not built |
| 7 | ✅ and **binding** | "This website loads no third-party script of any kind" — **verified: zero third-party requests** |
| 9 | ✅ **D9** | Face verification claim stands; the teacher capture showing "Geo+Face verified" is published under the depicted-state rule, gap tracked |

---

## 6. Verified, not asserted

Measured on the built output; every number below was produced by running something.

| Budget (§8.1) | Target | Measured |
|---|---|---|
| JS, gzipped | < 100KB | **4.0KB** |
| CSS, gzipped | — | 8.2KB |
| HTML, gzipped | — | 4.6KB |
| Above-fold images | < 300KB | **36.6KB** desktop · **28KB** for *every* image on mobile |
| Third-party scripts | **zero** | **zero** — only `nikshaos.in` / `app.nikshaos.in` appear |
| Blueprint SVG | < 40KB | 22.2KB (3.1KB gz) |

**Accessibility**
- Contrast: **16/16 pairs pass** — body/muted text on white and on `bg-soft`, four foregrounds on
  navy, focus ring on both grounds, and the green accent bar. Brand rule 4 (4.5:1) holds everywhere.
- One `<h1>`; heading order sequential with no skips; `main`/`nav`/`header`/`footer` all present;
  skip link retained.
- **All 9 images carry real alt text and explicit `width`/`height`** (zero CLS by construction).
- Decorative blueprint and glow layers are `aria-hidden`.
- **Touch targets: 0 controls under 44px** — the header "Sign in" was 43px and was fixed.
- **Reduced motion verified by emulation:** 9 reveal elements, **0 armed, 0 transparent, 0
  transformed**, `motion-ok` never applied, no pointer transform — while the layers keep their
  static depth, so Act 0 still reads as composed. The final state, not a degraded leftover.
- **No-JS:** every heading, claim and CTA is present in the served HTML.

**Responsive:** verified at 390 (real mobile emulation), 1440. Document `scrollWidth` equals the
viewport at 390 — no horizontal overflow. Below 768px the 3D is dropped and the tablet layer is
hidden, per §7; the Admin Hub still reaches mobile readers in Act II.

---

## 7. Not done / open

1. **★ Owner review of D-A, D-B, D-C above** — these are the gating decisions.
2. **Not deployed.** Nothing has been copied to `/var/www/nikshaos-site`. The nginx change needs
   installing (`nginx -t && systemctl reload nginx`) for the AVIF MIME type and the new cache rules.
3. **Legal placeholders remain** — registered address, Grievance Officer, governing-law seat still
   render as visible `pending` markers. Owner action, and a launch gate.
4. **Not measured on real hardware.** LCP/INP/FPS targets are specified against a Moto G-class
   Android over 4G (§8.1). The byte budgets are met with large margins, but the field numbers have
   not been taken. This is the largest remaining verification gap.
5. **Captures that would unlock more:** Student 360 (Act I), AI Copilot (Act III — *and* claim 10
   must be verified first), fee receipt, finance collections, admissions enrolment, marks entry,
   one dark-mode shot.
6. **`sign-in` needs a non-demo build** to be publishable.

---

## 8. How to work on it

```bash
scripts/marketing/capture_shots.sh phone      # or tablet
node scripts/marketing/promote_shots.mjs      # explicit allow-list + provenance
node deploy/nikshaos/src/blueprint/make_blueprint.mjs
npm i sharp --no-save                         # build tooling only, not a repo dependency
node deploy/nikshaos/build_site.mjs           # prints every omitted act and why
```

⚠ **Shared worktree.** Other lanes commit to `release/v1.0-playstore`. Run
`git branch --show-current` before every commit and expect unrelated uncommitted files.
