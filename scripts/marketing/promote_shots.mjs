#!/usr/bin/env node
/**
 * Promotes reviewed captures from `build/marketing-capture/<tier>/` into
 * `deploy/nikshaos/src/product-shots/`, the only directory the website builds
 * from.
 *
 *   node scripts/marketing/promote_shots.mjs
 *
 * WHY THIS EXISTS
 * Nothing publishes straight out of `build/` (proposal §6.7). Promotion is a
 * deliberate, reviewed step, and this script is what makes "reviewed" mean
 * something: the roster below is an explicit allow-list. A capture that is not
 * named here is not promoted, no matter how good it looks, and every name
 * carries the two reviews §6.6 and §10.1 require:
 *
 *   dataHygiene   — no real school, pupil, contact, admission number or figure
 *   depictedState — the state shown is reachable in a build a customer could
 *                   run, OR is a committed capability with a tracked gap
 *
 * The script re-reads the capture manifest and copies its provenance forward,
 * so every published pixel can be traced to a commit, a device and a UTC
 * timestamp. It fails loudly rather than promoting anything it cannot verify.
 */
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync, rmSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, '..', '..');
const CAPTURES = join(REPO, 'build', 'marketing-capture');
const OUT = join(REPO, 'deploy', 'nikshaos', 'src', 'product-shots');

/* ------------------------------------------------------------------ roster *
 * The allow-list. Reviewed 2026-07-29 against the captures on disk.
 * ------------------------------------------------------------------------- */
const ROSTER = [
  {
    name: 'principal-admin-hub',
    tier: 'tablet',
    alt:
      'The Admin Hub on a tablet. A School Administration workspace header reads 1,248 students, ' +
      '86 staff and 96% attendance, above a three-column grid of modules — Admissions, Marketing, ' +
      'Finance, Student SIS, Exams, HR, Employee Platform, Management, Transport, Hostel, Library, ' +
      'Inventory and Director — beside a navigation rail.',
    dataHygiene: 'pass — built-in demo school; no real institution, pupil, contact or figure',
    depictedState:
      'pass — a signed-in principal reaches this screen in a shipping build; every module shown is one the role can open',
  },
  {
    name: 'teacher-dashboard',
    tier: 'phone',
    alt:
      "A teacher's dashboard on a phone. An attendance ring reads 89% present with 34 of 38 students " +
      'present and 1 of 3 classes marked, above an amber notice that attendance is not marked for ' +
      "Class 8-A Period 1 with a Mark now action, and the day's timetable starting with Mathematics " +
      'for Class 8-A in Room 204.',
    dataHygiene: 'pass — demo teacher "Priya"; no real pupil or contact data',
    depictedState:
      'pass under owner decision D9 — the "Geo+Face verified" check-in line depicts staff face verification, ' +
      'a committed product capability whose implementation gap is recorded in ' +
      'docs/engineering/FACE_VERIFICATION_IMPLEMENTATION_GAP.md and gated for launch',
  },
  {
    name: 'parent-dashboard',
    tier: 'phone',
    alt:
      'A parent view on a phone for Ravi Kumar of Class 8-A. Summary tiles read attendance Present, ' +
      'one homework item and ₹4,200 of fees, above alerts that a fee payment of ₹4,200 is due on ' +
      '12 June 2026 for Term 2, that four homework items are pending, and that a Mathematics exam is coming up.',
    dataHygiene: 'pass — demo pupil "Ravi Kumar" in the built-in demo school; the amount is demo data',
    depictedState:
      'pass — reachable by a signed-in parent in a shipping build. Re-reviewed 2026-07-29: the summary tiles ' +
      'that previously read "—" while the same values rendered populated below (proposal §6.5b) now read ' +
      'Present / 1 / ₹4,200, so the self-contradiction that blocked this shot is resolved',
  },
  {
    name: 'student-dashboard',
    tier: 'phone',
    alt:
      "A student's home screen on a phone. Today's timetable shows Science now with Mrs. Rao and English " +
      'next with Mr. Patel, above shortcuts to submit homework, open the report card and view progress, ' +
      'attendance marked present at 9:12 AM, and two homework items due with one overdue.',
    dataHygiene: 'pass — demo pupil; teacher names are demo fixtures',
    depictedState: 'pass — reachable by a signed-in student in a shipping build',
  },
];

/* ------------------------------------------------------------------ excluded *
 * Recorded, not silently dropped. The website is asset-driven: an absent shot
 * removes its section, so the reason it is absent has to be legible.
 * ------------------------------------------------------------------------- */
