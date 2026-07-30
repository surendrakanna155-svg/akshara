#!/usr/bin/env node
/**
 * Generates `deploy/nikshaos/src/blueprint.svg` — the campus blueprint plane
 * used as the site's background drawing (proposal §3.3).
 *
 *   node deploy/nikshaos/src/blueprint/make_blueprint.mjs
 *
 * WHY A GENERATOR AND NOT A HAND-DRAWN FILE
 * The drawing has to read as a real architectural plan: a consistent structural
 * grid, rooms that repeat on a module, dimension strings whose ticks line up
 * with the thing they measure. Those relationships are arithmetic. Authoring
 * them by hand produces a drawing that looks approximately right and falls apart
 * under inspection, and every later tweak reintroduces the drift.
 *
 * WHAT THIS IS NOT
 * This is site artwork, NOT a brand asset. It never draws, recolours or
 * approximates the N mark. Brand masters are traced from the reference board by
 * `brand/trace_from_reference.js` and are the only source of the mark
 * (BRAND_GUIDELINES.md §7).
 *
 * CONSTRAINTS (proposal §3.3 / §8.2)
 *   - single colour, applied by the page via CSS `mask-image` so one file serves
 *     both the light and the navy ground
 *   - under 40KB
 *   - decorative: the consuming element carries aria-hidden="true"
 *   - animated only by transform: translate3d() — never redrawn
 */
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, '..', 'blueprint.svg');

/* The drawing is authored in a 1600×1200 field. Consumers scale it; nothing
   below depends on the final rendered size. */
const W = 1600;
const H = 1200;

/** Structural module. Every room, corridor and block is a multiple of this. */
const M = 40;

const n = (v) => (Math.round(v * 10) / 10).toString().replace(/\.0$/, '');
const parts = [];
const push = (s) => parts.push(s);

/* Stroke weights, per §3.3: 0.5 construction · 1 detail · 1.5 primary. */
const HAIR = 0.5;
const THIN = 1;
const BOLD = 1.5;

/* ------------------------------------------------------------------ helpers */

function rect(x, y, w, h, sw = THIN, extra = '') {
  push(`<rect x="${n(x)}" y="${n(y)}" width="${n(w)}" height="${n(h)}" stroke-width="${sw}"${extra}/>`);
}

function line(x1, y1, x2, y2, sw = THIN, extra = '') {
  push(`<path d="M${n(x1)} ${n(y1)}L${n(x2)} ${n(y2)}" stroke-width="${sw}"${extra}/>`);
}

function circle(cx, cy, r, sw = THIN) {
  push(`<circle cx="${n(cx)}" cy="${n(cy)}" r="${n(r)}" stroke-width="${sw}"/>`);
}

/**
 * A dimension string: witness lines at each end, a run line between them, and
 * 45° architect's ticks where they meet. `side` flips the witness extension.
 */
function dimension(x1, y1, x2, y2, off, side = 1) {
  const horiz = y1 === y2;
  const t = 5;
  if (horiz) {
    const y = y1 + off * side;
    line(x1, y1, x1, y + 6 * side, HAIR);
    line(x2, y2, x2, y + 6 * side, HAIR);
    line(x1, y, x2, y, HAIR);
    line(x1 - t, y + t, x1 + t, y - t, HAIR);
    line(x2 - t, y + t, x2 + t, y - t, HAIR);
  } else {
    const x = x1 + off * side;
    line(x1, y1, x + 6 * side, y1, HAIR);
    line(x2, y2, x + 6 * side, y2, HAIR);
    line(x, y1, x, y2, HAIR);
    line(x - t, y1 + t, x + t, y1 - t, HAIR);
    line(x - t, y2 + t, x + t, y2 - t, HAIR);
  }
}

/** A leader line with a terminator dot — the callout language of a real plan. */
function leader(x, y, dx, dy, tail = 26) {
  circle(x, y, 3, HAIR);
  line(x, y, x + dx, y + dy, HAIR);
  line(x + dx, y + dy, x + dx + tail, y + dy, HAIR);
}

