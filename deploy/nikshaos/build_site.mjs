#!/usr/bin/env node
/**
 * Builds the nikshaos.in product website into `deploy/nikshaos/dist/`.
 *
 *   node deploy/nikshaos/build_site.mjs
 *
 * Output layout (mirrors the nginx vhost's `try_files $uri $uri.html`):
 *
 *   dist/index.html                    landing page
 *   dist/privacy.html                  -> /privacy
 *   dist/terms/user.html               -> /terms/user
 *   dist/terms/acceptable-use.html     -> /terms/acceptable-use
 *   dist/terms/institution.html        -> /terms/institution
 *   dist/assets/…                      brand assets, fonts, stylesheet, script
 *   dist/shots/…                       product captures, AVIF + WebP + PNG
 *
 * The four legal routes are NOT arbitrary: they are the `path` values in
 * `supabase/functions/_shared/legal/legal_catalog.ts`, which the Flutter client
 * joins to `LegalLinks.policyHostBaseUrl`. Changing a path here breaks the
 * in-app "view full policy" link. The post-build checks at the end of this file
 * assert that contract on the emitted bytes.
 *
 * Brand assets are COPIED from `brand/niksha-os/` — the approved package. This
 * script never draws or generates a mark; if an asset is missing it fails loudly
 * rather than substituting one.
 *
 * ★ ASSET-DRIVEN (proposal §3.0). An act renders only if every capture it names
 *   is present in `src/product-shots/shots.json`. Missing -> the act is OMITTED
 *   and the omission is printed. There is deliberately no code path that emits a
 *   shot-shaped element without a real file behind it, so placeholder UI is not
 *   discouraged here — it is unrepresentable.
 *
 * ★ ZERO THIRD-PARTY SCRIPTS. The site publishes "no third-party trackers"
 *   (claim 7). Keeping that true is a build constraint: no analytics, no fonts
 *   from a CDN, no embeds. Inter is vendored into `src/fonts/`. Do not add one.
 *
 * Requires `sharp` for the image pipeline — build tooling only, not a repo
 * dependency, the same convention as `brand/build_assets.js`:
 *
 *   npm i sharp --no-save
 */
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ACTS, DEFERRED_ACTS, LEGAL_ROUTES } from './src/acts.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, '..', '..');
const SRC = join(HERE, 'src');
const DIST = join(HERE, 'dist');
const BRAND = join(REPO, 'brand', 'niksha-os');
const LEGAL = join(REPO, 'docs', 'legal');
const SHOTS_DIR = join(SRC, 'product-shots');

let sharp = null;
try {
  ({ default: sharp } = await import('sharp'));
} catch {
  /* Resolved after the shot inventory is known: a build with no product shots
     does not need an encoder, and should not demand one. */
}

/* ------------------------------------------------------------------ *
 * Placeholder policy
 *
 * `docs/legal/PLACEHOLDERS.md` tokens that are genuine legal facts — the
 * registered address, the named Grievance Officer, the governing-law seat —
 * are NOT invented here. Only owner-authorised values are substituted; every
 * remaining token renders as a visible "pending" marker so a reader can never
 * mistake an unfilled field for a completed one.
 * ------------------------------------------------------------------ */
const SUPPORT_EMAIL = 'support@nikshaos.in';

const RESOLVED = {
  '[SUPPORT EMAIL]': SUPPORT_EMAIL,
  // Owner authorised support@ as the published contact address. Until dedicated
  // privacy@ / security@ mailboxes exist, routing these to the same verified
  // mailbox is accurate — it IS where such mail is received.
  '[PRIVACY EMAIL]': SUPPORT_EMAIL,
  '[SECURITY EMAIL]': SUPPORT_EMAIL,
  '[GRIEVANCE EMAIL]': SUPPORT_EMAIL,
};

/** Tokens that are legal facts; must be supplied by the owner before launch. */
const PENDING = [
  '[REGISTERED ADDRESS]',
  '[GRIEVANCE OFFICER NAME]',
  '[GRIEVANCE OFFICER DESIGNATION]',
  '[GOVERNING LAW CITY]',
  '[GOVERNING LAW STATE]',
];

