import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  generateCommunicationDrafts,
  resolveCommunicationLanguages,
  rewriteCustomNote,
} from "./communication_generator.ts";

Deno.test("generateCommunicationDrafts produces multilingual channel drafts", () => {
  const drafts = generateCommunicationDrafts({
    scenario: "absent",
    studentName: "Ravi",
    className: "Grade 8A",
    languages: ["english", "telugu"],
  });
  assertEquals(drafts.length, 2);
  assertEquals(drafts[0]!.channels.sms.length <= 160, true);
  assertEquals(drafts[1]!.language, "telugu");
});

Deno.test("rewriteCustomNote capitalizes and punctuates", () => {
  assertEquals(rewriteCustomNote("parent asked about homework"), "Parent asked about homework.");
});

Deno.test("resolveCommunicationLanguages prioritizes parent preference", () => {
  const langs = resolveCommunicationLanguages(["english"], "telugu");
  assertEquals(langs[0], "telugu");
});

Deno.test("fee reminder enriches with amount and due date", () => {
  const drafts = generateCommunicationDrafts({
    scenario: "fee_reminder",
    studentName: "Ravi",
    className: "Grade 8",
    languages: ["english"],
    context: { feeAmount: "5000", dueDate: "15 Jun" },
  });
  assertEquals(drafts[0]!.professional.includes("₹5000"), true);
  assertEquals(drafts[0]!.professional.includes("15 Jun"), true);
});
