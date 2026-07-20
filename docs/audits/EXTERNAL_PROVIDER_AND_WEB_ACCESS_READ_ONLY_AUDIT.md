# External Provider & Web Access — Read-Only Architecture Audit

**Date:** 2026-07-13  
**Scope:** AUDIT A (SMS / OTP / external provider) · AUDIT B (mobile vs browser ERP access)  
**Method:** Current repository code + live-path wiring evidence only. No implementation, no roadmap edits, no secret values printed.  
**Authority:** Current code and deployed live-path config patterns (env templates + prior live verification docs cross-checked against code).

**Classification vocabulary used throughout:**  
`WORKING / LIVE` · `PARTIAL` · `MISSING` · `HARDCODED` · `CONFIG-ONLY` · `UI-ONLY` · `MOCK / STUB` · `NOT APPLICABLE` · `UNKNOWN / NOT PROVEN`

---

## 1. Simple Owner Summary

| Question | Answer (plain language) |
|---|---|
| **Current SMS provider** | **Fast2SMS** for OTP login and gated transactional parent SMS (fee receipt / exam results). A separate **Twilio** path exists for communication-hub notification SMS, but defaults to **stub mode**. |
| **Is SMS provider hardcoded?** | **Partially.** There is a thin provider interface, but the only implemented OTP/transactional provider is Fast2SMS (provider id must be `"fast2sms"`). Endpoint and request shape are Fast2SMS-specific. |
| **Can I later change only the API key?** | **CONDITIONAL.** If you stay on Fast2SMS Quick route (`q`) with the same API shape, replacing only `SMS_PROVIDER_API_KEY` can work. If the new business account requires DLT / OTP route / sender / template registration, **key alone is not enough**. |
| **Is there a Super Admin SMS/provider configuration dashboard?** | **UI-ONLY / PARTIAL.** Control Center → Providers can store vault credentials for category `sms`, but it is **not wired** to the live OTP/transactional Fast2SMS path (that path reads **VPS env**, not vault). AI keys *are* vault-wired; SMS OTP is not. |
| **Does each school need its own SMS API key?** | **No (current architecture).** One platform env-configured Fast2SMS account serves all schools. School-specific SMS API keys are **MISSING**. |
| **Is SMS quota/plan enforcement working?** | **MISSING.** Entitlement limits cover students/schools only. SMS limits are scheduled PRC items (`PRC-A-053`, `PRC-B-FR-24`) — not implemented. |
| **Can users fully access Akshara from a browser URL?** | **MISSING / MOBILE-ONLY for the product client.** Live domain serves the **API backend**. There is **no Flutter `web/` platform** in the repo; release builds are APK/AAB/IPA only. |
| **Does phone + OTP web login work?** | **MISSING** as a browser ERP journey. Phone+OTP auth **works against the live API** from the mobile app (and can be called via HTTP). There is no deployed browser client to complete the owner journey. |
| **Which roles have real web access?** | **None proven as a browser product.** All roles (Super Admin / Principal / Finance / Teacher / Parent / Student / etc.) are implemented inside the **single Flutter mobile app** with responsive admin shells that *look* desktop-capable but are not deployed as web. |
| **Is mobile/web feature parity complete?** | **NOT APPLICABLE / MISSING** — there is no live web ERP client to parity against. |

---

## 2. SMS / OTP Evidence

### A1 — Current SMS provider

| Finding | Classification | Evidence |
|---|---|---|
| Primary OTP SMS provider = **Fast2SMS** | `WORKING / LIVE` (path exists; live key is deployment secret) | `supabase/functions/_shared/sms_provider.ts` — `FAST2SMS_ENDPOINT = "https://www.fast2sms.com/dev/bulkV2"`; `sendOtpSms` requires `provider === "fast2sms"`. |
| Fast2SMS used today? | `WORKING / LIVE` (code + env template + prior live Batch-2 verification) | `config.ts` defaults `SMS_PROVIDER` → `"fast2sms"`; `deploy/akshara-vps/.env.akshara.example`; `docs/archive/completed/LIVE_BACKEND_BATCH2_SAFE_LOGIN.md` (live verify 2026-06-23). |
| Other SMS providers present? | `PARTIAL` | **(1)** Fast2SMS — OTP + transactional. **(2)** Twilio — communication notification channel (`notification_providers.ts`), default stub. **(3)** Vault/Control Center lists `msg91` / `stub` for SMS category — **not** used by OTP sender. **(4)** Watchdog alert SMS also calls Fast2SMS directly (`deploy/akshara-vps/monitoring/akshara-watchdog.sh`). |
| Who handles OTP? | `WORKING / LIVE` | `auth_handlers.ts` → `sendOtpSms` → Fast2SMS. |
| Who handles general SMS / notifications? | `PARTIAL` | Transactional parent SMS (fee/results) → Fast2SMS via `sendTransactionalSms`, gated by `TRANSACTIONAL_SMS_ENABLED` (default **false**). Communication-hub SMS → Twilio path, default **stub**. |
| Push separate from SMS? | `WORKING / LIVE` (separate path) | Push = FCM HTTP v1 (`notification_providers.ts` / `fcm_v1_client.ts`). Client: `lib/core/notifications/push_messaging_service.dart`. |

