/**
 * The landing page, as a set of independently-omittable acts.
 *
 * ★ THE RULE THAT SHAPES THIS FILE (proposal §3.0)
 *   An act renders only if every product capture it names exists in
 *   `product-shots/shots.json`. An act with a missing shot is omitted
 *   ENTIRELY — never stubbed, never approximated, never a grey box. The
 *   current site fails exactly here, shipping three empty placeholders under
 *   copy promising screenshots "before public launch".
 *
 *   `requires` is what makes that mechanical rather than a matter of
 *   discipline: build_site.mjs drops any act whose requirements are unmet and
 *   logs what it dropped and why. There is no code path that emits a
 *   shot-shaped element without a real file behind it.
 *
 * ★ COPY IS GOVERNED BY THE CLAIMS REGISTER (proposal §10, decision D7)
 *   Every sentence here is evidence-backed. Where the register marks a claim
 *   ⚠, the wording is narrowed to what is actually verified — see the notes
 *   at each site. Do not restore a stronger form without new evidence.
 *
 * ★ STATIC FIRST (proposal §9.1, §12 W5)
 *   Each act's markup is its FINAL COMPOSED STATE. Motion is layered on later
 *   by site.js and removed entirely under `prefers-reduced-motion`. Nothing
 *   here is hidden pending an animation, so the page is complete with JS off —
 *   which is also what crawlers and link previews see.
 */

const APP = 'https://app.nikshaos.in';
const SUPPORT = 'support@nikshaos.in';

/* Legal routes are a CONTRACT, not URLs: these are the `path` values in
   supabase/functions/_shared/legal/legal_catalog.ts, joined at runtime to
   LegalLinks.policyHostBaseUrl by the Flutter client. Changing one breaks the
   in-app "view full policy" link. */
export const LEGAL_ROUTES = {
  privacy: '/privacy',
  user: '/terms/user',
  acceptableUse: '/terms/acceptable-use',
  institution: '/terms/institution',
};

/** A screenshot in a CSS device bezel.
 *
 *  §6.1 allows "a device bezel around an unmodified capture". The bezel is
 *  drawn in CSS, so not one pixel inside it is anything but the capture. */
function device(ctx, name, kind, opts = {}) {
  return `<div class="device device-${kind}">${ctx.picture(name, opts)}</div>`;
}

