// PRC-A cap 45 — provider secret encryption at rest.
//
// `platform_secret_vault.encrypted_payload` previously held reversible
// Base64 (`btoa`) while the UI claimed "Encrypted at rest" — a fake. This
// module replaces that with real AES-256-GCM via Web Crypto, mirroring the
// EXACT pattern already proven in this repo for social OAuth tokens
// (`../social/social_token_crypto.ts`: same algorithm, same 12-byte random
// IV per encryption, same `iv || ciphertext(+tag)` packing, same
// hex-or-base64 32-byte key acceptance). That module hardcodes its own env
// var (`SOCIAL_TOKEN_ENC_KEY`) and doesn't export its key-handling
// internals, so a byte-identical convention is duplicated here rather than
// imported, keyed instead from `VAULT_ENC_KEY` — a distinct secret so
// rotating one never affects the other.
//
// Stored-string format:
//   v2 (current):  "v2:" + base64( iv(12) || ciphertext || tag )
//   v1 (legacy):   base64(plaintext) — no "v2:" prefix. Pre-dates this
//                  module; `platform_secret_vault.key_version = 1` rows are
//                  exactly these. Still readable with NO key configured —
//                  see `decryptLegacyBase64`.
//
// Encryption always fails closed: with `VAULT_ENC_KEY` unset, `encryptSecretV2`
// throws `VaultEncryptionNotConfiguredError` — we never fall back to writing
// a plaintext/Base64 secret. Decryption of a v2 ciphertext with the wrong (or
// missing) key throws too — Web Crypto's GCM tag check fails closed, it never
// silently returns garbage.

const ENC_KEY_ENV = "VAULT_ENC_KEY";

/** Prefix marking a `v2` (AES-256-GCM) ciphertext; legacy v1 rows lack it. */
export const VAULT_V2_PREFIX = "v2:";

export class VaultEncryptionNotConfiguredError extends Error {
  constructor() {
    super(`${ENC_KEY_ENV} is not configured — cannot store provider secrets securely`);
    this.name = "VaultEncryptionNotConfiguredError";
  }
}

/** True when `VAULT_ENC_KEY` is set (non-empty) in the environment. */
export function vaultEncryptionConfigured(): boolean {
  return !!Deno.env.get(ENC_KEY_ENV)?.trim();
}

/** Loads + normalises `VAULT_ENC_KEY` to exactly 32 bytes (AES-256). */
function keyBytes(): Uint8Array {
  const raw = Deno.env.get(ENC_KEY_ENV)?.trim();
  if (!raw) throw new VaultEncryptionNotConfiguredError();
  // Accept hex (64 chars) or base64; normalise to 32 bytes — same acceptance
  // rule as social_token_crypto.ts's SOCIAL_TOKEN_ENC_KEY.
  let bytes: Uint8Array;
  if (/^[0-9a-fA-F]{64}$/.test(raw)) {
    bytes = new Uint8Array(raw.match(/.{2}/g)!.map((h) => parseInt(h, 16)));
  } else {
    const bin = atob(raw);
    bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  }
  if (bytes.length !== 32) {
    throw new Error(`${ENC_KEY_ENV} must decode to 32 bytes (got ${bytes.length})`);
  }
  return bytes;
}

async function importKey(): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    keyBytes() as unknown as BufferSource,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

function toB64(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

function fromB64(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** True when `stored` is a `v2` (AES-256-GCM) ciphertext produced by this module. */
export function isV2Ciphertext(stored: string): boolean {
  return stored.startsWith(VAULT_V2_PREFIX);
}

/**
 * Encrypts `plaintext` with AES-256-GCM under `VAULT_ENC_KEY`, a fresh random
 * IV every call (never reused). Throws `VaultEncryptionNotConfiguredError`
 * when no key is configured — callers must never fall back to storing the
 * secret unencrypted.
 */
export async function encryptSecretV2(plaintext: string): Promise<string> {
  const key = await importKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv: iv as unknown as BufferSource },
      key,
      new TextEncoder().encode(plaintext) as unknown as BufferSource,
    ),
  );
  const packed = new Uint8Array(iv.length + ct.length);
  packed.set(iv, 0);
  packed.set(ct, iv.length);
  return VAULT_V2_PREFIX + toB64(packed);
}

/**
 * Decrypts a `v2` ciphertext (as produced by `encryptSecretV2`). Throws
 * (GCM tag mismatch) on the wrong key or corrupted ciphertext — it never
 * silently returns garbage. Throws `VaultEncryptionNotConfiguredError` when
 * no key is configured at all.
 */
export async function decryptSecretV2(stored: string): Promise<string> {
  const key = await importKey();
  const packed = fromB64(stored.slice(VAULT_V2_PREFIX.length));
  const iv = packed.slice(0, 12);
  const ct = packed.slice(12);
  const pt = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: iv as unknown as BufferSource },
    key,
    ct as unknown as BufferSource,
  );
  return new TextDecoder().decode(pt);
}

/**
 * Legacy (`key_version = 1`) encode/decode — reversible Base64, kept ONLY so
 * pre-existing rows written before this module still decrypt. Never used for
 * new writes.
 */
export function encryptLegacyBase64(plaintext: string): string {
  return btoa(unescape(encodeURIComponent(plaintext)));
}

export function decryptLegacyBase64(encoded: string): string {
  return decodeURIComponent(escape(atob(encoded)));
}
