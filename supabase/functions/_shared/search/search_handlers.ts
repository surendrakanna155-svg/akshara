// Adaptive AI — P3-AI-2 / W2.S: Universal School Search route handler.
//
// GET /search?q=<term>&limit=<n>
//
// Deterministic, RBAC-scoped, ZERO tokens (decisions 2/3/9). Each entity
// category is searched ONLY if the caller holds its ERP view permission — the
// same permission engine as the rest of the ERP (rule 5: "can't see in UI → the
// resolver never returns it"). Results are grouped by category (decision 5).
// Category searchers are registered in a list so more entities are additive.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  orderResults,
  toAdmissionResult,
  toStaffResult,
  toStudentResult,
} from "./search_ranking.ts";
import { searchAdmissionsLeads, searchStaff, searchStudents } from "./search_repository.ts";
import type { SearchCategory, SearchGroup, SearchResult } from "./search_types.ts";

const MIN_QUERY_LEN = 2;
const DEFAULT_LIMIT = 8;
const MAX_LIMIT = 20;

interface CategorySearcher {
  category: SearchCategory;
  label: string;
  /** ERP view permission required to search this category (RBAC inheritance). */
  requiredPermission: string;
  search: (
    db: TenantQueryClient,
    orgId: string,
    schoolId: string,
    query: string,
    limit: number,
  ) => Promise<{ results: SearchResult[]; total: number }>;
}

/** The registry of category searchers. Additive: a new entity = one entry. */
const CATEGORY_SEARCHERS: readonly CategorySearcher[] = [
  {
    category: "students",
    label: "Students",
    requiredPermission: "viewSis",
    async search(db, orgId, schoolId, query, limit) {
      const { candidates, total } = await searchStudents(db, orgId, schoolId, query, limit);
      const results = orderResults(candidates.map((c) => toStudentResult(c, query))).slice(0, limit);
      return { results, total };
    },
  },
  {
    category: "staff",
    label: "Staff",
    requiredPermission: "viewEmployees",
    async search(db, orgId, schoolId, query, limit) {
      const { candidates, total } = await searchStaff(db, orgId, schoolId, query, limit);
      const results = orderResults(candidates.map((c) => toStaffResult(c, query))).slice(0, limit);
      return { results, total };
    },
  },
  {
    category: "admissions",
    label: "Admissions",
    requiredPermission: "viewAdmissions",
    async search(db, orgId, schoolId, query, limit) {
      const { candidates, total } = await searchAdmissionsLeads(db, orgId, schoolId, query, limit);
      const results = orderResults(candidates.map((c) => toAdmissionResult(c, query))).slice(0, limit);
      return { results, total };
    },
  },
];

function parseLimit(raw: string | null): number {
  const n = Number.parseInt(raw ?? "", 10);
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_LIMIT;
  return Math.min(MAX_LIMIT, n);
}

/** GET /search — the Universal School Search entity resolver. */
export async function handleUniversalSearch(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const query = (url.searchParams.get("q") ?? "").trim();
  if (query.length < MIN_QUERY_LEN) {
    return errorEnvelope("VALIDATION_ERROR", `q must be at least ${MIN_QUERY_LEN} characters`, 422);
  }
  const limit = parseLimit(url.searchParams.get("limit"));

  // Only the categories the caller is permitted to see (RBAC pre-filter, rule 5).
  const perms = auth.claims.permissions;
  const searchers = CATEGORY_SEARCHERS.filter((s) => perms.includes(s.requiredPermission));
  if (searchers.length === 0) {
    return jsonResponse(envelope({ query, groups: [] }));
  }

  try {
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);
    const groups: SearchGroup[] = await withTenantContext(config, auth.claims, async (db) => {
      const out: SearchGroup[] = [];
      for (const s of searchers) {
        const { results, total } = await s.search(db, orgId, schoolId, query, limit);
        if (results.length > 0) {
          out.push({ category: s.category, label: s.label, results, total });
        }
      }
      return out;
    });
    return jsonResponse(envelope({ query, groups }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Search failed";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}
