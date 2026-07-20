-- 20260900000023_vault_secret_encryption.sql
-- Owner decision #13 / PRA-P2-30 — provider-secret encryption at rest.
--
-- Context: `platform_secret_vault.encrypted_payload` used to hold reversible
-- Base64 (`btoa`) while the UI claimed "Encrypted at rest" — a fake (P2-30).
-- The application layer now stores real AES-256-GCM ciphertext instead
-- (`supabase/functions/_shared/vault/vault_crypto.ts`), keyed by the env secret
-- `VAULT_ENC_KEY` (a 32-byte AES-256 key). This migration aligns the SCHEMA
-- with that new reality; it deliberately performs NO data mutation.
--
-- Why no schema change to the storage columns is required:
--   * `encrypted_payload` is already `TEXT` (unbounded) — the v2 stored string
--     is  "v2:" || base64( iv(12) || ciphertext || auth_tag(16) )  and packs the
--     IV and GCM auth tag INSIDE that single column, so no separate iv/tag
--     columns and no column widening are needed.
--   * `key_version` already exists and records the encryption SCHEME of each row
--     (1 = legacy reversible Base64, 2 = AES-256-GCM), not a rotation counter.
--
-- What this migration DOES (all idempotent, all non-destructive):
--   1. Flips the `key_version` DEFAULT from the legacy 1 to the current 2, so a
--      row inserted without an explicit version is marked as the current AES
--      scheme rather than legacy. (The app always sets key_version explicitly on
--      write — see vault_service.storeSecret/rotateSecret — so this is defensive
--      / self-documenting, and it never touches existing rows.)
--   2. Documents the scheme on the table and columns so the security model is
--      discoverable directly from the database.
--
-- PRE-EXISTING BASE64 ROWS — re-encryption plan (NOT done here, on purpose):
--   Any rows written before AES landed still carry key_version = 1 and reversible
--   Base64 payloads. They are STILL READABLE (the app decrypts both schemes
--   transparently — vault_service.decryptCredential), so nothing breaks. They are
--   upgraded to AES-256-GCM either lazily (the next rotateSecret re-encrypts under
--   the current scheme) or in bulk by the application-layer maintenance routine
--   `reencryptLegacyVaultSecrets` (POST /control-center/vault/reencrypt,
--   super-admin only — see vault_reencrypt.ts). That routine is idempotent and
--   per-row fail-isolated: a bad row is skipped, never dropped.
--
--   Re-encryption is INTENTIONALLY NOT performed in SQL: the master key
--   `VAULT_ENC_KEY` lives only in the edge-function environment, never in the
--   database, so Postgres has no way to produce authenticated ciphertext. Any
--   attempt to "convert" payloads in SQL would corrupt them. This migration
--   therefore leaves every existing row byte-for-byte untouched.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'platform_secret_vault'
  ) THEN
    -- New rows default to the current AES-256-GCM scheme. Existing rows keep
    -- whatever key_version they already have — this changes the DEFAULT only.
    ALTER TABLE platform_secret_vault ALTER COLUMN key_version SET DEFAULT 2;

    COMMENT ON TABLE platform_secret_vault IS
      'Provider secrets (AI/WhatsApp/SMS credentials) encrypted at rest with '
      'AES-256-GCM under env key VAULT_ENC_KEY. Platform/super-admin scope only '
      '(erp_platform role). See supabase/functions/_shared/vault/.';
    COMMENT ON COLUMN platform_secret_vault.encrypted_payload IS
      'AES-256-GCM ciphertext. Format: "v2:" || base64(iv(12)||ciphertext||tag(16)). '
      'Legacy (key_version=1) rows hold reversible Base64 and are being phased out '
      'via rotateSecret / POST /control-center/vault/reencrypt. Never plaintext.';
    COMMENT ON COLUMN platform_secret_vault.key_version IS
      'Encryption SCHEME of the payload: 1 = legacy reversible Base64 (deprecated), '
      '2 = AES-256-GCM (current). Not a rotation counter.';
  END IF;
END $$;
