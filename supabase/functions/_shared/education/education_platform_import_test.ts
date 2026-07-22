// Program D · M1.3 — platform importer tests. Drives the importer with the REAL golden export artifact
// (produced by the WP-A exporter on the M0.1 fixture) through an in-memory FakeDb that routes the exact SQL
// the importer issues — the established education repository-test pattern (no network, no real DB).

import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type ExportArtifact,
  importPlatformBatch,
  PlatformImportRefused,
  recomputeContentFp,
} from "./education_platform_import.ts";
import artifactJson from "./__tests__/fixtures/export_artifact.json" with { type: "json" };

const GOLDEN = artifactJson as unknown as ExportArtifact;

function clone(a: ExportArtifact): ExportArtifact {
  return JSON.parse(JSON.stringify(a)) as ExportArtifact;
}

/** In-memory platform bank routing the exact SQL importPlatformBatch issues. content_hash is always $1. */
class FakeDb {
  platform: Array<{ content_hash: string; status: string }> = [];
  inserts = 0;
  updates = 0;
  tombstones = 0;

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.startsWith("SELECT content_hash, status FROM edu_platform_question_bank")) {
      return Promise.resolve(this.platform.map((r) => ({ ...r })) as unknown as T[]);
    }
    if (s.startsWith("INSERT INTO edu_platform_question_bank")) {
      this.inserts++;
      this.platform.push({ content_hash: args[0], status: "active" });
      return Promise.resolve([] as T[]);
    }
    if (s.includes("status = 'tombstoned'")) {
      this.tombstones++;
      const row = this.platform.find((r) => r.content_hash === args[0] && r.status === "active");
      if (row) row.status = "tombstoned";
      return Promise.resolve([] as T[]);
    }
    if (s.startsWith("UPDATE edu_platform_question_bank SET")) {
      this.updates++;
      const row = this.platform.find((r) => r.content_hash === args[0]);
      if (row) row.status = "active"; // refresh reactivates
      return Promise.resolve([] as T[]);
    }
    throw new Error(`unrouted SQL: ${s}`);
  }

  active(): string[] {
    return this.platform.filter((r) => r.status === "active").map((r) => r.content_hash).sort();
  }
}

Deno.test("import: fresh artifact inserts every row as active", async () => {
  const db = new FakeDb();
  const res = await importPlatformBatch(db, GOLDEN);
  assertEquals(res.inserted, 12);
  assertEquals(res.updated, 0);
  assertEquals(res.tombstoned, 0);
  assertEquals(res.rowCount, 12);
  assertEquals(db.active().length, 12);
});

Deno.test("import: re-import is idempotent (no inserts, no tombstones)", async () => {
  const db = new FakeDb();
  await importPlatformBatch(db, GOLDEN);
  const again = await importPlatformBatch(db, GOLDEN);
  assertEquals(again.inserted, 0);
  assertEquals(again.tombstoned, 0);
  assertEquals(again.updated, 12); // existing rows re-asserted to identical content
  assertEquals(db.active().length, 12);
});

Deno.test("import: recall propagates — an item absent from the full-sync artifact is tombstoned", async () => {
  const db = new FakeDb();
  await importPlatformBatch(db, GOLDEN);
  // Re-export drops one certified item; build a VALID reduced artifact (recompute the freeze fingerprint).
  const reduced = clone(GOLDEN);
  const dropped = reduced.rows[reduced.rows.length - 1].content_hash;
  reduced.rows = reduced.rows.slice(0, reduced.rows.length - 1);
  reduced.manifest.row_count = reduced.rows.length;
  reduced.manifest.content_fp = await recomputeContentFp(reduced.rows);

  const res = await importPlatformBatch(db, reduced);
  assertEquals(res.tombstoned, 1);
  assertEquals(res.inserted, 0);
  assertEquals(db.active().length, 11);
  assert(!db.active().includes(dropped), "dropped item must no longer be active");
});

Deno.test("import: manifest content_fp mismatch is refused fail-closed (no writes)", async () => {
  const db = new FakeDb();
  const tampered = clone(GOLDEN);
  tampered.rows[0].content_hash = "IH_tampered_value"; // changes real fp; manifest.content_fp now stale
  await assertRejects(() => importPlatformBatch(db, tampered), PlatformImportRefused);
  assertEquals(db.platform.length, 0); // fail-closed BEFORE any write
});

Deno.test("import: row_count mismatch is refused", async () => {
  const db = new FakeDb();
  const bad = clone(GOLDEN);
  bad.manifest.row_count = 999;
  await assertRejects(() => importPlatformBatch(db, bad), PlatformImportRefused);
  assertEquals(db.platform.length, 0);
});

Deno.test("import: a malformed row is refused before any write (no partial write)", async () => {
  const db = new FakeDb();
  const bad = clone(GOLDEN);
  bad.rows[3].marks = 0; // content_hash unchanged ⇒ fingerprint still passes ⇒ reaches row validation
  await assertRejects(() => importPlatformBatch(db, bad), PlatformImportRefused);
  assertEquals(db.platform.length, 0);
});

Deno.test("import: a duplicate content_hash in the artifact is refused", async () => {
  const db = new FakeDb();
  const dup = clone(GOLDEN);
  dup.rows = [dup.rows[0], { ...dup.rows[1], content_hash: dup.rows[0].content_hash }];
  dup.manifest.row_count = 2;
  dup.manifest.content_fp = await recomputeContentFp(dup.rows);
  await assertRejects(() => importPlatformBatch(db, dup), PlatformImportRefused);
  assertEquals(db.platform.length, 0);
});
