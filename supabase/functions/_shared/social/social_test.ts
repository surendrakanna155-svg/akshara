import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SOCIAL_TOKEN_ENC_KEY", btoa("x".repeat(32)));
// Ensure dry-run for the graph client (no Meta app configured).
Deno.env.delete("META_APP_ID");
Deno.env.delete("META_APP_SECRET");
Deno.env.delete("META_DRY_RUN");

const { encryptToken, decryptToken, socialEncryptionConfigured, tokenFingerprint } = await import(
  "./social_token_crypto.ts"
);
const { metaDryRun, metaConfigured, buildLoginUrl, publishToFacebookPage, publishToInstagram, META_SCOPES } =
  await import("./meta_graph_client.ts");

Deno.test("AES-GCM token round-trips and ciphertext is not plaintext", async () => {
  assertEquals(socialEncryptionConfigured(), true);
  const secret = "EAABsbCS1iHgBA_long_lived_page_token_12345";
  const enc = await encryptToken(secret);
  assertNotEquals(enc, secret);
  assertEquals(await decryptToken(enc), secret);
  // distinct IV per call → different ciphertext for same input
  assertNotEquals(await encryptToken(secret), enc);
});

Deno.test("token fingerprint reveals only last 4", () => {
  assertEquals(tokenFingerprint("abcdefgh"), "****efgh");
});

Deno.test("graph client is in dry-run without Meta credentials", () => {
  assertEquals(metaConfigured(), false);
  assertEquals(metaDryRun(), true);
});

Deno.test("login url carries the required publish scopes", () => {
  const url = buildLoginUrl("https://x/callback", "state1");
  assertEquals(url.includes("instagram_content_publish"), true);
  assertEquals(url.includes("pages_manage_posts"), true);
  assertEquals(META_SCOPES.includes("instagram_content_publish"), true);
});

Deno.test("dry-run facebook publish records the request and redacts the token", async () => {
  const r = await publishToFacebookPage("page-1", "SECRET_TOKEN", "Happy Diwali!", "https://x/p.png");
  assertEquals(r.status, "dry_run");
  assertEquals(r.channel, "facebook");
  assertEquals((r.request as Record<string, string>).access_token, "****");
});

Deno.test("dry-run instagram publish records container+publish steps", async () => {
  const r = await publishToInstagram("ig-1", "SECRET", "caption", "https://x/p.png");
  assertEquals(r.status, "dry_run");
  assertEquals(r.channel, "instagram");
  assertEquals((r.request as Record<string, string>).publish, "/ig-1/media_publish");
});
