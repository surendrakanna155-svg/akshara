import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import { applyDonationToCampaign } from "./alumni_write_handlers.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";

function schoolClaims(): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageAlumni"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

Deno.test("applyDonationToCampaign advances raised amount and donor count", () => {
  const campaign = {
    id: "camp_1",
    name: "Library Fund 2026",
    goalAmount: "₹10L",
    raisedAmount: "₹6.2L",
    donorCount: 48,
    status: "active",
  };
  const next = applyDonationToCampaign(campaign, "₹50,000");
  // 6.2L (620000) + 50000 = 670000 -> "₹6.7L"
  assertEquals(next.raisedAmount, "₹6.7L");
  assertEquals(next.donorCount, 49);
  // Other fields are preserved.
  assertEquals(next.name, "Library Fund 2026");
  assertEquals(next.goalAmount, "₹10L");
  // Source payload is not mutated.
  assertEquals(campaign.raisedAmount, "₹6.2L");
  assertEquals(campaign.donorCount, 48);
});

Deno.test("applyDonationToCampaign handles a zero-raised campaign with raw rupees", () => {
  const campaign = {
    id: "camp_2",
    name: "Robotics Lab Fund",
    raisedAmount: "₹0",
    donorCount: 0,
  };
  const next = applyDonationToCampaign(campaign, "1500");
  assertEquals(next.raisedAmount, "₹1,500");
  assertEquals(next.donorCount, 1);
});

Deno.test("applyDonationToCampaign defaults a missing donorCount to zero", () => {
  const campaign = { id: "camp_3", raisedAmount: "₹10,000" };
  const next = applyDonationToCampaign(campaign, "₹5,000");
  assertEquals(next.raisedAmount, "₹15,000");
  assertEquals(next.donorCount, 1);
});

Deno.test("manageAlumni required for donation write middleware", () => {
  const claims = { ...schoolClaims(), permissions: ["viewAlumni"] };
  const denied = requirePermission(claims, "manageAlumni") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("school staff with manageAlumni passes donation write middleware", () => {
  const denied = requirePermission(schoolClaims(), "manageAlumni") ??
    requireSchoolOperationalScope(schoolClaims());
  assertEquals(denied, null);
});
