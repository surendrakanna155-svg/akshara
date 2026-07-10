// Adaptive AI — P3-AI-2 / W2.S: deterministic match-priority ranking (pure).
//
// The ranking ladder of decision 7: Admission# → Entity ID → Phone → Roll+Class
// → Full Name (prefix) → Partial Name. PURE + deterministic so a candidate set
// always orders the same way and is trivially testable. The SQL fetches the
// candidate rows (any field matching); this module classifies + orders them.

import type { MatchField, SearchResult } from "./search_types.ts";

/** Rank weight per match field — LOWER is better (comes first). */
const RANK: Record<MatchField, number> = {
  admission_number: 0,
  entity_id: 1,
  phone: 2,
  roll_class: 3,
  name_prefix: 4,
  name_partial: 5,
};

export interface StudentCandidate {
  id: string;
  displayName: string;
  studentCode: string;
  admissionNumber: string | null;
  publicStudentId: string | null;
  className: string | null;
  sectionName: string | null;
  rollNumber: string | null;
  status: string;
}

function norm(s: string): string {
  return s.toLowerCase().trim();
}

/** Classify how this candidate matched the query → the best (lowest-rank) field.
 * Mirrors the SQL's OR-conditions, evaluated in priority order. */
export function classifyStudentMatch(c: StudentCandidate, query: string): MatchField {
  const q = norm(query);
  if (c.admissionNumber && norm(c.admissionNumber).startsWith(q)) return "admission_number";
  if (
    (c.studentCode && norm(c.studentCode).startsWith(q)) ||
    (c.publicStudentId && norm(c.publicStudentId).startsWith(q))
  ) {
    return "entity_id";
  }
  if (c.rollNumber && norm(c.rollNumber) === q) return "roll_class";
  if (norm(c.displayName).startsWith(q)) return "name_prefix";
  return "name_partial";
}

function cohort(c: StudentCandidate): string | null {
  if (!c.className) return null;
  return c.sectionName ? `${c.className}-${c.sectionName}` : c.className;
}

/** Build the disambiguating subtitle from the non-sensitive identifiers
 * (decision 6): class-section, roll, admission#, public id. */
export function studentSubtitle(c: StudentCandidate): string {
  const parts: string[] = [];
  const co = cohort(c);
  if (co) parts.push(`Class ${co}`);
  if (c.rollNumber) parts.push(`Roll ${c.rollNumber}`);
  if (c.admissionNumber) parts.push(`Adm# ${c.admissionNumber}`);
  if (c.publicStudentId) parts.push(`ID ${c.publicStudentId}`);
  if (c.status && c.status !== "active") parts.push(c.status);
  return parts.join(" · ");
}

export function toStudentResult(c: StudentCandidate, query: string): SearchResult {
  const matchField = classifyStudentMatch(c, query);
  return {
    category: "students",
    id: c.id,
    title: c.displayName,
    subtitle: studentSubtitle(c),
    deepLink: `/students/${c.id}`,
    matchField,
    rank: RANK[matchField],
  };
}

/** Order results by the ladder (rank asc), then by title, then id — a stable,
 * deterministic ordering independent of the DB's row order. */
export function orderResults(results: SearchResult[]): SearchResult[] {
  return [...results].sort((a, b) =>
    (a.rank - b.rank) ||
    a.title.localeCompare(b.title) ||
    a.id.localeCompare(b.id)
  );
}
