# nikshaos.in redesign — session handover

> ## ⛔ SUPERSEDED 2026-07-29 — the site has since been built
>
> Read [`WEBSITE_V1_BUILD_RECORD.md`](./WEBSITE_V1_BUILD_RECORD.md) first. This document remains
> accurate as the record of *design decisions and hard-won pipeline gotchas*, and those still bind.
>
> **Two things below are now factually wrong:**
> - **§2.3 / §13 "4 publishable captures".** The phone-tier captures did not exist on disk —
>   `build/` is git-ignored and had been cleaned. Both tiers were re-captured; `parent-dashboard`
>   is now **unblocked** and `sign-in` is **not publishable** (it carries testing-mode chrome).
> - **§5 palette.** Those hex values predate the brand re-trace. `brand/BRAND_GUIDELINES.md §2` —
>   which §5 itself names as the authority — is canonical.

**Date:** 2026-07-29 · **Branch:** `release/v1.0-playstore` · **Status:** paused, cleanly
**Reason for pause:** owner redirected this session to the messaging/communication workstream.
**Source of truth for design:** [`NIKSHAOS_SITE_REDESIGN_PROPOSAL.md`](./NIKSHAOS_SITE_REDESIGN_PROPOSAL.md) (Rev 2, ~1,070 lines)

> **Website implementation never started, deliberately.** Three gates were agreed and only one is
> met. Nothing is half-built; there is no partial site to clean up.

---

## 1. Where the redesign stopped

| Gate for starting implementation | State |
|---|---|
| Visual design finalised | ⚠️ **Direction agreed, not signed off** — 5-act structure specified to animation level, 6 decisions open (§12) |
| Capture pipeline ready | ✅ **DONE** — built, proven, committed |
| Required product assets exist | ⚠️ **4 of 5 captures publishable**; hero satisfiable, mid-page acts not |

Stopped **immediately before** writing any site code. The live site at `nikshaos.in` is untouched
and still serves the original hand-built static build from `deploy/nikshaos/`.

---

## 2. What is completed

### 2.1 Audit of the live site
Full teardown in proposal §1. The live site is `deploy/nikshaos/src/landing.html` (254 lines) +
`styles.css` (314) assembled by `build_site.mjs` (470) into `dist/`, served from
`/var/www/nikshaos-site`.

**Must survive any redesign** (§1.1) — these are load-bearing:
- **The four legal routes are a contract, not URLs.** `/privacy`, `/terms/user`,
  `/terms/acceptable-use`, `/terms/institution` are the exact `path` values in
  `supabase/functions/_shared/legal/legal_catalog.ts`, joined at runtime to
  `LegalLinks.policyHostBaseUrl` by the Flutter client. **Changing any breaks the in-app
  "view full policy" link.**
- `build_site.mjs`'s placeholder policy — unfilled legal facts render as visible *pending*
  markers, never silently blank.
- `stripInternalNotes()` — strips `> OWNER ACTION:` blockquotes from published legal pages.
- Fail-loud brand asset copying.
- Existing a11y baseline: skip link, `:focus-visible`, 44px targets, `tabular-nums`.

**P0 problems** driving the redesign: the "Screens" section ships three grey placeholder boxes
plus copy admitting the site is unfinished; the product is never shown; nine uniform feature cards
read as a specification rather than an argument.

### 2.2 Capture pipeline — built, proven, committed
Commit **`c74a2b7c`** `feat(marketing): automated, reproducible product screenshot capture`

| File | Role |
|---|---|
| `integration_test/marketing_capture_test.dart` | Declarative shot list; boots app, signs in per persona, asserts anchor, captures |
| `test_driver/marketing_capture_driver.dart` | Host side; writes `build/marketing-capture/<tier>/<name>.png` |
| `scripts/marketing/capture_shots.sh` | Tier orchestration, provenance manifest, always restores device |
| `scripts/marketing/README.md` | Operator guide |

Run: `scripts/marketing/capture_shots.sh {phone|tablet|desktop}`

**★ Patrol cannot screenshot.** The `patrol` package has no screenshot API, and this repo's
`capturePatrolScreenshot` (`patrol_test/helpers/patrol_helpers.dart:47`) returns early on
Android/iOS after writing a `.marker` file — so `patrol_test/screenshots/`, which reads as a
seven-persona screenshot suite, **has never produced an image**. Capture requires
`IntegrationTestWidgetsFlutterBinding`; `PatrolBinding` cannot coexist with it.

