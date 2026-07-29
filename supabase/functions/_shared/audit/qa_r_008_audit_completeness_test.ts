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
  attendanceAudit,
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
  // `teacher` write routes audit without a `teacher` catalog group: the exam-marks
  // route uses the `exam` specs, homework/leave use the education / school-completion
  // specs, and the two attendance-marking routes (POST /teacher/attendance/draft
  // and /submit, owned by `pilot/pilot_operations_handlers.ts`) emit an ad-hoc
  // `attendanceDraftSaved` / `attendanceSubmitted` spec built inline by that
  // module's `auditMobileWrite` helper. All are audited; only the last is not
  // catalogued — recorded here so the wording matches the code.
  "teacher",
  // Student-attendance CORRECTIONS (`attendanceAudit`): the parent submit, the
  // staff submit, and the direct staff decision route each emit a spec — see the
  // note on AUDIT_EXEMPT_MODULES below for the exemption this replaced.
  "attendance",
  // `subscriptions` plan-assignment audits via the `entitlements` source module
  // (`subscriptionAudit.planAssigned`).
  "subscriptions",
  // `parent` experience acknowledge audits via `parentExperienceAudit`.
  "parent",
  // staff Face ID check-in/out audits via `staffAttendanceAudit` (O5).
  "staff_attendance",

  // ─── API-100: modules this test could not previously SEE ────────────────
  // The inventory it reads is now derived from the dispatcher rather than
  // hand-maintained, so 13 modules with mutating routes appeared that were
  // simply absent from the old 315-rule list. Their classifications below are
  // evidence-based — each was checked for an actual audit emission — not
  // assumed. That the gate had been green while blind to them is the point of
  // API-100.
  //
  // `academics/exam_administration/exam_administration_handlers.ts` emits
  // `examAudit.{markUpdated,markGraceApplied,marksReminderSent,resultsPublished}`.
  "exam_administration",
  // `school_completion/*_handlers.ts` emit `schoolCompletionAudit.*` (branding,
  // class-subject assignment, timetable workforce) via emitMutationAudit.
  "school_completion",
  // `attendance_auth/face_enrollment_handlers.ts` emits
  // `attendanceAuthAudit.{faceEnrolled,faceRevoked}` through recordMutationAudit,
  // in the same transaction as the enrolment write.
  "attendance_auth",
  // `parent_experience/*` acknowledgements emit `parentExperienceAudit` — the
  // same group the pre-existing `parent` entry already names.
  "parent_experience",
  // `pilot/pilot_operations_handlers.ts` — the mobile task paths under
  // /teacher, /student, /parent and /homework. Same ad-hoc `auditMobileWrite`
  // + `moduleEntityAudit("parent.leave.attachment.added")` pattern the
  // pre-existing `teacher` entry documents; the registry names the module
  // `pilot_operations`, so it needs its own entry.
  "pilot_operations",
]);