### A2 — Provider coupling / call chain

**Classification:** `PARTIAL` abstraction — **adapter-shaped interface with a single hardcoded concrete provider** (Fast2SMS). Not provider-agnostic in practice.

**OTP call chain (authoritative):**

```
Flutter client
  LoginScreen / StaffLoginScreen
  → authProvider.sendOtp / staffLoginProvider.sendOtp
  → ApiAuthRepository / AuthRemoteDatasource POST /auth/login
→ Edge: auth_handlers.handleLogin
  → generateOtp() + hashToken → insert otp_requests
  → (pilot/dev allowlist?) return OTP in JSON
  → else smsConfigFrom(AppConfig) → sendOtpSms(SmsConfig, phone, otp)
→ sms_provider.sendOtpSms
  → requires provider === "fast2sms"
  → buildFast2SmsRequest → fetch https://www.fast2sms.com/dev/bulkV2
```

**Exact files / functions:**

| Layer | Path | Symbol |
|---|---|---|
| Client login UI | `lib/features/auth/login_screen.dart` | `_submit` → `sendOtp` |
| Client OTP UI | `lib/features/auth/otp_verification_screen.dart` | `verifyOtp` |
| Staff login UI | `lib/features/auth/staff/staff_login_screen.dart`, `staff_otp_screen.dart` | |
| Client auth state | `lib/features/auth/auth_provider.dart` | `_sendOtpViaApi`, `_verifyOtpViaApi` |
| Client API | `lib/core/repositories/api/auth/remote/auth_remote_datasource.dart` | `verifyOtp` / login |
| Config load | `supabase/functions/_shared/config.ts` | `loadConfig()` SMS fields |
| Auth handlers | `supabase/functions/_shared/auth_handlers.ts` | `handleLogin`, `handleVerifyOtp`, `smsConfigFrom` |
| SMS adapter | `supabase/functions/_shared/sms_provider.ts` | `SmsConfig`, `sendOtpSms`, `sendTransactionalSms`, `buildFast2SmsRequest` |
| Rate limit | `supabase/functions/_shared/otp_rate_limit.ts` | `evaluateOtpRateLimit` |
| Transactional fee SMS | `supabase/functions/_shared/finance/finance_collections_handlers.ts` | `notifyParentOfReceipt` |
| Transactional exam SMS | `supabase/functions/_shared/academics/exam_administration/exam_administration_handlers.ts` | `notifyParentsOfResults` |
| Comm-hub SMS (Twilio) | `supabase/functions/_shared/communication/notification_provider_config.ts`, `notification_providers.ts` | `loadNotificationProviderConfig`, `sendSms` |
| Tests | `sms_provider_test.ts`, `sms_provider_transactional_qa_c_011_test.ts`, `otp_rate_limit_test.ts` | unit/pure helpers; network mocked |

**Unsupported provider behaviour:** any `SMS_PROVIDER` other than `"fast2sms"` returns `SMS_PROVIDER_UNSUPPORTED` (`sms_provider.ts`).

### A3 — API key replacement behaviour

**Verdict: `CONDITIONAL` — KEY-ONLY REPLACEMENT NOT ALWAYS SUFFICIENT**

Owner question: *If testing with one Fast2SMS account, then create the final Akshara company Fast2SMS account with new API key — can I replace ONLY the API key?*