**Hard-won gotchas** (all cost real debugging time — do not rediscover):
- Session lives in the **Android Keystore**, not SharedPreferences. `prefs.clear()` does not sign
  out. Without clearing `AuthSessionStorage` + `TokenStorage`, every shot after the first captures
  the *previous* persona's workspace while still looking valid.
- `convertFlutterSurfaceToImage()` is **once per test**, not per process.
- `pumpAndSettle` never returns (continuous animations) — use the bounded `settle()` helper.
- Taps must scroll into view first; a widget mid-screen on phone falls below the fold on tablet.
- **`--profile` is unavailable**: `flutter drive` compiles the integration-test target, which
  imports `flutter_test`, which cannot be AOT-compiled. Debug is visually identical
  (`debugShowCheckedModeBanner: false`).
- Tier = `wm size` **AND** `wm density` together; logical width (`px / (density/160)`) selects the
  layout. The script measures the PNGs and **fails** if the logical width lands outside the tier.
- The manifest needed four fixes before it was trustworthy (stale build mode; inverted
  `workingTreeClean`; a manifest written for a run that captured nothing and still exited 0;
  `physicalSize` recording the requested rather than captured size).

### 2.3 Captures produced
10 across two tiers, reproducible. Currently on disk: `build/marketing-capture/phone/` (5 + manifest).

| Shot | Best tier | Publishable |
|---|---|---|
| `principal-admin-hub` | **tablet** | ✅ Strongest large-format asset — NavigationRail, 3-column grid |
| `teacher-dashboard` | **phone** | ✅ |
| `student-dashboard` | **phone** | ✅ |
| `sign-in` | phone | ✅ |
| `parent-dashboard` | phone | ⛔ **Blocked** — screen contradicts itself (§10) |

### 2.4 Branding sweep
Commit **`7589e091`** — 208 files. Removed pre-rename "Akshara" branding from every user-visible
surface; guard at `test/branding/niksha_branding_guard_test.dart` prevents regression. Related:
`da1dd7e5` re-traced all three brand masters.

---

## 3. Planned but not implemented

**Everything site-side.** No HTML, CSS, or JS was written. Specifically pending:
- All five acts (§5 of the proposal specifies each to transform/scroll-range level)
- The campus blueprint SVG artwork
- Vendoring Inter (currently named in CSS but never loaded — the site has never rendered in its
  own typeface)
- The horizontal wordmark lockup (absent; `styles.css:64` documents the gap)
- `build_site.mjs` image pipeline (manifest → `<picture>` with AVIF/WebP/PNG)
- GSAP + ScrollTrigger integration
- Six missing captures: Student 360, AI Copilot, parent fees/receipt, finance collections,
  attendance register, admissions enrolment, marks entry, dark mode

---

## 4. Important design decisions

| # | Decision | Rationale |
|---|---|---|
| **D1** | Capture pipeline is a **prerequisite workstream** | No usable screenshot existed; 1,604 candidate images all failed |
| **D2** | **Never repair the web ERP for marketing.** Preference: ① Flutter tablet → ② Flutter mobile → ③ web ERP only where already production-quality → ④ **defer the section** | Web ERP is unseeded, error-stating, "Akshara"-branded |
| **D3** | Automated, deterministic, versioned capture | With ~196 open defects the UI will change; hand-captures go stale |
| **D7** | **Every claim evidence-backed**; unverifiable claims qualified or omitted | Gates launch |
| **D9** | Face-verification claim **kept**; treated as committed capability | Owner decision; now being delivered by a separate session |
| **—** | ★ **Governing principle: the marketing website must never drive product work.** The product decides what can be shown. | Owner directive, binding |

### 4.1 ★ Asset-driven architecture (proposal §3.0) — the biggest structural decision

> A section renders **only** if every real capture it needs exists. A section with a missing asset
> is **omitted entirely** — never stubbed, never approximated, never a grey box.

Enforced mechanically in `build_site.mjs`: it logs what it dropped and why. Two consequences:
placeholder UI becomes *unrepresentable*, and omissions are loud.

**This reversed an earlier design.** Rev 1's Act II chained its five beats so each flow-line fed
the next — remove one beat and the chain visibly breaks. Rewritten: acts are **independent and
individually omittable**, and the connective line is computed from the beats that actually render.

