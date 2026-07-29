# nikshaos.in — Complete Redesign Proposal

**Date:** 2026-07-29 · **Rev 2** · **Status:** design under refinement; capture pipeline APPROVED and in build
**Scope:** the public product website at `nikshaos.in`. Not `app.nikshaos.in`, not `api.nikshaos.in`.
**Source of the current site:** `deploy/nikshaos/` on `release/v1.0-playstore`.

> **Website implementation has NOT begun and will not begin until all three gates are met:**
> visual design finalised · capture pipeline ready · required product assets exist.

---

## Owner decisions — recorded 2026-07-29

| Ref | Decision | Status |
|---|---|---|
| **D1** | Capture pipeline approved as a **prerequisite workstream**. No placeholder UI, no concept dashboards, no generated mockups. | ✅ **APPROVED — in build** |
| **D2** | Do **not** repair the web ERP for marketing. Representation preference order: **① Flutter tablet → ② Flutter mobile → ③ web ERP only where already production quality → ④ defer the section until the UI exists.** | ✅ **APPROVED** |
| **D3** | Automated Patrol-driven pipeline: deterministic demo data, high-resolution, reproducible, **versioned so future UI changes regenerate assets**. | ✅ **APPROVED — in build** |
| **D7** | Every statement must be **evidence-backed**. If a claim cannot be verified on the deployed production environment: **qualify it accurately, or omit it until verified.** Never exaggerate. | ✅ **APPROVED — gates launch** |
| — | **Governing principle:** *the marketing website must not drive product work.* The product determines what can be shown. | ✅ **BINDING** |

**Consequences that reshaped this document:** §3.0 (asset-driven architecture and the
deferral policy), §6 (the pipeline as actually built), §10 (per-claim evidence register).

---

## 0. Executive summary — read this first

The brief asks for a cinematic, depth-based product website built **entirely on real product
screenshots**. The design is the easy half. This audit found that the hard half — the
screenshots — **does not currently exist in a usable form**, and that is the real critical path.

Three findings change the shape of the project:

| # | Finding | Consequence |
|---|---|---|
| **F1** | **No usable product screenshot exists today.** All 1,604 candidate images in the repo fail for marketing use (§2). Only **3** real screenshots exist — phone-only, two personas, captured by hand. | The redesign is gated on building a **capture pipeline**, not on writing CSS. This is the long pole. |
| **F2** | The hero the brief describes needs a **large-format Principal Dashboard**. The web ERP that would provide it is currently **broken, unseeded, and still branded "Akshara"**. | Capture the *Flutter* app at tablet size instead. Avoids a dependency on repairing the web ERP. §6.2 |
| **F3** | `release/v1.0-playstore` HEAD is a **security pause** — confirmed unauthenticated exposure on the live pilot, tenant-isolation self-check red. | **Never capture from the live pilot.** Capture only from a local demo build. Also forces a claims review (§9) before publishing privacy language. |

**What I recommend:** approve the design direction in §4–§7, and approve the capture programme in
§6 as a *prerequisite wave*. Implementation of the site itself is ~1 week of work; the capture
pipeline is what determines the launch date.

**What I need decisions on:** §11.

---

## 1. Audit of the current website

The live site is a hand-authored static build: `deploy/nikshaos/src/landing.html` (254 lines) +
`src/styles.css` (314 lines), assembled by `build_site.mjs` (470 lines) into `dist/`, served by
nginx from `/var/www/nikshaos-site`.

### 1.1 What is genuinely good and must survive the redesign

These are not accidents and re-authoring them from scratch would be a regression.

- **The legal route contract.** `/privacy`, `/terms/user`, `/terms/acceptable-use`,
  `/terms/institution` are the exact `path` values in
  `supabase/functions/_shared/legal/legal_catalog.ts`, joined at runtime to
  `LegalLinks.policyHostBaseUrl` by the Flutter client. **Changing any of these four paths
  breaks the in-app "view full policy" link.** They are a contract, not URLs.
- **The placeholder policy in `build_site.mjs`.** Unfilled legal facts (registered address,
  Grievance Officer) render as visible *pending* markers rather than silently as blank. That is
  the correct behaviour and must be carried forward verbatim.
- **`stripInternalNotes()`.** Removes `> OWNER ACTION:` blockquotes from published legal pages.
  Keep.
- **The brand discipline.** `build_site.mjs` copies marks from `brand/niksha-os/` and *fails
  loudly* if one is missing rather than substituting. Keep.
- **The privacy section's copy.** It is the best-written prose on the site — specific, verifiable,
  non-boastful ("enforced in the database, not just the UI"). The redesign keeps the substance and
  changes only the staging. **Subject to the claims review in §9.**
- **Accessibility baseline already present:** skip link, `:focus-visible` ring, 44px minimum touch
  targets, `font-variant-numeric: tabular-nums` on numbers, semantic landmarks.

### 1.2 What is wrong — the reason for a redesign

