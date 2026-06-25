# Social Media Integration (Phase 2) — Meta (Facebook/Instagram)

Extends the Marketing Publisher so a school can **connect a Meta account and
auto-publish posters to its Facebook Page and Instagram Business account** through
the selected-destinations flow. Built as an extension of the certified Phase-1
publisher (create → AI poster + captions → preview → approval → select destinations
→ publish).

## What was built (backend)

- **`_shared/social/social_token_crypto.ts`** — OAuth tokens are encrypted at rest
  with **AES-256-GCM** (`SOCIAL_TOKEN_ENC_KEY`, 32 bytes). Connecting is refused if no
  key is configured — tokens are never stored in clear text.
- **`_shared/social/meta_graph_client.ts`** — the Graph API client: Facebook Login
  URL (scopes `pages_manage_posts`, `instagram_content_publish`, …), code→token
  exchange, managed-Pages fetch (with linked IG accounts), Facebook Page photo/feed
  post, Instagram two-step container→publish. **Dry-run safe:** when no Meta app is
  configured (or `META_DRY_RUN=true`), every publish returns a structured `dry_run`
  result recording the exact request that *would* be sent — so the integration is
  testable and certifiable before App Review.
- **`social_media_connections`** table (migration `20260730000000`): one row per
  connected Page (+ optional IG business account), school-scope RLS, encrypted page
  token, `viewSocialConnections`/`manageSocialConnections` perms.
- **Endpoints** (`/social/...`): `POST connect/start` (login URL), `POST
  connect/complete` (exchange + store, encrypted), `GET connections` (no tokens
  exposed), `DELETE connections/:id` (disconnect). All RBAC- + school-scope-gated;
  connect/disconnect audited.
- **Publisher integration** — `publisher_dispatch` now posts the `facebook`/`instagram`
  destinations via the connected account (Graph API, or `dry_run`), falling back to
  `pending_connection` when no account is linked. Publishing stays **approval-gated**
  (`approveAchievementPromotion`) and only goes to the **user-selected** channels.

## Certification status — ✅ PRODUCTION CERTIFIED (live, dry-run mode)

- Backend unit tests **11/11** (AES-GCM round-trip, token never stored in clear,
  login-URL scopes, dry-run FB/IG request construction with token redaction) +
  `deno check` clean.
- **Live cert 13/13 PASS** (2026-06-25) against the real VPS / real DB / school-scope
  JWT via `scripts/qa/live_cert_social_media.py`: unauth→401, read needs
  `viewSocialConnections`, connect needs `manageSocialConnections`, OAuth login URL
  carries the publish scopes, connect stores a connection, **token is encrypted at rest
  (`stored=ENC` — no plaintext in `encrypted_page_token`)**, list never exposes the
  token, publisher posts FB+IG via the connection (`dry_run`, records the Graph request),
  disconnect works, FB/IG fall back to `pending_connection` without a connection,
  unauth disconnect→401, clean teardown.
- Deployed: migration `20260730000000` applied (table + RLS + grants + 2 perms + 6 role
  mappings), `SOCIAL_TOKEN_ENC_KEY` set on the VPS, `_shared/social/` + publisher +
  router live, edge recreated. Server runs in **dry-run** until the owner completes the
  Meta steps below; it flips to real posting automatically (no code change).

## ⚠️ Owner-gated go-live steps (external — cannot be done from this repo)

Real publishing to live Facebook/Instagram accounts requires steps that only the
business owner can complete with Meta:

1. **Create a Meta app** at developers.facebook.com (type: Business). Add **Facebook
   Login** and the **Instagram Graph API**.
2. **Business verification** of the Meta Business account.
3. **App Review** for the advanced permissions the publisher uses:
   `pages_manage_posts`, `pages_read_engagement`, `pages_show_list`, `instagram_basic`,
   `instagram_content_publish`, `business_management`. (Until approved, only users with
   a role on the app can publish — fine for piloting with the school's own account.)
4. **Instagram** must be a **Business/Creator** account **linked to the Facebook Page**.
5. **Server config** on the VPS `.env.akshara`, then recreate the edge:
   - `META_APP_ID`, `META_APP_SECRET`
   - `META_REDIRECT_URI` (e.g. `https://akshara.veloraunisexsalon.com/social/connect/callback`)
   - `SOCIAL_TOKEN_ENC_KEY` (already set at deploy — 32-byte key)
   - leave `META_DRY_RUN` unset (or `false`) to send real posts.
6. **Image hosting** — Graph requires a publicly reachable image URL for photo posts.
   Posters must be rendered + uploaded to public storage (the asset `previewUrl`); the
   poster image-generation hook is the remaining piece for live image posts (captions +
   Page text posts work without it).

Once 1–6 are done, the same connect flow stores a real Page token (encrypted) and the
publisher posts for real — no code change needed; the dry-run guard turns off
automatically because `metaConfigured()` becomes true.