const EXCLUDED = [
  {
    name: 'sign-in',
    tier: 'phone + tablet',
    reason:
      'QA/debug chrome, forbidden by §6.1. The demo-auth build renders "Testing mode — choose a demo ' +
      'account", a "Testing accounts" persona row and "Testing OTP: 123456 only". The tablet capture ' +
      'additionally still reads "Akshara Demo School" (pre-rename). Publishable only from a build ' +
      'without ENABLE_DEMO_AUTH.',
  },
  {
    name: 'principal-admin-hub',
    tier: 'phone',
    reason:
      'Decision D11, confirmed by inspection on 2026-07-29: at phone width every module card leaves its ' +
      'right half and lower area empty, so three cards fill the viewport where thirteen fit on tablet, and ' +
      'the workspace header loses its 1,248 students / 86 staff / 96% attendance row entirely. The defect is ' +
      'phone-width only — the tablet capture of this screen is correct and is the one published. Reported, ' +
      'not fixed: per D2 the website must not commission product work.',
  },
  {
    name: 'teacher-dashboard / student-dashboard / parent-dashboard',
    tier: 'tablet',
    reason:
      'Layout defects at the tablet tier (proposal §6.5b), confirmed by inspection on 2026-07-29: ' +
      '"Mathematics" breaks mid-word into "Mathema / tics", content caps at ~63% of the canvas leaving a ' +
      'dead band, the docked AI affordance overlaps a row, the "Attendance not marked" row renders twice, ' +
      'and the student AI card still reads "AKSHARA …". Per D2 these are reported, not fixed for the website; ' +
      'the phone tier of each is used instead.',
  },
];

/* --------------------------------------------------------------------------- */

function fail(msg) {
  console.error(`\nFATAL: ${msg}\n`);
  process.exit(1);
}

const manifests = {};
for (const tier of ['phone', 'tablet', 'desktop']) {
  const p = join(CAPTURES, tier, 'manifest.json');
  if (existsSync(p)) manifests[tier] = JSON.parse(readFileSync(p, 'utf8'));
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const shots = {};
for (const entry of ROSTER) {
  const { name, tier } = entry;
  const src = join(CAPTURES, tier, `${name}.png`);
  if (!existsSync(src)) {
    fail(
      `roster entry "${name}" (${tier}) has no capture at ${src}.\n` +
        `Run: scripts/marketing/capture_shots.sh ${tier}`,
    );
  }

  const manifest = manifests[tier];
  if (!manifest) fail(`no capture manifest for tier "${tier}". A capture run must write one.`);

  const shot = (manifest.shots || []).find((s) => s.name === name);
  if (!shot) {
    fail(
      `"${name}" exists as a file but is absent from the ${tier} manifest.\n` +
        `An unmanifested image has no provenance and is never published.`,
    );
  }

  /* Provenance travels with the pixels. A shot whose capture run had a dirty
     working tree is still promotable, but the fact is recorded rather than lost. */
  copyFileSync(src, join(OUT, `${name}.png`));
  shots[name] = {
    file: `${name}.png`,
    tier,
    pixels: shot.pixels,
    alt: entry.alt,
    review: { dataHygiene: entry.dataHygiene, depictedState: entry.depictedState },
    capture: {
      commit: manifest.commit,
      branch: manifest.branch,
      workingTreeClean: manifest.workingTreeClean,
      capturedUtc: manifest.capturedUtc,
      device: manifest.device,
      build: manifest.build,
      data: manifest.data,
      logicalWidth: manifest.logicalWidth,
      density: manifest.density,
    },
  };
  console.log(`promoted  ${name.padEnd(22)} ${tier.padEnd(7)} ${shot.pixels}`);
}

writeFileSync(
  join(OUT, 'shots.json'),
  JSON.stringify(
    {
      note:
        'Promoted, reviewed product captures. This file is the website\'s only source of product ' +
        'imagery: build_site.mjs renders a section only if every shot it names is present here. ' +
        'Generated by scripts/marketing/promote_shots.mjs — do not hand-edit.',
      promotedUtc: new Date().toISOString().replace(/\.\d+Z$/, 'Z'),
      rules: {
        allowed: 'crop, scale, format conversion, a device bezel around an unmodified capture, blurring personal data',
        forbidden:
          'retouching UI, compositing across screens, inventing or editing any number/name/state, upscaling, ' +
          'a mid-animation frame, any QA or debug chrome',
      },
      shots,
      excluded: EXCLUDED,
    },
    null,
    2,
  ) + '\n',
);

console.log(`\n${Object.keys(shots).length} shots -> ${OUT}`);
console.log(`excluded (recorded in shots.json): ${EXCLUDED.length} entries`);

/* A capture sitting in build/ that nobody decided about is the failure mode this
   warning exists for — it is how an unreviewed image drifts into a release. */
for (const [tier, manifest] of Object.entries(manifests)) {
  for (const s of manifest.shots || []) {
    const inRoster = ROSTER.some((r) => r.name === s.name && r.tier === tier);
    const inExcluded = EXCLUDED.some((e) => e.name.includes(s.name) && e.tier.includes(tier));
    if (!inRoster && !inExcluded) {
      console.warn(`  ! undecided: ${tier}/${s.name} is captured but neither promoted nor excluded`);
    }
  }
}
