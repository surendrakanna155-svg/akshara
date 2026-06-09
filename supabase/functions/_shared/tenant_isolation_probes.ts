import type { AccessTokenClaims } from "./jwt.ts";
import type { TenantQueryClient } from "./tenant_db.ts";

export interface IsolationProbeResult {
  name: string;
  pass: boolean;
  detail: string;
}

export interface IsolationProbeReport {
  pass: boolean;
  enforced: true;
  role: string;
  tests: IsolationProbeResult[];
}

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STAFF_A = "a3000000-0000-4000-8000-000000000001";
const PARENT = "a3000000-0000-4000-8000-000000000003";
const STUDENT_USER = "a3000000-0000-4000-8000-000000000004";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const STUDENT_B = "a4000000-0000-4000-8000-000000000002";
const LEAD_SCHOOL_A = "b5000000-0000-4000-8000-000000000001";
const LEAD_SCHOOL_B = "b5000000-0000-4000-8000-000000000002";
const HANDOFF_SCHOOL_A = "b6000000-0000-4000-8000-000000000001";
const HANDOFF_SCHOOL_B = "b6000000-0000-4000-8000-000000000002";

function schoolClaims(schoolId: string): AccessTokenClaims {
  return {
    sub: STAFF_A,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: schoolId,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: [],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "probe",
  };
}

function orgClaims(): AccessTokenClaims {
  return {
    sub: STAFF_A,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: null,
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
    permissions: [],
    permissions_version: 1,
    scope: "organization",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "probe",
  };
}

function parentClaims(schoolId: string): AccessTokenClaims {
  return {
    sub: PARENT,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: schoolId,
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions: [],
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: [STUDENT_A],
    session_id: "probe",
  };
}

function studentClaims(): AccessTokenClaims {
  return {
    sub: STUDENT_USER,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "student",
    role_slugs: ["student"],
    primary_role: "student",
    permissions: [],
    permissions_version: 1,
    scope: "student",
    school_group_id: null,
    student_id: STUDENT_A,
    child_ids: [],
    session_id: "probe",
  };
}

async function count(db: TenantQueryClient, sql: string, args: unknown[] = []): Promise<number> {
  return await db.queryCount(sql, args);
}

/** Runs enforced RLS probes on an active erp_tenant connection (context already set per probe). */
export async function runEnforcedIsolationProbes(
  runWithClaims: (
    claims: AccessTokenClaims,
    fn: (db: TenantQueryClient) => Promise<IsolationProbeResult>,
  ) => Promise<IsolationProbeResult>,
): Promise<IsolationProbeReport> {
  const tests: IsolationProbeResult[] = [];

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM schools WHERE id = $1", [SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b", pass: n === 0, detail: `visible_schools=${n}` };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM schools WHERE organization_id = $1", [ORG]);
    return { name: "org_scope_sees_school_metadata", pass: n >= 2, detail: `visible_schools=${n}` };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM school_memberships");
    return { name: "org_scope_denied_raw_school_memberships", pass: n === 0, detail: `visible_memberships=${n}` };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students");
    return { name: "org_scope_denied_raw_students", pass: n === 0, detail: `visible_students=${n}` };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM org_school_summary WHERE tenant_id = $1", [ORG]);
    return { name: "org_scope_reads_aggregate_view", pass: n >= 2, detail: `summary_rows=${n}` };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students WHERE id = $1", [STUDENT_A]);
    return { name: "parent_sees_linked_child", pass: n === 1, detail: `visible_students=${n}` };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_B), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students WHERE id = $1", [STUDENT_B]);
    return { name: "parent_cannot_see_unlinked_student", pass: n === 0, detail: `visible_students=${n}` };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students");
    return { name: "student_sees_self_only", pass: n === 1, detail: `visible_students=${n}` };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM admissions_leads");
    return {
      name: "org_scope_denied_raw_admissions_leads",
      pass: n === 0,
      detail: `visible_leads=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_leads WHERE school_id = $1",
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_leads",
      pass: n >= 1,
      detail: `visible_leads=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_leads WHERE id = $1",
      [LEAD_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_leads",
      pass: n === 0,
      detail: `visible_cross_school_leads=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_leads WHERE id = $1",
      [LEAD_SCHOOL_A],
    );
    return {
      name: "school_a_sees_probe_lead",
      pass: n === 1,
      detail: `visible_probe_lead=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM admissions_fee_handoffs");
    return {
      name: "org_scope_denied_raw_admissions_fee_handoffs",
      pass: n === 0,
      detail: `visible_handoffs=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM admissions_fee_handoffs");
    return {
      name: "parent_scope_denied_admissions_fee_handoffs",
      pass: n === 0,
      detail: `visible_handoffs=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_fee_handoffs WHERE school_id = $1",
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_fee_handoffs",
      pass: n >= 1,
      detail: `visible_handoffs=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_fee_handoffs WHERE id = $1",
      [HANDOFF_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_fee_handoffs",
      pass: n === 0,
      detail: `visible_cross_school_handoffs=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_fee_handoffs WHERE id = $1",
      [HANDOFF_SCHOOL_A],
    );
    return {
      name: "school_a_sees_probe_fee_handoff",
      pass: n === 1,
      detail: `visible_probe_handoff=${n}`,
    };
  }));

  const pass = tests.every((t) => t.pass);
  return { pass, enforced: true, role: "erp_tenant", tests };
}
