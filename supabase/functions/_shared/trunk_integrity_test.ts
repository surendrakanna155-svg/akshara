// Trunk Integrity regression guards (W0 — Canonical Trunk Certification).
//
// PERMANENT invariants that any future lane-convergence MUST preserve. Run with:
//   deno test --allow-read supabase/functions/_shared/trunk_integrity_test.ts
//
// These are pure static checks over the repository files (no DB, no network), so
// a merge that silently reintroduces a conflict marker, a duplicate migration
// version, a duplicate table, or an unregistered edge router fails CI here.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const HERE = new URL(".", import.meta.url); // supabase/functions/_shared/
const FUNCTIONS = new URL("../", HERE); // supabase/functions/
const MIGRATIONS = new URL("../../migrations/", HERE); // supabase/migrations/
const APP_TS = new URL("../api/app.ts", HERE);
// ICA-F4: the module-router registration moved from app.ts into the declarative
// route_registry.ts (MODULE_ROUTES). The registration guard now checks that file.
const ROUTE_REGISTRY_TS = new URL("route_registry.ts", HERE);

function readDirFiles(dir: URL, suffix: string): string[] {
  const names: string[] = [];
  for (const e of Deno.readDirSync(dir)) {
    if (e.isFile && e.name.endsWith(suffix)) names.push(e.name);
  }
  return names.sort();
}

function walk(dir: URL, suffixes: string[]): URL[] {
  const out: URL[] = [];
  for (const e of Deno.readDirSync(dir)) {
    const child = new URL(e.name + (e.isDirectory ? "/" : ""), dir);
    if (e.isDirectory) out.push(...walk(child, suffixes));
    else if (suffixes.some((s) => e.name.endsWith(s))) out.push(child);
  }
  return out;
}

Deno.test("trunk-integrity: migration versions are unique and strictly monotonic", () => {
  const files = readDirFiles(MIGRATIONS, ".sql");
  assert(files.length > 100, `expected the full migration set, found ${files.length}`);
  const versions = files.map((f) => f.slice(0, 14));
  // 14-digit numeric prefix on every migration.
  for (const [i, v] of versions.entries()) {
    assert(/^\d{14}$/.test(v), `migration ${files[i]} has a non-14-digit version prefix "${v}"`);
  }
  const seen = new Set<string>();
  for (let i = 0; i < versions.length; i++) {
    assert(!seen.has(versions[i]), `duplicate migration version ${versions[i]} (${files[i]})`);
    seen.add(versions[i]);
    if (i > 0) {
      assert(
        versions[i] > versions[i - 1],
        `migrations not strictly monotonic: ${files[i - 1]} then ${files[i]}`,
      );
    }
  }
});

Deno.test("trunk-integrity: no table has two UNGUARDED CREATE TABLE statements", () => {
  // A guarded `CREATE TABLE IF NOT EXISTS` recreate (idempotent recovery) is
  // allowed; two plain unguarded creates of the same table are a real collision.
  const files = readDirFiles(MIGRATIONS, ".sql");
  const unguarded = new Map<string, string>();
  // Capture an optional schema qualifier so `storage.buckets` and
  // `storage.objects` are distinct; normalize the default `public.` schema.
  const re = /CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?((?:[a-z_][a-z0-9_]*\.)?[a-z_][a-z0-9_]*)/gi;
  for (const f of files) {
    const sql = Deno.readTextFileSync(new URL(f, MIGRATIONS));
    for (const m of sql.matchAll(re)) {
      if (m[1]) continue; // IF NOT EXISTS — idempotent, allowed
      let table = m[2].toLowerCase();
      if (table.startsWith("public.")) table = table.slice(7);
      if (unguarded.has(table)) {
        throw new Error(
          `table "${table}" has two UNGUARDED CREATE TABLE statements (${unguarded.get(table)} + ${f})`,
        );
      }
      unguarded.set(table, f);
    }
  }
  assert(unguarded.size > 50, `expected many tables, found ${unguarded.size}`);
});

Deno.test("trunk-integrity: every edge module router imported is registered exactly once", () => {
  // ICA-F4: registration lives in the declarative route_registry.ts (MODULE_ROUTES),
  // not app.ts. app.ts now dispatches via matchModuleRoute — assert that indirection
  // is intact so no future edit reintroduces a hand-rolled router array in app.ts.
  const appSrc = Deno.readTextFileSync(APP_TS);
  assert(
    appSrc.includes("matchModuleRoute"),
    "app.ts must dispatch module routes via matchModuleRoute (route_registry.ts)",
  );
  assert(
    !appSrc.includes("const moduleRouters = ["),
    "app.ts must not reintroduce an inline moduleRouters array (registration belongs in route_registry.ts)",
  );

  const src = Deno.readTextFileSync(ROUTE_REGISTRY_TS);
  // route* functions imported from a *_router.ts module.
  const imported = new Set<string>();
  for (const m of src.matchAll(/import\s*\{\s*(route[A-Z]\w*)\s*\}\s*from\s*"[^"]*_router\.ts"/g)) {
    imported.add(m[1]);
  }
  assert(imported.size > 30, `expected many module routers, found ${imported.size}`);
  // The MODULE_ROUTES array region.
  const arrStart = src.indexOf("export const MODULE_ROUTES");
  const arrEnd = src.indexOf("] as const;", arrStart);
  assert(arrStart >= 0 && arrEnd > arrStart, "MODULE_ROUTES array not found");
  const arr = src.slice(arrStart, arrEnd);
  for (const r of imported) {
    const count = (arr.match(new RegExp(`\\b${r}\\b`, "g")) ?? []).length;
    assertEquals(count, 1, `router ${r} is registered ${count}× in MODULE_ROUTES (expected exactly 1)`);
  }
  // ASIP + PRA + DRP coexistence anchors.
  for (const anchor of ["routeSupport", "routeIdentity", "routeAudit", "routeFinance"]) {
    assert(imported.has(anchor), `expected ${anchor} to be a registered module router`);
  }
});

Deno.test("trunk-integrity: no unresolved git conflict markers in edge functions", () => {
  const files = walk(FUNCTIONS, [".ts"]);
  const offenders: string[] = [];
  for (const f of files) {
    const text = Deno.readTextFileSync(f);
    for (const line of text.split("\n")) {
      if (/^<<<<<<< /.test(line) || /^>>>>>>> /.test(line) || /^=======$/.test(line)) {
        offenders.push(f.pathname);
        break;
      }
    }
  }
  assertEquals(offenders, [], `git conflict markers found in: ${offenders.join(", ")}`);
});

Deno.test("trunk-integrity: ASIP mirror bridges stay SECURITY DEFINER + search_path pinned + PUBLIC-revoked", () => {
  const mig = Deno.readTextFileSync(
    new URL("20260920000040_support_platform_mirror.sql", MIGRATIONS),
  );
  for (const fn of ["app_support_mirror_incident", "app_support_mirror_evidence", "app_support_propagate_resolution"]) {
    assert(mig.includes(fn), `bridge ${fn} missing`);
    assert(
      new RegExp(`REVOKE ALL ON FUNCTION ${fn}[\\s\\S]*?FROM PUBLIC`).test(mig),
      `bridge ${fn} must REVOKE ... FROM PUBLIC`,
    );
  }
  const defCount = (mig.match(/SECURITY DEFINER SET search_path = public, pg_temp/g) ?? []).length;
  assert(defCount >= 3, `expected >=3 SECURITY DEFINER+search_path bridges, found ${defCount}`);
});
