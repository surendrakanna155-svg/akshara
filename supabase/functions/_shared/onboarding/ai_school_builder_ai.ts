// B7 — AI School Builder (Phase 1): optional Claude refinement.
//
// The deterministic blueprint (ai_school_builder_service.ts) always produces a
// complete, valid proposal. This step asks Claude to tailor it to the school's
// board / type / context — sharper class span, sensible section count, locally
// appropriate fee categories and modules — and to write a short rationale.
//
// Constraints (enforced in the system prompt AND re-validated here):
// - Output ONLY a JSON object with the allowed keys.
// - Every field is validated; anything missing/invalid falls back to the
//   deterministic value. classes/sections are bounded and de-duplicated.
// Any failure (no key, refusal, bad JSON, transport error) returns the
// deterministic blueprint unchanged — enrichment is strictly additive and safe.

import { type Governance, governedTextFor } from "../ai/model_gateway.ts";
import type { StartupOnboardingPayload } from "./startup_onboarding_repository.ts";
import { GRADE_LADDER, type SchoolBlueprint, type SchoolBrief } from "./ai_school_builder_service.ts";

const ENRICH_MAX_TOKENS = 1100;
const MAX_CLASSES = 16;
const MAX_SECTIONS = 8;
const MAX_FEE_CATEGORIES = 10;
const MAX_MODULES = 16;

const SYSTEM_PROMPT = `
You are Akshara's AI School Builder. A school founder gives a short brief and a
deterministic baseline setup. Your job is to refine the baseline into a clean,
realistic startup configuration for an Indian K-12 school.

Strict rules:
- Output ONLY a JSON object, no prose around it, with these keys (all optional —
  omit a key to keep the baseline value):
  classes (string[]), sections (string[]), feeModel (string),
  feeCategories (string[]), modulesEnabled (string[]),
  defaultLanguage (string), rationale (string).
- "classes" must be real grade/class names ordered low → high (e.g. "Nursery",
  "LKG", "UKG", "Grade 1" … "Grade 12"). Do not invent non-academic entries.
- "sections" are short section labels applied to every class (e.g. "A","B","C").
- "feeModel" is one of: term_wise, monthly, quarterly, annual, semester.
- "feeCategories" are fee heads (e.g. "Tuition","Transport","Examination").
- "modulesEnabled" are lowercase module keys (e.g. sis, finance, attendance,
  transport, hostel, library, inventory).
- Keep classes ≤ 16, sections ≤ 8, fee categories ≤ 10.
- "rationale" is one short sentence (no numbers you did not derive from the brief).
- Never include names, addresses, phone numbers, or any personal data.
`.trim();

interface RefinedFields {
  classes?: unknown;
  sections?: unknown;
  feeModel?: unknown;
  feeCategories?: unknown;
  modulesEnabled?: unknown;
  defaultLanguage?: unknown;
  rationale?: unknown;
}

const ALLOWED_FEE_MODELS = new Set([
  "term_wise",
  "monthly",
  "quarterly",
  "annual",
  "semester",
]);

const LADDER_LOWER = new Set(GRADE_LADDER.map((g) => g.toLowerCase()));

function cleanStrings(value: unknown, max: number): string[] | null {
  if (!Array.isArray(value)) return null;
  const seen = new Set<string>();
  const out: string[] = [];
  for (const v of value) {
    if (typeof v !== "string") continue;
    const t = v.trim();
    if (!t) continue;
    const key = t.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(t);
    if (out.length >= max) break;
  }
  return out.length > 0 ? out : null;
}

/** Classes must look like real grades — guard against the model going off-script. */
function validClasses(value: unknown): string[] | null {
  const cleaned = cleanStrings(value, MAX_CLASSES);
  if (!cleaned) return null;
  const ok = cleaned.filter((c) => {
    const n = c.toLowerCase();
    return LADDER_LOWER.has(n) || /^(grade|class)\s+\d{1,2}$/.test(n) || /^\d{1,2}$/.test(n);
  });
  return ok.length > 0 ? ok : null;
}

function parseJsonObject(text: string): RefinedFields | null {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1)) as RefinedFields;
  } catch {
    return null;
  }
}

function asString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

/**
 * Returns a blueprint refined by Claude. Returns the deterministic blueprint
 * unchanged on any failure (no key, refusal, bad JSON, transport error).
 */
export async function enrichSchoolBlueprintWithClaude(
  baseline: SchoolBlueprint,
  brief: SchoolBrief,
  governance: Governance,
): Promise<SchoolBlueprint> {
  const userMessage = [
    "Brief from the school founder:",
    JSON.stringify({
      schoolName: brief.schoolName,
      board: brief.board ?? brief.curriculum,
      schoolType: brief.schoolType,
      lowestGrade: brief.lowestGrade,
      highestGrade: brief.highestGrade,
      estimatedStudents: brief.estimatedStudents,
      estimatedTeachers: brief.estimatedTeachers,
      languages: brief.languages,
      interestedModules: brief.interestedModules,
      notes: brief.notes,
    }),
    "Deterministic baseline to refine (keep what is already good):",
    JSON.stringify({
      classes: baseline.proposal.classes,
      sections: baseline.proposal.sections,
      feeModel: baseline.proposal.feeModel,
      feeCategories: baseline.proposal.feeCategories,
      modulesEnabled: baseline.proposal.modulesEnabled,
      defaultLanguage: baseline.proposal.defaultLanguage,
    }),
    "Return the refined JSON object now.",
  ].join("\n");

  const applyBlueprint = (text: string): SchoolBlueprint => {
    const parsed = parseJsonObject(text);
    if (!parsed) return baseline;

    const feeModelRaw = asString(parsed.feeModel, "").toLowerCase().replace(/\s+/g, "_");
    const proposal: StartupOnboardingPayload = {
      ...baseline.proposal,
      classes: validClasses(parsed.classes) ?? baseline.proposal.classes,
      sections: cleanStrings(parsed.sections, MAX_SECTIONS) ?? baseline.proposal.sections,
      feeModel: ALLOWED_FEE_MODELS.has(feeModelRaw) ? feeModelRaw : baseline.proposal.feeModel,
      feeCategories: cleanStrings(parsed.feeCategories, MAX_FEE_CATEGORIES) ??
        baseline.proposal.feeCategories,
      modulesEnabled: (cleanStrings(parsed.modulesEnabled, MAX_MODULES) ??
        baseline.proposal.modulesEnabled!).map((m) => m.toLowerCase().replace(/\s+/g, "_")),
      defaultLanguage: asString(parsed.defaultLanguage, baseline.proposal.defaultLanguage!)
        .toLowerCase(),
    };

    return {
      proposal,
      source: "ai",
      rationale: asString(parsed.rationale, baseline.rationale),
      warnings: baseline.warnings,
    };
  };

  const text = await governedTextFor(governance, "school_builder", {
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
    maxTokens: ENRICH_MAX_TOKENS,
  });
  return text ? applyBlueprint(text) : baseline;
}