**Launch floor = Act 0 + Act IV + Act V.** Publishable, honest, complete-looking on day one, and it
grows richer as captures land — with no rebuild.

### 4.2 ★ A real screenshot can still make a false claim (§10.1)

`02-teacher-dashboard.png` is genuine and unmodified, and shows "Geo+Face verified" — a capability
that could not run when captured. Every pixel real; the claim false. Hence the **depicted-state
rule**: a capture may depict a state reachable in a shipping build, **or** a committed capability
whose gap is recorded and gated. *Reviewing pixels for authenticity is not the same as reviewing
them for truth.*

---

## 5. Branding

**Authority:** `brand/BRAND_GUIDELINES.md`. **Assets:** `brand/niksha-os/{svg,png,icons,play}/`.

**Palette (NIKSHA OS):**

| Role | Hex |
|---|---|
| App canvas / icon background | `#0B1F4B` |
| Deep | `#1E3A8A` |
| Primary | `#2563EB` |
| Light | `#38BDF8` |
| Growth accent | `#10B981` |

Neutrals: `--ink #0F172A` · `--body #334155` · `--muted #64748B` · `--line #E2E8F0` · `--bg-soft #F8FAFC`

**Non-negotiable brand rules:**
1. Gradients run **bottom-left → top-right**. Always. *"A gradient that runs the other way reads as descent."*
2. Green is an **accent, never a fill**.
3. Never recolour a mark outside the palette — use monochrome variants.
4. Body text and the mark clear **4.5:1** on every background.

**Typography:** Inter. Wordmark per §5: Inter 700, tracking `+0.14em`; `OS` sub-label Inter 600 in
brand primary. **Numbers use `tabular-nums` everywhere** — a product rule that must hold on the site.

**Motion tokens** mirrored from `lib/theme/motion.dart` so the site feels like the app:
`instant 80ms · fast 120ms · standard 180ms · slow 240ms`; enter `easeOutCubic`
(`cubic-bezier(.215,.61,.355,1)`), exit `easeInCubic`; reveal start scale `0.98`.

**Tone:** specific, verifiable, non-boastful. The current privacy section is the reference for
register — keep its substance, change only its staging.

**Naming:** product = **NIKSHA OS**; company = **NIKSHA Technologies Pvt. Ltd.** Product
self-reference uses "NIKSHA OS", company reference uses "NIKSHA". Android package id stays
`com.akshara.erp` (immutable after first Play upload, never user-visible).

---

## 6–7. Landing page structure, sections, components

**Organising metaphor:** *A school is a building. NIKSHA OS is its blueprint made operational.* —
chosen because the blueprint language **already exists** in the product (the open-book line art in
the app canvas) and in the brand (*"N rising from an open book, summit flag"*).

Total scroll ≈ 6.5 viewports desktop.

```
Header (glass, shrinks on scroll)
├─ ACT 0 · APERTURE ......... "The school, in one system."     ~1.6vh  REQUIRED
├─ ACT I  · THE RECORD ...... "One student. One record."       ~1.8vh  optional
├─ ACT II · THE JOURNEYS .... 5 beats, degrades by beat        ~2.2vh  optional (≥2 beats)
├─ ACT III· THE BOUNDARY .... "It answers. It never edits."    ~1.0vh  optional
├─ ACT IV · THE GUARDRAILS .. DPDP, roles, audit trail         ~0.9vh  REQUIRED (copy only)
└─ ACT V  · CLOSE ........... sign in / talk to us             ~0.6vh  REQUIRED
Footer
```

**The nine feature cards are deleted**, their content redistributed into Acts II and IV.

### Act 0 composition — mixed-format, evidence-based

| Layer | Content | z |
|---|---|---|
| 1 · far | Campus blueprint plane | `-620px` |
| 2 | Ambient glow (`#38BDF8` @14%) | `-400px` |
| 3 · context | **Admin Hub, tablet** — dimmed ~70%, the system behind the phones | `-160px` |
| 4 · **anchor** | **Teacher dashboard, phone** | `0` |
| 5 | **Parent app phone**, forward-left | `+210px` |
| 6 · near | AI Copilot card | `+300px` (omitted until captured) |

Headline/sub at `z: +60px`.