| Problem | Evidence | Severity |
|---|---|---|
| **The "Screens" section ships an admission of incompleteness.** Three empty grey `div`s labelled "Principal dashboard", "Attendance marking", "Parent view", with the copy *"Product screenshots are being captured from the release build and will be published here before public launch."* | `landing.html:199–229` | **P0 — the site tells visitors it is unfinished.** |
| **The product is never shown.** A platform website with zero pixels of the platform. Everything is asserted in prose. | whole page | **P0** |
| **It reads as documentation.** Nine sibling `<article>` feature cards, each a heading plus a paragraph. Uniform weight, no hierarchy, no narrative — a specification, not an argument. | `landing.html:122–195` | P0 (the brief's core complaint) |
| **Zero motion.** Not "restrained motion" — none at all, beyond `scroll-behavior: smooth` and 0.15s button hovers. | `styles.css` | P1 |
| **Flat.** No depth, no layering, no perspective. Every element sits on the same plane. | — | P1 |
| **No wordmark.** `styles.css:64–73` documents that the horizontal lockup master does not exist, so the name is typeset from the spec as a fallback. | `styles.css:64` | P1 — brand gap |
| **Inter is referenced but not vendored.** `--font: Inter, …` with no `@font-face`; visitors get the platform UI font. The site has never actually rendered in its own typeface. | `styles.css:24–27` | P1 |
| **Text-heavy.** ~1,100 words of body copy for a product nobody can see. | — | P1 |
| **Uniform section rhythm.** Every section is `.section` → eyebrow → title → lede → grid. Five times. Predictable to the point of invisibility. | — | P2 |
| **No dark mode**, despite the product shipping a certified dark theme (178 goldens cover it). | — | P2 |
| **Modules listed, not connected.** The single most important product truth — *one record, every workflow* — is stated in one sentence at `landing.html:63–67` and then contradicted by a grid of nine disconnected boxes. | — | P1 |

### 1.3 Verdict

Keep: the build pipeline, the legal contract, the placeholder policy, the privacy substance,
the a11y baseline.
Replace: the entire landing page — structure, layout, visual system, and every section.

---

## 2. ★ The screenshot problem — the central finding

The brief's hardest requirement is *"Use ONLY our actual application… every dashboard, every
mobile screen… must come from our real Flutter/Web application."* I agree with the requirement
completely. Here is the honest state of what we have.

### 2.1 Every existing image source, and why each fails

| Source | Count | Why it cannot be used |
|---|---|---|
| **Flutter golden tests** `test/golden/goldens/` | **178** | ✗ **Text renders as solid black rectangles.** Flutter's test environment substitutes the `Ahem` font (every glyph is a filled box) and this repo loads no real font into goldens — there is no `flutter_test_config.dart` and no `FontLoader`. I opened `ds_v2_flagship_principal_command_light_600x1400.png` to confirm. These are **layout fingerprints, not screenshots.** They are excellent at their job and useless for this one. |
| **Web ERP visual baselines** `web/visual-baselines/{light,dark}/` | **1,410** | ✗ Captured with **no backend connected**. Every content area is an honest-empty state: *"Collections are ready — Fee payments load here from /finance/collections once the backend is connected."* ✗ Also branded **"Akshara SCHOOL ERP"**, not NIKSHA OS. |
| **Web ERP live baselines** `web/visual-baselines/live/` | **16** | ✗ **Error states.** `finance_dashboard.png` shows *"Something went wrong — Failed to construct 'URL': Invalid URL"*. Consistent with domain-migration risk R4 (old host baked into the bundle). ✗ Also "Akshara" branded. |
| **Archived design mockups** `docs/archive/design/mockups*/` | ~30 | ✗ Mockups, and archived. The brief explicitly forbids these. |
| **Play Store screenshots** `docs/release/screenshots/` | **3** | ✅ **The only real ones.** |

### 2.2 The 3 real screenshots — and what they prove

`docs/release/screenshots/README.md` documents a rigorous, repeatable procedure that already works:

- Real app, real Android device (emulator, API 36), **1080×2160**
- `flutter build apk --profile --dart-define=ENABLE_DEMO_AUTH=true`
- The app's **built-in demo school — 1,248 students, 86 staff** (demo data already exists)
- `adb exec-out screencap -p`
- Explicit rules: never mid-animation, never composited, never retouched, never a QA banner

I opened `02-teacher-dashboard.png`. The product is genuinely premium and needs no help:
soft mesh-gradient canvas, white cards on generous radii, a thick navy progress ring at
**89% Present**, honest states, an amber "Attendance not marked for Class 8-A · Period 1" nudge
with a **Mark now** action, "Good morning, Priya", real timetable rows (Mathematics · 8-A ·
Room 204). **The blueprint motif the brief asks for is already in the product** — a low-opacity
open-book line illustration sits in the app's own background.

**This is the single most important input to the design: the product is already beautiful. The
website's job is to get out of its way.**

Coverage gaps: phone-only; teacher and admin only; no parent, no finance, no Student 360, no AI
copilot, no dark mode, no tablet. And the README flags a real (owner-decision) defect visible in
`03-mark-attendance.png` — the docked AI button overlaps the bottom action bar.

### 2.3 What this means

The website cannot be built first and screenshotted later. **The capture programme in §6 is a
prerequisite wave**, and the site's layout is designed against the shot list in §6.4 so that every
slot has a real image to fill it — or is omitted (§3.0).

### 2.4 Status — the pipeline now exists and works

Built and run against a live Android 16 emulator on 2026-07-29:

```
00:38 +6: All tests passed!
captured: principal-admin-hub.png  (232,415 bytes)
captured: teacher-dashboard.png    (227,094 bytes)
captured: parent-dashboard.png     (241,669 bytes)
captured: student-dashboard.png    (217,416 bytes)
captured: sign-in.png              (103,428 bytes)
```

**Five real captures of the real app, reproducibly, in 38 seconds.** Two properties worth noting:

- **No device chrome.** `takeScreenshot` captures the Flutter surface only — no status bar, no
  navigation bar. Better than the `adb screencap` route in `docs/release/screenshots/README.md`,
  which captures the whole device and needs the status bar cropped afterwards.
- **Real fonts, real demo data** — *School Administration · 1,248 Students · 86 Staff ·
  96% Attendance*, rendered by the real widget tree.

This is the mechanism the 178 goldens could never provide (§2.1) and it is now the project's
capture path.

---

## 3. Design direction

### 3.0 ★ Asset-driven architecture — the design adapts to the product

D2 inverts the usual order: **the product decides what the website shows.** That is not just a
sourcing rule, it is an architectural constraint, and honouring it properly changes the build.

#### The rule

> A section renders **only** if every real product asset it needs exists in the manifest.
> A section with a missing asset is **omitted entirely** — never stubbed, never approximated,
> never filled with a grey box.

The current site fails exactly here: `landing.html:199–229` ships three empty placeholders under
copy promising screenshots "before public launch". Under this rule that section would simply not
have existed, and the site would have been better for it.

#### How it is enforced — mechanically, not by discipline

`build_site.mjs` already fails loudly when a brand asset is missing rather than substituting one.
The same rule extends to product shots:

```
for each act:
    required = manifest entries the act's template references
    if any required entry is absent  -> omit the act, log "OMITTED: <act> (missing: …)"
    else                             -> render it
```

Two properties follow, and both matter:

1. **Placeholder UI becomes impossible.** Not discouraged — unrepresentable. There is no code
   path that emits a shot-shaped element without a real file behind it.
2. **The omission is loud.** The build prints what it dropped and why, so "we are missing the
   Copilot shot" is a visible build output rather than something a reader discovers.

#### What this forces the design to change

My Rev 1 Act II chained its five beats so that *"the line's last node is the first node of the
next beat"*. That is a nice idea and it is **wrong under D2**: remove one beat and the chain
visibly breaks. Revised:

- **Acts are independent modules.** Each stands alone and is individually omittable.
- **The connective line is computed from the beats that actually render**, not authored as a
  fixed five-link chain. Three journeys draw a three-link flow that looks deliberate, because
  it is.
- **No act depends on another act's asset.** Act 0's anchor is not required by Act I.

#### The launch floor

Not every act is optional, or there would be no page.

| Act | Status | Rationale |
|---|---|---|
| **0 · Aperture** | **REQUIRED** | Without one real product image above the fold there is no product website. Falls back from tablet → phone hero (D2 order) before it blocks. |
| **IV · Guardrails** | **REQUIRED** | Pure copy — no product asset needed. Survives any asset state. |
| **V · Close** | **REQUIRED** | Copy + actions only. |
| I · The Record | optional | Needs Student 360. |
| II · The Journeys | optional, **and degrades by beat** | Renders with ≥2 beats; below that it is omitted rather than shown as a stub. |
| III · The Boundary | optional | Needs the Copilot screen. |

**Launch floor = Act 0 + Act IV + Act V.** That page is publishable, honest and complete-looking
on day one, and it grows richer as captures land — without a rebuild and without ever showing a
placeholder.

#### Representation preference, per D2

Applied per shot, highest available wins:

1. **Flutter tablet** (logical 834×1194) — the large-format story
2. **Flutter mobile** (logical 390×844) — proven; 3 shots already exist
3. **Web ERP** — *only* where already production quality. Today: **nothing qualifies.** The
   1,410 light/dark baselines are unseeded empty states, the 16 live baselines are error states,
   and all of them are branded "Akshara" (§2.1). This tier is currently empty and that is fine.
4. **Defer the section** — the design's answer to a missing asset, not a reason to build UI.

#### The line this draws around product work

The website may **report** a product defect it happens to expose (as the Play capture exposed the
Admin Hub width bug). It may **not** commission product work to fill a marketing slot. When a
shot is unavailable, the correct action is to omit the section and record why — never to open a
UI ticket so the website can have a picture.

### 3.1 The idea

> **A school is a building. NIKSHA OS is its blueprint made operational.**

The brief asks for an architectural blueprint background. The stronger move is to make the
blueprint the *organising metaphor* rather than wallpaper, because it is **already the product's
own visual language** (the open-book line art in the app canvas) and **already the brand's**
(the NIKSHA OS mark is *"N rising from an open book, summit flag"*, per `BRAND_GUIDELINES.md §1`).

So the page reads as a set of drawings that resolve into the real thing:

- The background is a **campus blueprint** — drawn as vector, at 5–8% opacity, in brand blue.
- Product screenshots enter **as if pinned onto the drawing** at different depths.
- Connection lines between modules are drawn in the **same stroke weight and language as the
  blueprint** — so "one record, every workflow" is expressed in the drawing itself, not in a
  sentence.

This is defensible, ownable, and cannot be mistaken for a Linear or Stripe clone — while sitting
comfortably in that tier.

### 3.2 Visual system — inherited, not invented

Everything below is taken from existing project sources. The website must not invent a parallel
design language.

**Palette** — `brand/BRAND_GUIDELINES.md §2` (NIKSHA OS):

| Role | Hex | Use on site |
|---|---|---|
| App canvas / icon bg | `#0B1F4B` | Hero void, Act III ground |
| Deep | `#1E3A8A` | Gradient mid, headings on light |
| Primary | `#2563EB` | Actions, links, connection lines |
| Light | `#38BDF8` | Highlights, focus ring, glow |
| Growth accent | `#10B981` | **Accent only, never a fill** (brand rule 2) |

Neutrals carried from the current site: `--ink #0F172A`, `--body #334155`, `--muted #64748B`,
`--line #E2E8F0`, `--bg-soft #F8FAFC`.

**Brand rules that constrain the design (non-negotiable, `BRAND_GUIDELINES.md §2`):**
1. Gradients run **bottom-left → top-right**. Always. *"A gradient that runs the other way reads as descent."*
2. Green is an **accent, never a fill**.
3. Never recolour a mark outside the palette — use the monochrome variants.
4. Body text and the mark clear **4.5:1** on every background.

**Motion tokens** — mirrored from `lib/theme/motion.dart` so the site feels like the app:

| Token | Value | Web equivalent |
|---|---|---|
| `instant` | 80ms | micro-feedback |
| `fast` | 120ms | hover |
| `standard` | 180ms | default transition |
| `slow` | 240ms | section reveal |
| `enter` | `easeOutCubic` | `cubic-bezier(.215,.61,.355,1)` |
| `exit` | `easeInCubic` | `cubic-bezier(.55,.055,.675,.19)` |
| `enterScale` | 0.98 | reveal start scale |

Scroll-scrubbed camera moves are the one exception — they are driven by scroll position, not
duration.

**Typography.** Vendor **Inter** properly (variable, `woff2`, subset latin + latin-ext,
`font-display: swap`, self-hosted, preloaded). Today it is named but never loaded — fixing this
alone visibly upgrades the site. Wordmark per `§5`: Inter 700, tracking `+0.14em`; `OS` sub-label
Inter 600 in brand primary. **Numbers use `tabular-nums` everywhere** — this is a product rule
and it should hold on the site.

**Elevation.** Two shadow families: a tight contact shadow and a wide soft ambient — matching the
app's card treatment. Glass (`backdrop-filter`) is used in **exactly one place**: the sticky
header. See §8 for why.

### 3.3 The blueprint asset

New site artwork — **not** a brand master, and it must not redraw or recolour the N mark.

- Drawn as vector: campus plan geometry (classroom blocks, a quadrangle, a corridor grid, stairs,
  a library, a field), plus section elevations.
- Line weights 0.5 / 1 / 1.5px at 1× with dimension ticks and leader lines.
- Single colour, `#2563EB`, opacity 5–8% on light ground, 10–12% on the navy ground.
- Delivered as **one optimised SVG under 40KB**, used via CSS `background-image`, `aria-hidden`.
- Animates only by `transform: translate3d()` on scroll (parallax) — never by redraw.

---

## 4. Page architecture — the five acts

Total scroll ≈ 6.5 viewports on desktop. Every act has one job and one product truth.

```
Header (glass, shrinks)
│
├─ ACT 0 · APERTURE ......... "The school, in one system."        ~1.6 vh   depth scene
├─ ACT I  · THE RECORD ...... "One student. One record."          ~1.8 vh   pinned, decompose→reconnect
├─ ACT II · THE JOURNEYS .... admissions→academic→finance→comms→AI ~2.2 vh   pinned, 5 beats
├─ ACT III· THE BOUNDARY .... "It answers. It never edits."       ~1.0 vh   navy, the AI claim
├─ ACT IV · THE GUARDRAILS .. DPDP, roles, audit trail            ~0.9 vh   navy→light
└─ ACT V  · CLOSE ........... sign in / talk to us                ~0.6 vh
Footer (unchanged structure, restyled)
```

The nine feature cards are **deleted** and their content redistributed into Acts II and IV.

---

## 5. Every section, every animation, every interaction

Notation: `z` = `translateZ` in a `perspective: 1400px` container. `p` = scroll progress 0→1
within the act's ScrollTrigger.

### Header

**Composition.** Symbol + wordmark left; `Product · Journeys · Privacy · Contact` centre;
`Sign in` (primary) right.

**Animation.** On first scroll past 80px: height 76→60px, background
`rgba(255,255,255,0)` → `rgba(255,255,255,.82)`, `backdrop-filter: blur(12px)` fades in,
hairline border appears. 180ms `easeOutCubic`. Single class toggle driven by one
IntersectionObserver sentinel — **not** a scroll listener.

**Interaction.** Nav links scrub the page to the act (native `scrollIntoView`, smooth). Hover:
2px underline grows from left, 120ms. `Sign in` lifts 1px with shadow step (mirrors
`Motion.hoverLift`).

---

### ACT 0 · APERTURE — "The school, in one system."

The brief's hero, built from real pixels only.

**Composition — 6 depth layers inside one `perspective` container:**

| Layer | Content | z | Source |
|---|---|---|---|
| 1 · far | Campus blueprint plane | `-620px` | SVG artwork |
| 2 | Ambient glow (radial, brand `#38BDF8` at 14%) | `-400px` | CSS |
| 3 · anchor | **Principal / Admin Hub dashboard, tablet format** | `0` | **real capture** (§6.4 #1) |
| 4 | **Attendance card** + **Finance card**, flanking | `+120px` | **real crops** (§6.4 #6,#7) |
| 5 | **Parent app phone**, forward-left | `+210px` | **real capture** (§6.4 #4) |
| 6 · near | **AI Copilot card**, hovering upper-right | `+300px` | **real capture** (§6.4 #8) |

Headline and sub sit at `z: +60px`, so they occupy the scene rather than floating above it.

**Copy.**
> **The school, in one system.**
> Admissions to alumni. One record per student, every workflow reading the same truth.
> `[Sign in]` `[See how it works ↓]`

Down from ~55 words to ~20.

**Animations.**

1. **Entrance (once, on load).** Layers arrive far→near, 90ms stagger, each
   `opacity 0→1` + `translateZ(−80px)→final` + `scale(.98)→1`, 240ms `easeOutCubic`. Total 700ms.
   Headline arrives at 120ms so the page never looks empty.
2. **Mouse parallax (desktop, fine pointer only).** Pointer position → normalised `−1…1`.
   The **scene container** takes `rotateY(x·6deg) rotateX(−y·4deg)`. Each layer additionally
   translates by `x · depth · 14px`, depth being its z-rank. Values are **lerped at 0.08 toward
   the target inside a single rAF loop** — one loop, one pointermove listener on the container,
   never per-element.
3. **Scroll camera (`p` 0→1).** Scene `translateZ` `0 → +260px` (dolly in) and
   `rotateX` `0 → 4deg` (camera settles). Blueprint plane counter-translates `y: −40px` (parallax).
   Headline `opacity 1→0`, `y: 0→−60px`, done by `p=0.6` so it clears before the cards.
4. **Idle drift.** Layers 4–6 breathe on an infinite `translateY` ±4px sine, 6–9s, offset phases.
   **Paused when the act is off-screen** and disabled under reduced motion.

**Interactions.** Cards are non-interactive images (`pointer-events: none`) except the two CTAs.
Hovering the scene does not "select" anything — the depth response *is* the feedback. Keyboard
users tab straight to the CTAs; the scene is `aria-hidden` except for the anchor screenshot,
which carries a real description.

---

### ACT I · THE RECORD — "One student. One record. Every workflow."

The brief's decompose-and-reconnect sequence. This is the argument the product actually wins on.

**Pinned** for ~1.8vh, scrubbed.

**Beat 1 (`p` 0→0.30) — Decompose.** The tablet dashboard from Act 0 is still centre. It
separates into four real module screens which travel outward:

- **Attendance** → left, `x −340px`, `rotateY +14deg`
- **Finance** → right, `x +340px`, `rotateY −14deg`
- **Parent app** → forward, `z +260px`, `scale 1.06`
- **Teacher app** → back-left, `rotateY +22deg`, `z −120px`

Each is a real capture. The dashboard itself fades to 0 by `p=0.28` — it does not shrink into a
generic box; it hands off.

**Beat 2 (`p` 0.30→0.62) — The record appears.** A **real Student 360 screen** scales in at
centre from `scale .92`, with a soft `#38BDF8` glow at 18% behind it. Caption, small:
*"Rahul Sharma · Class 8-A · Admission 2019-0142"* — **read from the actual screenshot**, never
typed in as fiction.

**Beat 3 (`p` 0.62→0.88) — Reconnect.** Four connection lines draw from each module to the record
via `stroke-dashoffset` 1→0, staggered 80ms, in blueprint stroke language (1.5px, `#2563EB`, 60%).
A 3px `#38BDF8` pulse travels each line once, on arrival. The four modules ease **inward** by
~12% — they orbit closer, they do not collapse.

**Beat 4 (`p` 0.88→1) — Settle & release.** The whole assembly rotates `rotateY −4deg → 0`, the
caption line resolves:
> **One student. One record. Every workflow.**
> Attendance, marks, fees, transport and hostel all write to the same student — so the number a
> principal sees and the number a parent sees cannot disagree.

**Interactions.** None during the pin — the scroll *is* the interaction. On release, each of the
four modules becomes hover-responsive: 1px lift, shadow step, and its label fades in. Clicking one
does nothing (they are images); the cursor stays `default`, so nothing promises interactivity it
does not have.

**Reduced motion / no-JS:** the act renders as its **final state** (record centre, four modules
placed, lines drawn) as a static composition, plus the caption. Nothing is lost.

---

### ACT II · THE JOURNEYS — five beats

Replaces the nine feature cards. Each journey is one pinned beat; the connective line from the
previous journey persists so the five read as one continuous flow.

| Beat | Journey | Real screen shown | Line drawn |
|---|---|---|---|
| 1 | **Admissions** | Admissions / enrolment | Enquiry → Application → **Student record** |
| 2 | **Academic** | Mark attendance + marks entry | Record → Attendance → Marks → Result |
| 3 | **Finance** | Fee collection + receipt | Record → Demand → Collection → Receipt |
| 4 | **Communication** | Parent app — notices / results | Record → Parent's phone |
| 5 | **AI** | Copilot / Intelligence | Every module → **read** → Copilot |

**Animation per beat (`p` local 0→1):**
- `0→0.25` — the screen enters from `x +180px`, `rotateY −18deg`, `opacity 0` → seated at
  `rotateY −6deg`, `opacity 1`.
- `0.25→0.65` — the flow line draws left-to-right, each node popping (`scale .8→1`, 120ms) as the
  line reaches it. **The line's last node is the first node of the next beat** — the visual claim
  that these are not separate products.
- `0.65→1` — the screen recedes to `z −80px`, `opacity .35`, and slides left as the next beat's
  screen enters. Two beats are briefly co-present; the page never goes empty.

**Copy per beat:** a 3-word title and one sentence, maximum. Example, Finance:
> **Finance** — Transport and hostel raise demands against the same student account, so there is
> one balance to reconcile, not three.

**Interaction.** A slim progress rail (5 ticks) on the left edge shows position within the act and
is **clickable** — jumping to a beat scrubs the pinned timeline. Ticks are real `<button>`s with
labels, giving keyboard and screen-reader users a way through the act that does not require
scrolling through it.

---

### ACT III · THE BOUNDARY — "It answers. It never edits."

Navy ground (`#0B1F4B`). The single most differentiating claim NIKSHA OS makes, and the one most
worth staging.

**Composition.** The real Copilot screen, centre, lifted. Behind it, thin blueprint lines run from
each module *into* the copilot. In front, a single line attempts to run *out* of the copilot back
toward the records — and **stops at a boundary**, a 1px `#38BDF8` vertical rule, with a small
terminator.

**Animation.** `0→0.4` inbound lines draw (read paths) — calm, `#2563EB`. `0.4→0.7` the outbound
line draws, reaches the boundary, and **halts**; the boundary flares once (`#38BDF8`, 240ms) and
the outbound line retracts. `0.7→1` copy resolves. The retraction happens **once** — repeating it
would turn a serious claim into a gimmick.

**Copy.**
> **It answers. It never edits.**
> The copilot reads your data and explains what it finds. It is architecturally prevented from
> writing to records — it cannot change a mark, a payment or an attendance entry.

⚠ **Subject to §9 claims review before publication.**

**Interaction.** None. This section is a statement; interactivity would undercut it.

---

### ACT IV · THE GUARDRAILS

Carries forward the current site's four privacy commitments — the best copy on the existing site —
restaged as a 2×2 on the navy ground, with the blueprint at 10% behind.

**Animation.** Reveal only: 60ms stagger, `y +24px→0`, `opacity 0→1`, 240ms `easeOutCubic`.
Deliberately the calmest act on the page. After Acts 0–III, restraint here reads as seriousness.

**Interaction.** The four legal links (`/privacy`, `/terms/user`, `/terms/acceptable-use`,
`/terms/institution`) — **exact paths preserved** per §1.1.

---

### ACT V · CLOSE

**Composition.** Wordmark, one line, two actions, support email. Blueprint resolves to its densest
state here — the drawing completes as the page ends.

**Copy.**
> **Run your school on one system.**
> `[Sign in]` `[Talk to us]` · support@nikshaos.in

**Animation.** Blueprint opacity 5%→9% across the act. Nothing else.

---

## 6. The capture programme — how real screenshots get made

This is the prerequisite wave. It is engineering work, not design work.

### 6.1 Non-negotiable rules (extending `docs/release/screenshots/README.md §5`)

**Allowed:** crop the device status bar; scale; convert format; add a device bezel around an
unmodified capture; blur or replace personal data.
**Forbidden:** retouching UI; compositing elements from different screens; inventing or editing
any number, name or state; upscaling; shipping a mid-animation frame; any QA/debug chrome.

> A device bezel around a real, unmodified screen is honest and standard practice. Any pixel
> *inside* the bezel that did not come from the running app is a fabrication and is out of bounds.

### 6.2 Where each format comes from

| Format | Source | Rationale |
|---|---|---|
| **Phone** (390×844 class) | Flutter app, Android emulator | Proven — 3 already captured |
| **Tablet / large dashboard** | **Flutter app on a tablet emulator (834×1194)** | ★ **Not the web ERP.** The app is already responsive at this size (`lib/theme/breakpoints.dart`; 834×1194 goldens exist). The web ERP is broken, unseeded and still "Akshara"-branded (§2.1) — depending on it would import that repair into this project's critical path. |
| **Dark mode** | Same harness, `--dart-define` theme override | The dark theme is certified (178 goldens cover light+dark) |

If the owner later wants true desktop-browser imagery, that becomes a separate wave gated on
repairing and re-branding the web ERP. **Recommendation: not now.**

### 6.3 The pipeline — as built and proven

Status: **built, run against a live Android 16 emulator, and producing real PNGs on the host.**

#### ★ Patrol cannot take screenshots — the finding that shaped the design

D3 asked for a Patrol-driven pipeline. Building it surfaced two blocking facts:

1. **The `patrol` package exposes no screenshot API.** Verified against the installed
   `patrol-4.6.1` — nothing in its `lib/` provides capture.
2. **This repo's `capturePatrolScreenshot` is a no-op on device.**
   `patrol_test/helpers/patrol_helpers.dart:47–64` returns early on Android/iOS and, on host,
   writes a `.marker` file containing a timestamp. So
   `patrol_test/screenshots/screenshot_regression_test.dart` — which reads as a screenshot suite
   covering seven personas — has **never produced an image**. It records *intent* for regression
   tooling. That is a legitimate design for its purpose, and it is not a capture pipeline.

Capture requires `IntegrationTestWidgetsFlutterBinding`, because only it can ship bytes over the
driver channel to the host process — the on-device test cannot write into the repository.
`PatrolBinding` and `IntegrationTestWidgetsFlutterBinding` cannot both own the binding.

**Resolution:** the pipeline is an `integration_test` driven by `flutter drive`. Patrol's
ergonomics are not lost in any way that matters — no captured path involves a native dialog, so
`flutter_test` finders plus explicit bounded waits do the whole job. `PatrolTester` *is*
constructible standalone (`PatrolTester({tester, config})`) if a future shot ever needs it.

#### Files

| File | Role |
|---|---|
| `integration_test/marketing_capture_test.dart` | Declarative shot list; boots the app, signs in per persona, asserts an anchor, captures |
| `test_driver/marketing_capture_driver.dart` | Host side — receives bytes, writes `build/marketing-capture/<name>.png` |
| `scripts/marketing/capture_shots.sh` | Orchestration: sets the layout tier, runs the drive, writes the manifest, **always restores the device** |

#### Three non-obvious things it has to get right

1. **The session is not in SharedPreferences.** `AuthSessionStorage` writes to the platform
   secure store (Android Keystore), which survives `prefs.clear()`, app restart and the whole
   test process. Without an explicit `authSessionStorage.clear()` + `tokenStorage.clear()` the app
   silently restores the previous persona and **every shot after the first captures the wrong
   workspace** — while still looking like a valid screenshot. This was observed, not theorised.
2. **`convertFlutterSurfaceToImage()` is once per _test_, not once per process.** A process-wide
   flag makes the first capture succeed and every later one fail with *"Call
   convertFlutterSurfaceToImage() before taking a screenshot"*. Reset per test.
3. **`pumpAndSettle` cannot be used.** The app runs continuous animations (docked AI affordance,
   progress rings, skeleton shimmer), so settling never completes and the call throws. The harness
   pumps for a bounded period and treats "still animating" as normal.

#### Layout tiers are chosen by logical width, not resolution

`lib/theme/breakpoints.dart`: mobile ≤ 767 · tablet 768–1199 · desktop ≥ 1200, where
`logical = physical / (density / 160)`. So the tier is set by `wm size` **and** `wm density`
together — changing one without the other captures the wrong layout at the right resolution,
which is the failure mode least likely to be noticed.

| Tier | `wm size` | `wm density` | Logical | App tier |
|---|---|---|---|---|
| phone | 1170×2532 | 480 | 390×844 | mobile |
| tablet | 1668×2388 | 320 | 834×1194 | **tablet** ← D2 preference ① |
| desktop | 2880×2048 | 320 | 1440×1024 | desktop |

This is how the D2-preferred large-format shots are produced **without touching the web ERP**.

#### Reproducibility and versioning (D3)

- **Deterministic data** — the app's built-in demo school, mock repositories (`enableApiMode: false`),
  a cleared session and `SchoolConfiguration.demoDefault()` on every run.
- **Anchor assertions** — each shot asserts its screen rendered before the shutter fires, so a
  navigation change fails the run instead of silently publishing the wrong screen. When it fails,
  the harness dumps every visible `Text` in the tree, which is how the principal's real landing
  screen (**Admin Hub**, not a dashboard) was discovered.
- **Manifest** written per run with commit SHA, branch, **working-tree-clean flag**, device model,
  Android version, tier, logical/physical size, density, build flags, UTC timestamp and the pixel
  dimensions of every PNG.
- **Regeneration** — re-running the script after any UI change reproduces the whole set. Assets
  are versioned by the commit recorded in their manifest, so a stale shot is detectable rather
  than merely suspected.

#### Promotion is deliberate

Captures land in `build/marketing-capture/` (git-ignored). **Nothing is published from there.**
Promotion into `deploy/nikshaos/src/product-shots/` is a reviewed step gated on §6.5 data hygiene
**and the §10.1 depicted-state rule**. `build_site.mjs` then refuses to render any shot lacking a
manifest entry — the same fail-loud discipline it already applies to brand assets.

### 6.4 Shot list — 12 shots, mapped to the layout

| # | Screen | Format | Used in | Status |
|---|---|---|---|---|
| 1 | **Admin Hub / Principal** | tablet | Act 0 anchor, Act I | ✅ phone captured; **tablet needed** |
| 2 | Teacher dashboard | phone | Act I (teacher) | ✅ captured |
| 3 | Mark attendance | phone | Act II beat 2 | ⚠️ captured — **has the AI-button overlap defect** |
| 4 | **Parent — fees & receipt** | phone | Act 0 layer 5, Act II beat 3 | ⬜ |
| 5 | **Student 360** | tablet | **Act I centrepiece** | ⬜ ★ highest value |
| 6 | Attendance register | tablet crop | Act 0 layer 4 | ⬜ |
| 7 | Finance collections | tablet crop | Act 0 layer 4 | ⬜ |
| 8 | **AI Copilot** | phone | Act 0 layer 6, **Act III** | ⬜ ★ Act III cannot ship without it |
| 9 | Admissions enrolment | tablet | Act II beat 1 | ⬜ |
| 10 | Marks entry | phone | Act II beat 2 | ⬜ |
| 11 | Parent — notices/results | phone | Act II beat 4 | ⬜ |
| 12 | Any of the above, **dark** | phone | Act III | ⬜ |

**3 of 12 exist. Two blockers: #5 Student 360 and #8 AI Copilot** — Acts I and III are built
around them.

**Shot #3 carries a known product defect** (docked AI button overlapping the bottom action bar —
an open owner decision per the README). **Recommendation: do not ship #3 until that is resolved**;
Act II beat 2 uses marks entry (#10) in the interim.

### 6.5 Data hygiene

The demo school (1,248 students, 86 staff) is built into the app and already uses demo names
("Priya"). Before publication, each capture is reviewed against a checklist: no real school name,
no real phone/email, no real admission number, no real photograph, no real financial figure
attributable to a real institution. **Because F3 places the live pilot under a security pause,
capture from the live pilot is prohibited outright** — demo build only, which is what the existing
procedure already does.

### 6.6 Integration into the build

Assets land in `deploy/nikshaos/src/product-shots/`. `build_site.mjs` gains a step that, for each
manifest entry, emits AVIF + WebP + PNG at 1×/2× and writes a `<picture>` with explicit
`width`/`height` (zero CLS), `alt` from the manifest, `loading="lazy"` below the fold and
`fetchpriority="high"` for the Act 0 anchor.

---

## 7. Responsive strategy

| Breakpoint | Experience |
|---|---|
| **≥1280px** | Full cinematic: all six depth layers, mouse parallax, all five acts pinned and scrubbed. |
| **1024–1279px** | Depth preserved, amplitudes reduced ~40%; layer 4 crops drop to keep the composition legible. |
| **768–1023px (tablet)** | Depth **preserved** per the brief, but pinning is dropped. Acts become tall scroll sections with entrance transforms and parallax on the blueprint only. No mouse parallax (coarse pointer). |
| **<768px (mobile)** | **No scroll-scrubbing, no pinning, no 3D.** Each act becomes a single static composition — depth pre-composed into the image rather than computed live — with one `y+16px → 0, opacity 0→1` reveal, 240ms. Act 0 shows the phone capture full-bleed; the tablet dashboard is dropped rather than shrunk into illegibility. |

**Why mobile is deliberately plain:** NIKSHA OS sells to Indian schools, and the people who open
this link will overwhelmingly do so on a mid-range Android phone over 4G. A cinematic desktop
experience that drops to 25fps on a ₹12,000 device is a worse first impression than an elegant
static one. **Performance targets are validated on a low-end Android device, not on a MacBook.**

---

## 8. Performance

### 8.1 Budgets (enforced, not aspirational)

| Metric | Budget | Measured on |
|---|---|---|
| LCP | **< 2.0s** | Moto G-class Android, 4G |
| CLS | **< 0.02** | all breakpoints |
| INP | **< 200ms** | desktop + mobile |
| JS (gz) | **< 100KB** | GSAP + ScrollTrigger ≈ 50KB; site code ≈ 15KB |
| Images above fold | **< 300KB** total | AVIF |
| Sustained scroll FPS | **≥ 58** desktop, **≥ 55** tablet | DevTools performance trace |

### 8.2 The rules that make 60fps achievable

1. **Animate only `transform` and `opacity`.** Never `top/left/width/height`, never `filter`,
   never `box-shadow`. Shadow "changes" are done by cross-fading two pre-rendered shadow layers.
2. **`will-change` is applied on ScrollTrigger `onEnter` and removed on `onLeave`.** Leaving
   `will-change` on dozens of layers permanently exhausts GPU memory and is the most common cause
   of exactly the jank this design risks.
3. **Layer budget: ≤ 12 composited layers per act.** Audited in DevTools Layers.
4. **One rAF loop for the whole page.** Mouse parallax, idle drift and any lerp share it. No
   `scroll` listeners anywhere — ScrollTrigger and IntersectionObserver only.
5. **`backdrop-filter` in exactly one place** (the sticky header, ~60px tall). It is the single
   most expensive property on Safari and low-end Android. Every other "glass" surface uses a
   pre-composed translucent background instead.
6. **`content-visibility: auto` + `contain-intrinsic-size`** on Acts II–V so off-screen acts cost
   nothing to lay out.
7. **Idle animations pause off-screen**, via the act's own IntersectionObserver.
8. **Images:** AVIF (WebP fallback, PNG last), responsive `srcset`, explicit dimensions,
   `decoding="async"`, `loading="lazy"` below fold, `fetchpriority="high"` on the Act 0 anchor.
   Screenshots are large (a 1080×2160 PNG is ~237KB); AVIF at q60 should land near 40–60KB.
9. **Fonts:** self-hosted Inter variable, subset, `preload` the one weight used above the fold,
   `font-display: swap`, `size-adjust` tuned so the fallback swap does not shift layout.
10. **No WebGL.** Per the brief, and unnecessary — CSS 3D transforms do everything here.

### 8.3 Library choice

**Recommendation: keep the site static HTML/CSS and add GSAP + ScrollTrigger.**

- Preserves `build_site.mjs`, the legal-route contract, the placeholder policy and the nginx
  deployment — all of which work and none of which benefit from a rewrite.
- ScrollTrigger is the right tool for pinned, scrubbed timelines; Framer Motion would require
  importing React into a static marketing site for no gain.
- ~50KB gz, one dependency, no build-system change.

CSS scroll-driven animations (`animation-timeline: view()`) are not yet broad enough to be the
primary mechanism, but the reduced-motion and no-JS fallbacks are pure CSS regardless.

---

## 9. Accessibility

Because this page is *made of* motion, accessibility is a first-class design constraint, not a
pass at the end.

1. **`prefers-reduced-motion: reduce` removes all scroll-scrubbed motion and all 3D.** Not
   "reduced" — removed. Every act renders in its **final composed state**, statically. Pins are
   not created. The idle drift and the mouse parallax do not initialise. This is checked with
   `matchMedia` before any GSAP timeline is built, and re-checked on change.
2. **The DOM is complete and readable without JavaScript.** No text is ever gated behind animation
   state. With JS disabled the page is a clean, well-typeset, fully-readable document with all
   screenshots visible. This is also what search engines and link previews see.
3. **Focus order follows visual order.** 3D transforms must not scramble tab order — layers are
   ordered in the DOM as they read, and depth comes from `translateZ`, never from reordering.
4. **Real alt text on every product screenshot**, from the manifest, describing *what the screen
   shows* — "Teacher dashboard showing 89% attendance for the day and an unmarked Class 8-A
   register" — not "screenshot of the app". Decorative blueprint and glow layers are
   `aria-hidden="true"`.
5. **No scroll hijacking.** Scroll velocity is never intercepted or overridden; animation is
   *scrubbed by* natural scroll. PageDown, Home/End, spacebar and trackpad momentum all behave
   normally.
6. **Pinned acts are keyboard-traversable.** The Act II progress rail is real `<button>` elements
   with accessible names; a keyboard user can reach every journey without scrubbing.
7. **Contrast ≥ 4.5:1** for body text and ≥ 3:1 for large text and meaningful graphics, on both
   the light and navy grounds — enforcing `BRAND_GUIDELINES.md §2` rule 4. The navy ground
   (`#0B1F4B`) is checked against every foreground used on it.
8. **Focus-visible ring preserved** — the current `3px solid #38BDF8, offset 2px` is good; it must
   remain visible against the navy sections too.
9. **Touch targets ≥ 44px**, already the current baseline.
10. **Landmarks and headings:** one `<h1>`, sequential `h2` per act, `<main>`, `<nav>`, `<footer>`,
    skip link retained.
11. **`prefers-contrast: more`** drops the blueprint and glow layers and raises text contrast.
12. **Autoplay:** the idle drift is decorative, under 5s per cycle and pausable by reduced-motion;
    there is no video, no audio, and nothing that flashes.

> Note: `lib/theme/` has **no reduce-motion handling today**, and the defect register carries
> "the reduce-motion expression (whole app at once)" as a pending fix. The website will not
> inherit that gap.

---

## 10. Claims register — every statement, its evidence, its verdict

Per D7: every statement must be evidence-backed. A claim that cannot be verified on the deployed
production environment is **qualified accurately or omitted until verified**. This register is the
gate; nothing publishes with an unresolved ❌ or ⚠.

**Legend:** ✅ evidenced · ⚠ needs qualification or verification · ❌ not currently true

| # | Claim (from the live site) | Verdict | Evidence / problem | Action |
|---|---|---|---|---|
| 1 | "Teachers mark attendance and enter marks from a phone" | ✅ | `03-mark-attendance.png` — real capture | Keep |
| 2 | "Absent, medical and debarred are recorded honestly — never silently as a zero that drags an average down" | ✅ | Frozen design decision, implemented; excluded from totals/avg/rank | Keep — one of the strongest true claims we have |
| 3 | "Concessions require two-person approval before anything payable is reduced" | ✅ | FIN-D4 maker–checker, implemented | Keep |
| 4 | "Corrections route through an approval so the register stays auditable" | ✅ | Attendance correction approval path | Keep |
| 5 | "State-board and CBSE grading, FA/SA assessment cycles…" | ✅ | Shipped in the release lane | Keep |
| 6 | "Transport fees… raised as a demand against the student's existing fee account rather than a separate ledger" | ✅ | TRN-9 decision, implemented | Keep |
| 7 | "We never sell data, and never advertise to children… no third-party trackers" | ✅ | Verifiable by absence; the new site must ship **zero** third-party scripts to keep it true | Keep — **and it constrains the build: no analytics, no fonts-from-CDN, no embeds** |
| 8 | "The Institution is the Data Fiduciary. NIKSHA OS acts as a Data Processor" | ✅ | Legal docs | Keep |
| 9 | **"Staff attendance is verified by live camera and geofence — not a PIN that can be shared"** | ❌ | **`assets/models/mobilefacenet.tflite` is NOT in the repository.** `MobileFaceNetEmbedder` fails loud with `FACE_MODEL_MISSING` and never fabricates an embedding. Face verification **cannot run in any build produced from this tree.** | **Rewrite to the geofence half only**, or omit until the model ships. ⚠ **Also blocks a screenshot** — see §10.1 |
| 10 | **"The AI copilot… is architecturally prevented from writing to your records"** | ⚠ | What exists is a **system prompt** (`"You are read-only."`, `anthropic_client_test.ts`), read-only quota checks, and UI hint text. **A prompt is a request, not an architectural guarantee.** Separately, `_shared/ai/ai_wallet_handlers.ts` imports `emitMutationAudit` — the AI subsystem *does* write, to credit/quota state | **Narrow the claim to what is enforced.** Verify whether the copilot path can reach any student-record mutation; if the boundary is real, say precisely that ("cannot write to student records"), not "cannot write". If it is only a prompt, the claim must go |
| 11 | **"Access is enforced… enforced in the database, not just the UI"** | ⚠ | RLS exists in code, **but** the live pilot's `/health/tenant-access` reports `isolation.pass=false` and commit `8050eda2` records the forced-auth test passing in-repo while the running system behaves differently | **Cannot publish as-is under D7** — it is precisely a claim unverifiable on the deployed environment. Either fix the deployment and re-verify, or drop the "in the database" half |
| 12 | "Leadership dashboards computed deterministically from your own data — the same number, every time you ask" | ✅ | Deterministic-first architecture; no request-path AI | Keep |
| 13 | "Changes leave a trail… a school can always reconstruct what happened" | ⚠ | Audit exists for money/marks/attendance; "always" is absolute | Soften "always" → name the three domains it actually covers |
| 14 | "NIKSHA OS runs… for Indian schools" (present tense, plural) | ⚠ | One pilot. Plural present tense implies an installed base | Qualify to pilot reality until there are multiple live schools |
| 15 | "operated by NIKSHA Technologies Pvt. Ltd." | ⚠ | `docs/legal/PLACEHOLDERS.md` still has `[REGISTERED ADDRESS]` and `[GRIEVANCE OFFICER NAME]` unfilled — the entity's statutory details are not settled | Owner to confirm incorporation status before the corporate claim publishes |
| 16 | "The AI Operating System for Schools" (H1) | ⚠ | Positioning, not a capability claim — but it front-loads "AI" for a product whose AI surface is a read-only copilot | Defensible **if** Act III describes the boundary honestly. If claim 10 gets cut, revisit the H1 |

### 10.1 ★ A real screenshot can still make a false claim

This is the finding I did not expect, and it changes the capture rules.

`docs/release/screenshots/02-teacher-dashboard.png` is a genuine, unmodified capture of the real
app. It shows:

> **Checked in** · 9:02 AM · **Geo+Face verified**

Every pixel is real. **And it advertises a capability that cannot run** — the face model is not
bundled (claim 9). Publishing it would misrepresent the product *without a single fabricated
pixel.*

So authenticity of pixels is necessary but **not sufficient**. §6.1 gains a rule:

> **Depicted-state rule.** A capture may only be published if the state it depicts is reachable
> in a build a customer could actually run. Demo *data* is fine; a demo-only *capability* shown
> as working is not.

Every shot is reviewed against this rule, not just against the retouching rules. For the teacher
dashboard specifically: either the model ships, or the shot is re-captured in a geofence-only
check-in state, or that screen is not used.

### 10.2 Why this matters more after a redesign



The current site makes strong, specific security claims. Two examples:

> *"Access is enforced, not assumed… A parent can reach their own children's records and nothing
> else — **enforced in the database, not just the UI**."*
> *"The AI copilot… is **architecturally prevented** from writing to your records."*

Meanwhile, `release/v1.0-playstore` HEAD (commit `8050eda2`) records **confirmed, reproducible,
unauthenticated** findings against the deployed pilot — including that `/health/tenant-access`
reports `isolation.pass=false`, and that a forced-auth test *passes in this repository* while the
running system behaves differently.

These are not necessarily contradictory — the claims may be true of the code while the deployed
instance lags it, which is precisely what commit `8050eda2` says. But a **redesign that stages
these claims more prominently, in a more persuasive frame, raises the stakes on each one.**

**Recommendation:** every security, privacy and AI claim on the new site is re-verified against
current reality before publication, and any claim that cannot be evidenced today is either
softened to what is true or held back until it is. This is a short review, and it should gate
launch. Making a page beautiful is not a reason to make it less careful.

---

## 11. Decisions

### 11.1 Resolved 2026-07-29

D1 ✅ approved · D2 ✅ Flutter-first preference order · D3 ✅ automated + versioned ·
D7 ✅ evidence-backed claims gate launch. See the decisions table at the top of this document.

### 11.2 Still open

| # | Decision | My recommendation |
|---|---|---|
| **D4** | **Mark-attendance shot has a real UI defect** — the docked AI button overlaps the bottom action bar (`docs/release/screenshots/README.md §3`, an open owner decision). | **Do not fix it for the website.** Under the D2 governing principle, this is product work the marketing site must not drive. **Omit the screen** and let Act II render one beat shorter. Fix it when product priority says so. *(This reverses my Rev 1 recommendation, which had it backwards.)* |
| **D5** | **Which branch?** Site source is on `release/v1.0-playstore`, which is also under the security pause. | **`release/v1.0-playstore`** — domain, rename and site are one product decision. |
| **D6** | **Draw the horizontal wordmark lockup?** Absent today (`styles.css:64`); the name is typeset as a fallback. | **Yes.** Pure brand work — it does not touch the product, so the D2 principle does not bar it. |
| **D8** | **Dark mode for the website itself?** | **Not in v1.** The product's dark theme can still appear *in screenshots*. |
| **D9** | **NEW — claim 9 (face-verified staff attendance) is not true in any buildable artifact** (§10, `FACE_MODEL_MISSING`). Ship the model, or change the claim? | **Change the claim** to geofence-only. Shipping a model to make a website sentence true is exactly the inversion D2 forbids. |
| **D10** | **NEW — claim 11 ("enforced in the database") cannot be verified on the deployed environment** — live isolation check is red. | **Omit the "in the database" half until the deployment verifies**, per D7. This is a publication decision, not a request to fix infrastructure. |
| **D11** | **NEW — does the Admin Hub card layout defect** (visible in the first tablet/phone capture: each module card leaves its right half empty) **disqualify the Admin Hub as the Act 0 hero?** | **Use the tablet capture if it composes well; otherwise fall back to the teacher dashboard**, which is already strong. Report the defect; do not commission a fix. |

---

## 12. If approved — sequencing

| Wave | Work | Depends on |
|---|---|---|
| **W1** | Patrol capture harness + manifest schema + tablet emulator profile | D1, D3 |
| **W2** | Capture the 9 missing shots; data-hygiene review | W1, D2 |
| **W3** | Blueprint SVG artwork; Inter vendored; wordmark lockup | D6 |
| **W4** | `build_site.mjs` image pipeline (AVIF/WebP, manifest→`<picture>`) | W2 |
| **W5** | Acts 0–V build: structure + static/reduced-motion state **first**, motion layered on after | W3, W4 |
| **W6** | Performance pass on a real low-end Android; a11y audit; claims review | W5, D7 |
| **W7** | Deploy to `/var/www/nikshaos-site`; EOS gate | W6 |

W5 building the **static state first** is deliberate: it guarantees the reduced-motion and no-JS
experience is a designed artifact rather than a degraded leftover.

---

## 13. Explicitly out of scope

- `app.nikshaos.in` (the web ERP) — not repaired, re-seeded or re-branded here.
- `api.nikshaos.in` — untouched.
- The four legal documents' **content** — only their presentation changes; paths are frozen.
- Any change to the Flutter app **except** the D4 defect fix, if approved.
- Pricing, blog, careers, docs, changelog — none exist and none are proposed for v1.
