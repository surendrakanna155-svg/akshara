# Deployment Model, Provisioning, Backup & Data Security Plan

Status: **PLAN / FUTURE** — not built yet. Written 2026-06-23.
Plain-language plan for offering two kinds of school setups and keeping every
school's data safe.

---

## 1. The big picture (in plain words)

When a new school signs up, we ask one question: **"How private do you want to be?"**

There are two answers:

- **Shared SaaS** — the school lives inside our one big Akshara system, in the
  same database as other schools. Cheapest, fastest to switch on (minutes). Data
  is kept separate by software rules, not by separate machines. This is the
  default and what 95% of schools should pick.

- **Dedicated Infrastructure** — the school gets its **own private server (VPS)**
  with its **own PostgreSQL database**. Nobody else's data is on that machine.
  Costs more, takes longer to set up (an hour, not minutes), and we maintain more
  servers. This is for big schools/chains, or anyone with a strict
  "our data must be on our own machine" rule.

The key idea: **same app, same code, same migrations — just a different address
for where the data lives.** A school can also be *moved* from Shared to Dedicated
later without changing the app.

---

## 2. How separation actually works in each model

### Shared SaaS (one database, many schools)
- Every important table already needs a `school_id` (tenant) column.
- PostgreSQL **Row-Level Security (RLS)** makes sure a logged-in user can only
  ever see rows where `school_id` matches their own school. We already use RLS
  heavily (137 policies live), so this is the natural fit.
- One backup covers all schools at once.
- Risk to watch: a single bad RLS policy could leak across schools — so RLS
  policies are the crown jewels and must be tested for every table.