/**
 * Inventory modules that emit audits WITHOUT a bespoke named catalog group —
 * either through the generic `moduleEntityAudit` factory (a dotted-slug spec per
 * CRUD verb) or, for `copilot`, through a direct `recordServerAuditEvent` write.
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
  // PRC-A Batch 2 — all three emit via moduleEntityAudit()/emitMutationAudit
  // inside the same transaction as the write they record.
  "certificate_desk",
  "gate_pass",
  "complaints",
  // PRC-A Batch 3 — the /ai-wallet/grant mutation audits via moduleEntityAudit
  // ("aiWallet.credit_granted") inside the same tenant transaction as the insert.
  "aiWallet",

  // ─── API-100: modules the derived inventory surfaced ────────────────────
  // `control_center/control_center_write_handlers.ts` →
  // moduleEntityAudit("control_center.{lead,school}.created") + emitMutationAudit.
  "control_center",
  // `hr/{hr_write,leave_accrual,statutory_payroll}_handlers.ts` →
  // moduleEntityAudit("hr.employee.access_revoked" …) + emitMutationAudit.
  "hr",
  // `management/management_write_handlers.ts` → emitMutationAudit +
  // moduleEntityAudit.
  "management",
  // `legal/legal_handlers.ts` → emitMutationAudit on the acceptance write.
  "legal",
  // `timetable/timetable_handlers.ts` → emitMutationAudit on publish/generate/
  // period moves.
  "timetable",
  // `copilot/copilot_handlers.ts` → `recordServerAuditEvent` on every session
  // and message write (five call sites). Not the mutation catalog, but a real
  // server-side audit row per mutation — recorded here rather than exempted, so
  // the wording matches the code.
  "copilot",
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
  // ── WITHDRAWN EXEMPTION (P1 fix) ────────────────────────────────────────────
  // `attendance` used to sit here as:
  //     "parent correction submission (audited at staff approval)"
  // That premise was FALSE, and a green test asserting it turned an open
  // question into a settled one. Two things were wrong:
  //   1. The staff decision route (PATCH /attendance/corrections/:id/status,
  //      gated on approveAttendanceCorrection) wrote NO audit row either — so
  //      the approval the exemption deferred to did not exist on that path. The
  //      only decision path that did audit was the separate approvals workflow,
  //      which writes to `approval_audit_entries`.
  //   2. Even a real deferral would lose the submission itself: a request that
  //      is never decided, or is rejected, leaves no trace of who asked or when.
  // Both submits AND the direct decision route now emit `attendanceAudit` specs
  // in the same transaction as the write, so `attendance` is CATALOGUED above.
  // Approval decisions (single + PRI-1 batch approve/reject/cancel) write to the
  // dedicated `approval_audit_entries` ledger via `insertAuditEntry` — one row per
  // decision — rather than the mutation catalog. That ledger is the audit path.
  approvals: "dedicated approval_audit_entries ledger (insertAuditEntry per decision)",
  // API-100: the ROUTE-REGISTRY name for the same router is `approval` (singular);
  // the derived inventory keys on that, so the exemption needs both spellings
  // until the two vocabularies are reconciled.
  approval: "dedicated approval_audit_entries ledger (insertAuditEntry per decision)",
  // API-100: every stock write in `inventory_finance/inventory_stock_repository.ts`
  // inserts exactly one immutable `stock_movements` row (qty_before → qty_after)
  // in the same statement as the movement. That ledger is STRONGER than the
  // mutation catalog for this surface — it records the numeric before/after the
  // catalog would only summarise — so it is the audit path, by design.
  inventory_finance:
    "immutable stock_movements ledger, one row per write with qty_before → qty_after",
  // PRC-A Batch 2 / owner decision #1. Health deliberately does NOT use the
  // mutation catalog: it has a dedicated immutable `student_health_access_log`
  // (SELECT/INSERT grant only) written in the SAME transaction as the event it
  // records. That is strictly STRONGER than the mutation catalog here, because
  // the owner requirement is to audit sensitive READS too ("who looked at this
  // child's health data") — which a mutation-only catalog cannot express.
  student_health:
    "dedicated immutable student_health_access_log (audits sensitive READS as well as writes)",
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
  attendanceAudit,
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

// ── the withdrawn attendance exemption ───────────────────────────────────────
//
// Pins the correction of a false premise, so it cannot quietly come back: the
// `attendance` module claimed exemption on the grounds that "the audited
// mutation is the staff APPROVAL, not the parent submit". The direct staff
// decision route audited nothing, so there was no approval audit to defer to.
Deno.test("QA-R-008: `attendance` is catalogued, not exempt — the submit and the decision are BOTH audited", () => {
  assertEquals(
    Object.prototype.hasOwnProperty.call(AUDIT_EXEMPT_MODULES, "attendance"),
    false,
    "attendance must not claim an audit exemption: its correction routes emit audits",
  );
  assert(
    CATALOGUED_MODULES.has("attendance"),
    "attendance must be classified as catalogued (attendanceAudit)",
  );

  // The SUBMIT is audited in its own right — not deferred to a later decision.
  const requested = attendanceAudit.correctionRequested("att_corr_p_1", {
    sisStudentId: "sis-7",
    studentId: "1e5f0b6a-0000-4000-8000-000000000001",
    dateLabel: "2026-07-21",
    markChange: { from: "absent", to: "present" },
    reason: "was in the medical room",
    requesterId: "parent-1",
    requesterRole: "parent",
    source: "POST /parent/attendance/corrections",
  });
  assertEquals(requested.audit.entityType, "attendance_correction");
  assertEquals(requested.audit.metadata?.before, { mark: "absent" });
  assertEquals(requested.audit.metadata?.after, { mark: "present" });
  assertEquals(requested.audit.metadata?.source, "POST /parent/attendance/corrections");

  // The DECISION is audited too, with the real status transition.
  const decided = attendanceAudit.correctionDecided("att_corr_p_1", {
    sisStudentId: "sis-7",
    studentId: "1e5f0b6a-0000-4000-8000-000000000001",
    dateLabel: "2026-07-21",
    before: { status: "pending" },
    after: { status: "rejected" },
    markChange: { from: "absent", to: "present" },
    requestReason: "was in the medical room",
    requesterId: "parent-1",
    requesterRole: "parent",
    source: "PATCH /attendance/corrections/:id/status",
    nonce: "2026-07-21T09:00:00.000Z",
  });
  assertEquals(decided.audit.metadata?.before, { status: "pending" });
  assertEquals(decided.audit.metadata?.after, { status: "rejected" });
  assertEquals(decided.domain.eventType, "attendance.correction.decided");
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
    [
      "attendance",
      attendanceAudit.correctionRequested("att_corr_1", {
        sisStudentId: "sis-1",
        studentId: null,
        dateLabel: "2026-07-21",
        markChange: { from: "absent", to: "present" },
        reason: "was in the medical room",
        requesterId: "user-1",
        requesterRole: "parent",
        source: "POST /parent/attendance/corrections",
      }),
    ],
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
