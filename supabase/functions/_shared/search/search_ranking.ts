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

// ─── Staff (employees) ───────────────────────────────────────────────────────

export interface StaffCandidate {
  id: string;
  displayName: string;
  employeeCode: string;
  email: string | null;
  phone: string | null;
  status: string;
}

export function classifyStaffMatch(c: StaffCandidate, query: string): MatchField {
  const q = norm(query);
  if (c.employeeCode && norm(c.employeeCode).startsWith(q)) return "entity_id";
  if (
    (c.phone && norm(c.phone).replace(/\s+/g, "").includes(q.replace(/\s+/g, ""))) ||
    (c.email && norm(c.email).startsWith(q))
  ) {
    return "phone"; // contact-field match (phone/email) — permission is viewEmployees
  }
  if (norm(c.displayName).startsWith(q)) return "name_prefix";
  return "name_partial";
}

export function toStaffResult(c: StaffCandidate, query: string): SearchResult {
  const matchField = classifyStaffMatch(c, query);
  const parts: string[] = [];
  if (c.employeeCode) parts.push(c.employeeCode);
  if (c.status && c.status !== "active") parts.push(c.status);
  return {
    category: "staff",
    id: c.id,
    title: c.displayName,
    subtitle: parts.join(" · "),
    deepLink: `/staff/${c.id}`,
    matchField,
    rank: RANK[matchField],
  };
}

// ─── Admissions (leads) ──────────────────────────────────────────────────────

export interface AdmissionCandidate {
  id: string;
  studentName: string;
  parentName: string;
  classLabel: string | null;
  phone: string | null;
  stage: string;
}

export function classifyAdmissionMatch(c: AdmissionCandidate, query: string): MatchField {
  const q = norm(query);
  if (c.phone && norm(c.phone).replace(/\s+/g, "").includes(q.replace(/\s+/g, ""))) return "phone";
  if (norm(c.studentName).startsWith(q) || norm(c.parentName).startsWith(q)) return "name_prefix";
  return "name_partial";
}

export function toAdmissionResult(c: AdmissionCandidate, query: string): SearchResult {
  const matchField = classifyAdmissionMatch(c, query);
  const parts: string[] = [];
  if (c.classLabel) parts.push(`Class ${c.classLabel}`);
  if (c.parentName) parts.push(`Parent: ${c.parentName}`);
  if (c.stage) parts.push(c.stage.replace(/_/g, " "));
  return {
    category: "admissions",
    id: c.id,
    title: c.studentName,
    subtitle: parts.join(" · "),
    deepLink: `/admissions/leads/${c.id}`,
    matchField,
    rank: RANK[matchField],
  };
}

// ─── Finance (invoices) ──────────────────────────────────────────────────────

export interface FinanceInvoiceCandidate {
  id: string;
  invoiceNumber: string;
  invoiceStatus: string;
  dueDate: string;
  studentName: string;
}

export function classifyFinanceInvoiceMatch(c: FinanceInvoiceCandidate, query: string): MatchField {
  const q = norm(query);
  if (c.invoiceNumber && norm(c.invoiceNumber).startsWith(q)) return "entity_id";
  if (norm(c.studentName).startsWith(q)) return "name_prefix";
  return "name_partial";
}

export function toFinanceInvoiceResult(c: FinanceInvoiceCandidate, query: string): SearchResult {
  const matchField = classifyFinanceInvoiceMatch(c, query);
  const parts: string[] = [];
  if (c.studentName) parts.push(c.studentName);
  if (c.invoiceStatus) parts.push(c.invoiceStatus);
  if (c.dueDate) parts.push(`Due ${c.dueDate}`);
  return {
    category: "finance",
    id: c.id,
    title: c.invoiceNumber,
    subtitle: parts.join(" · "),
    deepLink: `/finance/invoices/${c.id}`,
    matchField,
    rank: RANK[matchField],
  };
}

// ─── Communications (broadcasts) ────────────────────────────────────────────

export interface BroadcastCandidate {
  id: string;
  title: string;
  audience: string;
  status: string;
}

export function classifyBroadcastMatch(c: BroadcastCandidate, query: string): MatchField {
  const q = norm(query);
  if (norm(c.title).startsWith(q)) return "name_prefix";
  return "name_partial";
}

export function toBroadcastResult(c: BroadcastCandidate, query: string): SearchResult {
  const matchField = classifyBroadcastMatch(c, query);
  const parts: string[] = [];
  if (c.audience) parts.push(c.audience.replace(/_/g, " "));
  if (c.status) parts.push(c.status);
  return {
    category: "communications",
    id: c.id,
    title: c.title,
    subtitle: parts.join(" · "),
    deepLink: `/communications/broadcasts/${c.id}`,
    matchField,
    rank: RANK[matchField],
  };
}

// ─── Classes (distinct class-section labels) ────────────────────────────────

export interface ClassCandidate {
  /** Composed "class_name-section_name" (or bare class_name when no section). */
  label: string;
  className: string;
  sectionName: string | null;
  /** Current-enrollment headcount for this class/section. */
  enrollmentCount: number;
}

export function classifyClassMatch(c: ClassCandidate, query: string): MatchField {
  const q = norm(query);
  if (norm(c.label) === q) return "roll_class";
  if (norm(c.className).startsWith(q)) return "name_prefix";
  return "name_partial";
}

export function toClassResult(c: ClassCandidate, query: string): SearchResult {
  const matchField = classifyClassMatch(c, query);
  return {
    category: "classes",
    // No natural row id for a distinct (class, section) group — the label is
    // the stable identifier and doubles as the deep-link path segment.
    id: c.label,
    title: c.label,
    subtitle: `Class · ${c.enrollmentCount} enrolled`,
    deepLink: `/academics/classes/${c.label}`,
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