export const ACTS = [
  /* ==================================================================== 0 */
  {
    id: 'aperture',
    title: 'Act 0 · Aperture',
    required: true,
    /* The scene is composed to read correctly with whichever layers exist; the
       anchor is the one thing without which there is no product website. */
    requires: ['teacher-dashboard'],
    optional: ['principal-admin-hub', 'parent-dashboard'],
    render(ctx) {
      const hasContext = ctx.has('principal-admin-hub');
      const hasFore = ctx.has('parent-dashboard');
      return `
<section class="act act-aperture" id="top">
  <div class="bp-plane bp-plane-light" aria-hidden="true" data-parallax="0.06"></div>
  <div class="aperture-glow" aria-hidden="true"></div>

  <div class="container">
    <div class="aperture-copy" data-reveal>
      <h1 class="display">The school, in one system.</h1>
      <p class="lede">
        Admissions to alumni. One record per student, and every workflow reading the same truth.
      </p>
      <div class="cta-row">
        <a class="btn btn-primary btn-lg" href="${APP}">Sign in</a>
        <a class="btn btn-quiet btn-lg" href="#same-truth">See how it works</a>
      </div>
      <!-- Claim 14 (§10) is ⚠: the live database is demo scale and APP_ENV=staging
           is a ratified pre-launch gate, so plural present tense would imply an
           installed base that does not exist. Stated as pilot reality instead. -->
      <p class="micro">Currently in pilot with schools in India. New school? <a href="#close">Talk to us</a>.</p>
    </div>

    <div class="stage" data-scene>
      <!-- The sizes attribute mirrors the CSS layout exactly. Above 1030px the
           stage is a fixed 980px, so the layers are fixed pixel widths rather
           than vw — declaring vw there would make the browser fetch a rendition
           larger than anything the page can display. The mobile values
           deliberately match Act II's, so the same rendition serves both and
           each capture is downloaded once rather than twice. -->
      ${
        hasContext
          ? `<div class="layer layer-context" data-depth="-1.6">
        ${device(ctx, 'principal-admin-hub', 'tablet', {
          sizes: '(max-width: 767px) 74vw, (max-width: 1030px) 40vw, 412px',
          fetchpriority: 'high',
          loading: 'eager',
        })}
      </div>`
          : ''
      }
      <div class="layer layer-anchor" data-depth="0">
        ${device(ctx, 'teacher-dashboard', 'phone', {
          sizes: '(max-width: 767px) 58vw, (max-width: 1030px) 20vw, 206px',
          fetchpriority: 'high',
          loading: 'eager',
        })}
      </div>
      ${
        hasFore
          ? `<div class="layer layer-fore" data-depth="2.1">
        ${device(ctx, 'parent-dashboard', 'phone', {
          sizes: '(max-width: 767px) 40vw, (max-width: 1030px) 16vw, 162px',
        })}
      </div>`
          : ''
      }
    </div>
  </div>
</section>`;
    },
  },

  /* =================================================================== II *
   * Rev 2's Act II staged five module journeys (admissions → academic →
   * finance → communication → AI). Those beats need screens that do not
   * exist yet — admissions enrolment, marks entry, fee receipt, the copilot —
   * so under §3.0 that act is omitted rather than stubbed.
   *
   * What DOES exist is the same school seen by four different people, which
   * carries the identical product truth ("one record, every workflow reading
   * the same truth") using only captures that are real today. It degrades by
   * card and disappears below two.
   * ==================================================================== */
  {
    id: 'same-truth',
    title: 'Act II · The same truth',
    required: false,
    requires: [],
    /* Renders with >= 2 of these; each card is independently omittable. */
    degradesOver: ['principal-admin-hub', 'teacher-dashboard', 'parent-dashboard', 'student-dashboard'],
    minimum: 2,
    render(ctx) {
      const cards = [
        {
          shot: 'principal-admin-hub',
          kind: 'tablet',
          role: 'Principal',
          line:
            'The whole school in one workspace — every module the role is authorised to open, ' +
            'and the day\'s numbers computed from the school\'s own records.',
        },
        {
          shot: 'teacher-dashboard',
          kind: 'phone',
          role: 'Teacher',
          line:
            'Today\'s classes, who is still unmarked, and a register that can be completed from ' +
            'a phone while standing in the classroom.',
        },
        {
          shot: 'parent-dashboard',
          kind: 'phone',
          role: 'Parent',
          line:
            'Their own child, and nothing else: attendance, homework and exactly what is due, ' +
            'with the amount and the date.',
        },
        {
          shot: 'student-dashboard',
          kind: 'phone',
          role: 'Student',
          line:
            'The timetable for today, what has to be submitted, and results when they are ' +
            'published — not a cut-down parent view.',
        },
      ].filter((c) => ctx.has(c.shot));

      return `
<section class="act act-truth section-soft" id="same-truth">
  <div class="container">
    <p class="eyebrow">One record</p>
    <h2 class="section-title">Four people. One version of the truth.</h2>
    <p class="section-lede">
      A principal, a teacher, a parent and a student open the same platform and get four
      different workspaces — each showing only what that person is responsible for, and only
      the data they are permitted to see. Attendance, marks, fees, transport and hostel all
      write to the same student, so the number a principal sees and the number a parent sees
      cannot disagree.
    </p>

    <div class="truth-grid truth-grid-${cards.length}">
      ${cards
        .map(
          (c) => `<figure class="truth-card" data-reveal>
        ${device(ctx, c.shot, c.kind, { sizes: '(max-width: 767px) 50vw, 22vw' })}
        <figcaption>
          <h3>${c.role}</h3>
          <p>${c.line}</p>
        </figcaption>
      </figure>`,
        )
        .join('\n      ')}
    </div>
  </div>
</section>`;
    },
  },

  /* =================================================================== IV *
   * Pure copy — no product asset — so it survives any asset state and is part
   * of the launch floor. Deliberately the calmest act on the page: after the
   * depth of Act 0, restraint here reads as seriousness.
   * ==================================================================== */
  {
    id: 'guardrails',
    title: 'Act IV · Guardrails',
    required: true,
    requires: [],
    render() {
      return `
<section class="act act-guardrails section-navy" id="guardrails">
  <div class="bp-plane bp-plane-dark" aria-hidden="true" data-parallax="0.04"></div>
  <div class="container">
    <p class="eyebrow eyebrow-light">Privacy &amp; data protection</p>
    <h2 class="section-title">Children's data, handled the way it should be.</h2>
    <p class="section-lede section-lede-light">
      A school platform holds some of the most sensitive data there is. NIKSHA OS is written to
      India's Digital Personal Data Protection Act, 2023, and the DPDP Rules, 2025.
    </p>

    <div class="commitments">
      <div class="commitment" data-reveal>
        <h3>We never sell data, and never advertise to children</h3>
        <!-- Claim 7 (§10) is ✅ and it CONSTRAINS THE BUILD: this page ships zero
             third-party scripts — no analytics, no CDN fonts, no embeds — because
             that is what keeps the sentence true. Do not add one. -->
        <p>No behavioural advertising, no data brokerage, no third-party trackers. This website
        loads no third-party script of any kind.</p>
      </div>
      <div class="commitment" data-reveal>
        <h3>Your school owns its records</h3>
        <p>
          The Institution is the Data Fiduciary. NIKSHA OS acts as a Data Processor, handling
          data only on the school's documented instructions.
        </p>
      </div>
      <div class="commitment" data-reveal>
        <h3>Access is enforced, not assumed</h3>
        <!-- Claim 11 (§10) + decision D10: the live verification (521b7e57, 9/9 checks
             on api.nikshaos.in) evidences that access IS enforced, but those checks did
             not measure row-level enforcement. The previous site's "enforced in the
             database, not just the UI" is therefore NOT carried forward. Restore it only
             if row-level enforcement is separately verified on the deployment. -->
        <p>
          Every request is authenticated and checked against the user's role and school before
          it is served. A parent can reach their own children's records and nothing else.
        </p>
      </div>
      <div class="commitment" data-reveal>
        <h3>Changes leave a trail</h3>
        <!-- Claim 13 (§10) is ⚠ on the word "always": the audit trail covers money,
             marks and attendance. Those three are named instead of claiming totality. -->
        <p>
          Corrections to money, marks and attendance are recorded with who made them and when,
          so a school can reconstruct what happened in each.
        </p>
      </div>
    </div>

    <div class="legal-links">
      <a class="btn btn-light" href="${LEGAL_ROUTES.privacy}">Read the Privacy Policy</a>
      <a class="legal-link" href="${LEGAL_ROUTES.user}">Parent &amp; User Terms</a>
      <a class="legal-link" href="${LEGAL_ROUTES.acceptableUse}">Acceptable Use</a>
      <a class="legal-link" href="${LEGAL_ROUTES.institution}">Institution Agreement</a>
    </div>
  </div>
</section>`;
    },
  },

  /* ==================================================================== V */
  {
    id: 'close',
    title: 'Act V · Close',
    required: true,
    requires: [],
    render() {
      return `
<section class="act act-close" id="close">
  <div class="bp-plane bp-plane-dense" aria-hidden="true" data-parallax="0.03"></div>
  <div class="container close-inner">
    <h2 class="section-title">Run your school on one system.</h2>
    <p class="section-lede">
      Write to us and a person will reply — whether you are running a pilot and need help, or
      considering NIKSHA OS for your school.
    </p>
    <div class="cta-row">
      <a class="btn btn-primary btn-lg" href="${APP}">Sign in</a>
      <a class="btn btn-outline btn-lg" href="mailto:${SUPPORT}">Talk to us</a>
    </div>
    <p class="close-email"><a href="mailto:${SUPPORT}">${SUPPORT}</a></p>
    <p class="micro">
      NIKSHA OS is operated by NIKSHA Technologies Pvt. Ltd. For a security concern, please see
      our <a href="${LEGAL_ROUTES.acceptableUse}">Acceptable Use Policy</a>.
    </p>
  </div>
</section>`;
    },
  },
];

/* ---------------------------------------------------------------------------
 * Acts specified in the proposal but NOT built, and exactly why. Printed by the
 * build so an omission is a visible build output rather than something a reader
 * discovers. Restoring one is a matter of capturing its screen — no rebuild.
 * ------------------------------------------------------------------------- */
export const DEFERRED_ACTS = [
  {
    id: 'record',
    title: 'Act I · The Record',
    missing: ['student-360'],
    note: 'the decompose → Student 360 → reconnect sequence has no centrepiece without a Student 360 capture',
  },
  {
    id: 'journeys',
    title: 'Act II · The Journeys (5 module beats)',
    missing: ['admissions-enrolment', 'marks-entry', 'fee-receipt', 'ai-copilot'],
    note: 'superseded for v1 by the persona act above, which makes the same argument from captures that exist',
  },
  {
    id: 'boundary',
    title: 'Act III · The Boundary',
    missing: ['ai-copilot'],
    note:
      'needs the Copilot screen. Note also that claim 10 ("architecturally prevented from writing") is ⚠ in ' +
      '§10 — what exists is a system prompt and read-only quota checks, not a proven architectural boundary. ' +
      'This act must not ship until BOTH the capture exists and the boundary is verified.',
  },
];
