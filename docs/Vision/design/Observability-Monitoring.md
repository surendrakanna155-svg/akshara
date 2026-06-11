# Design — Observability & Monitoring

**Status:** Future · v1.0 uses health endpoints + scripts

## Goals

- SLOs for API latency, error rate, OTP delivery, webhook success  
- Correlation ID tracing end-to-end (client → Edge → DB)  
- Alerting before schools report issues  

## Architecture

| Component | Tooling (proposed) |
|-----------|-------------------|
| Metrics | Prometheus / Supabase metrics export |
| Logs | Structured JSON; `correlation_id` field |
| Traces | OpenTelemetry on Edge Functions |
| Dashboards | Grafana per environment |
| Alerts | PagerDuty on SLO burn |

Existing: `GET /health/ready`, `/health/tenant-access`, `/health/operations`.

## Permissions

`platformAdmin` — all dashboards. `schoolAdmin` — school-scoped usage stats only (no PII).

## Data model

- `ops_metrics_snapshots` (optional) — daily rollups  
- No PII in metrics labels  

## APIs

- `GET /health/operations` — extend with queue depths, OTP failure rate  
- Internal only: `GET /ops/metrics` (platform token)  

## Rollout plan

1. Correlate all 5xx with `correlation_id` in support playbook  
2. Export Edge logs to central sink  
3. SLO dashboard for pilot schools  
4. OTP + webhook alerts  

## Risks

| Risk | Mitigation |
|------|------------|
| Log PII leakage | Redact phone/email at ingest |
| Alert fatigue | SLO-based thresholds only |