const pendingSeen = new Set();

/**
 * Removes internal engineering directives from the published rendering.
 *
 * The source documents carry `> OWNER ACTION: …` blockquotes addressed to the
 * repo owner (fill placeholders, host the file, set the Play Console field).
 * Those are instructions to us, not terms offered to a reader — publishing them
 * on a public legal page is a defect. Stripped here rather than in the source,
 * so the markdown stays useful as an internal working document.
 */
function stripInternalNotes(md) {
  const lines = md.split('\n');
  const out = [];
  let i = 0;
  while (i < lines.length) {
    // The marker appears both at column 0 and indented inside a list item, so
    // the `>` must not be anchored to the line start.
    if (/^\s*>\s*OWNER ACTION\b/i.test(lines[i])) {
      while (i < lines.length && /^\s*>/.test(lines[i])) i++;  // consume the quote
      while (i < lines.length && !lines[i].trim()) i++;        // and its trailing blank
      continue;
    }
    out.push(lines[i]);
    i++;
  }
  // "(see PLACEHOLDERS.md)" points at an internal repo file; the surrounding
  // "Draft for owner sign-off" status is kept because it is true and the
  // pre-launch notice says the same thing.
  return out.join('\n').replace(/\s*\(see \[?PLACEHOLDERS\.md\]?(\([^)]*\))?\)/g, '');
}

function applyPlaceholders(md) {
  let out = md;
  for (const [token, value] of Object.entries(RESOLVED)) {
    out = out.split(token).join(value);
  }
  for (const token of PENDING) {
    if (out.includes(token)) {
      pendingSeen.add(token);
      const label = token.slice(1, -1).toLowerCase();
      out = out
        .split(token)
        .join(`<span class="pending" title="To be completed before public launch">${label} — pending</span>`);
    }
  }
  // Internal repo links have no public equivalent; render as plain text.
  out = out.replace(/\[CHANGELOG\]\(CHANGELOG\.md\)/g, 'the document changelog');
  return out;
}

/* ------------------------------------------------------------------ *
 * Markdown -> HTML
 *
 * Deliberately small: it handles exactly the constructs the four legal
 * documents use (ATX headings, `-` lists, ordered lists, blockquotes, `---`
 * rules, tables, and inline bold/italic/code/link). Not a general renderer.
 * ------------------------------------------------------------------ */
function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/* Sentinel used to shield already-built HTML from escapeHtml(). It must not be
   anything that can occur in the source text: a bare number would be swallowed
   the first time a policy said "within 30 days". U+0001 cannot appear in the
   markdown, which is the whole point. */
const SENTINEL_OPEN = 'SPAN';
const SENTINEL_CLOSE = '';
const SENTINEL_RE = /SPAN(\d+)/g;