/**
 * A block of rooms off a corridor. `rooms` cells of `cell` width sit above a
 * corridor of `corr` depth; each room gets a door swing, which is the detail
 * that makes a plan read as a plan rather than a grid.
 */
function roomBlock(x, y, rooms, cell, depth, corr, flip = false) {
  const total = rooms * cell;
  rect(x, y, total, depth + corr, BOLD);
  const roomY = flip ? y + corr : y;
  const corrY = flip ? y : y + depth;
  /* corridor */
  line(x, corrY, x + total, corrY, THIN);
  line(x, corrY + corr, x + total, corrY + corr, HAIR);
  for (let i = 1; i < rooms; i++) {
    line(x + i * cell, roomY, x + i * cell, roomY + depth, THIN);
  }
  /* doors onto the corridor */
  for (let i = 0; i < rooms; i++) {
    const dx = x + i * cell + cell * 0.34;
    const dw = cell * 0.3;
    const dy = flip ? roomY : roomY + depth;
    line(dx, dy, dx + dw, dy, HAIR, ' stroke-dasharray="3 3"');
    const sweep = flip ? 1 : 0;
    push(
      `<path d="M${n(dx)} ${n(dy)}A${n(dw)} ${n(dw)} 0 0 ${sweep} ${n(dx + dw)} ${n(
        flip ? dy + dw : dy - dw,
      )}" stroke-width="${HAIR}"/>`,
    );
  }
}

/** A stair run: treads, a walking line and its direction arrow. */
function stair(x, y, w, h, treads = 9) {
  rect(x, y, w, h, THIN);
  const step = h / treads;
  for (let i = 1; i < treads; i++) line(x, y + i * step, x + w, y + i * step, HAIR);
  line(x + w / 2, y + h - step * 0.5, x + w / 2, y + step * 0.5, HAIR);
  line(x + w / 2, y + step * 0.5, x + w / 2 - 4, y + step * 1.4, HAIR);
  line(x + w / 2, y + step * 0.5, x + w / 2 + 4, y + step * 1.4, HAIR);
}

/* ==================================================================== drawing
 *
 * VERTICAL ZONING — the plan and the section must never collide.
 *   y  1M .. 20M   site plan (viewed from above)
 *   y 22M .. 27M   section elevation (the same campus seen from the side)
 * Every element below is placed inside one of those two bands, and the bands do
 * not overlap. The first draft ignored this and the elevation ran through the
 * sports field; the zoning is what prevents that class of error recurring.
 * -------------------------------------------------------------------------- */

/* --- construction grid: the faint field every plan is set out on ---------- */
push('<g class="bp-grid">');
for (let x = M; x < W; x += M) line(x, 0, x, H, HAIR);
for (let y = M; y < H; y += M) line(0, y, W, y, HAIR);
push('</g>');

/* --- site boundary -------------------------------------------------------- */
push('<g class="bp-site">');
rect(M, M, W - 2 * M, H - 2 * M, THIN, ' stroke-dasharray="14 6 3 6"');
push('</g>');

/* --- north point ---------------------------------------------------------- */
push('<g class="bp-north">');
circle(W - 3.2 * M, 3.2 * M, 26, HAIR);
line(W - 3.2 * M, 3.2 * M + 20, W - 3.2 * M, 3.2 * M - 22, THIN);
line(W - 3.2 * M, 3.2 * M - 22, W - 3.2 * M - 7, 3.2 * M - 8, THIN);
line(W - 3.2 * M, 3.2 * M - 22, W - 3.2 * M + 7, 3.2 * M - 8, THIN);
push('</g>');

/* --- north teaching block: 8 classrooms off a corridor -------------------- */
push('<g class="bp-block">');
roomBlock(2 * M, 2 * M, 8, 1.5 * M, 2 * M, M);
dimension(2 * M, 2 * M, 14 * M, 2 * M, 26, -1);

/* --- west teaching block (rooms open east) -------------------------------- */
roomBlock(2 * M, 6.5 * M, 5, 1.5 * M, 2 * M, M, true);

