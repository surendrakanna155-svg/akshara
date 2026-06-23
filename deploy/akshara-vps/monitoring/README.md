# Akshara monitoring (Batch 7)

Plain-language goal: **somebody finds out when the system breaks — before the
schools do.** Two parts:

1. **Edge request logging** (in `supabase/functions/api/index.ts`): one structured
   JSON line per request — method, path, status, duration, correlation id, client
   IP — with NO bodies/tokens/query strings (no secret leakage). Server errors log
   at level 50. View: `docker logs akshara-edge`. The `x-correlation-id` is echoed
   back in the response header for tracing.

2. **Watchdog** (`akshara-watchdog.sh`, cron every 5 min) — checks and alerts on:
   - `/health/ready` (API + DB), `/health/backup` (backup fresh), `/health/storage`
   - disk usage ≥ `DISK_WARN_PCT`
   - TLS cert expiring within `CERT_WARN_DAYS`
   - every container running (postgres also health-checked)

   Failing checks are logged and pushed to alert sinks with a per-check cooldown
   (anti-spam); a recovered check sends a one-time "RECOVERED" notice.

## Alert sinks (all optional; it always logs to `/var/log/akshara/watchdog.log`)

- **Webhook** (`ALERT_WEBHOOK_URL`): POST `{host,severity,text}` — point at Slack /
  Telegram / n8n.
- **SMS** (`ALERT_SMS_PHONES`, Fast2SMS): CRITICAL only; reuses the OTP Fast2SMS key
  if `ALERT_SMS_API_KEY` is empty.

## Install (on the VPS)

```bash
tar czf - -C deploy/akshara-vps monitoring | ssh root@<vps> 'tar xzf - -C /opt/akshara'
ssh root@<vps> 'cd /opt/akshara/monitoring && ./install-monitoring.sh'
# configure sinks in /opt/akshara/monitoring/monitoring.env, then:
ssh root@<vps> '/opt/akshara/monitoring/akshara-watchdog.sh && tail /var/log/akshara/watchdog.log'
```

## Production note

`/health/backup` and `/health/storage` are guarded by `x-internal-health-token`
when `INTERNAL_HEALTH_TOKEN` is set (required once `APP_ENV=production`). Put the
same token in `monitoring.env` so the watchdog can read them.

## Not included (deliberate, would need paid/external accounts)

Backend Sentry/Datadog (app-side adapters already exist, wire a DSN to enable),
Prometheus `/metrics` + Grafana, log aggregation (Loki/ELK). The watchdog +
structured logs cover the "know when it's down" need without new vendors.
