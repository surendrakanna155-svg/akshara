import type { CommunicationScenario, IntelLanguage } from "./intelligence_types.ts";

export interface CommunicationContext {
  feeAmount?: string;
  dueDate?: string;
  examName?: string;
  meetingDate?: string;
}

export interface CommunicationDraftInput {
  scenario: CommunicationScenario;
  studentName?: string;
  className?: string;
  customNote?: string;
  languages: IntelLanguage[];
  context?: CommunicationContext;
  parentPreferredLanguage?: IntelLanguage;
}

export interface ChannelDraft {
  whatsapp: string;
  sms: string;
  email: string;
}

export interface MultilingualDraft {
  language: IntelLanguage;
  professional: string;
  parentFriendly: string;
  channels: ChannelDraft;
}

const SCENARIO_TEMPLATES: Record<CommunicationScenario, (name: string, cls: string) => string> = {
  absent: (n, c) =>
    `We noticed ${n || "your child"} from ${c || "class"} was absent recently. Please share the reason so we can support catch-up.`,
  homework_missing: (n, c) =>
    `${n || "Your child"} (${c || "class"}) has pending homework. Kindly ensure submission to stay on track.`,
  low_attendance: (n, c) =>
    `Attendance for ${n || "your child"} (${c || "class"}) is below the recommended threshold. Let's work together to improve regularity.`,
  parent_meeting: (n, c) =>
    `We would like to schedule a parent meeting regarding ${n || "your child"} (${c || "class"}). Please suggest a convenient time.`,
  behavior_issue: (n, c) =>
    `We need to discuss a behavior concern involving ${n || "your child"} (${c || "class"}). Our goal is supportive correction.`,
  appreciation: (n, c) =>
    `We appreciate ${n || "your child"}'s positive participation in ${c || "class"}. Thank you for your support at home.`,
  fee_reminder: (n, c) =>
    `Friendly reminder: fee payment for ${n || "your child"} (${c || "class"}) is pending. Please complete at your earliest convenience.`,
  exam_reminder: (n, c) =>
    `Upcoming exam for ${n || "your child"} (${c || "class"}). Please ensure revision and adequate rest before the assessment.`,
};

function enrichScenarioText(
  scenario: CommunicationScenario,
  base: string,
  ctx?: CommunicationContext,
): string {
  if (scenario === "fee_reminder" && ctx?.feeAmount) {
    const due = ctx.dueDate ? ` by ${ctx.dueDate}` : "";
    return base.replace(
      "is pending.",
      `of ₹${ctx.feeAmount} is pending${due}.`,
    );
  }
  if (scenario === "exam_reminder" && ctx?.examName) {
    return base.replace("Upcoming exam", `Upcoming ${ctx.examName} exam`);
  }
  if (scenario === "parent_meeting" && ctx?.meetingDate) {
    return `${base} Proposed date: ${ctx.meetingDate}.`;
  }
  return base;
}

/** Resolve languages: parent preference first, then explicit list. */
export function resolveCommunicationLanguages(
  languages: IntelLanguage[],
  parentPreferredLanguage?: IntelLanguage,
): IntelLanguage[] {
  if (parentPreferredLanguage && parentPreferredLanguage !== "english") {
    const rest = languages.filter((l) => l !== parentPreferredLanguage);
    return [parentPreferredLanguage, ...rest];
  }
  return languages.length ? languages : ["english"];
}

const LANG_PREFIX: Partial<Record<IntelLanguage, string>> = {
  telugu: "[తెలుగు] ",
  hindi: "[हिंदी] ",
  tamil: "[தமிழ்] ",
  kannada: "[ಕನ್ನಡ] ",
  malayalam: "[മലയാളം] ",
  bengali: "[বাংলা] ",
  marathi: "[मराठी] ",
};

export function generateCommunicationDrafts(
  input: CommunicationDraftInput,
): MultilingualDraft[] {
  const languages = resolveCommunicationLanguages(
    input.languages,
    input.parentPreferredLanguage,
  );
  const raw = SCENARIO_TEMPLATES[input.scenario](
    input.studentName ?? "",
    input.className ?? "",
  );
  const base = enrichScenarioText(input.scenario, raw, input.context);
  const note = input.customNote?.trim()
    ? ` Additional context: ${input.customNote.trim()}`
    : "";

  return languages.map((language) => {
    const prefix = language === "english" ? "" : (LANG_PREFIX[language] ?? `[${language}] `);
    const professional = `${prefix}${base}${note}`;
    const parentFriendly = `${prefix}Dear Parent, ${base.replace(/We noticed/g, "Just letting you know")}${note} — ${input.className ?? "School"} Team`;
    return {
      language,
      professional,
      parentFriendly,
      channels: {
        whatsapp: parentFriendly.slice(0, 500),
        sms: professional.slice(0, 160),
        email: `Subject: School update — ${input.scenario.replaceAll("_", " ")}\n\n${professional}\n\nRegards,\nSchool Administration`,
      },
    };
  });
}

/** Architecture hook for voice-note → message (transcription stub). */
export function rewriteCustomNote(note: string): string {
  const trimmed = note.trim();
  if (!trimmed) return "";
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1) +
    (trimmed.endsWith(".") ? "" : ".");
}
