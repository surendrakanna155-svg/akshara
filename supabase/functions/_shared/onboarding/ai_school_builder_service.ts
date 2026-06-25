// B7 — AI School Builder (Phase 1): deterministic school blueprint.
//
// Turns a short founder "brief" (board, school type, grade range, rough size…)
// into a complete, board-appropriate startup-onboarding proposal: classes,
// section labels, fee model + categories, branding, default language, modules.
//
// This stage is fully deterministic and never calls an LLM, so it ALWAYS works
// (no API key, offline, refusals). The optional Claude pass (ai_school_builder_ai.ts)
// refines this baseline and falls back to it on any failure. The output matches
// StartupOnboardingPayload exactly so the admin can review → save → go-live with
// the existing endpoints. Nothing here writes to the DB — it only proposes.

import type { StartupOnboardingPayload } from "./startup_onboarding_repository.ts";

/** Canonical Indian K-12 grade ladder, lowest → highest. */
export const GRADE_LADDER = [
  "Nursery",
  "LKG",
  "UKG",
  "Grade 1",
  "Grade 2",
  "Grade 3",
  "Grade 4",
  "Grade 5",
  "Grade 6",
  "Grade 7",
  "Grade 8",
  "Grade 9",
  "Grade 10",
  "Grade 11",
  "Grade 12",
] as const;

const DEFAULT_ACADEMIC_YEAR = "2026-27";
const DEFAULT_THEME_PRIMARY = "#1565C0";
const DEFAULT_THEME_SECONDARY = "#42A5F5";
const SECTION_CAPACITY = 40; // mirrors provisioning default
const MAX_SECTIONS = 6;

/** The founder-supplied brief that seeds the proposal. All fields optional. */
export interface SchoolBrief {
  schoolName?: string;
  board?: string;
  curriculum?: string;
  schoolType?: string; // day_school | residential | preschool | primary | high_school | higher_secondary
  address?: string;
  contactPhone?: string;
  contactEmail?: string;
  lowestGrade?: string;
  highestGrade?: string;
  grades?: string[];
  sectionsPerGrade?: number;
  estimatedStudents?: number;
  estimatedTeachers?: number;
  languages?: string[];
  interestedModules?: string[];
  academicYear?: string;
  notes?: string;
}

export interface SchoolBlueprint {
  proposal: StartupOnboardingPayload;
  source: "deterministic" | "ai";
  rationale: string;
  warnings: string[];
}

function titleCase(value: string): string {
  return value
    .trim()
    .split(/\s+/)
    .map((w) => (w ? w[0]!.toUpperCase() + w.slice(1) : w))
    .join(" ");
}

/** Find a grade in the ladder, tolerant of "grade 1" / "1" / "Class 1" / "I". */
function ladderIndex(label?: string): number {
  if (!label) return -1;
  const norm = label.trim().toLowerCase().replace(/^class\s+/, "grade ");
  const direct = GRADE_LADDER.findIndex((g) => g.toLowerCase() === norm);
  if (direct !== -1) return direct;
  const num = norm.match(/^(?:grade\s+)?(\d{1,2})$/);
  if (num) return GRADE_LADDER.findIndex((g) => g === `Grade ${num[1]}`);
  return -1;
}

/** Default grade window per school type when no explicit range is given. */
function defaultGradeWindow(schoolType?: string): [number, number] {
  switch ((schoolType ?? "").toLowerCase()) {
    case "preschool":
      return [0, 2]; // Nursery–UKG
    case "primary":
      return [3, 7]; // Grade 1–5
    case "high_school":
      return [3, 12]; // Grade 1–10
    case "higher_secondary":
      return [3, 14]; // Grade 1–12
    default:
      return [0, 12]; // Nursery–Grade 10
  }
}

function resolveGrades(brief: SchoolBrief): string[] {
  const explicit = (brief.grades ?? [])
    .map((g) => g.trim())
    .filter((g) => g.length > 0);
  if (explicit.length > 0) return explicit;

  const [defLo, defHi] = defaultGradeWindow(brief.schoolType);
  let lo = ladderIndex(brief.lowestGrade);
  let hi = ladderIndex(brief.highestGrade);
  if (lo === -1) lo = defLo;
  if (hi === -1) hi = defHi;
  if (hi < lo) [lo, hi] = [hi, lo];
  return GRADE_LADDER.slice(lo, hi + 1);
}

/** A → B → C section labels. */
function sectionLabels(count: number): string[] {
  const n = Math.max(1, Math.min(MAX_SECTIONS, Math.round(count)));
  return Array.from({ length: n }, (_, i) => String.fromCharCode(65 + i));
}

function resolveSectionCount(brief: SchoolBrief, gradeCount: number): number {
  if (brief.sectionsPerGrade && brief.sectionsPerGrade > 0) return brief.sectionsPerGrade;
  if (brief.estimatedStudents && gradeCount > 0) {
    const perGrade = brief.estimatedStudents / gradeCount;
    return Math.max(1, Math.min(MAX_SECTIONS, Math.ceil(perGrade / SECTION_CAPACITY)));
  }
  return 2;
}

