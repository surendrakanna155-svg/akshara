// Social Media Integration — token encryption (Phase 2).
//
// OAuth access tokens are secrets: they are encrypted at rest with AES-256-GCM
// using a server-side key (env SOCIAL_TOKEN_ENC_KEY, 32 bytes as base64 or hex).
// Without a configured key, connecting is refused (we never store a token in the
// clear). Format of the stored string: base64( iv(12) || ciphertext || tag ).

const ENC_KEY_ENV = "SOCIAL_TOKEN_ENC_KEY";

export class SocialEncryptionNotConfiguredError extends Error {
  constructor() {
    super(`${ENC_KEY_ENV} is not configured — cannot store social tokens securely`);
    this.name = "SocialEncryptionNotConfiguredError";
  }
}

export function socialEncryptionConfigured(): boolean {
  return !!Deno.env.get(ENC_KEY_ENV)?.trim();
}

function keyBytes(): Uint8Array {
  const raw = Deno.env.get(ENC_KEY_ENV)?.trim();
  if (!raw) throw new SocialEncryptionNotConfiguredError();
  // Accept hex (64 chars) or base64; normalise to 32 bytes.
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

export async function encryptToken(plaintext: string): Promise<string> {
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
  return toB64(packed);
}

export async function decryptToken(encrypted: string): Promise<string> {
  const key = await importKey();
  const packed = fromB64(encrypted);
  const iv = packed.slice(0, 12);
  const ct = packed.slice(12);
  const pt = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: iv as unknown as BufferSource },
    key,
    ct as unknown as BufferSource,
  );
  return new TextDecoder().decode(pt);
}

/** Last-4 fingerprint for safe display/audit without revealing the token. */
export function tokenFingerprint(plaintext: string): string {
  return plaintext.length <= 4 ? "****" : `****${plaintext.slice(-4)}`;
}