function inline(text) {
  // Protect already-injected pending spans from escaping.
  const spans = [];
  let t = text.replace(/<span class="pending"[^>]*>.*?<\/span>/g, (m) => {
    spans.push(m);
    return SENTINEL_OPEN + (spans.length - 1) + SENTINEL_CLOSE;
  });

  t = escapeHtml(t);
  t = t.replace(/`([^`]+)`/g, (_, c) => `<code>${c}</code>`);
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  t = t.replace(/(^|[^*])\*([^*\n]+)\*/g, '$1<em>$2</em>');
  // Markdown links. Repo-relative .md targets have no public page -> plain text.
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
    if (/^https?:\/\//.test(href)) {
      return `<a href="${href}" rel="noopener noreferrer" target="_blank">${label}</a>`;
    }
    const map = {
      'PRIVACY_POLICY.md': LEGAL_ROUTES.privacy,
      'PARENT_USER_TERMS.md': LEGAL_ROUTES.user,
      'ACCEPTABLE_USE_POLICY.md': LEGAL_ROUTES.acceptableUse,
      'INSTITUTION_AGREEMENT.md': LEGAL_ROUTES.institution,
    };
    const key = href.split('/').pop();
    if (map[key]) return `<a href="${map[key]}">${label}</a>`;
    return label;
  });
  t = t.replace(SENTINEL_RE, (_, i) => spans[Number(i)]);
  return t;
}

function renderMarkdown(md) {
  const lines = md.split('\n');
  const out = [];
  let i = 0;

  const flushList = (tag, items) => {
    out.push(`<${tag}>`);
    for (const it of items) out.push(`<li>${inline(it)}</li>`);
    out.push(`</${tag}>`);
  };

  while (i < lines.length) {
    const line = lines[i];

    if (!line.trim()) { i++; continue; }

    // Horizontal rule
    if (/^---+$/.test(line.trim())) { out.push('<hr />'); i++; continue; }

    // Heading
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      const level = h[1].length;
      const text = inline(h[2]);
      const id = h[2].toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      out.push(`<h${level} id="${id}">${text}</h${level}>`);
      i++;
      continue;
    }

    // Blockquote (consume the run)
    if (/^>\s?/.test(line)) {
      const buf = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        buf.push(lines[i].replace(/^>\s?/, ''));
        i++;
      }
      out.push(`<blockquote>${renderMarkdown(buf.join('\n'))}</blockquote>`);
      continue;
    }

    // Table
    if (/^\|/.test(line) && i + 1 < lines.length && /^\|[\s:|-]+\|?$/.test(lines[i + 1])) {
      const cells = (r) => r.replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
      const head = cells(lines[i]);
      i += 2;
      const body = [];
      while (i < lines.length && /^\|/.test(lines[i])) { body.push(cells(lines[i])); i++; }
      out.push('<div class="table-wrap"><table><thead><tr>');
      for (const c of head) out.push(`<th>${inline(c)}</th>`);
      out.push('</tr></thead><tbody>');
      for (const row of body) {
        out.push('<tr>');
        for (const c of row) out.push(`<td>${inline(c)}</td>`);
        out.push('</tr>');
      }
      out.push('</tbody></table></div>');
      continue;
    }

    // Unordered list
    if (/^[-*]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^[-*]\s+/.test(lines[i])) {
        let item = lines[i].replace(/^[-*]\s+/, '');
        i++;
        // Continuation lines (indented) belong to the same item.
        while (i < lines.length && /^\s{2,}\S/.test(lines[i]) && !/^[-*]\s+/.test(lines[i].trim())) {
          item += ' ' + lines[i].trim();
          i++;
        }
        items.push(item);
      }
      flushList('ul', items);
      continue;
    }

    // Ordered list
    if (/^\d+\.\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\d+\.\s+/.test(lines[i])) {
        let item = lines[i].replace(/^\d+\.\s+/, '');
        i++;
        while (i < lines.length && /^\s{2,}\S/.test(lines[i]) && !/^\d+\.\s+/.test(lines[i].trim())) {
          item += ' ' + lines[i].trim();
          i++;
        }
        items.push(item);
      }
      flushList('ol', items);
      continue;
    }

    // Paragraph (consume until blank / block start)
    const para = [];
    while (
      i < lines.length &&
      lines[i].trim() &&
      !/^(#{1,6}\s|[-*]\s|\d+\.\s|>|\|)/.test(lines[i]) &&
      !/^---+$/.test(lines[i].trim())
    ) {
      para.push(lines[i]);
      i++;
    }
    if (para.length) {
      // Soft line breaks normally join — the documents are wrapped prose. The
      // exception is a line opening with a bold label (`**Last updated:** …`),
      // which is a metadata row the author intended to stand on its own; joining
      // those turns the document header into one run-on sentence.
      let text = '';
      for (let n = 0; n < para.length; n++) {
        const isLabel = /^\*\*[^*]+:\*\*/.test(para[n]);
        text += n === 0 ? para[n] : (isLabel ? '\n' : ' ') + para[n];
      }
      out.push(`<p>${inline(text).split('\n').join('<br />')}</p>`);
    }
  }

  return out.join('\n');
}

/* ------------------------------------------------------------------ *
 * Build helpers
 * ------------------------------------------------------------------ */
function need(path, what) {
  if (!existsSync(path)) {
    console.error(`\nFATAL: approved brand asset missing: ${what}\n  expected at: ${path}\n` +
      `This script does not substitute branding. Add the approved asset and re-run.\n`);
    process.exit(1);
  }
  return path;
}

function fail(msg) {
  console.error(`\nFATAL: ${msg}\n`);
  process.exit(1);
}

rmSync(DIST, { recursive: true, force: true });
mkdirSync(join(DIST, 'assets'), { recursive: true });
mkdirSync(join(DIST, 'terms'), { recursive: true });
mkdirSync(join(DIST, 'shots'), { recursive: true });

/* ------------------------------------------------------------------ *
 * Product shots -> responsive image pipeline
 *
 * Every published shot must carry provenance. `shots.json` is written by
 * scripts/marketing/promote_shots.mjs from the capture manifest; a PNG sitting
 * in the directory without an entry is refused rather than published, the same
 * fail-loud discipline the brand assets already get.
 * ------------------------------------------------------------------ */
const WIDTHS = [300, 600, 900, 1200];

const shotsManifest = existsSync(join(SHOTS_DIR, 'shots.json'))
  ? JSON.parse(readFileSync(join(SHOTS_DIR, 'shots.json'), 'utf8'))
  : { shots: {} };
const SHOTS = shotsManifest.shots || {};

const rendered = {};
if (Object.keys(SHOTS).length) {
  if (!sharp) {
    fail(
      'product shots are present but `sharp` is not installed, so AVIF/WebP cannot be encoded.\n' +
        '  npm i sharp --no-save        (build tooling only, not a repo dependency)',
    );
  }
  for (const [name, meta] of Object.entries(SHOTS)) {
    const src = join(SHOTS_DIR, meta.file);
    if (!existsSync(src)) fail(`shots.json lists "${name}" but ${meta.file} is not in ${SHOTS_DIR}.`);

    const { width: srcW, height: srcH } = await sharp(src).metadata();

    /* The manifest's pixel dimensions come from the capture run. If the file on
       disk disagrees, the provenance no longer describes these pixels — which is
       exactly the class of defect that made the capture manifest untrustworthy
       four times over (§6.3). Refuse rather than publish a false record. */
    if (meta.pixels && meta.pixels !== `${srcW}x${srcH}`) {
      fail(
        `"${name}" is ${srcW}x${srcH} on disk but its manifest records ${meta.pixels}.\n` +
          `  Re-run scripts/marketing/promote_shots.mjs so provenance matches the pixels.`,
      );
    }

    const widths = WIDTHS.filter((w) => w <= srcW);
    if (!widths.length) widths.push(srcW);

    const variants = { avif: [], webp: [], png: [] };
    for (const w of widths) {
      const h = Math.round((srcH / srcW) * w);
      const base = `${name}-${w}`;
      const resized = sharp(src).resize({ width: w, withoutEnlargement: true });
      await resized.clone().avif({ quality: 55, effort: 4 }).toFile(join(DIST, 'shots', `${base}.avif`));
      await resized.clone().webp({ quality: 78 }).toFile(join(DIST, 'shots', `${base}.webp`));
      await resized.clone().png({ compressionLevel: 9, palette: true }).toFile(join(DIST, 'shots', `${base}.png`));
      variants.avif.push(`/shots/${base}.avif ${w}w`);
      variants.webp.push(`/shots/${base}.webp ${w}w`);
      variants.png.push(`/shots/${base}.png ${w}w`);
      if (w === widths[widths.length - 1]) variants.fallback = { src: `/shots/${base}.png`, w, h };
    }
    rendered[name] = { ...meta, srcW, srcH, variants };
  }
}

/**
 * A `<picture>` with explicit intrinsic dimensions.
 *
 * `width`/`height` are always emitted so the browser reserves the box before
 * the bytes arrive — this is what holds CLS under 0.02 (§8.1). Alt text comes
 * from the manifest and describes what the screen SHOWS, never "screenshot of
 * the app" (§9.4).
 */
function picture(name, { sizes = '100vw', loading = 'lazy', fetchpriority } = {}) {
  const s = rendered[name];
  if (!s) fail(`picture("${name}") — no such promoted shot. An act must declare it in \`requires\`.`);
  const fp = fetchpriority ? ` fetchpriority="${fetchpriority}"` : '';
  return `<picture>
  <source type="image/avif" srcset="${s.variants.avif.join(', ')}" sizes="${sizes}" />
  <source type="image/webp" srcset="${s.variants.webp.join(', ')}" sizes="${sizes}" />
  <img src="${s.variants.fallback.src}" srcset="${s.variants.png.join(', ')}" sizes="${sizes}"
       width="${s.srcW}" height="${s.srcH}" alt="${escapeHtml(s.alt || '')}"
       loading="${loading}" decoding="async"${fp} />
</picture>`;
}

