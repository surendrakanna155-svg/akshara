import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyPriorResolutions,
  buildEngineeringHandoff,
  clusterFingerprint,
  clusterTitle,
  isSettableSupportStatus,
  deterministicInvestigation,
  diagnosticsFromMirrorEvidence,
  errorSignature,
  type MirrorDiagnostics,
} from "./support_platform_service.ts";
import type {
  PlatformEvidenceRow,
  PlatformIncidentRow,
  PlatformNoteRow,
} from "./support_platform_repository.ts";
import type { KbMatch } from "./support_kb_service.ts";

function diag(over: Partial<MirrorDiagnostics> = {}): MirrorDiagnostics {
  return {
    signals: [],
    apiErrorCount: 0,
    topErrorStatus: null,
    topErrorPath: null,
    failingCorrelationId: null,
    ...over,
  };
}

function incident(over: Partial<PlatformIncidentRow> = {}): PlatformIncidentRow {
  return {
    id: "i1",
    source_org_id: "org1",
    source_school_id: "sch1",
    public_ref: "SUP-ABCD1234",
    title: "Cannot open marks",
    description: "nothing happens",
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
    cluster_id: null,
    first_seen_at: "t",
    mirrored_at: "t",
    updated_at: "t",
    ...over,
  };
}

Deno.test("errorSignature is a stable ordered signature of the failure signals", () => {
  const d = diag({ signals: ["recent 403 (permission/RBAC)", "recent 5xx (server error)"], topErrorPath: "/sis/marks" });
  assertEquals(errorSignature(d), "403,5xx,/sis/marks");
});

Deno.test("clusterFingerprint is identical for the same category+module+signature", () => {
  const d = diag({ signals: ["recent 403 (permission/RBAC)"], topErrorPath: "/sis/marks" });
  const a = clusterFingerprint("permission_rbac", "sis", d);
  const b = clusterFingerprint("permission_rbac", "sis", d);
  assertEquals(a, b);
  assertEquals(a, "permission_rbac|sis|403,/sis/marks");
});

Deno.test("clusterFingerprint differs when the module differs", () => {
  const d = diag({ signals: ["recent 403 (permission/RBAC)"] });
  assertEquals(
    clusterFingerprint("permission_rbac", "sis", d) ===
      clusterFingerprint("permission_rbac", "finance", d),
    false,
  );
});

Deno.test("clusterTitle is human-readable", () => {
  const d = diag({ signals: ["recent 403 (permission/RBAC)"] });
  assertEquals(clusterTitle("permission_rbac", "sis", d), "permission/rbac in sis (403)");
});

Deno.test("diagnosticsFromMirrorEvidence reads the diagnostics row", () => {
  const rows: PlatformEvidenceRow[] = [
    {
      id: "e1",
      incident_id: "i1",
      kind: "diagnostics",
      payload: { signals: ["recent 5xx (server error)"], apiErrorCount: 2, topErrorStatus: 500, topErrorPath: "/x", failingCorrelationId: "ak-1" },
      collected_at: "t",
    },
  ];
  const d = diagnosticsFromMirrorEvidence(rows);
  assertEquals(d.apiErrorCount, 2);
  assertEquals(d.topErrorStatus, 500);
  assertEquals(d.failingCorrelationId, "ak-1");
});

Deno.test("deterministicInvestigation maps a 403 to an RBAC root cause and scales confidence with cluster size", () => {
  const d = diag({ signals: ["recent 403 (permission/RBAC)"], apiErrorCount: 1, topErrorPath: "/sis/marks" });
  const single = deterministicInvestigation(incident(), d, 1);
  const many = deterministicInvestigation(incident(), d, 5);
  assertEquals(single.likelyRootCause.includes("Permission/RBAC"), true);
  assertEquals(single.summary.includes("a single school"), true);
  assertEquals(many.summary.includes("5 schools"), true);
  assertEquals(many.confidence > single.confidence, true); // cluster breadth raises confidence
});

