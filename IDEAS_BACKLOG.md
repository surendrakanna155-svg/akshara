# Ideas Backlog

A safe place for ideas that pop up mid-work, so none get lost. When the owner
shares a sudden idea, it gets added here (dated) and we keep working on the
current task. We come back and implement these on purpose, later.

Format: `- [ ] (YYYY-MM-DD) The idea, in plain words.`

## Open ideas

- [ ] (2026-06-24) **First-time student data onboarding (bulk import + structure + placeholders).**
  Day-one student setup for a new school. A real CSV import already exists on the
  backend (`/onboarding/imports/students/preview|commit|rollback`, parent gets an
  OTP login via `upsertUserByPhone`). What's missing: a downloadable **Excel
  template** (.xlsx/.csv), capturing **how many sections per class** and **how
  many students per section** at onboarding, **auto-generating editable
  placeholder students** when a school gives only structure, and a quick
  **add-one-student** form. Owner decisions (2026-06-24): admission number stays
  the real ID, **Aadhaar is optional + stored masked** (dedupe only, not the
  login); auto-created students are **editable placeholders** (no real parent
  phone, can't OTP-login until replaced); schools get a **downloadable Excel
  template** they fill and upload. This is the concrete first slice of the AI
  School Builder below. Full plan:
  [docs/plans/FIRST_TIME_STUDENT_DATA_ONBOARDING_PLAN.md](docs/plans/FIRST_TIME_STUDENT_DATA_ONBOARDING_PLAN.md)

- [ ] (2026-06-20) **AI School Builder — AI-configured School Operating System.**
  FUTURE STRATEGIC INITIATIVE, priority HIGH. During first-time school setup, an
  AI interview (board / school type / strength / facilities / programs / channels)
  generates a school-specific experience: tailored workspaces, dynamic navigation,
  dashboards, and cards — so each school feels custom-built, not a generic
  menu-heavy ERP. Includes a future Question Intelligence Platform that generates
  papers strictly within board/class/chapter/blueprint/difficulty boundaries.
  **DO NOT BUILD until these are done first:** Workspace Architecture
  Consolidation → Navigation Simplification → Mobile UX Modernization → Screen
  Consolidation. Full spec: [docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md](docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md)

- [ ] (2026-06-20) **Notifications, posters & holiday calendar.** Three gaps found in
  audit: (1) real push notifications — backend ready but phone app not connected to
  Firebase; (2) principal broadcasts are text-only, need poster/greeting image support;
  (3) no holiday calendar — principal can't mark a date as holiday/festival or notify
  everyone. Suggested order: push → posters → holiday calendar. Full plan:
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

- **Batch 8b — Question-paper AI (gated on the question bank).** Batch 8 made the
  copilot and parent insights real via Claude (see
  [docs/LIVE_BACKEND_BATCH8_REAL_AI.md](docs/LIVE_BACKEND_BATCH8_REAL_AI.md)) and
  built a reusable Claude client. Question-paper AI was deferred: there is no
  question-bank schema/data yet, and the foundation plan mandates bank-first,
  constrained AI gap-fill last. Sequence: build the bank + deterministic blueprint
  engine first, then wire constrained AI generation (teacher approval required) on
  top of the shared Claude client. Plan:
  [docs/plans/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md](docs/plans/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md)

## Done