/* ------------------------------------------------------------------ *
 * Act gating — the mechanical form of §3.0
 * ------------------------------------------------------------------ */
const ctx = { has: (n) => Boolean(rendered[n]), picture };
const omissions = [];
const body = [];

for (const act of ACTS) {
  const missing = (act.requires || []).filter((n) => !rendered[n]);

  /* An act that degrades by item (the persona grid) needs a floor, not a full
     set: below the floor it is omitted rather than shown as a stub. */
  let present = null;
  if (act.degradesOver) {
    present = act.degradesOver.filter((n) => rendered[n]);
    if (present.length < (act.minimum ?? 1)) {
      missing.push(`fewer than ${act.minimum} of [${act.degradesOver.join(', ')}]`);
    }
  }

  if (missing.length) {
    if (act.required) {
      fail(
        `${act.title} is REQUIRED by the launch floor but is missing: ${missing.join(', ')}.\n` +
          `  Capture it, review it, and promote it with scripts/marketing/promote_shots.mjs.`,
      );
    }
    omissions.push({ title: act.title, missing });
    continue;
  }

  body.push(act.render(ctx));
  if (present && present.length < act.degradesOver.length) {
    const dropped = act.degradesOver.filter((n) => !rendered[n]);
    omissions.push({ title: `${act.title} (rendered, degraded)`, missing: dropped, partial: true });
  }
}

