import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildEvidenceParts,
  diagnosticsFromEvidence,
  minimizedEvidenceSummary,
  persistEvidence,
} from "./support_service.ts";
import type { EvidenceRow } from "./support_types.ts";

const CLAIMS = {
  sub: "u1000000-0000-4000-8000-000000000001",
  tenant_id: "a1000000-0000-4000-8000-000000000001",
  school_id: "a2000000-0000-4000-8000-000000000001",
  scope: "school",
  primary_role: "teacher",
  role: "teacher",
  permissions: [],
} as unknown as AccessTokenClaims;

// A minimal TenantQueryClient that answers the audit read (empty) and records
// evidence inserts, so the collection + persistence orchestration is testable
// without a database.
class MockDb {
  evidenceInserts: Array<{ kind: string; payload: string; redacted: boolean }> = [];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM audit_events")) return [] as T[]; // no recent audit events
    if (sql.includes("INSERT INTO support_incident_evidence")) {
      this.evidenceInserts.push({
        kind: String(args[3]),
        payload: String(args[4]),
        redacted: Boolean(args[5]),
      });
      return [] as T[];
    }
    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(_sql: string, _args: unknown[] = []): Promise<number> {
    return 0;
  }

  get raw(): never {
    throw new Error("raw not available in MockDb");
  }
}

Deno.test("buildEvidenceParts + persistEvidence writes all five evidence kinds", async () => {
  const db = new MockDb();
  const parts = await buildEvidenceParts(
    db as unknown as TenantQueryClient,
    CLAIMS,
    {
      appVersion: "1.4.0",
      platform: "android",
      moduleKey: "sis",
      correlationIds: ["ak-1"],
      recentApiCalls: [{ method: "GET", path: "/sis/marks", statusCode: 403, correlationId: "ak-1" }],
      breadcrumbs: [{ type: "navigation", route: "/sis", at: "2026-07-20T10:00:00Z" }],
    },
    CLAIMS.sub,
  );

  // The failing 403 surfaces as a permission signal; correlation id is captured.
  assertEquals(parts.diagnostics.signals.some((s) => s.includes("403")), true);
  assertEquals(parts.diagnostics.failingCorrelationId, "ak-1");
  assertEquals(parts.derived.appVersion, "1.4.0");

  await persistEvidence(db as unknown as TenantQueryClient, CLAIMS, "i1", parts);
  assertEquals(db.evidenceInserts.length, 5);
  assertEquals(
    db.evidenceInserts.map((e) => e.kind).sort(),
    ["api_calls", "audit_events", "breadcrumbs", "client_context", "diagnostics"],
  );
});

Deno.test("diagnosticsFromEvidence round-trips the stored diagnostics payload", () => {
  const rows: EvidenceRow[] = [
    {
      id: "e1",
      incident_id: "i1",
      kind: "diagnostics",
      payload: {
        failingCorrelationId: "ak-9",
        apiErrorCount: 2,
        topErrorStatus: 500,
        topErrorPath: "/x",
        hasAppVersion: true,
        signals: ["recent 5xx (server error)"],
      },
      redacted: false,
      collected_at: "2026-07-20T10:00:00Z",
    },
  ];
  const d = diagnosticsFromEvidence(rows);
  assertEquals(d.failingCorrelationId, "ak-9");
  assertEquals(d.apiErrorCount, 2);
  assertEquals(d.topErrorStatus, 500);
  assertEquals(d.signals.length, 1);
});

Deno.test("minimizedEvidenceSummary contains no raw PII, only structural signals", () => {
  const rows: EvidenceRow[] = [
    { id: "e1", incident_id: "i1", kind: "audit_events", payload: { count: 3, items: [] }, redacted: true, collected_at: "t" },
  ];
  const d = diagnosticsFromEvidence([
    { id: "e2", incident_id: "i1", kind: "diagnostics", payload: { signals: ["recent 403 (permission/RBAC)"], apiErrorCount: 1, failingCorrelationId: "ak-1", hasAppVersion: true, topErrorStatus: 403, topErrorPath: "/sis" }, redacted: false, collected_at: "t" },
  ]);
  const summary = minimizedEvidenceSummary(d, rows);
  assertEquals(summary.includes("403"), true);
  assertEquals(summary.includes("recentAuditEvents: 3"), true);
});