| Scenario | Sufficient? | Why (code evidence, not guess) |
|---|---|---|
| Stay on Fast2SMS, keep `FAST2SMS_ROUTE=q` (Quick), same endpoint/auth header shape | **Likely yes — key-only** | Quick route sends free-text message; code uses `authorization: <apiKey>` + `route=q` only (`buildFast2SmsRequest`). Env key: `SMS_PROVIDER_API_KEY`. |
| New business account requires Fast2SMS **OTP** route | **No — not key-only** | Needs `FAST2SMS_ROUTE=otp` (+ Fast2SMS website verification noted in env example / Batch-2 doc). |
| New business account requires **DLT** compliance | **No — not key-only** | Needs `FAST2SMS_ROUTE=dlt` **and** `FAST2SMS_SENDER_ID` **and** `FAST2SMS_MESSAGE_ID` (`config.ts`, `sms_provider.ts`). |
| Switch provider away from Fast2SMS | **No** | Code rejects non-`fast2sms` providers. |

**Account/provider-specific fields checked in code:**

| Item | Present in live OTP path? | Notes |
|---|---|---|
| API key | Yes — env `SMS_PROVIDER_API_KEY` | Required |
| Sender ID | Yes — env `FAST2SMS_SENDER_ID` | Used **only** when route=`dlt` |
| Route | Yes — env `FAST2SMS_ROUTE` (default `q`) | `q` / `otp` / `dlt` |
| Entity ID / DLT entity ID | **Not in code** | No env or field for DLT entity ID |
| DLT template / message ID | Yes — env `FAST2SMS_MESSAGE_ID` | Used as Fast2SMS `message` param on `dlt` |
| OTP template text | **Hardcoded** for route `q` | `buildOtpMessage()`: `"Your Akshara OTP is ${otp}. Valid for 5 minutes..."` |
| Registered mobile number | Not stored as config | Destination is user phone; Indian 10-digit normalisation in `toIndianMobile` |
| Authorization header format | **Hardcoded** | `authorization: <apiKey>` (Fast2SMS style) |
| Endpoint | **Hardcoded** | `https://www.fast2sms.com/dev/bulkV2` |
| Callback / webhook | **MISSING** | No SMS delivery webhook handling found for Fast2SMS |
| Account ID / campaign ID | **MISSING** in OTP path | Twilio path uses `accountSid` separately |
| Regulatory / DLT config | Partial via route + sender + message id | No separate entity-id field |

**Owner-facing statement:**  
If the final company Fast2SMS account continues to work with the **Quick (`q`) route** using the same HTTP API, replacing **only** `SMS_PROVIDER_API_KEY` on the VPS and recreating the edge container is enough. If the final account is meant for **OTP or DLT** production messaging, you must also set route / sender / template env vars — **key-only is not enough**.

### A4 — Secret / config storage

| Config item | Where it lives | Classification |
|---|---|---|
| `SMS_PROVIDER` | VPS / edge env (`loadConfig`) | `CONFIG-ONLY` (deployment secret/env) |
| `SMS_PROVIDER_API_KEY` | VPS `.env.akshara` (chmod 600 pattern); example placeholders only in git | `CONFIG-ONLY` / deployment secret |
| `FAST2SMS_ROUTE` / `SENDER_ID` / `MESSAGE_ID` | Same env | `CONFIG-ONLY` |
| `TRANSACTIONAL_SMS_ENABLED` | Env (default false) | `CONFIG-ONLY` |
| `AUTH_OTP_*` / rate limits | Env | `CONFIG-ONLY` |
| Twilio / SendGrid / FCM stubs | Env via `notification_provider_config.ts` | `CONFIG-ONLY` / often `MOCK / STUB` |
| Control Center vault SMS credentials | DB `platform_secret_vault` + `platform_provider_configs` | `PARTIAL` / **not consumed by OTP path** |
| Hardcoded in Flutter/source | API key: **no**. Endpoint + message text: **yes** | Endpoint/message = `HARDCODED`; key = not in source |

**Leakage checks (no secret values printed):**

| Surface | Risk | Classification |
|---|---|---|
| Flutter / web client | SMS keys not in dart-defines / `live_release.json` | `WORKING / LIVE` (keys stay server-side) |
| API responses | Non-pilot OTP not returned in body; pilot/dev may return OTP code | `PARTIAL` (OTP code leakage for allowlisted phones is intentional) |
| Logs | Failures log `result.code` / `detail` (provider message), not the API key | `PARTIAL` — provider error text may appear in logs |
| Git-tracked files | Examples use placeholders (`__fast2sms_api_key__`); `.env` / `.env.*` gitignored | `WORKING / LIVE` for ignore policy; **do not commit real `.env.akshara`** |

