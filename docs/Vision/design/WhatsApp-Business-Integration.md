# Design — WhatsApp Business Integration

**Status:** Future · v1.0 = deep-link invites + stub/live Twilio SMS

## Goals

- Template-based WhatsApp for OTP, fee reminders, attendance alerts, broadcasts  
- WABA (WhatsApp Business API) per school or shared platform number  
- Delivery receipts synced to `comm_deliveries`  

## Architecture

| Layer | v1.0 | Target |
|-------|------|--------|
| Invite links | `wa.me` deep links | ✅ |
| Outbound templates | Stub / partial | Meta Cloud API |
| Inbound | — | Webhook → ticket/message |
| Audience | Broadcast normalization | Template variable binding |

## Permissions

`sendBroadcast`, `manageCommunications` — school scope. Template approval — platform admin.

## Data model

Extend `comm_deliveries.provider_ref`, `comm_templates.wa_template_id`, `school_integration_configs.whatsapp`.

## APIs

- `POST /communications/broadcasts` — `channel: whatsapp`  
- `POST /webhooks/whatsapp` — inbound (future)  
- `GET /communications/templates` — approved templates  

## Rollout plan

1. v1.0 — verify deep links + queue records (UAT)  
2. Pilot — one school WABA + fee reminder template  
3. GA — template library per vertical  

## Risks

| Risk | Mitigation |
|------|------------|
| Meta template rejection | Pre-approve generic education pack |
| Per-message cost | Budget caps per school |
