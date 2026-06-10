import { assertEquals } from "jsr:@std/assert@1";
import { parseCsvText } from "./onboarding_repository.ts";

Deno.test("parseCsvText maps headers to row objects", () => {
  const rows = parseCsvText(
    "studentName,admissionNumber,classLabel\nRavi,ADM-1,8-A\n",
  );
  assertEquals(rows.length, 1);
  assertEquals(rows[0]?.studentName, "Ravi");
  assertEquals(rows[0]?.admissionNumber, "ADM-1");
});

Deno.test("buildWhatsAppInviteLink encodes message", async () => {
  const { buildWhatsAppInviteLink } = await import("./onboarding_repository.ts");
  const link = buildWhatsAppInviteLink("https://app.test/i/abc", "Parent A");
  assertEquals(link.includes("wa.me"), true);
  assertEquals(link.includes("Parent"), true);
});
