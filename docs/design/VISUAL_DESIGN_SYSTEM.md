# Akshara Visual Design System — "Premium School OS"

> **Status:** APPROVED direction (2026-06-20). Owner chose **Premium Light as the
> default theme + Dark Premium as a mode toggle** (build light first, dark after).
> Goal: Akshara should feel like a **premium, modern product**, not a traditional
> ERP / government portal. This spec is the single source of truth for the look;
> it feeds dashboard modernization and every future UX batch.
>
> Reference mockups: `docs/design/mockups/parent_home_light.png` and
> `parent_home_dark.png` (editable HTML beside them). These were the
> owner-approved concept renders.

---

## 1. Design principles
1. **Calm, airy, app-like** — generous spacing, big friendly greetings, one idea
   per card. The opposite of a dense data-grid ERP.
2. **Intentful color** — neutral canvas, color reserved for status (green/amber/
   red) and a single indigo→violet brand accent. Never rainbow.
3. **Soft depth** — hairline borders + soft, slightly indigo-tinted shadows.
   No hard 1px grey ERP boxes.
4. **Subtle line-art as the brand's quiet signature** — monoline illustrations at
   5–15% opacity, decorative only, never reducing readability.
5. **AI is first-class** — an AI suggestion surface + a center AI action are part
   of the chrome, signalling "intelligent product."
6. **Mobile-first** — every spec below is defined at phone width first.

---

## 2. Color palette

### Light (default)
| Role | Token | Hex |
|------|-------|-----|
| Canvas (gradient) | `bg` | `#F6F7FB → #F3F1FB → #FBF1F7` (soft indigo→pink wash) |
| Surface / card | `surface` | `#FFFFFF` |
| Hairline border | `border` | `#ECEAF6` |
| Ink (text) | `ink` | `#1E1B3A` |
| Muted text | `muted` | `#6B6890` / `#8480A6` |
| Brand primary | `primary` | `#5B5BF0` (indigo) |
| Brand primary 2 | `primary2` | `#8B5CF6` (violet) — used in gradients |
| Success | `ok` | `#1A7F46` on `#E7F8EE` |
| Warning | `warn` | `#B0700E` on `#FEF3E2` |
| Danger | `bad` | `#C0392B` on `#FDECEE` |

### Dark (mode toggle)
| Role | Hex |
|------|-----|
| Canvas | `#1B1C33 → #12121F → #0A0A12` (radial, subtle glow top-right) |
| Surface / card | `#161726` |
| Hairline border | `#282A44` |
| Ink | `#F1F0FB` |
| Muted | `#9794BE` |
| Brand primary | `#9FA0FF` | 
| Accent 2 | `#37E0D8` (cyan, used in progress/glow) |
| Success / Warning / Danger | `#49E0A4` / `#F4C868` / `#FF7A93` (on deep tints) |

Brand gradient: **`#6366F1 → #8B5CF6`** (light) / **`#6C6DFF → #9B5BE6`** (dark).

---

## 3. Background strategy
- A **very soft full-screen gradient** canvas (not flat white/grey).
- **Line-art module motifs** placed bottom-right / behind hero cards at **6–14%
  opacity** (light) / **10–22%** (dark): graduation cap (academics/overview),
  open book (homework/library), bar-chart (finance/intelligence), bus
  (transport), bookshelf (library), campus (hostel), message (communication).
- Motifs are **decorative only** — never behind body text at an opacity that
  hurts legibility.

## 4. Card style
- White (light) / `#161726` (dark) surfaces, **20–24px radius**.
- **1px hairline border** + **soft tinted shadow** `0 14px 40px rgba(91,91,240,.10)`
  (light) / `0 16px 36px rgba(0,0,0,.42)` (dark).
- Hero/greeting card uses the **brand gradient tint** with a faint line-art motif.
- KPI cards: small **rounded icon badge** (status-tinted) + label + big number.

## 5. Shadows (elevation scale)
| Level | Light | Use |
|-------|-------|-----|
| 1 rest | `0 2px 6px rgba(30,27,58,.05)` | inline chips |
| 2 card | `0 14px 40px rgba(91,91,240,.10)` | cards, KPIs |
| 3 lifted | `0 24px 60px rgba(91,91,240,.20)` | dialogs, FAB, hero |

Dark uses deep black shadows + a **colored glow** on primary elements (AI bar, FAB).

## 6. Typography
- Family: system (SF / Roboto) now; **Inter** is the intended brand face.
- Display/heading: **800 weight, −0.5 letter-spacing**, tight line-height (greetings,
  card titles, big KPI numbers).
- Body/secondary: muted color, 1.4–1.5 line-height.
- Numbers: **tabular**, large and confident (₹ amounts, %, grades).

## 7. Illustration system (core language)
- **Single-weight monoline** SVG, rounded caps/joins, no fills (except tiny accent
  dots).
- One motif per module, drawn from the same kit so the language is consistent.
- Used in: hero card backgrounds, **empty states** (primary use), section
  dividers, workspace landing heroes.
- Tint = theme primary or monochrome; opacity 5–15%.

## 8. Dashboard style
- **Greeting hero** (gradient + motif) → status pills → **KPI row** (3 tiles) →
  **insight/progress card** → **AI suggestion bar** → content.
- Big numbers, lots of whitespace, at most 4 primary colors on screen.

## 9. Empty states
- Centered **line-art illustration** + short human title + one secondary line +
  a single primary action button. (e.g. "No reports yet → Create report".)

## 10. Workspace landing pages
- Each workspace (Front Office, Finance, Teacher, …) opens on a **branded hero**:
  workspace name, a relevant line-art motif, 2–3 headline stats, then its module
  cards. Establishes "you are in workspace X" with personality.

## 11. Bottom navigation
- Light glass / dark glass bar, 4 primary tabs + **center docked AI action**
  (gradient FAB in a reserved notch — ties to UX Batch 3b item #4) + a "More" tab.

---

## 12. AI School Builder alignment (future-readiness)
The system is **token-driven** (palette, gradient, motif set, radius, shadow) so the
future **AI School Builder** can emit a per-school theme: a school's brand color
becomes `primary`/gradient; its type (IIT/NEET foundation, residential, K-12…)
selects the **workspace set + motif pack**; light/dark is a per-user toggle on top.
Nothing here hardcodes a single school's identity — dynamic theming drops in at the
token layer. (See `docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md`.)

## 13. Rollout (not yet implemented)
- **Phase A:** encode tokens in `lib/theme/` (light first), build the shared
  primitives (gradient hero card, KPI tile, AI suggestion bar, empty-state with
  motif, line-art asset kit), migrate **one reference screen** (Parent home) and
  certify.
- **Phase B:** roll across dashboards/workspaces (folds in UX Batch 3b mobile work
  + Batch 4 dashboard modernization).
- **Phase C:** add the **dark theme** toggle.
Each phase: `flutter analyze` 0 err + full suite + golden regen, per the project bar.