/* ------------------------------------------------------------------ *
 * Page shell — shared by the landing page and every legal page.
 * ------------------------------------------------------------------ */
const NAV = `
    <a class="brand" href="/" aria-label="NIKSHA OS home">
      <img class="brand-symbol" src="/assets/niksha-os-symbol.png" alt="" width="34" height="34" />
      <span class="brand-name"><span class="wordmark">NIKSHA</span><span class="suffix">OS</span></span>
    </a>
    <nav class="nav" aria-label="Primary">
      <a href="/#same-truth">Product</a>
      <a href="/#guardrails">Privacy</a>
      <a href="/#close">Contact</a>
      <a class="btn btn-primary btn-sm" href="https://app.nikshaos.in">Sign in</a>
    </nav>`;

const FOOTER = `
  <footer class="site-footer">
    <div class="container footer-grid">
      <div class="footer-brand">
        <img src="/assets/niksha-os-symbol-on-dark.png" alt="" width="40" height="40" />
        <p class="footer-name"><span class="wordmark">NIKSHA</span><span class="suffix">OS</span></p>
        <p class="footer-tagline">One system for the whole school.</p>
      </div>
      <div>
        <h2>Product</h2>
        <ul>
          <li><a href="/#same-truth">Overview</a></li>
          <li><a href="/#guardrails">Privacy &amp; data</a></li>
          <li><a href="https://app.nikshaos.in">Sign in</a></li>
        </ul>
      </div>
      <div>
        <h2>Legal</h2>
        <ul>
          <li><a href="${LEGAL_ROUTES.privacy}">Privacy Policy</a></li>
          <li><a href="${LEGAL_ROUTES.user}">Parent &amp; User Terms</a></li>
          <li><a href="${LEGAL_ROUTES.acceptableUse}">Acceptable Use</a></li>
          <li><a href="${LEGAL_ROUTES.institution}">Institution Agreement</a></li>
        </ul>
      </div>
      <div>
        <h2>Contact</h2>
        <ul>
          <li><a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a></li>
        </ul>
      </div>
    </div>
    <div class="container footer-base">
      <p>&copy; 2026 NIKSHA Technologies Pvt. Ltd. All rights reserved.</p>
    </div>
  </footer>`;