/* --- east laboratory block ------------------------------------------------ */
roomBlock(20 * M, 6.5 * M, 5, 1.6 * M, 2 * M, M);
push('</g>');

/* --- central quadrangle --------------------------------------------------- */
push('<g class="bp-quad">');
const qx = 11 * M, qy = 6.5 * M, qw = 7 * M, qh = 5 * M;
rect(qx, qy, qw, qh, BOLD);
/* cross paths */
line(qx + qw / 2, qy, qx + qw / 2, qy + qh, HAIR, ' stroke-dasharray="6 5"');
line(qx, qy + qh / 2, qx + qw, qy + qh / 2, HAIR, ' stroke-dasharray="6 5"');
/* planting ring at the crossing */
circle(qx + qw / 2, qy + qh / 2, 34, THIN);
circle(qx + qw / 2, qy + qh / 2, 20, HAIR);
dimension(qx, qy + qh, qx + qw, qy + qh, 30, 1);
push('</g>');

/* --- connecting corridors ------------------------------------------------- */
push('<g class="bp-corridor">');
/* north block -> quad */
line(qx + qw / 2 - M / 2, 5 * M, qx + qw / 2 - M / 2, qy, THIN);
line(qx + qw / 2 + M / 2, 5 * M, qx + qw / 2 + M / 2, qy, THIN);
/* quad -> east labs */
line(qx + qw, qy + 1.5 * M, 20 * M, qy + 1.5 * M, THIN);
line(qx + qw, qy + 2.5 * M, 20 * M, qy + 2.5 * M, THIN);
/* quad -> west block */
line(9.5 * M, qy + 1.5 * M, qx, qy + 1.5 * M, THIN);
line(9.5 * M, qy + 2.5 * M, qx, qy + 2.5 * M, THIN);
push('</g>');

/* --- stairs --------------------------------------------------------------- */
push('<g class="bp-stair">');
stair(14 * M, 2 * M, 1.4 * M, 3 * M);
stair(28.4 * M, 13 * M, 1.4 * M, 2.6 * M, 7);
push('</g>');

/* --- library: reading hall with stack runs -------------------------------- */
push('<g class="bp-library">');
const lx = 30 * M, ly = 6.5 * M, lw = 7 * M, lh = 4.5 * M;
rect(lx, ly, lw, lh, BOLD);
for (let i = 1; i <= 7; i++) line(lx + i * (lw / 8), ly + M * 0.6, lx + i * (lw / 8), ly + lh - M * 0.6, HAIR);
line(lx, ly + M * 0.6, lx + lw, ly + M * 0.6, HAIR);
line(lx, ly + lh - M * 0.6, lx + lw, ly + lh - M * 0.6, HAIR);
push('</g>');

/* --- sports field: track + pitch ------------------------------------------ */
push('<g class="bp-field">');
const fx = 3 * M, fy = 13 * M, fw = 12 * M, fh = 6 * M;
push(
  `<rect x="${n(fx)}" y="${n(fy)}" width="${n(fw)}" height="${n(fh)}" rx="${n(fh / 2)}" stroke-width="${BOLD}"/>`,
);
push(
  `<rect x="${n(fx + 22)}" y="${n(fy + 22)}" width="${n(fw - 44)}" height="${n(fh - 44)}" rx="${n(
    (fh - 44) / 2,
  )}" stroke-width="${HAIR}"/>`,
);
rect(fx + 2.4 * M, fy + 1.3 * M, fw - 4.8 * M, fh - 2.6 * M, THIN);
line(fx + fw / 2, fy + 1.3 * M, fx + fw / 2, fy + fh - 1.3 * M, HAIR);
circle(fx + fw / 2, fy + fh / 2, 26, HAIR);
dimension(fx, fy, fx, fy + fh, 30, -1);
push('</g>');