Deno.test("buildEngineeringHandoff produces a complete deterministic package", () => {
  const evidence: PlatformEvidenceRow[] = [
    { id: "e1", incident_id: "i1", kind: "diagnostics", payload: { signals: ["recent 403 (permission/RBAC)"], apiErrorCount: 1, topErrorStatus: 403, topErrorPath: "/sis/marks", failingCorrelationId: "ak-1" }, collected_at: "t" },
    { id: "e2", incident_id: "i1", kind: "client_context", payload: { appVersion: "1.4.0" }, collected_at: "t" },
  ];
  const notes: PlatformNoteRow[] = [
    { id: "n1", incident_id: "i1", author_user_id: "u1", body: "checked the role grants", created_at: "t" },
  ];
  const h = buildEngineeringHandoff(incident({ cluster_id: "c1" }), evidence, notes, 3);
  assertEquals(h.incidentRef, "SUP-ABCD1234");
  assertEquals(h.environment.module, "sis");
  assertEquals(h.reproduction.failingCorrelationId, "ak-1");
  assertEquals(h.reproduction.topErrorStatus, 403);
  assertEquals(h.cluster?.affectedIncidents, 3);
  assertEquals(h.supportNotes.length, 1);
  assertEquals(Object.keys(h.evidence).sort(), ["client_context", "diagnostics"]);
});

// ─── ASIP-8: prior-resolution folding ──────────────────────────────────────────

function kbMatch(over: Partial<KbMatch> = {}): KbMatch {
  return {
    id: "a1",
    fingerprint: "permission_rbac|sis|403,/sis/marks",
    category: "permission_rbac",
    moduleKey: "sis",
    title: "permission/rbac in sis (403)",
    rootCause: "The role was missing the marks-view grant",
    resolution: "granted viewMarks to the class-teacher role",
    resolvedCount: 3,
    schoolsSeen: 5,
    matchType: "exact",
    distance: null,
    updatedAt: "t",
    ...over,
  };
}

Deno.test("applyPriorResolutions: an EXACT match leads with the proven fix and raises confidence to the floor", () => {
  const base = { summary: "s", likelyRootCause: "generic", recommendedFix: "reproduce it", confidence: 55 };
  const out = applyPriorResolutions(base, [kbMatch()]);
  assert(out.recommendedFix.startsWith("Known issue — previously resolved:"));
  assert(out.recommendedFix.includes("granted viewMarks"));
  assertEquals(out.likelyRootCause, "The role was missing the marks-view grant");
  assertEquals(out.confidence, 80, "confidence floor of 80 for a known signature");
});

Deno.test("applyPriorResolutions: a high base confidence is preserved (capped at 95), never lowered", () => {
  const base = { summary: "s", likelyRootCause: "rc", recommendedFix: "f", confidence: 92 };
  assertEquals(applyPriorResolutions(base, [kbMatch()]).confidence, 92);
  const hi = applyPriorResolutions({ ...base, confidence: 99 }, [kbMatch()]);
  assertEquals(hi.confidence, 95, "capped at 95");
});

Deno.test("applyPriorResolutions: related/semantic-only matches never override the base narrative", () => {
  const base = { summary: "s", likelyRootCause: "rc", recommendedFix: "f", confidence: 50 };
  const out = applyPriorResolutions(base, [kbMatch({ matchType: "related" }), kbMatch({ matchType: "semantic" })]);
  assertEquals(out.recommendedFix, "f");
  assertEquals(out.confidence, 50);
});

Deno.test("applyPriorResolutions: no matches → base unchanged", () => {
  const base = { summary: "s", likelyRootCause: "rc", recommendedFix: "f", confidence: 50 };
  assertEquals(applyPriorResolutions(base, []), base);
});

// ─── RC-3 (audit P1-B): resolution has exactly one path ──────────────────────
//
// `/support-status` writes only the mirror row. Resolving must additionally
// propagate to the school incident, notify the reporter and learn a KB article,
// all of which live in `/resolve`. While `resolved` was settable via
// `/support-status`, an agent picking it from the dropdown closed the console
// view while the school's incident stayed open and the reporter was never told.

Deno.test("RC-3: /support-status may set every workflow status EXCEPT resolved", () => {
  assert(isSettableSupportStatus("queue"));
  assert(isSettableSupportStatus("investigating"));
  assert(isSettableSupportStatus("awaiting_engineering"));
  assert(!isSettableSupportStatus("resolved"), "resolve must go through /resolve only");
});

Deno.test("RC-3: unknown statuses are still rejected", () => {
  assert(!isSettableSupportStatus(""));
  assert(!isSettableSupportStatus("closed"));
  assert(!isSettableSupportStatus("RESOLVED"), "must not be case-bypassable");
});