function resolveBoardCurriculum(brief: SchoolBrief): { board: string; curriculum: string } {
  const board = (brief.board ?? "").trim();
  const curriculum = (brief.curriculum ?? "").trim();
  if (board && curriculum) return { board, curriculum };
  if (board) return { board, curriculum: board };
  if (curriculum) return { board: curriculum, curriculum };
  return { board: "CBSE", curriculum: "CBSE" };
}

function resolveModules(brief: SchoolBrief): string[] {
  const modules = new Set<string>(["sis", "finance", "attendance"]);
  for (const m of brief.interestedModules ?? []) {
    const key = m.trim().toLowerCase().replace(/\s+/g, "_");
    if (key) modules.add(key);
  }
  if ((brief.schoolType ?? "").toLowerCase() === "residential") {
    modules.add("hostel");
    modules.add("transport");
  }
  return Array.from(modules);
}

function resolveFeeCategories(brief: SchoolBrief, modules: string[]): string[] {
  const categories = ["Tuition", "Examination", "Activity"];
  if (modules.includes("transport")) categories.push("Transport");
  if (modules.includes("hostel")) categories.push("Hostel");
  if (modules.includes("library")) categories.push("Library");
  return categories;
}

/**
 * Deterministic, board-aware proposal. Always succeeds; never calls an LLM.
 */
export function buildSchoolBlueprint(brief: SchoolBrief): SchoolBlueprint {
  const grades = resolveGrades(brief);
  const sectionCount = resolveSectionCount(brief, grades.length);
  const sections = sectionLabels(sectionCount);
  const { board, curriculum } = resolveBoardCurriculum(brief);
  const modules = resolveModules(brief);
  const feeCategories = resolveFeeCategories(brief, modules);
  const languages = (brief.languages ?? [])
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
  const defaultLanguage = (languages[0] ?? "en").toLowerCase();
  const academicYear = (brief.academicYear ?? "").trim() || DEFAULT_ACADEMIC_YEAR;
  const schoolName = (brief.schoolName ?? "").trim();

  const warnings: string[] = [];
  if (!schoolName) warnings.push("School name is missing — add it before go-live");
  if (!brief.address?.trim()) warnings.push("School address not provided — required for go-live");
  if (!brief.contactPhone?.trim() && !brief.contactEmail?.trim()) {
    warnings.push("No contact phone or email — required for go-live");
  }
  if (brief.estimatedStudents && brief.estimatedTeachers && brief.estimatedTeachers > 0) {
    const ratio = brief.estimatedStudents / brief.estimatedTeachers;
    if (ratio > 25) {
      warnings.push(
        `Estimated teacher–student ratio is 1:${Math.round(ratio)} — consider more teachers (target ≤ 1:25)`,
      );
    }
  }

  const totalSections = grades.length * sections.length;
  const rationale = [
    `Proposed ${grades.length} classes (${grades[0]} → ${grades[grades.length - 1]})`,
    `with ${sections.length} section${sections.length > 1 ? "s" : ""} each (${totalSections} total),`,
    `for a ${board} ${(brief.schoolType ?? "day school").replace(/_/g, " ")}.`,
    `Term-wise fees across ${feeCategories.length} categories;`,
    `${modules.length} modules enabled to start.`,
  ].join(" ");

  const proposal: StartupOnboardingPayload = {
    schoolName: schoolName || undefined,
    board,
    curriculum,
    address: brief.address?.trim() || undefined,
    contactPhone: brief.contactPhone?.trim() || undefined,
    contactEmail: brief.contactEmail?.trim() || undefined,
    academicYear,
    classes: grades,
    sections,
    feeModel: "term_wise",
    feeCategories,
    themePrimary: DEFAULT_THEME_PRIMARY,
    themeSecondary: DEFAULT_THEME_SECONDARY,
    defaultLanguage,
    modulesEnabled: modules,
  };

  return { proposal, source: "deterministic", rationale, warnings };
}

/** Brief defaults so the schoolName at least carries through in display. */
export function normalizeBrief(raw: unknown): SchoolBrief {
  const b = (raw ?? {}) as Record<string, unknown>;
  const str = (v: unknown): string | undefined =>
    typeof v === "string" && v.trim().length > 0 ? v.trim() : undefined;
  const num = (v: unknown): number | undefined =>
    typeof v === "number" && Number.isFinite(v) ? v : undefined;
  const arr = (v: unknown): string[] | undefined =>
    Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : undefined;
  return {
    schoolName: str(b.schoolName),
    board: str(b.board),
    curriculum: str(b.curriculum),
    schoolType: str(b.schoolType),
    address: str(b.address),
    contactPhone: str(b.contactPhone),
    contactEmail: str(b.contactEmail),
    lowestGrade: str(b.lowestGrade),
    highestGrade: str(b.highestGrade),
    grades: arr(b.grades),
    sectionsPerGrade: num(b.sectionsPerGrade),
    estimatedStudents: num(b.estimatedStudents),
    estimatedTeachers: num(b.estimatedTeachers),
    languages: arr(b.languages),
    interestedModules: arr(b.interestedModules),
    academicYear: str(b.academicYear),
    notes: str(b.notes),
  };
}

export { titleCase };