### Dedicated Infrastructure (one database = one school)
- A whole VPS + PostgreSQL belongs to exactly one school.
- Same Akshara tables, same migrations — but `school_id` is still present (so the
  code path is identical; we don't fork the app for dedicated schools).
- Backups, upgrades, and monitoring are per-school.
- Strongest possible isolation: a problem on one school's box can't touch another.

**Decision rule we tell sales:** start everyone on Shared SaaS. Offer Dedicated
only when the school asks for it, is large (e.g. >2,000 students), is a multi-branch
group, or has a contractual data-isolation requirement.

---

## 3. Provisioning — what happens at onboarding (the orchestration)

This is the part the question was really about: *"how do we manage this at
onboarding time?"*

We do **NOT** hand-build servers. We build a one-button **Provisioner** (a small
control service / script) that the Akshara Control Center calls. Steps:

```
Create New School
      │
      ▼
Choose Deployment Type  ──► Shared SaaS ──► just insert school row + seed defaults  (DONE in minutes)
      │
      └─► Dedicated Infrastructure
                │
                ▼
        Provisioner job runs (automated, ~30–60 min, no human SSH):
          1. Spin up a fresh VPS from a saved "golden image"
             (Ubuntu + Docker + our stack pre-installed).
          2. Start the Akshara stack (postgres + postgrest + gateway + edge)
             from the same docker-compose we use today.
          3. Run ALL Akshara migrations in order  ──► creates all 155 tables + RLS automatically.
          4. Seed the one school's defaults (roles, settings, admin account).
          5. Point a subdomain at it:  <school>.akshara.app  (DNS + TLS cert auto).
          6. Health-check (/health/ready must say database:true).
          7. Register the school in our central registry with its connection info.
          8. Email/notify: "School X is ready."
```

### How the app knows where to connect
- We keep a tiny central **School Registry** (one small shared table/service):
  `school_id → deployment_type → base_url`.
- When the app logs a user in, it asks the registry "where is my school?" and gets
  back the right server address (the big shared one, or the school's dedicated
  one). Everything after that is identical.
- This means the **same app build** works for every school — no per-school app.

### "Run migrations / create all tables automatically"
- Migrations are already version-numbered (we have 98+ today). The provisioner
  runs them top-to-bottom on the new empty database — this is exactly what creates
  every table and RLS policy. No manual SQL, ever.
- The **same migration runner** is used to upgrade every school later (Shared and
  Dedicated) so all schools stay on the same schema version. We track each
  school's current migration version in the registry.

### What we need to build for this (future work, in order)
1. **School Registry** service + table (tiny, lives in the shared system).
2. **Golden VPS image** (pre-baked so spin-up is fast and identical every time).
3. **Provisioner** script/job that runs the 8 steps above and can be re-run safely
   (idempotent).
4. **Migration fleet runner** — apply a new migration to ALL schools (shared +
   every dedicated box) and report which succeeded/failed.
5. **De-provision / move** tooling — delete a closed school cleanly, or move a
   school from Shared → Dedicated (export its rows, import into a fresh box).

> Note: today our live VPS uses the Supabase Postgres image. A cheaper future
> option for Dedicated is **plain managed PostgreSQL** (provider-hosted DB with
> automatic backups) instead of running Postgres ourselves on each VPS — fewer
> servers to babysit. Worth comparing on cost vs control before we scale to many
> dedicated schools.

---

## 4. Backup plan (so a VPS crash never loses data)

Rule of thumb to design against: **3-2-1** — keep **3** copies of data, on **2**
different kinds of storage, with **1** copy off the server (somewhere else
entirely). Goals we promise:

- **RPO (how much data we can afford to lose): ≤ 15 minutes.**
- **RTO (how fast we recover): ≤ 1 hour for Dedicated, ≤ 2 hours for full Shared.**

### Layers of backup (each school, both models)
1. **Continuous (WAL) backups** — PostgreSQL streams its change-log so we can
   restore to *any minute* (point-in-time recovery). This is what limits data loss
   to ~15 min, not a whole day.
2. **Nightly full snapshot** — a complete `pg_dump`/base backup every night,
   compressed and encrypted.
3. **Off-site copy** — every backup is pushed to **object storage in a different
   location** (e.g. S3-compatible bucket / different datacenter), NOT on the same
   VPS. If the whole VPS dies, backups survive.
4. **Retention:** keep 7 daily, 4 weekly, 12 monthly. (Tunable per contract.)
5. **VPS-level snapshots** (provider image snapshots) nightly too — lets us rebuild
   the *whole machine* fast, not just the database.

### When a VPS crashes — the runbook
```
1. Provisioner spins a fresh VPS from the golden image (same as onboarding).
2. Restore latest base backup + replay WAL up to the last safe minute.
3. Health-check (/health/ready = database:true).
4. Flip the registry's base_url to the new box (DNS/subdomain follows).
5. App reconnects automatically — users back online.
```

### Test the backups (the part everyone skips)
- **Automated monthly restore drill:** a scheduled job restores a random school's
  backup into a throwaway box and checks row counts. A backup you've never
  restored is not a backup. Alert if a drill fails.
- Alert if any school misses a nightly backup.

### Higher tier (optional, for the biggest dedicated schools)
- **Hot standby replica:** a second PostgreSQL on another machine kept in sync
  live. If the primary dies, promote the replica in minutes (near-zero data loss).
  Costs ~2x the database — offer as a premium "High Availability" add-on.

---

## 5. Data security plan

### Isolation
- **Shared:** RLS on every table + `school_id` on every row. RLS policies get their
  own test suite; no table ships without a tested policy.
- **Dedicated:** physical isolation — separate VPS, separate DB credentials,
  separate network. Strongest guarantee.

### Encryption
- **In transit:** HTTPS/TLS everywhere (already live via Let's Encrypt). Database
  connections use TLS too.
- **At rest:** disk encryption on every VPS; **backups encrypted** before they
  leave the box (so a leaked backup file is useless without the key).
- **Secrets:** DB passwords, JWT signing keys, API keys live in a secrets manager
  / env vault — never in the repo, never in the app bundle. Each dedicated school
  gets its **own** unique DB password and JWT secret (so one leak ≠ all schools).

### Access control
- App users: phone + OTP login → JWT → RLS enforces what they can see (already
  live). Roles: principal / teacher / parent / student etc.
- **Server access (us):** SSH by key only, no passwords; ideally through one
  bastion/jump host with logging. Today we use password SSH + ControlMaster — a
  future hardening item is key-only + disable root password login.
- **Least privilege in DB:** the app connects as a limited role, NOT as superuser
  (we already apply migrations as `supabase_admin`, app uses restricted roles).

### Monitoring & audit
- Central log + metrics per school (up/down, error rate, disk full, failed logins).
- **Audit trail** table: who changed what, when (important for fees, marks,
  attendance — anything disputable).
- Automated alerts: backup failed, disk >85%, restore drill failed, cert expiring,
  unusual login spikes.

### Privacy / compliance (India schools = children's data)
- Data stays in **India region** servers.
- Clear data-retention + deletion policy: when a school leaves, we export their
  data to them and securely wipe the box (and age out backups per retention).
- Parental consent / privacy policy wording for student data (legal review later).

### Hardening checklist (per VPS, baked into golden image)
- Firewall: only 80/443 public; database port localhost-only (already done today).
- Auto security updates.
- Fail2ban / rate-limit on login.
- No service runs as root unless required.
- Regular dependency/image patching as part of the migration-fleet runs.

---

## 6. Suggested build order (when we pick this up)

1. School Registry (table + lookup at login) — unlocks everything else.
2. Golden VPS image + scripted stack start.
3. Provisioner (the 8-step onboarding job) for Dedicated.
4. Backup system: WAL + nightly + off-site + encryption, for the current live VPS
   first, then templated into the golden image.
5. Automated monthly restore drill.
6. Migration fleet runner (upgrade all schools safely).
7. Security hardening pass (key-only SSH, secrets vault, per-school secrets).
8. Optional HA replica tier + Shared→Dedicated move tooling.

> Dependency note: this assumes the live backend keeps maturing. It builds on the
> current VPS stack (Supabase Postgres + edge function) already running at
> api.nikshaos.in. Reuse that docker-compose as the golden-image base.