**Why mixed-format, decided on evidence:** capturing at both tiers proved the **ERP shell** renders
a genuine large-format dashboard on tablet, while **persona apps** are correct only on phone (at
tablet they show a capped column, mid-word text breaking, an overlapping AI affordance and a
duplicated row). So D2's preference resolves **per shot**. This also keeps the product's own first
pillar honest — *"Mobile-first, genuinely"* — which a desktop-dashboard hero would contradict.

---

## 8. UX / animation decisions

Full beat-by-beat spec in proposal §5. Highlights:

- **Act 0:** entrance far→near, 90ms stagger; **mouse parallax** ±6° rotateY / ±4° rotateX, lerped
  at 0.08 in **one rAF loop** with a single listener; scroll dollies the scene `translateZ 0→+260px`;
  idle drift ±4px sine, **paused off-screen**.
- **Act I:** pinned, 4 beats — decompose → glowing Student Record → reconnect (SVG
  `stroke-dashoffset`, 80ms stagger, one `#38BDF8` pulse per line) → settle.
- **Act II:** 5 pinned beats; each beat's last flow node is the next beat's first — **computed from
  the beats that render**, never a fixed chain. Slim clickable progress rail of real `<button>`s.
- **Act III:** inbound read-paths draw; a single outbound line hits a boundary, flares once, and
  **retracts — once**. Repeating it would turn a serious claim into a gimmick.
- **Act IV:** reveal only, 60ms stagger. Deliberately the calmest act — after Acts 0–III, restraint
  reads as seriousness.
- **Interaction rules:** no scroll hijacking, ever; cursor stays `default` over non-interactive
  screenshots so nothing promises interactivity it lacks.
- **Reduced motion:** `prefers-reduced-motion` **removes** all scrubbed motion and 3D — not
  "reduces". Every act renders in its **final composed state**. Checked via `matchMedia` before any
  timeline is built.
- **Build order:** static/reduced-motion state **first**, motion layered on after — so the
  fallback is a designed artifact, not a degraded leftover.

**Responsive:** ≥1280 full cinematic · 1024–1279 depth at ~60% amplitude · 768–1023 depth kept,
pinning dropped · <768 **no scrubbing, no pinning, no 3D** — static compositions, one 240ms reveal.
Mobile is deliberately plain because the audience opens links on mid-range Android over 4G.

---

## 9. Assets required

**Have:** 4 publishable captures (§2.3); brand marks in `brand/niksha-os/`.

**Need — captures:** Student 360 (Act I centrepiece), **AI Copilot** (Act III cannot ship without
it), parent fees/receipt, finance collections, attendance register, admissions enrolment, marks
entry, one dark-mode shot.

**Need — artwork:** campus blueprint SVG (vector, <40KB, single colour `#2563EB`, 5–8% opacity on
light / 10–12% on navy, `aria-hidden`, animated only by `translate3d`); horizontal wordmark lockup;
vendored Inter variable woff2 (subset latin + latin-ext, `font-display: swap`, `size-adjust` tuned).

**Blocked:** `parent-dashboard` — summary tiles read `Attendance —`, `Fees due —`, `Grade —` while
the same facts appear populated below (`92% Present`, `₹4,200 due`). Honest-state dashes are correct
when data is *absent*; here it is present and the tiles aren't reading it. Reported, not fixed (D2).

---

## 10. SEO and performance goals

| Metric | Budget | Measured on |
|---|---|---|
| LCP | **< 2.0s** | Moto G-class Android, 4G |
| CLS | **< 0.02** | all breakpoints |
| INP | **< 200ms** | desktop + mobile |
| JS (gz) | **< 100KB** | GSAP+ScrollTrigger ≈50KB, site ≈15KB |
| Above-fold images | **< 300KB** | AVIF |
| Sustained scroll FPS | **≥58** desktop / **≥55** tablet | DevTools trace |

**Rules that make 60fps achievable:** animate only `transform`/`opacity`; `will-change` applied on
`onEnter` and **removed on `onLeave`**; ≤12 composited layers per act; one rAF loop, zero scroll
listeners; **`backdrop-filter` in exactly one place** (the sticky header) — it is the single most
expensive property on Safari and low-end Android; `content-visibility: auto` on off-screen acts;
AVIF→WebP→PNG with explicit dimensions; **no WebGL**.

**SEO:** existing meta/OG/canonical/twitter-card are sound — carry them forward. Keep semantic
landmarks, one `<h1>`, sequential `h2` per act. **The DOM must be complete and readable with JS
off** — which is also what crawlers and link previews see.

