// ASIP-8 — Continuous Learning: pure/DB-free unit tests. A tiny SQL-fragment
// mock db exercises the deterministic learn (upsert) and recall paths; no
// network, no pgvector, no model.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { SUPPORT_PLATFORM_ORG } from "./support_platform_repository.ts";
import {
  clusterFingerprint,
  CLUSTER_TITLE_MAX,
  clusterTitle,
  diagnosticsFromMirrorEvidence,
} from "./support_platform_service.ts";
import type { PlatformEvidenceRow, PlatformIncidentRow } from "./support_platform_repository.ts";
import type { KbArticleRow } from "./support_kb_repository.ts";
import {
  articleEmbedText,
  incidentQueryText,
  learnFromResolution,
  recallForIncident,
  toKbMatch,
} from "./support_kb_service.ts";

function mockDb(
  responders: Array<{ match: string; rows: unknown[] }>,
): { db: TenantQueryClient; calls: Array<{ sql: string; args: unknown[] }> } {
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  return {
    calls,
    db: {
      queryObject: <T>(sql: string, args: unknown[] = []): Promise<T[]> => {
        calls.push({ sql, args });
        const hit = responders.find((r) => sql.includes(r.match));
        return Promise.resolve((hit?.rows ?? []) as T[]);
      },
      queryCount: (_sql: string, _args: unknown[] = []): Promise<number> => Promise.resolve(0),
      // deno-lint-ignore no-explicit-any
    } as any as TenantQueryClient,
  };
}

const CLAIMS = { tenant_id: SUPPORT_PLATFORM_ORG, sub: "support-user" } as unknown as AccessTokenClaims;

function incident(over: Partial<PlatformIncidentRow> = {}): PlatformIncidentRow {
  return {
    id: "i1",
    source_org_id: "org1",
    source_school_id: "sch1",
    public_ref: "SUP-ABCD1234",
    title: "Cannot open marks",
    description: "tap Marks nothing happens",
    category: "permission_rbac",
    severity: "sev2",
    source_status: "new",
    module_key: "sis",
    screen_route: "/sis/marks",
    app_version: "1.4.0",
    platform: "android",
    support_status: "queue",
    assigned_to: null,
    escalated_at: null,
    cluster_id: "c1",
    first_seen_at: "t",
    mirrored_at: "t",
    updated_at: "t",
    ...over,
  };
}

function diagEvidence(): PlatformEvidenceRow[] {
  return [{
    id: "e1",
    incident_id: "i1",
    kind: "diagnostics",
    payload: { signals: ["recent 403 (permission/RBAC)"], apiErrorCount: 1, topErrorStatus: 403, topErrorPath: "/sis/marks", failingCorrelationId: "ak-1" },
    collected_at: "t",
  }];
}

function article(over: Partial<KbArticleRow> = {}): KbArticleRow {
  return {
    id: "a1",
    fingerprint: "permission_rbac|sis|403,/sis/marks",
    category: "permission_rbac",
    module_key: "sis",
    error_signature: "403,/sis/marks",
    title: "permission/rbac in sis (403,/sis/marks)",
    root_cause: "Permission/RBAC gap on /sis/marks",
    resolution: "granted the missing permission",
    source_incident_ref: "SUP-ABCD1234",
    source_cluster_id: "c1",
    resolved_count: 2,
    schools_seen: 3,
    status: "active",
    created_at: "t",
    updated_at: "t",
    ...over,
  };
}

Deno.test("articleEmbedText composes category/module/title/rootCause/resolution", () => {
  const t = articleEmbedText({ category: "permission_rbac", moduleKey: "sis", title: "T", rootCause: "RC", resolution: "R" });
  assert(t.includes("category: permission_rbac"));
  assert(t.includes("module: sis"));
  assert(t.includes("T") && t.includes("RC") && t.includes("R"));
});

Deno.test("incidentQueryText includes signals when present, omits module when null", () => {
  const diag = diagnosticsFromMirrorEvidence(diagEvidence());
  const t = incidentQueryText(incident({ module_key: null }), diag);
  assert(t.includes("category: permission_rbac"));
  assert(!t.includes("module:"), "no module line when module_key is null");
  assert(t.includes("signals:"));
});

Deno.test("toKbMatch maps a row to the console shape", () => {
  const m = toKbMatch(article(), "exact");
  assertEquals(m.matchType, "exact");
  assertEquals(m.id, "a1");
  assertEquals(m.resolvedCount, 2);
  assertEquals(m.schoolsSeen, 3);
  assertEquals(m.distance, null);
});

Deno.test("learnFromResolution: empty resolution learns nothing (no upsert)", async () => {
  const { db, calls } = mockDb([]);
  const res = await learnFromResolution(db, CLAIMS, {
    incident: incident(),
    evidence: diagEvidence(),
    resolution: "   ",
    clusterRootCause: "",
    schoolsSeen: 1,
  });
  assertEquals(res, null);
  assertEquals(calls.length, 0, "no DB write for an empty resolution");
});

