# Akshara storage-api (Batch 7)

Real file storage for the lean VPS stack. Plain-language goal: **photo/album
uploads ("School Memories") and document files actually work** — before this, the
app's signed-URL upload/download code pointed at a Supabase Storage service that
was never deployed, so every upload failed.

## What it is

- `supabase/storage-api:v1.19.3` container on `akshara-net`, file backend on the
  `akshara_storage_data` Docker volume.
- It manages its own `storage.*` schema (buckets/objects/prefixes/…) and validates
  the same JWTs as PostgREST.
- The edge talks to it **internally** via the gateway for signing (`createSignedUploadUrl`
  / `createSignedUrl`), then **rewrites the URL origin to `PUBLIC_STORAGE_BASE_URL`**
  so the device can PUT/GET the bytes directly.
- The public Nginx vhost routes `/storage/v1/*` → `127.0.0.1:5000` (storage-api).
  Access is safe: the bucket is private; every upload/download needs a short-lived
  signed token.

## How requests flow

```
device ── presign ──▶ edge ── /storage/v1/object/sign ──▶ gateway ──▶ storage-api
   ◀── public signed URL (origin rewritten to PUBLIC_STORAGE_BASE_URL) ──┘
device ── PUT/GET bytes ──▶ https://<public>/storage/v1/... ──▶ Nginx :5000 ──▶ storage-api
```

## One-time setup on a fresh box

```bash
# 0. roles already exist (supabase image). Set the storage-admin password once:
PW=$(openssl rand -hex 24)
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "ALTER ROLE supabase_storage_admin WITH LOGIN PASSWORD '$PW';"
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "GRANT ALL PRIVILEGES ON DATABASE akshara_db TO supabase_storage_admin;"

# 1. Hand the storage schema to the storage admin (drop the lean stub first —
#    it has zero objects, so this is non-destructive). storage-api recreates it.
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "DROP SCHEMA IF EXISTS storage CASCADE; CREATE SCHEMA storage AUTHORIZATION supabase_storage_admin;"

# 2. storage.env from the example (fill ANON/SERVICE keys, PGRST_JWT_SECRET, $PW)
cp storage.env.example /opt/akshara/storage.env && chmod 600 /opt/akshara/storage.env

# 3. start the container (lets it run its 36 internal migrations)
docker compose -f /opt/akshara/docker-compose.akshara.yml up -d akshara-storage
# (or docker run ... supabase/storage-api:v1.19.3 — see compose for flags)

# 4. grants + bucket + tenant policies (we run with DB_INSTALL_ROLES=false)
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db \
  < storage_grants_bucket_policies.sql

# 5. public route: add to /etc/nginx/sites-available/akshara inside the 443 server,
#    BEFORE `location /`, then `nginx -t && systemctl reload nginx`:
#      client_max_body_size 60M;
#      location /storage/v1/ {
#        proxy_pass http://127.0.0.1:5000/;   # trailing slash strips the prefix
#        proxy_set_header Host $host;
#        proxy_request_buffering off;
#      }

# 6. edge env: PUBLIC_STORAGE_BASE_URL=https://akshara.veloraunisexsalon.com
#    in /opt/akshara/.env.akshara, then: docker restart akshara-edge
```

## Verify

```bash
curl -s http://127.0.0.1:3000/health/storage          # {"status":"ok","reachable":true}
curl -s https://<public>/storage/v1/status            # HTTP 200
# full signed-URL round trip (service key): create upload URL -> PUT -> sign -> GET
```

## Gotchas learned (Batch 7)

- `DB_INSTALL_ROLES=true` tries to CREATE roles → fails (they exist) / needs
  superuser. Use `false` + apply `storage_grants_bucket_policies.sql`.
- `service_role` has BYPASSRLS but **still needs table GRANTs** — without the
  grants you get a misleading "new row violates row-level security policy" whose
  underlying code is `42501` (insufficient privilege).
- `supabase_storage_admin` needs `ALL PRIVILEGES ON DATABASE` to run its migration
  runner (else "permission denied for database").
- The running container was first started via `docker run`; the compose entry now
  matches it. Prefer compose going forward.