function shell({ title, description, body, bodyClass = '', canonical, script = false }) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${title}</title>
<meta name="description" content="${description}" />
<link rel="canonical" href="${canonical}" />
<meta property="og:type" content="website" />
<meta property="og:site_name" content="NIKSHA OS" />
<meta property="og:title" content="${title}" />
<meta property="og:description" content="${description}" />
<meta property="og:url" content="${canonical}" />
<meta property="og:image" content="https://nikshaos.in/assets/og-image-1200x630.png" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="theme-color" content="#0B1F4B" />
<link rel="icon" href="/assets/favicon-32.png" sizes="32x32" />
<link rel="icon" href="/assets/favicon-192.png" sizes="192x192" />
<link rel="apple-touch-icon" href="/assets/favicon-180.png" />
<link rel="preload" href="/assets/fonts/inter-latin.woff2" as="font" type="font/woff2" crossorigin />
<link rel="stylesheet" href="/assets/styles.css" />
</head>
<body class="${bodyClass}">
<a class="skip" href="#main">Skip to content</a>
<header class="site-header" data-header>
  <div class="container header-inner">${NAV}
  </div>
</header>
<span class="header-sentinel" data-header-sentinel aria-hidden="true"></span>
<main id="main">
${body}
</main>
${FOOTER}
${script ? '<script src="/assets/site.js" defer></script>' : ''}
</body>
</html>
`;
}

/* ------------------------------------------------------------------ *
 * Assets
 * ------------------------------------------------------------------ */

/* The traced SVG master is 406 paths and ~326KB — correct as a master, far too
   heavy for a 34px header mark, and nothing on the site references it. The PNGs
   are generated from that same master by brand/build_assets.js, so using one
   here is still the approved artwork (BRAND_GUIDELINES.md §6 permits "the vector
   master or a PNG generated from it"), at 9KB instead of 326KB. */
const ASSETS = [
  [join(BRAND, 'png', 'symbol-128-transparent.png'), 'niksha-os-symbol.png'],
  [join(BRAND, 'png', 'symbol-128-dark.png'), 'niksha-os-symbol-on-dark.png'],
  [join(BRAND, 'icons', 'favicon-32.png'), 'favicon-32.png'],
  [join(BRAND, 'icons', 'favicon-180.png'), 'favicon-180.png'],
  [join(BRAND, 'icons', 'favicon-192.png'), 'favicon-192.png'],
  [join(BRAND, 'icons', 'favicon-512.png'), 'favicon-512.png'],
  [join(BRAND, 'png', 'og-image-1200x630.png'), 'og-image-1200x630.png'],
];
for (const [from, to] of ASSETS) {
  need(from, to);
  copyFileSync(from, join(DIST, 'assets', to));
}

copyFileSync(join(SRC, 'styles.css'), join(DIST, 'assets', 'styles.css'));
copyFileSync(join(SRC, 'site.js'), join(DIST, 'assets', 'site.js'));

/* Site artwork (not a brand asset — it never draws the mark). */
need(join(SRC, 'blueprint.svg'), 'blueprint.svg (run src/blueprint/make_blueprint.mjs)');
copyFileSync(join(SRC, 'blueprint.svg'), join(DIST, 'assets', 'blueprint.svg'));

/* Inter, vendored. Claim 7 forbids a CDN font; §8.2.9 requires self-hosting. */
mkdirSync(join(DIST, 'assets', 'fonts'), { recursive: true });
for (const f of ['inter-latin.woff2', 'inter-latin-ext.woff2', 'Inter-LICENSE.txt']) {
  need(join(SRC, 'fonts', f), `vendored font ${f}`);
  copyFileSync(join(SRC, 'fonts', f), join(DIST, 'assets', 'fonts', f));
}

/* ------------------------------------------------------------------ *
 * Landing page
 * ------------------------------------------------------------------ */
writeFileSync(
  join(DIST, 'index.html'),
  shell({
    /* Claim 16 (§10): the old H1 "The AI Operating System for Schools"
       front-loaded AI for a product whose AI surface is a read-only copilot,
       and §10 makes it defensible only if Act III describes the boundary
       honestly. Act III is omitted (no Copilot capture, and claim 10 is still
       ⚠), so per that condition the AI framing is not carried forward. */
    title: 'NIKSHA OS — one system for the whole school',
    description:
      'NIKSHA OS runs admissions, attendance, examinations, fees, transport, hostel, library, HR and parent ' +
      'communication on one record per student — mobile-first, built for Indian schools.',
    canonical: 'https://nikshaos.in/',
    bodyClass: 'page-landing',
    body: body.join('\n'),
    script: true,
  }),
);

/* ------------------------------------------------------------------ *
 * Legal pages
 * ------------------------------------------------------------------ */
const LEGAL_PAGES = [
  { md: 'PRIVACY_POLICY.md', out: 'privacy.html', route: LEGAL_ROUTES.privacy, title: 'Privacy Policy' },
  { md: 'PARENT_USER_TERMS.md', out: 'terms/user.html', route: LEGAL_ROUTES.user, title: 'Parent & User Terms' },
  { md: 'ACCEPTABLE_USE_POLICY.md', out: 'terms/acceptable-use.html', route: LEGAL_ROUTES.acceptableUse, title: 'Acceptable Use Policy' },
  { md: 'INSTITUTION_AGREEMENT.md', out: 'terms/institution.html', route: LEGAL_ROUTES.institution, title: 'School / Institution Agreement' },
];

const PRELAUNCH_NOTICE = `
<div class="notice" role="note">
  <strong>Pre-launch document.</strong> The registered address, named Grievance Officer and
  governing-law seat are marked <span class="pending">pending</span> and will be published
  before public release. For any question about this document, contact
  <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.