Deno.test("learnFromResolution: keys the article by the incident's cluster fingerprint", async () => {
  const { db, calls } = mockDb([{ match: "INSERT INTO support_kb_article", rows: [article()] }]);
  const res = await learnFromResolution(db, CLAIMS, {
    incident: incident(),
    evidence: diagEvidence(),
    resolution: "granted the missing permission",
    clusterRootCause: "",
    schoolsSeen: 3,
  });
  assert(res !== null);
  const insert = calls.find((c) => c.sql.includes("INSERT INTO support_kb_article"));
  assert(insert, "upsert was issued");
  // args: [tenant, fingerprint, category, module, signature, title, rootCause, resolution, ref, cluster, schoolsSeen]
  const expectedFp = clusterFingerprint("permission_rbac", "sis", diagnosticsFromMirrorEvidence(diagEvidence()));
  assertEquals(insert!.args[1], expectedFp);
  assertEquals(insert!.args[2], "permission_rbac");
  assertEquals(insert!.args[7], "granted the missing permission");
  assertEquals(insert!.args[10], 3, "schoolsSeen carried through");
});

Deno.test("learnFromResolution: prefers the cluster root cause when provided", async () => {
  const { db, calls } = mockDb([{ match: "INSERT INTO support_kb_article", rows: [article()] }]);
  await learnFromResolution(db, CLAIMS, {
    incident: incident(),
    evidence: diagEvidence(),
    resolution: "fixed",
    clusterRootCause: "the shared RBAC seed was missing the grant",
    schoolsSeen: 2,
  });
  const insert = calls.find((c) => c.sql.includes("INSERT INTO support_kb_article"))!;
  assertEquals(insert.args[6], "the shared RBAC seed was missing the grant");
});

Deno.test("recallForIncident: exact fingerprint hit first, then related", async () => {
  const related = article({ id: "a2", fingerprint: "permission_rbac|sis|403", title: "related" });
  const { db } = mockDb([
    { match: "fingerprint = $2", rows: [article()] }, // exact
    { match: "fingerprint <> $4", rows: [related] }, // related
  ]);
  const matches = await recallForIncident(db, incident(), diagEvidence());
  assertEquals(matches.length, 2);
  assertEquals(matches[0].matchType, "exact");
  assertEquals(matches[0].id, "a1");
  assertEquals(matches[1].matchType, "related");
  assertEquals(matches[1].id, "a2");
});

Deno.test("recallForIncident: no exact hit → related only, capped at 3", async () => {
  const related = [
    article({ id: "r1" }),
    article({ id: "r2" }),
    article({ id: "r3" }),
    article({ id: "r4" }),
  ];
  const { db } = mockDb([
    { match: "fingerprint = $2", rows: [] }, // no exact
    { match: "fingerprint <> $4", rows: related },
  ]);
  const matches = await recallForIncident(db, incident(), diagEvidence());
  assertEquals(matches.length, 3);
  assert(matches.every((m) => m.matchType === "related"));
});

Deno.test("recallForIncident: empty KB → no matches, never throws", async () => {
  const { db } = mockDb([]);
  const matches = await recallForIncident(db, incident(), diagEvidence());
  assertEquals(matches.length, 0);
});

// ─── RC-2 (audit P1-A): an over-length title must not reach the DB ────────────
//
// `module_key` is client-supplied and length-bounded nowhere — not by a DB
// constraint, not by request validation. It flows into clusterTitle(), whose
// output is written to support_kb_article.title under
// CHECK (char_length(title) <= 400). Before the clamp, a long module_key made
// that INSERT violate the CHECK; because learning ran inside the resolve
// transaction, the exception rolled back propagateResolution() — the incident
// stayed open and the school was never told.

Deno.test("RC-2: clusterTitle clamps to the KB CHECK bound for any module_key", () => {
  const long = "m".repeat(5000);
  const title = clusterTitle("permission_rbac", long, diagnosticsFromMirrorEvidence(diagEvidence()));
  assertEquals(title.length, CLUSTER_TITLE_MAX);
  assert(title.length <= 400, "must satisfy support_kb_article_title_len_ck");
});

Deno.test("RC-2: learnFromResolution never emits a title over the CHECK bound", async () => {
  const { db, calls } = mockDb([
    { match: "INSERT INTO support_kb_article", rows: [{ id: "a1", title: "t" } as unknown as KbArticleRow] },
  ]);
  await learnFromResolution(db, CLAIMS, {
    incident: incident({ module_key: "x".repeat(5000) }),
    evidence: diagEvidence(),
    resolution: "granted the role",
    clusterRootCause: "",
    schoolsSeen: 1,
  });
  const insert = calls.find((c) => c.sql.includes("support_kb_article"));
  assert(insert, "expected a KB upsert");

  // Only `title` is bounded at 400 — root_cause (2000) and resolution (4000)
  // are legitimately longer, so assert on the title argument specifically.
  const expectedTitle = clusterTitle(
    "permission_rbac",
    "x".repeat(5000),
    diagnosticsFromMirrorEvidence(diagEvidence()),
  );
  assertEquals(expectedTitle.length, CLUSTER_TITLE_MAX);
  assert(
    insert!.args.some((a) => a === expectedTitle),
    "the clamped title must be the value bound into the upsert",
  );
});
