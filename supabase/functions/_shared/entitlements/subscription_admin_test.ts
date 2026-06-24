import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  defaultStatusForPlan,
  parseAssignmentBody,
} from "./subscription_assignment.ts";
import { requirePermission } from "../permission_middleware.ts";
import { subscriptionAudit } from "../audit/mutation_audit_catalog.ts";
import type { AccessTokenClaims } from "../jwt.ts";

// ─── Body parsing / validation ───────────────────────────────────────────────
Deno.test("parseAssignmentBody accepts a valid plan and defaults status", () => {
  assertEquals(parseAssignmentBody({ planSlug: "professional" }),
    { planSlug: "professional", status: "active" });
  assertEquals(parseAssignmentBody({ planSlug: "trial" }),
    { planSlug: "trial", status: "trial" });
});

Deno.test("parseAssignmentBody honours an explicit valid status", () => {
  assertEquals(parseAssignmentBody({ planSlug: "standard", status: "suspended" }),
    { planSlug: "standard", status: "suspended" });
});

Deno.test("parseAssignmentBody accepts snake_case plan_slug", () => {
  assertEquals(parseAssignmentBody({ plan_slug: "enterprise" }),
    { planSlug: "enterprise", status: "active" });
});

Deno.test("parseAssignmentBody rejects unknown plan / status / empty", () => {
  assertEquals(parseAssignmentBody({ planSlug: "platinum" }), null);
  assertEquals(parseAssignmentBody({ planSlug: "standard", status: "bogus" }), null);
  assertEquals(parseAssignmentBody({}), null);
  assertEquals(parseAssignmentBody(null), null);
});

Deno.test("defaultStatusForPlan: trial→trial, others→active", () => {
  assertEquals(defaultStatusForPlan("trial"), "trial");
  assertEquals(defaultStatusForPlan("enterprise"), "active");
});

// ─── RBAC gate ───────────────────────────────────────────────────────────────
const superAdmin: AccessTokenClaims = {
  sub: "u-super",
  tenant_id: "org-1",
  organization_id: "org-1",
  school_id: null,
  role: "superAdmin",
  role_slugs: ["superAdmin"],
  primary_role: "superAdmin",
  permissions: ["managePlatformSubscriptions", "viewSubscription"],
  permissions_version: 1,
  scope: "platform",
  school_group_id: null,
  student_id: null,
  child_ids: [],
  session_id: "s1",
};

Deno.test("RBAC: superAdmin with managePlatformSubscriptions passes", () => {
  assertEquals(requirePermission(superAdmin, "managePlatformSubscriptions"), null);
});

Deno.test("RBAC: schoolAdmin without the slug is denied 403", () => {
  const schoolAdmin: AccessTokenClaims = {
    ...superAdmin,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewSubscription", "manageSchoolSetup"],
    scope: "school",
    school_id: "school-1",
  };
  const res = requirePermission(schoolAdmin, "managePlatformSubscriptions");
  assertEquals(res?.status, 403);
});

// ─── Audit spec ──────────────────────────────────────────────────────────────
Deno.test("subscriptionAudit.planAssigned emits the right event + payload", () => {
  const spec = subscriptionAudit.planAssigned("org-9", "professional", "active", "evt-1");
  assertEquals(spec.domain.eventType, "subscription.plan.assigned");
  assertEquals(spec.domain.sourceModule, "entitlements");
  assertEquals(spec.domain.payload, {
    organizationId: "org-9",
    planSlug: "professional",
    status: "active",
  });
  assertEquals(spec.audit.entityType, "organization_subscription");
  assertEquals(spec.audit.entityId, "org-9");
});

Deno.test("subscriptionAudit.planAssigned key is unique per event (every change audits)", () => {
  const a = subscriptionAudit.planAssigned("org-9", "standard", "active", "evt-1");
  const b = subscriptionAudit.planAssigned("org-9", "standard", "active", "evt-2");
  assertNotEquals(a.domain.idempotencyKey, b.domain.idempotencyKey);
});