### A5 — Super Admin provider dashboard

**Control Center Providers UI exists** (`lib/features/platform/control_center/providers/control_center_providers_screen.dart`) with category AI / WhatsApp / SMS and “Save & health-check”.

| Capability | Current state | Evidence |
|---|---|---|
| View active SMS provider | `UI-ONLY` / `PARTIAL` | Lists vault configs; **OTP live provider is env Fast2SMS**, not this list |
| Change provider | `UI-ONLY` | Vault allows `sms: msg91|stub` only (`vault_service.ts` `SUPPORTED_PROVIDERS`) — **not Fast2SMS**; UI also offers Gupshup/OpenRouter in one dropdown |
| Update API key (vault) | `PARTIAL` | Saves to vault; **OTP path does not read vault** (contrast AI: `ai_settings.ts` decrypts vault) |
| Update sender ID / DLT / templates | `MISSING` in UI | Those are env vars only |
| Enable/disable provider | `PARTIAL` (vault `isActive`) | Not wired to `sendOtpSms` |
| Test connectivity | `PARTIAL` | “health-check” decrypts length > 0 (`checkSecretHealth`) — **not** a real Fast2SMS ping |
| Provider health / delivery failures | `MISSING` for SMS OTP | No SMS delivery dashboard wired to Fast2SMS receipts |
| Rotate credentials | `PARTIAL` | Vault rotate API exists; OTP uses env rotate (ops recreate edge) |
| Configure fallback provider | `MISSING` for SMS OTP | Vault has `failover_secret_id` field; OTP path has no fallback |
| Audit history | `PARTIAL` | `platform_secret_audit_log` for vault actions; not SMS delivery audit UI |

**Trace:** UI → `ControlCenterRepository.saveProvider` → `POST /control-center/providers` → `handleUpsertPlatformProvider` → vault store. **OTP/transactional SMS never call vault decrypt.** AI path does (`ai_settings.ts`).

### A6 — School-level configuration

| Question | Finding | Classification |
|---|---|---|
| Per-school SMS API key required? | **No** in current design | `NOT APPLICABLE` / platform-owned |
| Per-school SMS config supported? | **No** for OTP/transactional Fast2SMS | `MISSING` |
| Architecture | **One platform-owned SMS account** via edge env for all tenants | `WORKING / LIVE` (platform-owned) |
| Mixed? | Vault org-scoped provider rows exist, but unused by OTP | `INCOMPLETE / unclear product surface` → classify `PARTIAL` |

WhatsApp school-completion providers (`msg91`/`gupshup`/`stub`) are a **separate** channel from OTP SMS.

### A7 — SMS quota / plan linkage

| Capability | State | Evidence |
|---|---|---|
| SaaS plan SMS quota | `MISSING` | `entitlement_service.ts` limits = `students` + `schools` only |
| School-wise SMS quota | `MISSING` | No `sms` limit fields found |
| SMS credit balance | `MISSING` | |
| Usage metering | `MISSING` for SMS | Control Center usage analytics exist as a general panel; mock includes SMS category stats — **not** Fast2SMS metering |
| Low-balance alerts / hard-soft limits / recharge | `MISSING` | |
| Super Admin SMS override | `MISSING` | |
| OTP rate limits (abuse control) | `WORKING / LIVE` | Per-phone / per-IP / cooldown — **not** commercial quota |

**PRC overlap (do not modify PRC):**

| PRC ID | Topic | Overlap |
|---|---|---|
| **PRC-A-053** | SMS limits | **YES** |
| **PRC-A-050..057** | SaaS plan limit runtime enforcement | **YES** (SMS is one limit type) |
| **PRC-B-FR-24** | SMS quota calculations | **YES** |
| **PRC-B-FL-06** | SMS failure mode testing | **YES** (related resilience) |
| **PRC-A-044..049** | Central AI provider keys / isolation | Related pattern (AI vault wired; SMS OTP not) — **partial conceptual overlap** |
| **PRC-A-113** | QR/OTP verification | Different OTP (gate/QR), not SMS login — **NO** for this audit’s SMS-provider question |

---

