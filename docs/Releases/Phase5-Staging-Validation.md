# Phase 5 Staging Validation

**Script:** `scripts/phase5_staging_verify.sh`  
**Introduced:** v10.4 Production Hardening  
**Scope:** Phase 5 endpoints (v9.8–v10.3) + v10.4 hardening checks

---

## Purpose

Automated smoke verification of the Phase 5 API surface against a live staging backend. Intended as a pre-deploy gate after Edge Function deploy or migration apply. Complements `flutter test` contract tests with real auth + RBAC validation.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Staging API | Supabase Edge Function `api` deployed |
| Migrations | Phase 5 foundation + permissions + probe seed + v10.4 storage |
| Probe users | Phone `9876543210` (admin), `9876543211` (parent) |
| Probe tenant | School `a2000000-0000-4000-8000-000000000001` |
| Probe student | `a4000000-0000-4000-8000-000000000001` |
| Tools | `curl`, `python3` |

---

## Usage

```bash
# Default staging URL (override with API_BASE_URL)
./scripts/phase5_staging_verify.sh

# Custom base URL and report directory
API_BASE_URL=https://your-project.supabase.co/functions/v1/api \
REPORT_DIR=reports/phase5_validation \
./scripts/phase5_staging_verify.sh
```

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed (auth/RBAC/data) |
| 2 | **Deploy blocked** — Phase 5 routes return 404 (Edge bundle stale) |

**Deploy first (v10.4.2):**

```bash
export SUPABASE_ACCESS_TOKEN=...
./scripts/deploy_staging.sh
./scripts/phase5_staging_verify.sh
```

Unauthenticated route probe: deployed routes return **401**; missing routes return **404**.

---

## Authentication Flow

The script performs OTP login for two personas:

1. **Admin** — `9876543210` → school scope token
2. **Parent** — `9876543211` → parent scope with school + student context

OTP is extracted from the login response message via regex (staging returns OTP in response body).

---

## Endpoint Checks

| # | Label | Method | Path | Token | Expected |
|---|-------|--------|------|-------|----------|
| 1 | Parent experience hub | GET | `/parent/experience/hub?studentId={STUDENT_A}` | Parent | 200 |
| 2 | Employee intelligence dashboard | GET | `/employees/intelligence/dashboard` | Admin | 200 |
| 3 | Operations hub | GET | `/operations/hub` | Admin | 200 |
| 4 | Memories events list | GET | `/memories/events` | Admin | 200 |
| 5 | Memories analytics | GET | `/memories/analytics` | Admin | 200 |
| 6 | Promotions list | GET | `/promotions` | Admin | 200 |
| 7 | Distribution reports | GET | `/inventory/distribution/reports` | Admin | 200 |
| 8 | Parent denied operations hub | GET | `/operations/hub` | Parent | 403 |

Check 7 validates v10.1 distribution reports wiring (extended in v10.4 staging coverage).  
Check 1 validates v10.4 parent hub extensions (guidance + homework intelligence payload).

---

## Report Output

Reports are written to `reports/phase5_validation/` (gitignored):

| File | Content |
|------|---------|
| `phase5_staging_verify.log` | Timestamped PASS/FAIL lines for each check |
| `summary.json` | `{ "pass": N, "fail": N, "log": "..." }` |

**Example `summary.json`:**

```json
{
  "pass": 8,
  "fail": 0,
  "log": "reports/phase5_validation/phase5_staging_verify.log"
}
```

The `reports/phase5_validation/` directory is created on first run. Commit the script and this doc; do not commit generated reports.

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | Staging Supabase functions URL | Base URL including `/functions/v1/api` |
| `REPORT_DIR` | `reports/phase5_validation` | Output directory for log + summary |

Probe IDs (`SCHOOL_A`, `STUDENT_A`) are hardcoded in the script to match probe seed migrations.

---

## CI Integration (recommended)

```yaml
# Example GitHub Actions step (manual staging gate)
- name: Phase 5 staging verify
  env:
    API_BASE_URL: ${{ secrets.STAGING_API_URL }}
  run: ./scripts/phase5_staging_verify.sh
```

Run after Edge deploy and before tagging release candidates that include Phase 5 changes.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Login FAIL | Probe users not seeded; OTP provider changed |
| 404 on `/memories/events` | Edge deploy missing memory router — run `./scripts/deploy_staging.sh` |
| Exit code 2 | Phase 5 routes not deployed; see preflight probes in log |
| 403 on admin checks | RBAC seed not applied; wrong school context |
| Parent hub 403 | Parent not linked to probe student |
| Distribution reports 500 | Phase 4 inventory foundation missing |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| `docs/Releases/v10.4-Production-Hardening.md` | Phase E deliverable context |
| `docs/ArchitectureReview/v10.4-Architecture-Review.md` | Staging validation review area |
| `docs/ArchitectureReview/v9.8-v10.3-Phase5-Consolidated-Review.md` | Phase 5 baseline review |
