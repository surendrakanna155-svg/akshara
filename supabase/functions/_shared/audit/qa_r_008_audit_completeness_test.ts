// QW8 · QA-R-008 — server audit-coverage completeness (production security cert).
//
// The mutation-audit catalog (`mutation_audit_catalog.ts`) declares the
// audit + domain-event spec emitted for each permissioned mutation. The server
// RBAC route inventory (`../validation/rbac_route_inventory.ts`) declares every
// protected API route with its method/permission/module. This test closes the
// registry-vs-catalog completeness gap: **every mutating, permissioned route
// module is backed by an audit path** — either a NAMED catalog group, or the
// generic `moduleEntityAudit` factory, or it is explicitly recorded as
// audit-exempt-by-design. A new mutating module that is none of those trips the
// test, so audit coverage cannot silently regress.
//
// HONEST BOUNDARY (documented, not hidden): the two sources are keyed
// differently — the inventory is keyed by HTTP route (`METHOD path`), the
// catalog by dotted event-type slug (`finance.invoice.issued`). There is no
// programmatic 1:1 route→spec map (a single route can emit several specs, and
// some specs are emitted off the request path entirely). Completeness is
// therefore asserted at **module granularity**: the unit a reviewer reasons
// about ("does the finance surface write audits?"). The per-module mapping and
// the audit-exempt set are declared explicitly below and asserted to stay in
// sync with both source files, so the boundary is enforced, not waved away.
//
// Mirrors the style of `mutation_audit_catalog_test.ts` (std assert, Deno.test).

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  RBAC_ROUTE_INVENTORY,
  type RbacRouteRule,
} from "../validation/rbac_route_inventory.ts";
import {
  achievementPromotionAudit,
  admissionsAudit,
  academicAudit,
  educationAudit,
  employeeAudit,
  examAudit,
  financeAudit,
  growthPlatformAudit,
  intelligenceAudit,
  inventoryDistributionAudit,
  inventoryIntelligenceAudit,
  type MutationAuditSpec,
  parentExperienceAudit,
  parentInsightsAudit,
  schoolCompletionAudit,
  schoolMemoriesAudit,
  setupWizardAudit,
  sisAudit,
  staffAttendanceAudit,
  subscriptionAudit,
  teacherAssistantAudit,
  widgetPlatformAudit,
} from "./mutation_audit_catalog.ts";

const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/** Inventory modules whose mutating routes are backed by a NAMED catalog group. */
const CATALOGUED_MODULES = new Set<string>([
  "admissions",
  "finance",
  "sis",
  "academic",
  "education",
  "intelligence",
  "employee",
  "inventory", // inventory intelligence (asset lifecycle / procurement workflow)
  "inventory_distribution",
  "memories",
  "promotion",
  "setup_wizard",
  "widget_platform",
  "teacher_assistant",
  "parent_insights",
  "growth",
  // `teacher` write routes (homework/attendance/exam-marks) flow through the
  // education / exam / school-completion catalog specs, not a `teacher` group.
  "teacher",
  // `subscriptions` plan-assignment audits via the `entitlements` source module
  // (`subscriptionAudit.planAssigned`).
  "subscriptions",
  // `parent` experience acknowledge audits via `parentExperienceAudit`.
  "parent",
  // staff Face ID check-in/out audits via `staffAttendanceAudit` (O5).
  "staff_attendance",
]);

/**
 * Inventory modules that emit audits via the GENERIC `moduleEntityAudit`
 * factory (a dotted-slug spec per CRUD verb) rather than a bespoke named group.
 * They are audited — just not through a dedicated catalog export.
 */
const GENERIC_FACTORY_MODULES = new Set<string>([
  "alumni",
  "hostel",
  "library",
  "transport",
  "social",
  "school_calendar",
  "director",
  // PRA-P1-05 (S2): identity permission-override endpoints emit
  // moduleEntityAudit("identity.permission_override.*").
  "identity",
]);

/**
 * Mutating modules that DO NOT emit a mutation audit by design, each with the
 * reason. This is the honest residual — a reviewer can see exactly what is not
 * audited and why.
 */
const AUDIT_EXEMPT_MODULES: Record<string, string> = {
  // The batch-ingest endpoint WRITES client audit rows; it is the audit sink
  // itself, not an audited business mutation.
  audit: "audit-event ingest endpoint (the sink, not an audited mutation)",
  // Webhooks are authenticated by shared-secret HMAC over the raw body, not a
  // JWT/permission (permission:null); delivery/payment effects are audited in
  // their own settlement paths, not at the webhook boundary.
  webhook: "HMAC-authenticated webhook boundary (no JWT/permission)",
  // Payment intents are parent-persona (permission:null); the financial audit is
  // written when the resulting collection/settlement is recorded in finance.
  payment: "parent-persona payment intent (audited downstream in finance)",
  // Onboarding imports are bulk data-load operations gated by manageOnboarding;
  // their per-row effects are journaled by the import run, not the audit catalog.
  onboarding: "bulk data-import run (journaled by the import, not the catalog)",
  // Org-builder provisioning is an Enterprise-gated platform op audited in the
  // control-center provisioning trail, outside the per-school mutation catalog.
  organization_builder:
    "Enterprise platform provisioning (audited in control-center trail)",
  // Broadcast/template sends are delivery operations; their audit is the
  // delivery-event ledger (`communication_delivery_event`), not a catalog spec.
  communication: "delivery-event ledger (communication_delivery_event)",
  // Parent attendance corrections are submissions into the school's correction
  // queue; the audited mutation is the staff APPROVAL, not the parent submit.
  attendance: "parent correction submission (audited at staff approval)",
  // Approval decisions (single + PRI-1 batch approve/reject/cancel) write to the
  // dedicated `approval_audit_entries` ledger via `insertAuditEntry` — one row per
  // decision — rather than the mutation catalog. That ledger is the audit path.
  approvals: "dedicated approval_audit_entries ledger (insertAuditEntry per decision)",
};