## 3. Provider Configuration Evidence

### Live OTP / transactional SMS (authoritative)

```
VPS file: /opt/akshara/.env.akshara  (pattern from deploy example; not in git)
  SMS_PROVIDER=fast2sms
  SMS_PROVIDER_API_KEY=<secret>
  FAST2SMS_ROUTE=q|otp|dlt
  FAST2SMS_SENDER_ID=...   # dlt only
  FAST2SMS_MESSAGE_ID=...  # dlt only
  TRANSACTIONAL_SMS_ENABLED=false|true
→ Deno edge loadConfig() → AppConfig → sms_provider.ts
```

Reload note (ops docs): env change requires edge container recreate, not plain restart.

### Super Admin Control Center (not authoritative for OTP)

- UI: `control_center_providers_screen.dart`
- Backend: `platform_providers_handlers.ts` + `vault_service.ts`
- Supported SMS vault names: **`msg91`, `stub` only** — **not `fast2sms`**
- Saving an SMS key here does **not** change OTP delivery today

### Parallel notification SMS (Twilio)

- Env: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`, `SMS_STUB_MODE` (default stub true)
- Used by communication notification delivery, not by `/auth/login`

### Watchdog alert SMS

- Separate Fast2SMS curl in `akshara-watchdog.sh`; reuses `SMS_PROVIDER_API_KEY` if `ALERT_SMS_API_KEY` empty
- Recipients via `ALERT_SMS_PHONES` — live addendum previously found recipients empty (`LV-6`)

---

## 4. SMS Plan / Quota Evidence

| Check | Result |
|---|---|
| Plan entitlements include SMS? | **No** — resolver limits are students/schools (`entitlement_service.ts`) |
| Runtime SMS spend gating beyond `TRANSACTIONAL_SMS_ENABLED`? | **No** |
| School SMS credit wallet? | **Missing** |
| Overlap with scheduled PRC SMS limits? | **Yes** — `PRC-A-053`, `PRC-B-FR-24` (open / not implemented) |

**Classification:** SMS commercial quota enforcement = `MISSING`. OTP abuse rate-limit = `WORKING / LIVE` (technical, not commercial).

---

## 5. Platform / Role Matrix

**Important platform fact:** Flutter project platforms in `.metadata` are **android + ios only**. There is **no `web/` directory**. Release script builds **apk / aab / ipa** only (`scripts/build_release.sh`). Live public domain (`API_BASE_URL` in `config/live_release.json`) is the **API edge**, not a Flutter web host. Privacy page text: “mobile application (Android)”.

| Role | Android/iOS App | Browser Web | Login Works | OTP Works | Functional Coverage | Production Wired |
|---|---|---|---|---|---|---|
| Super Admin | Yes (staff / AdminShell) | **No deployed client** | Via app phone OTP → staff session | Same backend OTP | Platform / Control Center / admin ERP modules in app | `WORKING / LIVE` (API + app flags) — web `MISSING` |
| School Admin | Yes (staff) | No | Phone OTP | Same | Admin ERP modules | App `WORKING / LIVE`; web `MISSING` |
| Principal | Yes (staff → management home) | No | Phone OTP | Same | Management / approvals etc. | App `WORKING / LIVE`; web `MISSING` |
| Finance | Yes (staff → finance home) | No | Phone OTP | Same | Finance modules | App `WORKING / LIVE`; web `MISSING` |
| Teacher | Yes (`/teacher`) | No | Phone OTP | Same | Teacher shell | App `WORKING / LIVE`; web `MISSING` |
| Parent | Yes (`/parent`) | No | Phone OTP | Same | Parent shell | App `WORKING / LIVE`; web `MISSING` |
| Student | Yes (`/student`) | No | Phone / student_id OTP | Same | Student shell | App `WORKING / LIVE`; web `MISSING` |
| Transport staff | Yes as `transportManager` staff ERP role | No | Phone OTP | Same | Transport admin modules | App `WORKING / LIVE`; web `MISSING` |
| Driver | **Not an `ErpRole` login** — driver is a **transport entity** managed by staff | No | N/A | N/A | CRUD under Transport | `NOT APPLICABLE` as end-user login role |
| Security (gate) | **No dedicated gate-security `ErpRole`** | No | N/A | N/A | “Platform operations / security” is ops UI, not gate staff portal | `MISSING` / `NOT APPLICABLE` |
| Other staff (VP, hostel, librarian, inventory, admissions, management) | Yes via `ErpRole` + AdminShell | No | Phone OTP | Same | Module-permission gated | App `WORKING / LIVE`; web `MISSING` |

**Auth model evidence:** `UserRole` = parent | teacher | student | staff; staff ERP detail via `ErpRole` (`lib/core/security/erp_role.dart`). Post-login homes: `homeRouteForRole` / `homeRouteForStaffErp`.

---

## 6. Browser OTP Journey Evidence

**Owner journey audited:**

> Open Akshara web URL → phone → OTP SMS → verify → role + tenant resolved → browser role workspace → do ERP work

| Step | Classification | Evidence |
|---|---|---|
| Open Akshara web URL / domain as ERP UI | `MISSING` | Domain points at API (`live_release.json` `API_BASE_URL=https://akshara.veloraunisexsalon.com`). Deploy stack = Postgres + PostgREST + nginx gateway + Deno edge — **no Flutter web static hosting** in `deploy/akshara-vps`. |
| Phone number input (browser) | `MISSING` | Login UI exists in Flutter (`login_screen.dart`) but no web build/host |
| OTP request / delivery / verify | Backend `WORKING / LIVE`; browser UI `MISSING` | `auth_handlers.ts` + Fast2SMS |
| Session / role / tenant resolution | Backend `WORKING / LIVE` | JWT claims + `resolveAuthSessionContext` |
| Browser role workspace | `MISSING` | No web client |
| Normal authorized ERP work in browser | `MISSING` | |

