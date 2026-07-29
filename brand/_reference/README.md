# Reference board — the source of truth

`niksha-brand-board.png` is the **approved brand artwork** for all three NIKSHA
brands. Every master in `brand/<brand>/svg/` is vectorised from it.

| | |
|---|---|
| File | `niksha-brand-board.png` |
| Dimensions | 1536 × 1024 |
| Bytes | 1,443,106 |
| SHA-256 | `a664c88765cd49f89f978e670617330ad6639974bf87857983427d65d308e4f2` |
| Approved | 2026-07-29, by the brand owner |

If that hash no longer matches, the board has been altered and **the masters no
longer derive from what was approved.** Re-trace, or restore the file.

---

## Why this lives in the repository

The masters are not hand-drawn — they are traced from this image, and every
gradient stop is a measured mean of its pixels. Without the board there is no way
to re-derive them, verify them, or make a faithful revision. It previously
existed only on one machine, outside version control.

## What the board contains

Three brand panels across the top — NIKSHA Technologies, NIKSHA OS, NIKSY — each
with its symbol, wordmark and tagline; app-icon treatments along the bottom.
Only the **symbols** are traced. The wordmarks are set in Inter per
`../BRAND_GUIDELINES.md` §5, not vectorised from this raster.

Within the board, each symbol occupies only a small area:

| Brand | Symbol artwork |
|---|---|
| NIKSHA Technologies | 296 × 226 px |
| NIKSHA OS | 244 × 269 px |
| NIKSY | 232 × 235 px |

That is the ceiling on achievable fidelity, and the reason the masters carry
several hundred paths: at icon and web sizes they are indistinguishable from the
board, but they cannot resolve detail the board never contained. **A
higher-resolution board is the single biggest available quality win** — if one is
ever produced, replace this file, update the hash above, and re-run the trace.

## Re-tracing

```bash
npm i sharp imagetracerjs          # not repo dependencies; tooling only
node brand/trace_from_reference.js # writes brand/<brand>/svg/<brand>-symbol.svg
node brand/build_assets.js         # regenerates every derivative
node brand/build_platform_icons.js # rewrites Android + iOS app icons
```

## The one intentional departure

The NIKSHA OS symbol on this board carries a **summit flag** at the upper right.
The approved mark does **not** — the flag was removed by owner decision, and the
trace deletes it by zone (`FLAG_ZONE` in `trace_from_reference.js`).

Verified at the pixel level: 63,544 flag pixels removed, and excluding that zone
the traced master matches the board's silhouette to 98.00%. Nothing else about
the OS mark was altered.

## Do not

- **Ship this file as an asset.** It is a source, not artwork. Ship a vector
  master or a PNG generated from it.
- **Edit it.** A revision means a new approved board, a new hash recorded here,
  and a re-trace — never a touch-up of either this image or a master.
- **Hand-edit a master to "fix" something.** Masters are build outputs of this
  board. Hand edits are silently lost on the next re-trace.
