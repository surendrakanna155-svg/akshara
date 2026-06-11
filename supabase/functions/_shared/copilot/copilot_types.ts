export type CopilotAssistantType =
  | "admissions"
  | "finance"
  | "sis"
  | "academic"
  | "communication"
  | "parentGuidance";

export const COPILOT_ASSISTANT_TYPES: CopilotAssistantType[] = [
  "admissions",
  "finance",
  "sis",
  "academic",
  "communication",
  "parentGuidance",
];

export interface CopilotAssistantDefinition {
  type: CopilotAssistantType;
  label: string;
  description: string;
  requiredViewPermission: string;
  skills: string[];
}

export const COPILOT_ASSISTANTS: CopilotAssistantDefinition[] = [
  {
    type: "admissions",
    label: "Admissions Assistant",
    description: "Summarize funnel metrics, explain stages, and answer admissions operations questions.",
    requiredViewPermission: "viewAdmissions",
    skills: ["summarize", "explain", "search", "report", "operational_qa"],
  },
  {
    type: "finance",
    label: "Finance Assistant",
    description: "Explain collections, defaulters, fee structures, and inventory-finance reconciliation.",
    requiredViewPermission: "viewFinance",
    skills: ["summarize", "explain", "search", "report", "operational_qa"],
  },
  {
    type: "sis",
    label: "SIS Assistant",
    description: "Student registry insights, enrollment status, and academic assignment context.",
    requiredViewPermission: "viewSis",
    skills: ["summarize", "explain", "search", "report", "operational_qa"],
  },
  {
    type: "academic",
    label: "Academic Assistant",
    description: "Academic years, classes, sections, and teacher assignment catalog guidance.",
    requiredViewPermission: "viewSis",
    skills: ["summarize", "explain", "search", "report", "operational_qa"],
  },
  {
    type: "communication",
    label: "AI Communication Assistant",
    description: "Draft broadcast guidance, fee reminders, delivery metrics, and channel strategy (read-only).",
    requiredViewPermission: "viewCommunications",
    skills: ["summarize", "explain", "draft_guidance", "channel_advice", "operational_qa"],
  },
  {
    type: "parentGuidance",
    label: "Parent Guidance Assistant",
    description: "Help staff answer parent FAQs, fee queries, and communication tone (read-only).",
    requiredViewPermission: "viewCommunications",
    skills: ["parent_faq", "draft_guidance", "explain", "operational_qa"],
  },
];

export const COPILOT_SUGGESTED_PROMPTS: Record<CopilotAssistantType, string[]> = {
  admissions: [
    "Summarize the admissions funnel this month",
    "Explain pending application stages",
    "Which leads need follow-up?",
    "Generate an admissions status report",
  ],
  finance: [
    "Summarize collections and defaulters",
    "Explain open AP commitments from inventory",
    "What fee structures are active?",
    "Generate a finance operations snapshot",
  ],
  sis: [
    "How many active student enrollments do we have?",
    "Explain student registry status breakdown",
    "Summarize recent enrollment changes",
    "Help me look up a student record workflow",
  ],
  academic: [
    "Summarize the academic catalog for this year",
    "Explain timetable conflicts for this term",
    "Which teachers are overloaded this week?",
    "Explain the student risk score",
    "Explain the school health score composition",
    "Identify analytics anomalies this week",
    "Generate a principal summary (read-only)",
    "Generate a weekly management briefing (read-only)",
  ],
  communication: [
    "Summarize notification templates available",
    "Explain broadcast delivery metrics and pending queue",
    "Draft a fee reminder message for parents (guidance only)",
    "Suggest audience and channel for a school holiday notice",
    "What channels are configured?",
    "Draft a parent communication checklist (guidance only)",
  ],
  parentGuidance: [
    "How should I explain a fee balance to a parent?",
    "Draft a polite absence follow-up message for parents",
    "What should parents see in the mobile app?",
    "Suggest talking points for a parent complaint about homework load",
  ],
};