**Overall journey classification: `MOBILE-ONLY` / `MISSING` (not `WORKING / LIVE` browser ERP).**

**Historical docs** (`docs/Operations/Rollout-Checklist.md`) still show `flutter build web ...` commands — those are **aspirational / stale relative to current repo** (no web platform). Code authority wins: **web client not present**.

### B3 — Web authentication parity (if web existed)

| Concern | Mobile app | Shared backend? | Browser status |
|---|---|---|---|
| Phone + OTP request/verify | Yes | Same `/auth/login` + `/auth/verify-otp` | No client |
| Session create / refresh / logout | Yes | Same sessions / refresh tokens | No client |
| Token storage | Secure storage native; Preferences on web *if* `kIsWeb` | N/A | `kIsWeb` branches exist (`secure_storage_backend.dart`) but web platform absent |
| Role / tenant / multi-school | Yes | Server claims | No client |
| Route guards | Yes (`route_guards.dart`, `app_router.dart`) | — | Designed in-app; not browser-hosted |
| Deep link / refresh | Mobile deep links partial | — | Browser back/refresh **UNKNOWN / NOT PROVEN** (no web deploy) |

---

## 7. Web Feature Parity Matrix

Because there is **no deployed Flutter web client**, module “web” coverage is **not** “Flutter can compile for web.” Classification below:

| Module | Mobile app | Browser web | Notes |
|---|---|---|---|
| Admissions | Both-intended in single app; API-flagged live | `MISSING` | Routes in AdminShell |
| Students / SIS | App | `MISSING` | |
| Attendance | App (teacher/parent/student) | `MISSING` | |
| Fees / finance | App | `MISSING` | |
| Exams | App | `MISSING` | |
| Question paper / education | App (flagged) | `MISSING` | |
| Homework | App | `MISSING` | |
| Communication | App | `MISSING` | |
| Transport | App | `MISSING` | |
| Reports | App | `MISSING` | |
| AI / copilot | App | `MISSING` | |
| Marketing | App surfaces | `MISSING` | |
| Settings / school admin | App | `MISSING` | |
| Super Admin / Control Center | App | `MISSING` | |
| Responsive admin layouts | Implemented (`AdminShell`, breakpoints) | `UI EXISTS` in code, **not live-wired as web** | Comment in `admin_shell.dart`: “Responsive desktop/tablet/mobile shell for the web ERP admin portal” — **intent**, not deployment proof |

**Feature parity mobile↔web:** `MISSING` (no web product surface).

### B5 — Responsive / browser usability