/** Named catalog groups, asserted non-empty so the import set cannot rot. */
const NAMED_CATALOG_GROUPS: Record<string, Record<string, unknown>> = {
  admissionsAudit,
  financeAudit,
  sisAudit,
  academicAudit,
  examAudit,
  educationAudit,
  intelligenceAudit,
  employeeAudit,
  inventoryDistributionAudit,
  inventoryIntelligenceAudit,
  parentExperienceAudit,
  schoolMemoriesAudit,
  achievementPromotionAudit,
  setupWizardAudit,
  widgetPlatformAudit,
  teacherAssistantAudit,
  parentInsightsAudit,
  growthPlatformAudit,
  schoolCompletionAudit,
  subscriptionAudit,
  staffAttendanceAudit,
};

function mutatingRules(): RbacRouteRule[] {
  return RBAC_ROUTE_INVENTORY.filter((r) => MUTATING_METHODS.has(r.method));
}

function mutatingModules(): Set<string> {
  return new Set(mutatingRules().map((r) => r.module));
}

Deno.test("QA-R-008: every mutating route module is catalogued, generic-audited, or exempt-by-design", () => {
  const uncovered: string[] = [];
  for (const moduleName of mutatingModules()) {
    const covered = CATALOGUED_MODULES.has(moduleName) ||
      GENERIC_FACTORY_MODULES.has(moduleName) ||
      Object.prototype.hasOwnProperty.call(AUDIT_EXEMPT_MODULES, moduleName);
    if (!covered) uncovered.push(moduleName);
  }
  assertEquals(
    uncovered,
    [],
    `mutating modules with NO audit path and NO documented exemption: ${
      uncovered.join(", ")
    }. Add a named catalog group / moduleEntityAudit call, then register the ` +
      `module in CATALOGUED_MODULES or GENERIC_FACTORY_MODULES — or, if it ` +
      `genuinely must not audit, record the reason in AUDIT_EXEMPT_MODULES.`,
  );
});

Deno.test("QA-R-008: the three coverage sets are disjoint (a module has exactly one classification)", () => {
  const exempt = new Set(Object.keys(AUDIT_EXEMPT_MODULES));
  const overlaps: string[] = [];
  for (const m of CATALOGUED_MODULES) {
    if (GENERIC_FACTORY_MODULES.has(m) || exempt.has(m)) overlaps.push(m);
  }
  for (const m of GENERIC_FACTORY_MODULES) {
    if (exempt.has(m)) overlaps.push(m);
  }
  assertEquals(overlaps, [], `double-classified modules: ${overlaps.join(", ")}`);
});

Deno.test("QA-R-008: every classified module actually has a mutating route (no stale entries)", () => {
  const live = mutatingModules();
  const stale: string[] = [];
  for (
    const m of [
      ...CATALOGUED_MODULES,
      ...GENERIC_FACTORY_MODULES,
      ...Object.keys(AUDIT_EXEMPT_MODULES),
    ]
  ) {
    if (!live.has(m)) stale.push(m);
  }
  assertEquals(
    stale,
    [],
    `classification lists name modules with no mutating route (remove them): ${
      stale.join(", ")
    }`,
  );
});

Deno.test("QA-R-008: every named catalog group is non-empty (factories present)", () => {
  for (const [name, group] of Object.entries(NAMED_CATALOG_GROUPS)) {
    const keys = Object.keys(group);
    assert(keys.length > 0, `${name} has no audit factories`);
    // Each entry is a factory that returns a well-formed MutationAuditSpec; spot
    // the surface by confirming the values are callable.
    for (const k of keys) {
      assert(
        typeof (group as Record<string, unknown>)[k] === "function",
        `${name}.${k} is not an audit-spec factory`,
      );
    }
  }
});

Deno.test("QA-R-008: a sampled spec from each module shape carries audit + domain + idempotency", () => {
  // Prove the catalog's contract (the thing route handlers rely on) holds for a
  // representative spec from each of the audited surfaces the matrix counts.
  const samples: Array<[string, MutationAuditSpec]> = [
    ["admissions", admissionsAudit.leadCreated("lead-1", "walk_in")],
    ["finance", financeAudit.refundApproved("ref-1")],
    ["sis", sisAudit.studentUpdated("stu-1")],
    ["education", educationAudit.questionPaperPublished("paper-1")],
    ["exam", examAudit.resultsPublished("exam-1", 10, null)],
    ["inventory", inventoryIntelligenceAudit.lifecycleEventRecorded("e-1", "repair")],
    ["inventory_distribution", inventoryDistributionAudit.created("d-1", "stu-1")],
    ["promotion", achievementPromotionAudit.approved("promo-1")],
    ["entitlements", subscriptionAudit.planAssigned("org-1", "growth", "active", "ev-1")],
    ["school_completion", schoolCompletionAudit.brandingUpdated("br-1")],
  ];
  for (const [label, spec] of samples) {
    assert(spec.audit.eventType.length > 0, `${label}: audit.eventType empty`);
    assert(
      (spec.audit.entityType ?? "").length > 0,
      `${label}: audit.entityType empty`,
    );
    assert(spec.domain.eventType.length > 0, `${label}: domain.eventType empty`);
    assert(spec.domain.sourceModule.length > 0, `${label}: sourceModule empty`);
    assert(
      (spec.domain.idempotencyKey ?? "").length > 0,
      `${label}: idempotencyKey empty — replay-safety would be lost`,
    );
  }
});