★ **A constraint from the claims register:** *"no third-party trackers"* is a published claim, so
the site must ship **zero third-party scripts** — no analytics, no CDN fonts, no embeds. Keeping
that claim true is a build constraint, not a preference.

---

## 11. Files, branches, commits

**Branch:** `release/v1.0-playstore` (⚠️ shared worktree — a face-verification session is active in
it; always `git branch --show-current` before committing, and expect unrelated uncommitted files).

| Commit | Scope |
|---|---|
| `a8ed4ce7` | `docs(website)` — proposal, branding record, WhatsApp brief |
| `c74a2b7c` | `feat(marketing)` — capture pipeline |
| `7589e091` | `feat(branding)` — 208-file NIKSHA sweep + guard |
| `da1dd7e5` | `feat(brand)` — re-traced masters |

**Files:**
- `docs/website/NIKSHAOS_SITE_REDESIGN_PROPOSAL.md` ← **the design SSOT**
- `docs/website/WEBSITE_REDESIGN_HANDOVER.md` ← this file
- `docs/engineering/NIKSHA_RENAME_RESIDUE_HANDOVER.md`
- `deploy/nikshaos/` ← live site source (`src/landing.html`, `src/styles.css`, `build_site.mjs`, `nginx/`)
- `scripts/marketing/`, `integration_test/marketing_capture_test.dart`, `test_driver/marketing_capture_driver.dart`
- `brand/BRAND_GUIDELINES.md`, `brand/niksha-os/`
- `build/marketing-capture/` (git-ignored)

**Infrastructure:** `nikshaos.in` + `www` → product website (`/var/www/nikshaos-site`);
`api.nikshaos.in` → edge API; `app.nikshaos.in` → web ERP. Migration complete (`20cced08`).
⚠️ Shared VPS — never edit other sites' nginx files.

---

## 12. Remaining recommendations & open decisions

| # | Decision | Recommendation |
|---|---|---|
| **D4** | Mark-attendance shot has a real UI defect (docked AI button overlaps action bar) | **Omit the screen.** Under D2 the website must not commission the fix |
| **D5** | Which branch | `release/v1.0-playstore` — domain, rename and site are one product decision |
| **D6** | Draw the horizontal wordmark lockup | **Yes** — pure brand work, doesn't touch the product |
| **D8** | Dark mode for the site itself | **Not in v1** — the product's dark theme can still appear in screenshots |
| **D10** | Claim 11 *"enforced in the database"* | Re-assess: `521b7e57` verified 9/9 live checks, but those didn't measure **row-level** enforcement. Keep "access is enforced"; keep "in the database" only if separately verified |
| **D11** | Admin Hub phone-tier card defect | Use the **tablet** capture (defect is phone-width only) |

**Also re-verify before launch:** claim 14 — *"runs … for Indian schools"* (plural present tense)
against a live DB at demo scale (10 schools, 5 students) and `APP_ENV=staging` as a ratified
pre-launch gate.

**Sequencing:** W3 blueprint + Inter + lockup → W4 `build_site.mjs` image pipeline → W5 acts
(**static state first**) → W6 perf on real low-end Android + a11y + claims review → W7 deploy + EOS gate.

---

## 13. Continuation prompt for a new session

Copy everything between the markers.