| Check | Classification | Evidence |
|---|---|---|
| Intentional responsive layouts | `PARTIAL` (code present for tablet/desktop widths) | `AksharaBreakpoints`, `AdminShell`, finance/admissions grids |
| Desktop navigation rail | `PARTIAL` (in-app) | `AdminNavigationRail` |
| Tables / forms / dialogs | App-oriented; portrait tablet may card-collapse | `useCardLayout` |
| File upload / PDF | App paths exist | Not browser-proven |
| Browser back / refresh / deep links | `UNKNOWN / NOT PROVEN` | No web host |

### B6 — Deployment readiness for pointing a domain at web ERP

| Check | Classification | Evidence |
|---|---|---|
| Web build configuration | `MISSING` | No `web/`; `.metadata` platforms android/ios only |
| Release script web target | `MISSING` | `build_release.sh` apk|aab|ipa only |
| Env injection for web | `MISSING` as product | `live_release.json` is for native release dart-defines |
| API base URL | `WORKING / LIVE` for API | Same URL would be usable *if* a web client existed |
| CORS for browser SPA | `UNKNOWN / NOT PROVEN` / likely incomplete | No CORS helpers found in `_shared/http.ts` grep |
| Auth redirect for web | `MISSING` | |
| HTTPS | API domain uses HTTPS (live) | Serves API, not SPA |
| Reverse proxy static web | `MISSING` | `gateway.conf` = `/rest/v1`, `/storage/v1` only |
| Deploy scripts for Flutter web artifact | Docs mention; **repo deploy path does not ship web** | Stale checklist vs code |

**Domain pointed at current stack ≠ browser ERP.** It is backend access for the mobile app.

---

## 8. Verified Gaps / Doubts Register

| ID | Capability | Current state | Exact evidence | User impact | PRC overlap | Existing roadmap overlap |
|---|---|---|---|---|---|---|
| **G-01** | Fast2SMS is the only implemented OTP SMS provider | `PARTIAL` / effectively `HARDCODED` concrete | `sms_provider.ts` rejects non-`fast2sms` | Cannot switch SMS vendor without code work | NO | YES (ops/integration docs; not a coded multi-provider roadmap item for OTP) |
| **G-02** | Key-only replacement for final business Fast2SMS account | `CONDITIONAL` | Route/sender/template envs in `config.ts` + `sms_provider.ts` | Owner may need DLT/template setup beyond key | NO | YES (Batch-2 open notes on DLT) |
| **G-03** | Super Admin SMS dashboard wired to live OTP | `UI-ONLY` | Control Center vault SMS ≠ `loadConfig` SMS; AI *is* vault-wired (`ai_settings.ts`) | Changing SMS key in UI does not change OTP | YES (conceptual vs PRC AI provider isolation 44–49) | YES (Control Center exists) |
| **G-04** | Vault SMS provider catalog mismatch | `PARTIAL` | Vault `sms: [msg91, stub]`; live OTP = Fast2SMS; UI dropdown mixes AI/WA names | Confusing / false sense of SMS management | NO | YES |
| **G-05** | School-specific SMS keys | `MISSING` | Platform env only | Schools cannot bring own SMS accounts | YES (PRC school AI isolation pattern analogous) | NO specific SMS-per-school item beyond PRC SMS limits |
| **G-06** | SMS quota / plan / credits | `MISSING` | Entitlements limits students/schools only | No commercial SMS metering or hard stop | **YES** `PRC-A-053`, `PRC-B-FR-24` | YES (PRC program) |
| **G-07** | Transactional parent SMS off by default | `CONFIG-ONLY` / off | `TRANSACTIONAL_SMS_ENABLED` default false | Fee/result SMS not sent until owner flips env | NO | YES (backlog O4-style notes historically) |
| **G-08** | Communication-hub SMS via Twilio stub | `MOCK / STUB` default | `SMS_STUB_MODE` default true; Twilio path separate | Broadcast SMS may not truly send | NO | YES (Production-Integrations docs) |
| **G-09** | Dual SMS stacks (Fast2SMS vs Twilio vs vault msg91) | `PARTIAL` / fragmented | Three parallel mechanisms | Ops confusion; inconsistent delivery | NO | YES |
| **G-10** | DLT entity ID not modeled | `MISSING` | No env/field | May block some DLT registrations if Fast2SMS requires it outside current params | NO | NO |
| **G-11** | SMS delivery webhooks / failure console | `MISSING` | No Fast2SMS callback handler | Hard to see delivery failures in-product | YES (PRC-B-FL-06 related) | NO |
| **G-12** | Flutter web platform / `web/` folder | `MISSING` | `.metadata` android/ios only; no `web/` | No browser ERP product | NO | Docs mention web historically; master roadmap does not schedule web client as current wave |
| **G-13** | Browser phone+OTP → role workspace journey | `MISSING` / `MOBILE-ONLY` | API live; no web host | Owner cannot run school from a browser URL today | NO | Stale Rollout-Checklist web build section |
| **G-14** | Production web deploy (domain → SPA) | `MISSING` | VPS gateway has no static Flutter web | Pointing a domain at current stack ≠ ERP UI | NO | NO |
| **G-15** | CORS / browser session hardening for SPA | `UNKNOWN / NOT PROVEN` | No CORS layer found | Would block or risk a future SPA | NO | NO |
| **G-16** | Driver / gate-security end-user portals | `MISSING` / `NOT APPLICABLE` | No `ErpRole.driver`; drivers are entities | Drivers don’t log into Akshara as a role | YES (transport PRC domains broader) | Transport module exists for managers |
| **G-17** | AdminShell “web ERP” responsive UX | `PARTIAL` / `UI EXISTS BUT NOT LIVE-WIRED` as browser | `admin_shell.dart` comment + breakpoints | Desktop layouts exist inside mobile app / large tablets only | NO | Design system docs |
| **G-18** | Watchdog SMS alert recipients | `PARTIAL` (key may exist; phones empty per prior live addendum) | `ALERT_SMS_PHONES`; LV-6 | Ops alerts may not SMS a human | NO | YES (roadmap alert-delivery item) |

