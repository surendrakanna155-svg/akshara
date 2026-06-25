# Ideas Backlog

A safe place for ideas that pop up mid-work, so none get lost. When the owner
shares a sudden idea, it gets added here (dated) and we keep working on the
current task. We come back and implement these on purpose, later.

Format: `- [ ] (YYYY-MM-DD) The idea, in plain words.`

## Open ideas

- [ ] (2026-06-25) **Parent Insights read-aloud (multilingual text-to-speech).**
  The Parent Insights screen can speak summaries aloud in the parent's chosen
  language (English/Hindi/Telugu) — valuable for low-literacy parents. Deferred
  from B3 because it needs a new TTS dependency (`flutter_tts`) + per-platform
  setup; B3 removed the fake "voice-ready" icon rather than ship a dead button.
  When built: drive it from `ParentInsightSnapshot` text, respect the language
  preference, add a play/stop control on each insight card.

- [ ] (2026-06-20) **AI School Builder — AI-configured School Operating System.**
  FUTURE STRATEGIC INITIATIVE, priority HIGH. **Partially delivered:** Phase 1 AI
  pre-fill (P2 B7) and the Dynamic Widget Platform / dynamic dashboards & cards
  (P3 B11) are both production-certified. Remaining = the deeper "AI interview
  reshapes the whole app" vision (board / school type / strength / facilities /
  programs / channels → fully tailored workspaces & navigation). Stays
  future/owner-gated — validate the shipped pieces with pilots first.
  Full spec: [docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md](docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md)

- [ ] (2026-06-20) **Notifications, posters & holiday calendar.** Three gaps: (1) real
  push notifications — backend ready but phone app not connected to Firebase
  (**owner-gated:** needs a Firebase account/setup); (2) principal broadcasts are
  text-only, need poster/greeting image support (**not started**); (3) no holiday
  calendar — principal can't mark a date as holiday/festival or notify everyone
  (**not started**). Note: transactional SMS is certified-ready but the go-live flag
  is **off** (owner action — sends real paid SMS). Suggested build order (mine):
  holiday calendar → posters; push/SMS are owner-gated. Full plan:
  [docs/NOTIFICATIONS_POSTERS_HOLIDAYS_PLAN.md](docs/NOTIFICATIONS_POSTERS_HOLIDAYS_PLAN.md)

- [ ] (2026-06-23) **Deployment model: Shared SaaS vs Dedicated Infrastructure + backup &
  data security.** At onboarding, school picks Shared SaaS (lives in our one big database,
  kept apart by Row-Level Security — default, minutes to set up) or Dedicated Infrastructure
  (its own private VPS + own PostgreSQL, ~1 hour, premium). Same app/code/migrations for both;
  a tiny School Registry tells the app which server to talk to. Provisioning is one automated
  "Provisioner" job (fresh VPS from golden image → start stack → run all migrations = creates
  all 155 tables + RLS automatically → seed → subdomain+TLS → health-check → register). Backup
  = 3-2-1: continuous WAL (lose ≤15 min) + nightly encrypted snapshot + off-site copy +
  monthly automated restore drill; crash recovery rebuilds from golden image and flips the
  registry. Security = RLS/physical isolation, TLS + encrypted-at-rest backups, per-school DB
  passwords/JWT secrets, key-only SSH, audit trail, India-region data. Full plan:
  [docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md](docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md)

- **Batch 7 follow-ups (owner/external deps).** Backups/storage/monitoring are live
  ([docs/LIVE_BACKEND_BATCH7_STORAGE_BACKUPS_MONITORING.md](docs/LIVE_BACKEND_BATCH7_STORAGE_BACKUPS_MONITORING.md)),
  but these need an account/decision to finish:
  (1) **Off-site backups** — provision an S3/R2 bucket + rclone remote, set RCLONE_REMOTE
  (today backups are local-only, honestly flagged offsite=false). (2) **WAL/PITR** to cut
  RPO from ~24h to ≤15 min (needs a Postgres archive_command + restart). (3) **Alert sinks**
  — set ALERT_WEBHOOK_URL and/or ALERT_SMS_PHONES so watchdog alerts actually reach a human
  (currently log-only). (4) **Backend error tracking/metrics** — wire a Sentry DSN (app-side
  adapters exist) and/or Prometheus+Grafana; deferred (vendor accounts).

## Done

- [x] (2026-06-25) **Question Intelligence — live certification (the last uncertified major module).**
  Batches 8b/8c + corrections built the question bank + deterministic blueprint engine +
  constrained AI gap-fill + submit/review/approve governance + principal-only validation +
  the Flutter moderation/approve UI; deployed live. Now **PRODUCTION CERTIFIED** —
  `scripts/qa/live_cert_question_intelligence.py` **20/20** (real auth + real DB + RBAC + real
  AI: bank-first exact-marks solver, syllabus boundary, full governance + publish gate,
  corrections, real AI candidate + moderation). Found + fixed one real defect: the syllabus
  boundary fell back to the global `subject_templates` catalogue, which the `erp_tenant` edge
  role couldn't read → 500 on generate for any school without a materialised syllabus; fixed
  with a SELECT grant (migration `20260728000000`). *Deepening (PYQ import/analytics) stays
  paused — validate teacher adoption first.* Cert: `docs/QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md`.

- [x] (2026-06-24) **First-time student data onboarding (bulk import + structure + placeholders).**
  Day-one student setup for a new school: backend CSV/Excel import
  (`/onboarding/imports/students/preview|commit|rollback`), section sizing, auto-generated
  editable placeholder students, add-one-student form, parent OTP provisioning. Owner
  decisions honoured: admission number is the real ID; Aadhaar optional + stored **masked**
  (dedupe only, never the login); placeholders carry no real parent phone until replaced.
  **Live-certified 10/10** on the VPS pilot and merged (`3a381b3`). The concrete first slice
  of the AI School Builder. Cert: `docs/B7_ONBOARDING_LIVE_CERTIFICATION.md`.
