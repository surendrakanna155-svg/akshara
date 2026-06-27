import { assertEquals } from "jsr:@std/assert@1";
import { generateCopilotResponse } from "./copilot_llm_client.ts";
import type { CopilotContextBundle } from "./copilot_context_engine.ts";

const baseContext: CopilotContextBundle = {
  school: { schoolId: "s1", name: "Akshara", code: "AKS" },
  academicYear: { label: "2026-27", status: "active" },
  finance: { access: "granted", completedCollections: 3, collectedAmount: "1000" },
  admissions: { access: "denied" },
  sis: { access: "denied" },
  communication: { access: "denied" },
  timetable: { access: "denied" },
  teacherOps: { access: "denied" },
  analytics: { access: "denied" },
  studentLookup: { access: "not_requested" },
};

function baseInput(apiKey?: string | null) {
  return {
    systemPrompt: "read-only policy",
    history: [],
    userMessage: "Summarize collections",
    assistantType: "finance" as const,
    context: baseContext,
    apiKey,
  };
}

Deno.test("copilot response is the deterministic stub without an api key", async () => {
  const result = await generateCopilotResponse(baseInput(undefined));
  assertEquals(result.stub, true);
  assertEquals(result.model, "akshara-stub");
  assertEquals(result.content.includes("read-only"), true);
});

Deno.test("copilot response falls back to the stub when Claude transport throws", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    // Must not throw — a transport failure degrades to the deterministic stub
    // so the handler never returns 500 with a dangling user message.
    const result = await generateCopilotResponse(baseInput("sk-ant-test"));
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
    assertEquals(result.content.includes("read-only"), true);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("copilot response falls back to the stub on a non-OK Claude response", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(new Response("upstream error", { status: 503 }))) as typeof fetch;
  try {
    const result = await generateCopilotResponse(baseInput("sk-ant-test"));
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
  } finally {
    globalThis.fetch = original;
  }
});
