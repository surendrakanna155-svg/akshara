import type { AccessTokenClaims } from "./jwt.ts";
import type { TenantQueryClient } from "./tenant_db.ts";
import {
  SIS_CONVERSION_CONVERTED_PROBE_SQL,
  SIS_CONVERSION_PROBE_SQL,
  SIS_CONVERSION_TARGET_PROBE_SQL,
} from "./sis/sis_conversion_repository.ts";
import {
  SIS_ENROLLMENTS_API_PROBE_SQL,
  SIS_ENROLLMENT_UPDATE_PROBE_SQL,
} from "./sis/sis_enrollments_repository.ts";
import {
  SIS_DIRECTORY_PROBE_SQL,
  SIS_STUDENT_CREATE_PROBE_SQL,
  SIS_STUDENT_DETAIL_PROBE_SQL,
  SIS_STUDENT_UPDATE_PROBE_SQL,
} from "./sis/sis_students_repository.ts";

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
const FEE_STRUCTURE_SCHOOL_A = "b7000000-0000-4000-8000-000000000001";
const FEE_STRUCTURE_SCHOOL_B = "b7000000-0000-4000-8000-000000000002";
const FEE_ASSIGNMENT_SCHOOL_B = "b8000000-0000-4000-8000-000000000002";
const STUDENT_ACCOUNT_SCHOOL_B = "b8100000-0000-4000-8000-000000000002";
const FINANCE_INVOICE_SCHOOL_A = "b9000000-0000-4000-8000-000000000001";
const FINANCE_INVOICE_SCHOOL_B = "b9000000-0000-4000-8000-000000000002";
const FINANCE_COLLECTION_SCHOOL_B = "ba000000-0000-4000-8000-000000000002";
const FINANCE_RECEIPT_SCHOOL_A = "ba100000-0000-4000-8000-000000000001";
const FINANCE_REFUND_SCHOOL_B = "bb000000-0000-4000-8000-000000000002";
const FINANCE_REFUND_SCHOOL_A_PROCESSED = "bb000000-0000-4000-8000-000000000001";
const STUDENT_PROFILE_SCHOOL_A = "bc000000-0000-4000-8000-000000000001";
const STUDENT_PROFILE_SCHOOL_B = "bc000000-0000-4000-8000-000000000002";
const SIS_ENROLLMENT_SCHOOL_A = "bc100000-0000-4000-8000-000000000001";
const SIS_ENROLLMENT_SCHOOL_B = "bc100000-0000-4000-8000-000000000002";
const ADMISSIONS_ENROLLMENT_SCHOOL_A = "bd000000-0000-4000-8000-000000000001";
const ADMISSIONS_ENROLLMENT_SCHOOL_B = "bd000000-0000-4000-8000-000000000002";

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

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM students WHERE id = $1",
      [STUDENT_B],
    );
    return {
      name: "school_a_cannot_see_school_b_students",
      pass: n === 0,
      detail: `visible_cross_school_students=${n}`,
    };
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

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_fee_structures WHERE id = $1",
      [FEE_STRUCTURE_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_fee_structures",
      pass: n === 0,
      detail: `visible_cross_school_structures=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_structures");
    return {
      name: "organization_denied_fee_structures",
      pass: n === 0,
      detail: `visible_structures=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_structures");
    return {
      name: "parent_denied_fee_structures",
      pass: n === 0,
      detail: `visible_structures=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_structures");
    return {
      name: "student_denied_fee_structures",
      pass: n === 0,
      detail: `visible_structures=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_fee_assignments WHERE id = $1",
      [FEE_ASSIGNMENT_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_fee_assignments",
      pass: n === 0,
      detail: `visible_cross_school_assignments=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_assignments");
    return {
      name: "organization_denied_fee_assignments",
      pass: n === 0,
      detail: `visible_assignments=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_assignments");
    return {
      name: "parent_denied_fee_assignments",
      pass: n === 0,
      detail: `visible_assignments=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_assignments");
    return {
      name: "student_denied_fee_assignments",
      pass: n === 0,
      detail: `visible_assignments=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_student_accounts WHERE id = $1",
      [STUDENT_ACCOUNT_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_student_accounts",
      pass: n === 0,
      detail: `visible_cross_school_accounts=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_student_accounts");
    return {
      name: "organization_denied_student_accounts",
      pass: n === 0,
      detail: `visible_accounts=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_invoices WHERE id = $1",
      [FINANCE_INVOICE_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_finance_invoices",
      pass: n === 0,
      detail: `visible_cross_school_invoices=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_invoices");
    return {
      name: "organization_denied_finance_invoices",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_invoices");
    return {
      name: "parent_denied_finance_invoices",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_invoices");
    return {
      name: "student_denied_finance_invoices",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_invoices WHERE id = $1",
      [FINANCE_INVOICE_SCHOOL_A],
    );
    return {
      name: "school_a_sees_probe_finance_invoice",
      pass: n === 1,
      detail: `visible_probe_invoice=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_invoices WHERE school_id = $1",
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_finance_invoices",
      pass: n >= 1,
      detail: `visible_school_a_invoices=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_collections WHERE id = $1",
      [FINANCE_COLLECTION_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_collections",
      pass: n === 0,
      detail: `visible_cross_school_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_collections");
    return {
      name: "organization_denied_collections",
      pass: n === 0,
      detail: `visible_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_collections");
    return {
      name: "parent_denied_collections",
      pass: n === 0,
      detail: `visible_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_collections");
    return {
      name: "student_denied_collections",
      pass: n === 0,
      detail: `visible_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_collections WHERE school_id = $1",
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_collections",
      pass: n >= 1,
      detail: `visible_school_a_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_receipts WHERE id = $1",
      [FINANCE_RECEIPT_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_receipts",
      pass: n === 1,
      detail: `visible_probe_receipt=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_collections
       WHERE collection_date = CURRENT_DATE AND collection_status = 'completed'`,
    );
    return {
      name: "organization_denied_daily_summary",
      pass: n === 0,
      detail: `visible_today_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_invoices
       WHERE invoice_status IN ('issued', 'partially_paid', 'paid')`,
    );
    return {
      name: "parent_denied_daily_summary",
      pass: n === 0,
      detail: `visible_invoice_summary=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_invoices
       WHERE invoice_status IN ('issued', 'partially_paid', 'paid')`,
    );
    return {
      name: "student_denied_daily_summary",
      pass: n === 0,
      detail: `visible_invoice_summary=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_collections
       WHERE school_id = $1
         AND collection_status IN ('completed', 'partially_refunded')`,
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_daily_summary",
      pass: n >= 1,
      detail: `visible_school_a_completed_collections=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_student_accounts WHERE status = 'open'`,
    );
    return {
      name: "organization_denied_finance_dashboard",
      pass: n === 0,
      detail: `visible_open_accounts=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_fee_assignments
       WHERE assignment_status = 'active'`,
    );
    return {
      name: "parent_denied_finance_dashboard",
      pass: n === 0,
      detail: `visible_active_assignments=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_invoices
       WHERE invoice_status != 'cancelled'`,
    );
    return {
      name: "student_denied_finance_dashboard",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      `SELECT count(DISTINCT student_id)::text AS count FROM finance_student_accounts
       WHERE school_id = $1 AND status = 'open'`,
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_finance_dashboard",
      pass: n >= 1,
      detail: `visible_open_accounts=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_refunds WHERE id = $1",
      [FINANCE_REFUND_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_refunds",
      pass: n === 0,
      detail: `visible_cross_school_refunds=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_refunds");
    return {
      name: "organization_denied_refunds",
      pass: n === 0,
      detail: `visible_refunds=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_refunds");
    return {
      name: "parent_denied_refunds",
      pass: n === 0,
      detail: `visible_refunds=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_refunds");
    return {
      name: "student_denied_refunds",
      pass: n === 0,
      detail: `visible_refunds=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_refunds WHERE school_id = $1",
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_refunds",
      pass: n >= 1,
      detail: `visible_school_a_refunds=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const rows = await db.queryObject<{ outstanding: string; account_outstanding: string }>(
      `SELECT
         fi.outstanding_amount::text AS outstanding,
         fsa.outstanding_amount::text AS account_outstanding
       FROM finance_refunds fr
       JOIN finance_invoices fi ON fi.id = fr.invoice_id
       JOIN finance_student_accounts fsa ON fsa.id = fr.student_account_id
       WHERE fr.id = $1 AND fr.refund_status = 'processed'`,
      [FINANCE_REFUND_SCHOOL_A_PROCESSED],
    );
    const row = rows[0];
    const pass = row != null &&
      parseFloat(row.outstanding) === 47000 &&
      parseFloat(row.account_outstanding) === 47000;
    return {
      name: "approved_refund_updates_balances",
      pass,
      detail: row
        ? `invoice_outstanding=${row.outstanding}, account_outstanding=${row.account_outstanding}`
        : "processed_refund_fixture_missing",
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM student_profiles");
    return {
      name: "organization_denied_student_profiles",
      pass: n === 0,
      detail: `visible_profiles=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM student_profiles");
    return {
      name: "parent_denied_student_profiles",
      pass: n === 0,
      detail: `visible_profiles=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM student_profiles");
    return {
      name: "student_denied_student_profiles",
      pass: n === 0,
      detail: `visible_profiles=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM student_profiles WHERE id = $1",
      [STUDENT_PROFILE_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_student_profiles",
      pass: n === 0,
      detail: `visible_cross_school_profiles=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM student_profiles WHERE id = $1",
      [STUDENT_PROFILE_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_student_profiles",
      pass: n === 1,
      detail: `visible_probe_profile=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM sis_student_enrollments");
    return {
      name: "organization_denied_sis_enrollments",
      pass: n === 0,
      detail: `visible_enrollments=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM sis_student_enrollments");
    return {
      name: "parent_denied_sis_enrollments",
      pass: n === 0,
      detail: `visible_enrollments=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM sis_student_enrollments");
    return {
      name: "student_denied_sis_enrollments",
      pass: n === 0,
      detail: `visible_enrollments=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sis_student_enrollments WHERE id = $1",
      [SIS_ENROLLMENT_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_sis_enrollments",
      pass: n === 0,
      detail: `visible_cross_school_enrollments=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sis_student_enrollments WHERE id = $1",
      [SIS_ENROLLMENT_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_sis_enrollments",
      pass: n === 1,
      detail: `visible_probe_enrollment=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "organization_denied_sis_students_api",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "parent_denied_sis_students_api",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "student_denied_sis_students_api",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_STUDENT_DETAIL_PROBE_SQL, [STUDENT_B]);
    return {
      name: "school_a_cannot_fetch_school_b_student_detail",
      pass: n === 0,
      detail: `visible_cross_school_detail=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_STUDENT_CREATE_PROBE_SQL);
    return {
      name: "organization_denied_sis_student_create",
      pass: n === 0,
      detail: `visible_profiles_for_create=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_STUDENT_CREATE_PROBE_SQL);
    return {
      name: "parent_denied_sis_student_create",
      pass: n === 0,
      detail: `visible_profiles_for_create=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_STUDENT_CREATE_PROBE_SQL);
    return {
      name: "student_denied_sis_student_create",
      pass: n === 0,
      detail: `visible_profiles_for_create=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_STUDENT_UPDATE_PROBE_SQL, [STUDENT_B]);
    return {
      name: "school_a_cannot_update_school_b_student",
      pass: n === 0,
      detail: `visible_cross_school_update_target=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_ENROLLMENTS_API_PROBE_SQL);
    return {
      name: "organization_denied_sis_enrollments_api",
      pass: n === 0,
      detail: `visible_enrollment_api_rows=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_ENROLLMENTS_API_PROBE_SQL);
    return {
      name: "parent_denied_sis_enrollments_api",
      pass: n === 0,
      detail: `visible_enrollment_api_rows=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_ENROLLMENTS_API_PROBE_SQL);
    return {
      name: "student_denied_sis_enrollments_api",
      pass: n === 0,
      detail: `visible_enrollment_api_rows=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_ENROLLMENT_UPDATE_PROBE_SQL, [SIS_ENROLLMENT_SCHOOL_B]);
    return {
      name: "school_a_cannot_update_school_b_enrollment",
      pass: n === 0,
      detail: `visible_cross_school_enrollment_update=${n}`,
    };
  }));

  tests.push(await runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_CONVERSION_PROBE_SQL);
    return {
      name: "organization_denied_admissions_conversion",
      pass: n === 0,
      detail: `visible_pending_conversions=${n}`,
    };
  }));

  tests.push(await runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_CONVERSION_PROBE_SQL);
    return {
      name: "parent_denied_admissions_conversion",
      pass: n === 0,
      detail: `visible_pending_conversions=${n}`,
    };
  }));

  tests.push(await runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_CONVERSION_PROBE_SQL);
    return {
      name: "student_denied_admissions_conversion",
      pass: n === 0,
      detail: `visible_pending_conversions=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_CONVERSION_TARGET_PROBE_SQL, [ADMISSIONS_ENROLLMENT_SCHOOL_B]);
    return {
      name: "school_a_cannot_convert_school_b_enrollment",
      pass: n === 0,
      detail: `visible_cross_school_conversion_target=${n}`,
    };
  }));

  tests.push(await runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      SIS_CONVERSION_CONVERTED_PROBE_SQL,
      [ADMISSIONS_ENROLLMENT_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_converted_enrollment",
      pass: n === 0,
      detail: `visible_cross_school_converted=${n}`,
    };
  }));

  const pass = tests.every((t) => t.pass);
  return { pass, enforced: true, role: "erp_tenant", tests };
}
