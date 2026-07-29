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
 *   dist/assets/…                      brand assets + stylesheet
 *
 * The four legal routes are NOT arbitrary: they are the `path` values in
 * `supabase/functions/_shared/legal/legal_catalog.ts`, which the Flutter client
 * joins to `LegalLinks.policyHostBaseUrl`. Changing a path here breaks the
 * in-app "view full policy" link.
 *
 * Brand assets are COPIED from `brand/niksha-os/` — the approved package. This
 * script never draws or generates a mark; if an asset is missing it fails loudly
 * rather than substituting one.
 */
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, '..', '..');
const SRC = join(HERE, 'src');
const DIST = join(HERE, 'dist');
const BRAND = join(REPO, 'brand', 'niksha-os');
const LEGAL = join(REPO, 'docs', 'legal');

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
   the first time a policy said "within 30 days". */
const SENTINEL_OPEN = '\u0001SPAN';
const SENTINEL_CLOSE = '\u0001';
const SENTINEL_RE = /\u0001SPAN(\d+)\u0001/g;

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
      'PRIVACY_POLICY.md': '/privacy',
      'PARENT_USER_TERMS.md': '/terms/user',
      'ACCEPTABLE_USE_POLICY.md': '/terms/acceptable-use',
      'INSTITUTION_AGREEMENT.md': '/terms/institution',
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
 * Page shell — shared by the landing page and every legal page.
 * ------------------------------------------------------------------ */
const NAV = `
    <a class="brand" href="/" aria-label="NIKSHA OS home">
      <img class="brand-symbol" src="/assets/niksha-os-symbol.svg" alt="" width="36" height="36" />
      <span class="brand-name"><span class="wordmark">NIKSHA</span><span class="suffix">OS</span></span>
    </a>
    <nav class="nav" aria-label="Primary">
      <a href="/#product">Product</a>
      <a href="/#features">Features</a>
      <a href="/#security">Privacy</a>
      <a href="/#contact">Contact</a>
      <a class="btn btn-primary btn-sm" href="https://app.nikshaos.in">Sign in</a>
    </nav>`;

const FOOTER = `
  <footer class="site-footer">
    <div class="container footer-grid">
      <div class="footer-brand">
        <img src="/assets/niksha-os-symbol-on-dark.svg" alt="" width="40" height="40" />
        <p class="footer-name"><span class="wordmark">NIKSHA</span><span class="suffix">OS</span></p>
        <p class="footer-tagline">The AI Operating System for Schools</p>
      </div>
      <div>
        <h3>Product</h3>
        <ul>
          <li><a href="/#product">Overview</a></li>
          <li><a href="/#features">Features</a></li>
          <li><a href="/#screens">Screens</a></li>
          <li><a href="https://app.nikshaos.in">Sign in</a></li>
        </ul>
      </div>
      <div>
        <h3>Legal</h3>
        <ul>
          <li><a href="/privacy">Privacy Policy</a></li>
          <li><a href="/terms/user">Parent &amp; User Terms</a></li>
          <li><a href="/terms/acceptable-use">Acceptable Use</a></li>
          <li><a href="/terms/institution">Institution Agreement</a></li>
        </ul>
      </div>
      <div>
        <h3>Contact</h3>
        <ul>
          <li><a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a></li>
        </ul>
      </div>
    </div>
    <div class="container footer-base">
      <p>&copy; 2026 NIKSHA Technologies Pvt. Ltd. All rights reserved.</p>
    </div>
  </footer>`;

function shell({ title, description, body, bodyClass = '', canonical }) {
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
<link rel="stylesheet" href="/assets/styles.css" />
</head>
<body class="${bodyClass}">
<a class="skip" href="#main">Skip to content</a>
<header class="site-header">
  <div class="container header-inner">${NAV}
  </div>
</header>
<main id="main">
${body}
</main>
${FOOTER}
</body>
</html>
`;
}

/* ------------------------------------------------------------------ *
 * Build
 * ------------------------------------------------------------------ */
function need(path, what) {
  if (!existsSync(path)) {
    console.error(`\nFATAL: approved brand asset missing: ${what}\n  expected at: ${path}\n` +
      `This script does not substitute branding. Add the approved asset and re-run.\n`);
    process.exit(1);
  }
  return path;
}

rmSync(DIST, { recursive: true, force: true });
mkdirSync(join(DIST, 'assets'), { recursive: true });
mkdirSync(join(DIST, 'terms'), { recursive: true });

// --- Brand assets (copied from the approved package, never generated here) ---
const ASSETS = [
  [join(BRAND, 'svg', 'niksha-os-symbol.svg'), 'niksha-os-symbol.svg'],
  [join(BRAND, 'svg', 'niksha-os-symbol-on-dark.svg'), 'niksha-os-symbol-on-dark.svg'],
  [join(BRAND, 'svg', 'niksha-os-symbol-white.svg'), 'niksha-os-symbol-white.svg'],
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

// --- Landing page ---
const landing = readFileSync(join(SRC, 'landing.html'), 'utf8');
writeFileSync(
  join(DIST, 'index.html'),
  shell({
    title: 'NIKSHA OS — The AI Operating System for Schools',
    description:
      'NIKSHA OS runs admissions, attendance, examinations, fees, transport, hostel, library, HR and parent communication for Indian schools — one mobile-first platform.',
    canonical: 'https://nikshaos.in/',
    bodyClass: 'page-landing',
    body: landing,
  }),
);

// --- Legal pages ---
const LEGAL_PAGES = [
  { md: 'PRIVACY_POLICY.md', out: 'privacy.html', route: '/privacy', title: 'Privacy Policy' },
  { md: 'PARENT_USER_TERMS.md', out: 'terms/user.html', route: '/terms/user', title: 'Parent & User Terms' },
  { md: 'ACCEPTABLE_USE_POLICY.md', out: 'terms/acceptable-use.html', route: '/terms/acceptable-use', title: 'Acceptable Use Policy' },
  { md: 'INSTITUTION_AGREEMENT.md', out: 'terms/institution.html', route: '/terms/institution', title: 'School / Institution Agreement' },
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
  const body = `
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
      body,
    }),
  );
}

console.log(`Built ${1 + LEGAL_PAGES.length} pages + ${ASSETS.length + 1} assets -> ${DIST}`);
if (pendingSeen.size) {
  console.log(`\nOWNER ACTION — unfilled legal fields rendered as "pending":`);
  for (const t of [...pendingSeen].sort()) console.log(`  ${t}`);
}