---

## 9. Final Owner Decision List

Verified gaps/doubts that may need **later roadmap discussion** (not added to the roadmap by this audit):

1. **SMS key rotation policy** — Confirm whether the final Fast2SMS business account will stay on Quick (`q`) or move to OTP/DLT (affects whether key-only replacement is enough).
2. **Unify or clarify SMS stacks** — Fast2SMS (OTP/transactional) vs Twilio (comm hub) vs Control Center vault `msg91` (unused by OTP).
3. **Wire Super Admin SMS settings to the real OTP path** — or explicitly document that SMS OTP is ops/env-only (unlike AI vault).
4. **SMS commercial quotas / plan limits** — already captured as PRC-A-053 / PRC-B-FR-24; confirm priority vs other PRC items.
5. **Transactional SMS go-live decision** — `TRANSACTIONAL_SMS_ENABLED` currently off.
6. **Browser / Flutter Web ERP product decision** — current architecture is **mobile app + API domain**; full browser ERP journey is **not live**.
7. **If browser ERP is desired** — requires web platform, build/deploy pipeline, hosting/CORS/session strategy, and role UX certification (not present today).
8. **Driver / security staff login products** — not present as roles; confirm whether they are needed or remain manager-managed entities.
9. **DLT production readiness** — sender ID / template ID / possible entity-ID gaps before high-deliverability SMS.
10. **SMS delivery observability** — no in-product Fast2SMS failure/health dashboard for OTP.

---

## Appendix — Evidence anchors (quick index)

| Topic | Primary paths |
|---|---|
| Fast2SMS adapter | `supabase/functions/_shared/sms_provider.ts` |
| Env config | `supabase/functions/_shared/config.ts`, `deploy/akshara-vps/.env.akshara.example` |
| OTP auth | `supabase/functions/_shared/auth_handlers.ts` |
| Vault / Control Center | `vault_service.ts`, `platform_providers_handlers.ts`, `control_center_providers_screen.dart` |
| AI vault contrast | `supabase/functions/_shared/ai/ai_settings.ts` |
| Twilio notification SMS | `notification_provider_config.ts`, `notification_providers.ts` |
| Entitlements (no SMS quota) | `entitlement_service.ts` |
| PRC SMS limits | `docs/roadmap/PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` (`PRC-A-053`, `PRC-B-FR-24`) |
| No web platform | `.metadata`, absence of `web/`, `scripts/build_release.sh` |
| Live API domain | `config/live_release.json` |
| Responsive admin intent | `lib/features/admin/admin_shell.dart`, `lib/theme/breakpoints.dart` |
| Role homes | `lib/router/app_router.dart`, `lib/features/auth/qa_login_persona.dart` |

---

*End of read-only audit. No code, roadmap, tracker, secret, or deployment changes were made beyond creating this report file.*