```text
=== BEGIN ===
Continue the nikshaos.in website redesign for NIKSHA OS (an AI-powered School Operating System,
Flutter + Supabase edge, Indian schools).

REPO: /Users/surendrakanna/Documents/Akshara_ERP-release
BRANCH: release/v1.0-playstore

READ FIRST, IN ORDER:
1. docs/website/WEBSITE_REDESIGN_HANDOVER.md   (state, decisions, open items)
2. docs/website/NIKSHAOS_SITE_REDESIGN_PROPOSAL.md  (design SSOT, ~1,070 lines — the full
   5-act spec with every animation, transform, performance budget and a11y rule)
3. brand/BRAND_GUIDELINES.md  (palette, gradient direction, wordmark)
4. scripts/marketing/README.md  (capture pipeline operator guide)

WHERE IT STOPPED
Design direction agreed and fully specified; capture pipeline built, proven and committed; NO
site code written. Live site still serves the original hand-built build from deploy/nikshaos/.

BINDING RULES — do not violate:
- The marketing website must NEVER drive product work. The product decides what can be shown.
  If a capture is unusable, OMIT the section; never open a UI ticket so the site can have a picture.
- Asset-driven: a section renders only if its real captures exist, else it is omitted entirely.
  Never a placeholder, stub, mockup, or invented UI. Enforce in build_site.mjs and LOG omissions.
- Launch floor = Act 0 + Act IV + Act V. That page is publishable alone.
- Every claim must be evidence-backed (D7). Unverifiable → qualify or omit.
- Depicted-state rule: a capture may show a state reachable in a shipping build, or a committed
  capability whose gap is recorded and gated. A 100% real screenshot can still make a false claim.
- ZERO third-party scripts — the site publishes a "no third-party trackers" claim. No analytics,
  no CDN fonts, no embeds.
- DO NOT change these four legal routes — they are joined at runtime by the Flutter client from
  supabase/functions/_shared/legal/legal_catalog.ts:
  /privacy, /terms/user, /terms/acceptable-use, /terms/institution
- Preserve in build_site.mjs: the pending-marker placeholder policy, stripInternalNotes(), and
  fail-loud brand asset copying.
- SHARED WORKTREE: other engineering sessions commit to this branch. Run
  `git branch --show-current` before every commit and expect unrelated uncommitted files.
  Never commit another lane's work.

WHAT EXISTS
- Capture pipeline: scripts/marketing/capture_shots.sh {phone|tablet|desktop}
  → build/marketing-capture/<tier>/*.png + manifest.json
  Gotchas already paid for (do NOT rediscover): Patrol cannot screenshot; the session lives in the
  Android Keystore not SharedPreferences; convertFlutterSurfaceToImage() is once PER TEST;
  pumpAndSettle never returns; --profile cannot build the integration-test target; tier =
  wm size AND wm density together.
- 4 publishable captures: principal-admin-hub (TABLET — the strongest large-format asset),
  teacher-dashboard, student-dashboard, sign-in (all PHONE).
  BLOCKED: parent-dashboard (its summary tiles show "—" while the same values render populated
  below). Reported to the product backlog; do not fix it here.

DESIGN IN ONE PARAGRAPH
Metaphor: "A school is a building. NIKSHA OS is its blueprint made operational" — the blueprint
language already exists in the product (open-book line art in the app canvas) and the brand
("N rising from an open book"). Five acts: 0 Aperture (mixed-format depth scene — tablet Admin Hub
held back as context, phones forward as the anchor), I The Record (decompose → glowing Student
Record → reconnect), II The Journeys (5 independently-omittable beats), III The Boundary
("It answers. It never edits." — an outbound write-path draws, hits a boundary, retracts ONCE),
IV Guardrails (calmest act, copy only), V Close. Motion tokens mirror lib/theme/motion.dart.
prefers-reduced-motion REMOVES all scrubbed motion and 3D — build the static state FIRST.

PERFORMANCE BUDGETS (measured on a Moto G-class Android over 4G, not a MacBook)
LCP <2.0s · CLS <0.02 · INP <200ms · JS <100KB gz · above-fold images <300KB · ≥58fps desktop.
Animate only transform/opacity; will-change added onEnter and REMOVED onLeave; one rAF loop, zero
scroll listeners; backdrop-filter in exactly ONE place (the sticky header); no WebGL.

RECOMMENDED NEXT STEPS
1. Capture the missing shots: Student 360, AI Copilot (Act III cannot ship without it), parent
   fees/receipt, finance collections, attendance register, admissions enrolment, marks entry, dark.
2. Draw the campus blueprint SVG (<40KB, #2563EB, 5–8% opacity, aria-hidden).
3. Vendor Inter (it is named in CSS today but never loaded — the site has never rendered in its
   own typeface) and draw the horizontal wordmark lockup.
4. Extend build_site.mjs: manifest → <picture> AVIF/WebP/PNG with explicit dimensions; fail loudly
   on an unmanifested capture; log omitted sections.
5. Build Acts 0/IV/V (the launch floor) STATIC first, then layer motion via GSAP ScrollTrigger.
6. Perf pass on a real low-end Android; a11y audit; claims review; then EOS gate.

OPEN DECISIONS (see handover §12): D4 mark-attendance defect · D6 wordmark lockup · D8 site dark
mode · D10 the "enforced in the database" claim · D11 Admin Hub phone defect.

Start by reading the two docs above and confirming the current capture inventory, then propose
your first concrete step. Do not begin writing site code until you have confirmed which acts are
satisfiable from existing assets.
=== END ===
```
