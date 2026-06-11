import type { CopilotContextBundle } from "./copilot_context_engine.ts";
import { COPILOT_ASSISTANTS, type CopilotAssistantType } from "./copilot_types.ts";

const READ_ONLY_POLICY = `
You are Akshara ERP Copilot — a read-only operational assistant.
Rules:
- Never instruct the user to mutate data or claim you changed records.
- Only use provided ERP context; if data is missing say so.
- Respect RBAC: denied context sections must not be inferred.
- Prefer concise bullet summaries for operational questions.
`.trim();

const COMMUNICATION_ASSISTANT_POLICY = `
Communication assistant mode:
- Provide draft message text as guidance only — user must send via Communications module.
- Recommend audience (all_parents, all_teachers, class) and channel (sms, whatsapp, email).
- Reference delivery queue metrics when explaining reach or delays.
`.trim();

const PARENT_GUIDANCE_POLICY = `
Parent guidance mode:
- Help school staff communicate clearly and empathetically with parents.
- Use SIS and finance context only when granted — never invent balances or attendance.
- Output talking points and sample phrases, not automated sends.
`.trim();

export function buildSystemPrompt(
  assistantType: CopilotAssistantType,
  context: CopilotContextBundle,
): string {
  const assistant = COPILOT_ASSISTANTS.find((a) => a.type === assistantType)!;
  const extraPolicy = assistantType === "communication"
    ? COMMUNICATION_ASSISTANT_POLICY
    : assistantType === "parentGuidance"
    ? PARENT_GUIDANCE_POLICY
    : "";
  return [
    READ_ONLY_POLICY,
    extraPolicy,
    `Assistant: ${assistant.label}`,
    `Skills: ${assistant.skills.join(", ")}`,
    `School context: ${JSON.stringify(context.school)}`,
    `Academic year: ${JSON.stringify(context.academicYear)}`,
    `Finance context: ${JSON.stringify(context.finance)}`,
    `Admissions context: ${JSON.stringify(context.admissions)}`,
    `SIS context: ${JSON.stringify(context.sis)}`,
    `Communication context: ${JSON.stringify(context.communication)}`,
    `Timetable context: ${JSON.stringify(context.timetable)}`,
    `Analytics context: ${JSON.stringify(context.analytics)}`,
    `Student lookup: ${JSON.stringify(context.studentLookup)}`,
  ].join("\n");
}

export function buildStubAssistantReply(
  assistantType: CopilotAssistantType,
  userMessage: string,
  context: CopilotContextBundle,
): string {
  const intro = `**${assistantType.toUpperCase()} Assistant (read-only stub)**\n\n`;
  const question = userMessage.trim().slice(0, 200);
  const lines = [
    intro,
    `You asked: "${question}"`,
    "",
    "**School**",
    `- ${context.school.name} (${context.school.code})`,
    `- Academic year: ${context.academicYear.label}`,
    "",
  ];

  if (context.finance.access === "granted") {
    lines.push(
      "**Finance snapshot**",
      `- Completed collections: ${context.finance.completedCollections}`,
      `- Open AP commitments: ${context.finance.openApCommitments}`,
      "",
    );
  }
  if (context.admissions.access === "granted") {
    lines.push(
      "**Admissions snapshot**",
      `- Leads: ${context.admissions.leadCount}`,
      `- Applications: ${JSON.stringify(context.admissions.applicationsByStatus)}`,
      "",
    );
  }
  if (context.communication.access === "granted") {
    lines.push(
      "**Communication snapshot**",
      `- Templates: ${context.communication.templateCount ?? 0}`,
      `- Broadcasts sent: ${context.communication.broadcastCount ?? 0}`,
      `- Pending deliveries: ${context.communication.pendingDeliveries ?? 0}`,
      "",
    );
  }
  if (context.sis.access === "granted") {
    lines.push(
      "**SIS snapshot**",
      `- Students: ${context.sis.studentCount}`,
      `- Active enrollments: ${context.sis.activeEnrollments}`,
      `- Classes: ${context.sis.academicClasses}`,
      "",
    );
  }
  if (context.timetable.access === "granted") {
    lines.push(
      "**Timetable scheduling (read-only)**",
      `- Conflicts: ${context.timetable.conflictCount ?? 0}`,
      `- Overloaded teachers: ${context.timetable.overloadedTeachers ?? 0}`,
      `- Recommendations available: ${(context.timetable.recommendations as unknown[])?.length ?? 0}`,
      "",
    );
  }
  if (context.analytics.access === "granted") {
    const dashboard = context.analytics.dashboard as Record<string, number> | undefined;
    const health = context.analytics.health as Record<string, number> | undefined;
    lines.push(
      "**Analytics & Intelligence (read-only)**",
      `- Student risk score: ${dashboard?.studentRiskScore ?? "n/a"}`,
      `- School health score: ${health?.schoolHealthScore ?? "n/a"}`,
      `- Anomalies flagged: ${(context.analytics.anomalies as unknown[])?.length ?? 0}`,
      `- Use this context to explain risk, health, trends, and management briefings.`,
      "",
    );
  }

  lines.push(
    "_Configure OPENAI_API_KEY on the API function for live LLM responses. No mutations were performed._",
  );
  return lines.join("\n");
}
