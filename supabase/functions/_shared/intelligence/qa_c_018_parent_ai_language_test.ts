// QW7 · QA-C-018 — Parent-FACING AI responds in the parent's language.
//
// Owner architecture (2026-06-30): LLM/AI *features* (Parent Guidance / Copilot /
// the communication draft generator) may produce output in the parent's language
// natively — that is NOT a translation pipeline (which is forbidden for comms).
// This certifies the EXISTING parent-AI language behaviour: the parent's
// preferred language is prioritised for parent-facing AI, and English is the
// default when there is no parent preference (so non-parent AI stays English).
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  generateCommunicationDrafts,
  resolveCommunicationLanguages,
} from "./communication_generator.ts";

Deno.test("QA-C-018: a parent's preferred language is prioritised for parent-facing AI", () => {
  const langs = resolveCommunicationLanguages(["english"], "telugu");
  assertEquals(langs[0], "telugu", "parent's language comes first");
  assertEquals(langs.includes("english"), true);
});

Deno.test("QA-C-018: no parent preference → English default (non-parent AI stays English)", () => {
  assertEquals(resolveCommunicationLanguages(["english"], undefined), ["english"]);
  assertEquals(resolveCommunicationLanguages([], undefined), ["english"]);
  // an explicit English preference is not reprioritised
  assertEquals(resolveCommunicationLanguages(["english"], "english"), ["english"]);
});

Deno.test("QA-C-018: parent-facing AI draft is generated in the parent's language (native, not translated)", () => {
  const drafts = generateCommunicationDrafts({
    scenario: "absent",
    studentName: "Asha",
    className: "5A",
    languages: ["english"],
    parentPreferredLanguage: "telugu",
  });
  assertEquals(drafts.length > 0, true);
  assertEquals(drafts[0].language, "telugu", "first draft is in the parent's language");
  // The Telugu draft carries the Telugu script marker (non-English output).
  assertEquals(drafts[0].parentFriendly.includes("[తెలుగు]"), true);
});
