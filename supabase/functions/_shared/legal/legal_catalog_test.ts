import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeOutstanding,
  LEGAL_POLICIES,
  requiredPolicyKeys,
} from "./legal_catalog.ts";
import { acceptedVersionsByKey } from "./legal_repository.ts";

Deno.test("parents must accept privacy + user terms", () => {
  assertEquals(requiredPolicyKeys("parent", "parent"), [
    "privacy",
    "user_terms",
  ]);
});

Deno.test("school staff accept privacy + acceptable use; admins also the institution agreement", () => {
  assertEquals(requiredPolicyKeys("school", "teacher"), [
    "privacy",
    "acceptable_use",
  ]);
  assertEquals(requiredPolicyKeys("school", "principal"), [
    "privacy",
    "acceptable_use",
    "institution_agreement",
  ]);
});

Deno.test("directors / org scope accept the institution agreement too", () => {
  assertEquals(requiredPolicyKeys("organization", "director"), [
    "privacy",
    "acceptable_use",
    "institution_agreement",
  ]);
});

Deno.test("students and platform operators are not gated", () => {
  assertEquals(requiredPolicyKeys("student", "student"), []);
  assertEquals(requiredPolicyKeys("platform", "superAdmin"), []);
});

Deno.test("a first-time user (no acceptances) has everything outstanding", () => {
  const required = requiredPolicyKeys("parent", "parent");
  const outstanding = computeOutstanding(required, new Map());
  assertEquals(outstanding.map((p) => p.key), ["privacy", "user_terms"]);
});

Deno.test("accepting the current versions clears outstanding", () => {
  const required = requiredPolicyKeys("parent", "parent");
  const accepted = new Map<string, Set<string>>([
    ["privacy", new Set([LEGAL_POLICIES.privacy.version])],
    ["user_terms", new Set([LEGAL_POLICIES.user_terms.version])],
  ]);
  assertEquals(computeOutstanding(required, accepted).length, 0);
});

Deno.test("an old accepted version still counts as outstanding (re-accept)", () => {
  const required = requiredPolicyKeys("parent", "parent");
  const accepted = new Map<string, Set<string>>([
    ["privacy", new Set(["1.0"])], // current is 2.0
    ["user_terms", new Set([LEGAL_POLICIES.user_terms.version])],
  ]);
  assertEquals(computeOutstanding(required, accepted).map((p) => p.key), [
    "privacy",
  ]);
});

Deno.test("acceptedVersionsByKey groups rows into a key→versions map", () => {
  const map = acceptedVersionsByKey([
    { policy_key: "privacy", policy_version: "1.0", accepted_at: "t" },
    { policy_key: "privacy", policy_version: "2.0", accepted_at: "t" },
    { policy_key: "user_terms", policy_version: "1.0", accepted_at: "t" },
  ]);
  assertEquals([...(map.get("privacy") ?? [])].sort(), ["1.0", "2.0"]);
  assertEquals([...(map.get("user_terms") ?? [])], ["1.0"]);
});