</div>`;

for (const page of LEGAL_PAGES) {
  const raw = readFileSync(join(LEGAL, page.md), 'utf8');
  const before = pendingSeen.size;
  const html = renderMarkdown(applyPlaceholders(stripInternalNotes(raw)));
  const hasPending = pendingSeen.size > before || /class="pending"/.test(html);
  const pageBody = `
<article class="legal container">
  <p class="legal-back"><a href="/">&larr; Back to NIKSHA OS</a></p>
  ${hasPending ? PRELAUNCH_NOTICE : ''}
  ${html}
</article>`;
  const outPath = join(DIST, page.out);
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(
    outPath,
    shell({
      title: `${page.title} — NIKSHA OS`,
      description: `${page.title} for NIKSHA OS, operated by NIKSHA Technologies Pvt. Ltd.`,
      canonical: `https://nikshaos.in${page.route}`,
      bodyClass: 'page-legal',
      body: pageBody,
    }),
  );
}

/* ------------------------------------------------------------------ *
 * ★ Post-build contract checks
 *
 * The four legal routes are joined at runtime by the Flutter client from
 * `supabase/functions/_shared/legal/legal_catalog.ts`. If a refactor drops or
 * renames one, the in-app "view full policy" link breaks silently — the site
 * still builds, still looks correct, and the failure only surfaces on a user's
 * phone. So the build asserts the contract on its own output rather than
 * trusting that nobody touched it.
 *
 * These run against dist/, not against intent: they check the bytes that will
 * be copied to /var/www/nikshaos-site.
 * ------------------------------------------------------------------ */
const built = readFileSync(join(DIST, 'index.html'), 'utf8');
const contractErrors = [];

/* ★ Read the expected paths from legal_catalog.ts — the OTHER side of the
   contract — rather than from this build's own constants.

   An earlier version of this check iterated LEGAL_PAGES and asserted that each
   route matched itself, which passed for every possible value of the routes and
   protected nothing. A guard has to compare the output against an INDEPENDENT
   source of truth or it is theatre. */
