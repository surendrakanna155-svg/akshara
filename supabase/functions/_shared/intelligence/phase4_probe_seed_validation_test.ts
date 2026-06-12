import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PROBE_SEED_PATH = new URL(
  "../../../migrations/20260622400001_phase4_probe_seed.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(PROBE_SEED_PATH);

const STAGING_ORG = "a1000000-0000-4000-8000-000000000001";
const STAGING_SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STAGING_SCHOOL_B = "a2000000-0000-4000-8000-000000000002";

Deno.test("phase4 probe seed uses staging org/school FKs not probe row ids", () => {
  assert(sql.includes(STAGING_ORG));
  assert(sql.includes(STAGING_SCHOOL_A));
  assert(sql.includes(STAGING_SCHOOL_B));
  assert(!sql.includes("'e0500000-0000-4000-8000-000000000001',\n    'f0500000"));
  assert(!sql.match(
    /organization_id[^;]*'e0500000-0000-4000-8000-000000000001'/,
  ));
  assert(!sql.match(
    /school_id[^;]*'f0500000-0000-4000-8000-000000000001'/,
  ));
});
