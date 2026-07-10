// Adaptive AI — P3-AI-2 / W2.S: Universal School Search (Entity Resolver) types
// (design doc 10 §10, owner-locked W2.S decisions).
//
// A deterministic, DB-driven, RBAC-scoped global search — "Search First → AI
// Later" (decision 9). ZERO model calls, ZERO tokens (decision 2). Results are
// grouped by category (decision 5) and carry enough identifying info to
// disambiguate non-unique names (decision 6); selecting one navigates directly
// to the ERP screen (decision 8). This file is types only.

export type SearchCategory =
  | "students"
  | "staff"
  | "classes"
  | "finance"
  | "transport"
  | "library"
  | "inventory"
  | "complaints"
  | "approvals"
  | "communications"
  | "events";

/** Which field produced the match — drives the deterministic ranking ladder
 * (decision 7: admission# → id → phone → roll+class → full name → partial). */
export type MatchField =
  | "admission_number"
  | "entity_id" // student_code / public id / employee id
  | "phone"
  | "roll_class"
  | "name_prefix"
  | "name_partial";

export interface SearchResult {
  category: SearchCategory;
  id: string;
  /** Primary display (full name / entity name). */
  title: string;
  /** Disambiguating identifiers, e.g. "Class 6-B · Roll 12 · Adm# 2024-001". */
  subtitle: string;
  /** Client route to navigate to on selection (no AI call). */
  deepLink: string;
  matchField: MatchField;
  /** Lower = better (the match-priority ladder). */
  rank: number;
}

export interface SearchGroup {
  category: SearchCategory;
  label: string;
  results: SearchResult[];
  /** How many candidates matched before the per-category display cap. */
  total: number;
}

export interface SearchResponse {
  query: string;
  groups: SearchGroup[];
}
