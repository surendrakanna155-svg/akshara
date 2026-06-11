import { assertEquals } from "jsr:@std/assert@1";
import { COPILOT_ASSISTANTS, COPILOT_SUGGESTED_PROMPTS } from "./copilot_types.ts";

Deno.test("copilot assistants are read-only skill bundles", () => {
  assertEquals(COPILOT_ASSISTANTS.length, 5);
  for (const assistant of COPILOT_ASSISTANTS) {
    assertEquals(assistant.skills.includes("summarize"), true);
    assertEquals(COPILOT_SUGGESTED_PROMPTS[assistant.type].length >= 3, true);
  }
});

Deno.test("copilot router exposes session message route", async () => {
  const { matchCopilotRoute } = await import("./copilot_router.ts");
  const match = matchCopilotRoute(
    "POST",
    "/copilot/sessions/d0400000-0000-4000-8000-000000000001/messages",
  );
  assertEquals(match?.handler.name, "handleSendMessage");
});

Deno.test("stub copilot response is read-only", async () => {
  const { buildStubAssistantReply } = await import("./copilot_prompt_orchestrator.ts");
  const reply = buildStubAssistantReply("finance", "Summarize collections", {
    school: { schoolId: "s1", name: "Akshara", code: "AKS" },
    academicYear: { label: "2026-27", status: "active" },
    finance: { access: "granted", completedCollections: 3, collectedAmount: "1000" },
    admissions: { access: "denied" },
    sis: { access: "denied" },
    communication: { access: "denied" },
    timetable: { access: "denied" },
    analytics: { access: "denied" },
    studentLookup: { access: "not_requested" },
  });
  assertEquals(reply.includes("read-only"), true);
  assertEquals(reply.includes("No mutations"), true);
});

Deno.test("copilot RBAC requires runAiCopilot for messages", async () => {
  const handlerSource = await Deno.readTextFile(
    new URL("./copilot_handlers.ts", import.meta.url),
  );
  assertEquals(handlerSource.includes('requirePermission(claims, "runAiCopilot")'), true);
  assertEquals(handlerSource.includes('eventType: "aiCopilotQuery"'), true);
});
