# Akshara ERP — Third-Party Services & Sub-processors

**Document version:** 1.0
**Status:** Draft for owner sign-off (see [PLACEHOLDERS.md](PLACEHOLDERS.md))
**Operator:** **[LEGAL ENTITY NAME]** ("Akshara", "we", "us").

> This page lists the third-party services Akshara uses to deliver the platform,
> what each one does, and whether it processes data **outside India**. It supports
> the [Privacy Policy](PRIVACY_POLICY.md) and the
> [Institution Agreement](INSTITUTION_AGREEMENT.md). When we add or change a
> material sub-processor, we record it here and in the [CHANGELOG](CHANGELOG.md).

---

## 1. How to read this list

- **Active** — integrated and in use to deliver the service.
- **Optional / off by default** — the integration exists in the product but is
  **disabled** unless the operator deliberately configures and enables it. When off,
  **no data is sent** to that service.
- A sub-processor processes personal data **only** on our instructions and to
  provide its specific function.

## 2. Hosting & core infrastructure

| Service | Function | Data handled | Location | Status |
|---|---|---|---|---|
| **Self-managed VPS** (operator-controlled server) | Hosts the database, API/edge functions, REST gateway and file storage | All service data | **India / operator-controlled** | **Active** |
| **PostgreSQL (self-hosted)** | Primary database | All service data | India / operator-controlled | **Active** |
| **Supabase Storage (self-hosted)** | File/photo/document storage; expiring signed URLs | Uploaded media & documents | India / operator-controlled | **Active** |

> Note: Akshara runs a **self-hosted** stack (PostgreSQL, REST gateway, storage,
> edge runtime) on the operator's own VPS. It does **not** use a third-party managed
> "Supabase Cloud", AWS RDS, Vercel or Netlify for production data.

## 3. Active sub-processors (third parties)

| Service | Provider | Function | Personal data shared | Processes data outside India? | Status |
|---|---|---|---|---|---|
| **Razorpay** | Razorpay (India) | Online fee payment processing (order creation, payment, signature/webhook verification) | Payer/parent identity context and payment amount; **card details are handled by Razorpay, not stored by Akshara** | India-based gateway (may process via international card networks) | **Active** |
| **Fast2SMS** | Fast2SMS (India) | Sends one-time passwords (OTP) by SMS for login | Mobile number + OTP message | India-based | **Active** |
| **Anthropic (Claude)** | Anthropic (USA) | Optional AI features (assistant, parent insights, question-paper assistance, summaries, predictions, captions) | The minimum text needed for the feature, from data the user can already see; **not used to train the provider's models** | **Yes — USA** | **Active when enabled** (deterministic fallback when not) |
| **Firebase Cloud Messaging (FCM)** | Google (USA) | Delivers push notifications to devices | Device push token + notification title/body | **Yes — USA** | **Active** |
| **Google OAuth (service account)** | Google (USA) | Mints short-lived tokens so the server can call FCM | Server-to-server only (no user data) | **Yes — USA** | **Active** (supports FCM) |
| **WhatsApp deep-links (`wa.me`)** | Meta | Opens a pre-filled WhatsApp chat **on the user's own device** when a user taps "contact on WhatsApp" | None sent by Akshara — the user composes/sends the message themselves | Meta servers (user-initiated) | **Active** (link-only; **no** WhatsApp Business API, **no** Meta data integration) |

## 4. Optional integrations (disabled by default — no data sent unless enabled)

These capabilities exist in the product but are **off** unless the operator
configures credentials and enables them. Until then they send **no data**.

| Service | Provider | Function | Outside India? |
|---|---|---|---|
| **Meta Graph API (Facebook / Instagram)** | Meta (USA) | Publishing approved school posts to a school's **own** connected FB/IG account (Phase 2; dry-run by default; requires Meta App Review) | Yes — USA |
| **Twilio** | Twilio (USA) | Alternative transactional SMS | Yes — USA |
| **SendGrid** | Twilio/SendGrid (USA) | Transactional email | Yes — USA |
| **MSG91** | MSG91 (India) | WhatsApp template messages | India-based |
| **Gupshup** | Gupshup (India) | WhatsApp template messages | India-based |
| **OpenRouter** | OpenRouter (USA) | Optional alternative AI routing | Yes — USA |

## 5. What we do NOT use

- ❌ No advertising or ad-network SDKs.
- ❌ No third-party analytics, behavioural tracking, or crash/telemetry SDKs (e.g.
  no Google Analytics, Firebase Analytics, Crashlytics, Sentry) embedded in the app.
- ❌ No data brokers.
- ❌ No sale of personal data.

## 6. International transfers

Where a sub-processor is outside India (Anthropic, Google/FCM, and any optional
US-based services if enabled), we send only the **minimum necessary** data, under
contractual safeguards, and consistent with the DPDP Act and Rules. We do not
transfer data to any jurisdiction restricted by the Central Government.

## 7. Changes to sub-processors

We keep this list current. Material additions or changes are recorded in the
[CHANGELOG](CHANGELOG.md). Institutions may contact **[PRIVACY EMAIL]** to ask about
sub-processors or to object to a change as provided in the
[Institution Agreement](INSTITUTION_AGREEMENT.md).
