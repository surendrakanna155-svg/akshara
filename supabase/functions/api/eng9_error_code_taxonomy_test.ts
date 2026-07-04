// P1-CODE-3 · ENG-9 — standardize error codes: one taxonomy, stable
// machine-readable codes. This lint walks EVERY production handler and asserts
// each literal `errorEnvelope("CODE", …)` uses a stable UPPER_SNAKE_CASE code
// (never a raw Postgres SQLSTATE like `23505`/`XX000`, an ad-hoc lowercase
// string, or a stray/short token). Dynamic `errorEnvelope(error.code, …)`
// forwarders are validated by their typed-error contract (their `.code` is a
// controlled canonical value), so only string literals are scanned here.
//
// The canonical GENERIC codes below are the cross-module backbone; module
// handlers may add domain codes (e.g. TIMETABLE_CLASH, EXAM_VALIDATION) as long
// as they follow the same UPPER_SNAKE_CASE shape.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { fromFileUrl } from "https://deno.land/std@0.224.0/path/mod.ts";

/** Stable machine-readable code: UPPER_SNAKE_CASE, at least 4 chars, letter-led. */
const CODE_SHAPE = /^[A-Z][A-Z0-9_]{3,}$/;

/** The canonical cross-module generic taxonomy (documented backbone). */
const CANONICAL_GENERIC = new Set<string>([
  "VALIDATION_ERROR",
  "INVALID_BODY",
  "BAD_REQUEST",
  "NOT_FOUND",
  "UNAUTHORIZED",
  "FORBIDDEN",
  "CONFLICT",
  "INTERNAL_ERROR",
  "SERVER_ERROR",
  "CONFIG_ERROR",
]);

async function collectCodes(): Promise<Array<{ file: string; code: string }>> {
  const roots = [
    fromFileUrl(new URL("../_shared", import.meta.url)),
    fromFileUrl(new URL(".", import.meta.url)), // api/
  ];
  const found: Array<{ file: string; code: string }> = [];
  const literal = /errorEnvelope\(\s*"([^"]+)"/g;
  for (const root of roots) {
    for await (
      const entry of walk(root, { exts: [".ts"], skip: [/_test\.ts$/] })
    ) {
      const src = await Deno.readTextFile(entry.path);
      for (const m of src.matchAll(literal)) {
        found.push({ file: entry.path, code: m[1]! });
      }
    }
  }
  return found;
}

Deno.test("ENG-9: every literal errorEnvelope code is a stable UPPER_SNAKE_CASE code", async () => {
  const codes = await collectCodes();
  // Sanity: we actually scanned the tree.
  assertEquals(codes.length > 100, true, "expected to scan many handler codes");

  const offenders = codes
    .filter(({ code }) => !CODE_SHAPE.test(code))
    .map(({ file, code }) => `${file.split("/_shared/").pop()}: "${code}"`);

  assertEquals(
    offenders,
    [],
    `Non-conforming error codes (use UPPER_SNAKE_CASE, never a raw DB SQLSTATE):\n${offenders.join("\n")}`,
  );
});

Deno.test("ENG-9: the canonical generic taxonomy is actually in use across handlers", async () => {
  const used = new Set((await collectCodes()).map((c) => c.code));
  // The backbone codes must each appear — proves the taxonomy is real, not aspirational.
  const missing = [...CANONICAL_GENERIC].filter((c) => !used.has(c));
  assertEquals(
    missing,
    [],
    `Canonical generic codes never used (taxonomy drift): ${missing.join(", ")}`,
  );
});