const catalogSrc = readFileSync(
  join(REPO, 'supabase', 'functions', '_shared', 'legal', 'legal_catalog.ts'),
  'utf8',
);
const catalogPaths = [...catalogSrc.matchAll(/^\s*path:\s*"([^"]+)"/gm)].map((m) => m[1]);

if (catalogPaths.length !== 4) {
  contractErrors.push(
    `expected 4 policy paths in legal_catalog.ts, found ${catalogPaths.length} ` +
      `[${catalogPaths.join(', ')}] — the catalog changed shape; re-check this build`,
  );
}

for (const route of catalogPaths) {
  const file = `${route.replace(/^\//, '')}.html`;
  if (!existsSync(join(DIST, file))) {
    contractErrors.push(
      `legal_catalog.ts publishes "${route}" but this build emits no dist/${file} — ` +
        `the in-app "view full policy" link for that document would 404`,
    );
  }
  if (!built.includes(`href="${route}"`)) {
    contractErrors.push(`legal_catalog.ts publishes "${route}" but the landing page does not link it`);
  }
}

/* Claim 7 is published ON this page ("no third-party trackers"), so a
   third-party request would make the site contradict itself. Absence is the
   only evidence for that claim, which makes it checkable. */
const externalHosts = [...built.matchAll(/(?:src|href)="https?:\/\/([^/"]+)/g)]
  .map((m) => m[1])
  .filter((h) => !/(^|\.)nikshaos\.in$/.test(h));
if (externalHosts.length) {
  contractErrors.push(
    `third-party request(s) would be issued: ${[...new Set(externalHosts)].join(', ')} — ` +
      `this breaks the published "no third-party trackers" claim`,
  );
}

/* Every product image must carry intrinsic dimensions (CLS) and real alt text. */
for (const tag of built.match(/<img\b[^>]*>/g) || []) {
  if (!/\bwidth="/.test(tag) || !/\bheight="/.test(tag)) {
    contractErrors.push(`an <img> lacks explicit width/height (CLS budget): ${tag.slice(0, 90)}…`);
  }
  if (!/\balt="/.test(tag)) {
    contractErrors.push(`an <img> lacks an alt attribute: ${tag.slice(0, 90)}…`);
  }
}

if (contractErrors.length) {
  console.error('\nFATAL: post-build contract checks failed:');
  for (const e of contractErrors) console.error(`  ✗ ${e}`);
  console.error('');
  process.exit(1);
}

/* ------------------------------------------------------------------ *
 * Report — omissions are a visible build output, never a silent gap.
 * ------------------------------------------------------------------ */
console.log(`Built ${1 + LEGAL_PAGES.length} pages · ${Object.keys(rendered).length} product shots · ${ASSETS.length + 5} assets -> ${DIST}`);

console.log(`\nActs rendered:`);
for (const act of ACTS) {
  const dropped = omissions.find((o) => o.title.startsWith(act.title));
  if (!dropped) console.log(`  ✓ ${act.title}`);
  else if (dropped.partial) console.log(`  ◐ ${act.title} — degraded, missing: ${dropped.missing.join(', ')}`);
}

const hard = omissions.filter((o) => !o.partial);
if (hard.length) {
  console.log(`\nOMITTED (asset-driven, §3.0) — a section with a missing capture is dropped, never stubbed:`);
  for (const o of hard) console.log(`  ✗ ${o.title} — missing: ${o.missing.join(', ')}`);
}

if (DEFERRED_ACTS.length) {
  console.log(`\nNOT BUILT — specified in the proposal, waiting on captures:`);
  for (const d of DEFERRED_ACTS) console.log(`  · ${d.title} — needs ${d.missing.join(', ')}\n      ${d.note}`);
}

if (pendingSeen.size) {
  console.log(`\nOWNER ACTION — unfilled legal fields rendered as "pending":`);
  for (const t of [...pendingSeen].sort()) console.log(`  ${t}`);
}