/* --- assembly ground ------------------------------------------------------ */
push('<g class="bp-assembly">');
const ax = 17 * M, ay = 13.4 * M, aw = 9 * M, ah = 4.8 * M;
rect(ax, ay, aw, ah, THIN, ' stroke-dasharray="8 6"');
for (let i = 1; i < 6; i++) line(ax, ay + i * 0.8 * M, ax + aw, ay + i * 0.8 * M, HAIR);
push('</g>');

/* --- section elevation strip: the same campus seen from the side ---------- */
push('<g class="bp-section">');
const sy = 27 * M;                       /* ground line, inside the 22M..27M band */
line(1.6 * M, sy, W - 1.6 * M, sy, THIN);
/* ground hatch */
for (let x = 1.6 * M; x < W - 1.6 * M; x += 16) line(x, sy, x - 8, sy + 9, HAIR);
/* stepped profile: [width, height, floors]. Widths are chosen so the run ends
   inside the site boundary — see the assertion after the loop. */
const bays = [
  [4 * M, 3.5 * M, 3],
  [6 * M, 5 * M, 4],
  [3.5 * M, 2.5 * M, 2],
  [5 * M, 4.4 * M, 3],
  [7 * M, 5 * M, 4],
  [4 * M, 3 * M, 2],
];
const GAP = 0.5 * M;
let bx = 3 * M;
for (const [w, h, floors] of bays) {
  push(`<path d="M${n(bx)} ${n(sy)}V${n(sy - h)}H${n(bx + w)}V${n(sy)}" stroke-width="${BOLD}"/>`);
  for (let f = 1; f < floors; f++) {
    const plate = sy - (h / floors) * f;
    line(bx, plate, bx + w, plate, HAIR);
  }
  /* window openings on each floor */
  for (let f = 0; f < floors; f++) {
    const top = sy - (h / floors) * (f + 1) + 7;
    const bot = sy - (h / floors) * f - 7;
    const cols = Math.max(2, Math.round(w / 46));
    for (let c = 0; c < cols; c++) {
      const wx = bx + 10 + c * ((w - 20) / cols);
      const ww = (w - 20) / cols - 9;
      if (ww > 6 && bot - top > 6) rect(wx, top, ww, bot - top, HAIR);
    }
  }
  bx += w + GAP;
}
dimension(3 * M, sy, 3 * M, sy - 5 * M, 26, -1);
push('</g>');

/* --- plan callouts -------------------------------------------------------- */
push('<g class="bp-callout">');
leader(6 * M, 3 * M, 0, -1.4 * M, 34);
leader(qx + qw / 2, qy + qh / 2, 2.4 * M, -1.9 * M, 30);
leader(lx + lw / 2, ly + lh / 2, 0, 2.2 * M, 30);
leader(23 * M, 8.5 * M, 1.4 * M, -1.4 * M, 26);
push('</g>');

/* --- layout assertions: a drawing that overflows is a defect, not a style -- */
const siteRight = W - M;
if (bx - GAP > siteRight) {
  console.error(`FATAL: section elevation ends at ${n(bx - GAP)}, past the site boundary ${siteRight}.`);
  process.exit(1);
}
const planBottom = Math.max(fy + fh, ay + ah);       /* lowest plan element */
const sectionTop = sy - Math.max(...bays.map((b) => b[1]));
if (planBottom >= sectionTop) {
  console.error(
    `FATAL: the plan (bottom ${n(planBottom)}) collides with the section (top ${n(sectionTop)}).`,
  );
  process.exit(1);
}

/* ================================================================== output */

const svg =
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" ` +
  `fill="none" stroke="#000" stroke-linecap="square" stroke-linejoin="miter" ` +
  `role="presentation" aria-hidden="true">` +
  parts.join('') +
  `</svg>\n`;

writeFileSync(OUT, svg);
const kb = (Buffer.byteLength(svg) / 1024).toFixed(1);
console.log(`blueprint.svg  ${kb}KB  (${parts.length} elements)  -> ${OUT}`);
if (Buffer.byteLength(svg) > 40 * 1024) {
  console.error(`FATAL: blueprint exceeds the 40KB budget in proposal §3.3 (${kb}KB).`);
  process.exit(1);
}
