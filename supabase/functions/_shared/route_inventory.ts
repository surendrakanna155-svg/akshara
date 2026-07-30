// SEC-AUTH-FIRST — the API's route surface, recovered from source.
//
// Guard infrastructure (imported by tests only; nothing on the request path uses
// it). `auth_precedes_dispatch_guard_test.ts` needs to probe EVERY route the API
// exposes, not a hand-picked sample — the previous forced-auth test listed twelve
// paths by hand and none of them happened to be one of the routes that was
// actually leaking, which is why a passing suite coexisted with a live exposure.
//
// A hand-maintained list would reproduce that failure, so the inventory is
// derived from the router sources instead. Three sources, deliberately
// overlapping so no single extraction bug can quietly shrink coverage:
//
//   1. EXACT LITERALS  — `path === "/finance/dashboard"` in any `*router*.ts`.
//   2. PARAMETERISED   — `path.match(/^\/academic\/years\/([^/]+)$/)`, with each
//                        capture group filled by a syntactically valid id.
//   3. TOP-LEVEL       — `path === "/auth/login"` in `api/app.ts`'s dispatch chain
//                        (the `/health/*` + `/auth/*` routes, which live outside
//                        the module registry).
//
// Extraction is inherently best-effort against source text, so the guard does NOT
// rely on it alone: it also probes a synthetic unknown path under every prefix
// declared in `route_registry.ts`, and asserts a coverage floor so a regex that
// stops matching fails loudly instead of silently testing nothing.

import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { dirname, fromFileUrl, join } from "https://deno.land/std@0.224.0/path/mod.ts";

const SHARED_DIR = dirname(fromFileUrl(import.meta.url));
const APP_TS = join(dirname(SHARED_DIR), "api", "app.ts");

/** `path === "<literal>"` */
const EXACT_RE = /path\s*===\s*"([^"]+)"/g;
/** `.match(/^...$/)` — the parameterised route form used by every router. */
const PATTERN_RE = /\.match\(\s*\/(\^[^\n]*?\$)\/\s*\)/g;

/** A syntactically valid id, so a route that parses its parameter still matches. */
export const PROBE_ID = "00000000-0000-4000-8000-000000000001";

/**
 * Turns a router's route regex source into one concrete path.
 * `^\/academic\/years\/([^/]+)$` → `/academic/years/<PROBE_ID>`
 * Optional groups (`(?:\/(publish|approve))?`) are dropped — the bare path is the
 * one that must be gated; the suffixed variants are covered by their own literals
 * or by the prefix probe.
 */
export function patternToPath(source: string): string | null {
  let s = source;
  s = s.replace(/^\^/, "").replace(/\$$/, "");
  s = s.replace(/\(\?:[^()]*(?:\([^()]*\)[^()]*)*\)\?/g, ""); // drop optional groups
  s = s.replace(/\(\[\^\/\]\+\)/g, PROBE_ID); // ([^/]+) → id
  s = s.replace(/\(\[\^\/\]\+\?\)/g, PROBE_ID);
  s = s.replace(/\\\//g, "/");
  if (!s.startsWith("/")) return null;
  // Anything left with regex metacharacters was not understood — skip it rather
  // than probe a nonsense path (the prefix probe still covers that subtree).
  if (/[\\()\[\]{}|?*+^$]/.test(s)) return null;
  return s;
}

async function routerSources(): Promise<string[]> {
  const out: string[] = [];
  for await (const e of walk(SHARED_DIR, { exts: [".ts"], includeDirs: false })) {
    if (!e.name.includes("router") || e.name.endsWith("_test.ts")) continue;
    out.push(await Deno.readTextFile(e.path));
  }
  return out;
}

/** Every route path the module routers expose, recovered from source. */
export async function extractModuleRoutePaths(): Promise<string[]> {
  const paths = new Set<string>();
  for (const src of await routerSources()) {
    for (const m of src.matchAll(EXACT_RE)) {
      if (m[1]!.startsWith("/")) paths.add(m[1]!);
    }
    for (const m of src.matchAll(PATTERN_RE)) {
      const p = patternToPath(m[1]!);
      if (p) paths.add(p);
    }
  }
  return [...paths].sort();
}

/** Every route path in `api/app.ts`'s top-level dispatch chain (`/health/*`, `/auth/*`). */
export async function extractTopLevelRoutePaths(): Promise<string[]> {
  const src = await Deno.readTextFile(APP_TS);
  const paths = new Set<string>();
  for (const m of src.matchAll(EXACT_RE)) {
    if (m[1]!.startsWith("/")) paths.add(m[1]!);
  }
  return [...paths].sort();
}

/** The union: every route path this API is known to expose. */
export async function extractRoutePaths(): Promise<string[]> {
  const all = new Set([
    ...await extractModuleRoutePaths(),
    ...await extractTopLevelRoutePaths(),
  ]);
  return [...all].sort();
}
