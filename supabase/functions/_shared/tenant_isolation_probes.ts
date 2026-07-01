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
import {
  ACADEMIC_CLASSES_PROBE_SQL,
  ACADEMIC_CLASSES_API_PROBE_SQL,
  ACADEMIC_CLASS_DETAIL_PROBE_SQL,
  ACADEMIC_CLASS_SCHOOL_A,
  ACADEMIC_CLASS_SCHOOL_B,
} from "./academic/classes_repository.ts";
import {
  ACADEMIC_SECTIONS_PROBE_SQL,
  ACADEMIC_SECTIONS_API_PROBE_SQL,
  ACADEMIC_SECTION_DETAIL_PROBE_SQL,
  ACADEMIC_SECTION_SCHOOL_A,
  ACADEMIC_SECTION_SCHOOL_B,
} from "./academic/sections_repository.ts";
import {
  ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL,
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A,
  ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B,
} from "./academic/teacher_assignments_repository.ts";
import {
  ACADEMIC_YEARS_PROBE_SQL,
  ACADEMIC_YEARS_API_PROBE_SQL,
  ACADEMIC_YEAR_DETAIL_PROBE_SQL,
  ACADEMIC_YEAR_SCHOOL_A,
  ACADEMIC_YEAR_SCHOOL_B,
} from "./academic/academic_years_repository.ts";
import {
  TRANSPORT_ROUTE_DETAIL_PROBE_SQL,
  TRANSPORT_ROUTE_SCHOOL_A,
  TRANSPORT_ROUTE_SCHOOL_B,
  TRANSPORT_ROUTES_API_PROBE_SQL,
} from "./transport/transport_read_repository.ts";
import {
  HR_EMPLOYEE_DETAIL_PROBE_SQL,
  HR_EMPLOYEE_SCHOOL_A,
  HR_EMPLOYEE_SCHOOL_B,
  HR_EMPLOYEES_API_PROBE_SQL,
} from "./hr/hr_read_repository.ts";
import {
  HOSTEL_STUDENT_DETAIL_PROBE_SQL,
  HOSTEL_STUDENT_SCHOOL_A,
  HOSTEL_STUDENT_SCHOOL_B,
  HOSTEL_STUDENTS_API_PROBE_SQL,
} from "./hostel/hostel_read_repository.ts";
import {
  LIBRARY_CATALOG_DETAIL_PROBE_SQL,
  LIBRARY_BOOK_SCHOOL_A,
  LIBRARY_BOOK_SCHOOL_B,
  LIBRARY_CATALOG_API_PROBE_SQL,
} from "./library/library_read_repository.ts";
import {
  INVENTORY_ASSET_DETAIL_PROBE_SQL,
  INVENTORY_ASSET_SCHOOL_A,
  INVENTORY_ASSET_SCHOOL_B,
  INVENTORY_ASSETS_API_PROBE_SQL,
} from "./inventory/inventory_read_repository.ts";
import {
  ALUMNI_REGISTRY_DETAIL_PROBE_SQL,
  ALUMNI_RECORD_SCHOOL_A,
  ALUMNI_RECORD_SCHOOL_B,
  ALUMNI_REGISTRY_API_PROBE_SQL,
} from "./alumni/alumni_read_repository.ts";
import {
  MANAGEMENT_PROBE_DETAIL_SQL,
  MANAGEMENT_PROBE_SCHOOL_A,
  MANAGEMENT_PROBE_SCHOOL_B,
} from "./management/management_read_repository.ts";
import {
  CONTROL_CENTER_SCHOOL_DETAIL_PROBE_SQL,
  CONTROL_CENTER_SCHOOL_A,
  CONTROL_CENTER_SCHOOLS_API_PROBE_SQL,
} from "./control_center/control_center_read_repository.ts";
import {
  PARENT_PROBE_DETAIL_SQL,
  PARENT_PROBE_SCHOOL_A,
  PARENT_PROBE_SCHOOL_B,
} from "./parent/parent_read_repository.ts";
import {
  TEACHER_PROBE_DETAIL_SQL,
  TEACHER_PROBE_SCHOOL_A,
  TEACHER_PROBE_SCHOOL_B,
} from "./teacher/teacher_read_repository.ts";
import {
  STUDENT_PROBE_DETAIL_SQL,
  STUDENT_PROBE_SCHOOL_A,
  STUDENT_PROBE_SCHOOL_B,
} from "./student/student_read_repository.ts";
import {
  AUDIT_PROBE_DETAIL_SQL,
  AUDIT_PROBE_SCHOOL_A,
  AUDIT_PROBE_SCHOOL_B,
  DOMAIN_EVENT_PROBE_DETAIL_SQL,
  DOMAIN_EVENT_PROBE_SCHOOL_A,
  DOMAIN_EVENT_PROBE_SCHOOL_B,
} from "./audit/audit_repository.ts";
import {
  PAYMENT_INTENT_PROBE_DETAIL_SQL,
  PAYMENT_INTENT_PROBE_SCHOOL_A,
  PAYMENT_INTENT_PROBE_SCHOOL_B,
  PAYMENT_WEBHOOK_PROBE_DETAIL_SQL,
  PAYMENT_WEBHOOK_PROBE_SCHOOL_A,
  PAYMENT_WEBHOOK_PROBE_SCHOOL_B,
} from "./payment/payment_repository.ts";
import {
  COMM_THREAD_PROBE_DETAIL_SQL,
  COMM_THREAD_PROBE_SCHOOL_A,
  COMM_THREAD_PROBE_SCHOOL_B,
  NOTIFICATION_DELIVERY_PROBE_DETAIL_SQL,
  NOTIFICATION_DELIVERY_PROBE_SCHOOL_A,
  NOTIFICATION_DELIVERY_PROBE_SCHOOL_B,
} from "./communication/communication_repository.ts";
import {
  ATTENDANCE_SESSION_PROBE_DETAIL_SQL,
  ATTENDANCE_SESSION_PROBE_SCHOOL_A,
  ATTENDANCE_SESSION_PROBE_SCHOOL_B,
  EXAM_MARK_PROBE_DETAIL_SQL,
  EXAM_MARK_PROBE_SCHOOL_A,
  EXAM_MARK_PROBE_SCHOOL_B,
  HOMEWORK_SUBMISSION_PROBE_DETAIL_SQL,
  HOMEWORK_SUBMISSION_PROBE_SCHOOL_A,
  HOMEWORK_SUBMISSION_PROBE_SCHOOL_B,
  MOBILE_LEAVE_PROBE_DETAIL_SQL,
  MOBILE_LEAVE_PROBE_SCHOOL_A,
  MOBILE_LEAVE_PROBE_SCHOOL_B,
  TIMETABLE_SLOT_PROBE_DETAIL_SQL,
  TIMETABLE_SLOT_PROBE_SCHOOL_A,
  TIMETABLE_SLOT_PROBE_SCHOOL_B,
} from "./pilot/pilot_operations_repository.ts";
import {
  ONBOARDING_IMPORT_JOB_PROBE_SCHOOL_A,
  ONBOARDING_IMPORT_JOB_PROBE_SCHOOL_B,
  ONBOARDING_IMPORT_JOB_PROBE_SQL,
  ONBOARDING_INVITE_PROBE_SCHOOL_A,
  ONBOARDING_INVITE_PROBE_SCHOOL_B,
  ONBOARDING_INVITE_PROBE_SQL,
} from "./onboarding/onboarding_repository.ts";
import {
  AP_COMMITMENT_PROBE_SCHOOL_A,
  AP_COMMITMENT_PROBE_SCHOOL_B,
  AP_COMMITMENT_PROBE_SQL,
  INVENTORY_VENDOR_PROBE_SCHOOL_A,
  INVENTORY_VENDOR_PROBE_SCHOOL_B,
  INVENTORY_VENDOR_PROBE_SQL,
  PURCHASE_ORDER_PROBE_SCHOOL_A,
  PURCHASE_ORDER_PROBE_SCHOOL_B,
  PURCHASE_ORDER_PROBE_SQL,
} from "./inventory_finance/inventory_finance_repository.ts";
import {
  AI_COPILOT_SESSION_PROBE_SCHOOL_A,
  AI_COPILOT_SESSION_PROBE_SCHOOL_B,
  AI_COPILOT_SESSION_PROBE_SQL,
} from "./copilot/copilot_repository.ts";
import {
  ACADEMIC_TIMETABLE_PROBE_SCHOOL_A,
  ACADEMIC_TIMETABLE_PROBE_SCHOOL_B,
  ACADEMIC_TIMETABLE_PROBE_SQL,
} from "./timetable/timetable_repository.ts";
import {
  ANALYTICS_SNAPSHOT_PROBE_SCHOOL_A,
  ANALYTICS_SNAPSHOT_PROBE_SCHOOL_B,
  ANALYTICS_SNAPSHOT_PROBE_SQL,
} from "./analytics/analytics_repository.ts";
import {
  INTEL_RISK_API_PROBE_SQL,
  INTEL_RISK_PROBE_SCHOOL_A,
  INTEL_RISK_PROBE_SCHOOL_B,
  INTEL_RISK_PROBE_SQL,
} from "./intelligence/student_risk_repository.ts";
import {
  EDU_QUESTION_BANK_API_PROBE_SQL,
  EDU_QUESTION_BANK_PROBE_SCHOOL_A,
  EDU_QUESTION_BANK_PROBE_SCHOOL_B,
  EDU_QUESTION_BANK_PROBE_SQL,
} from "./education/education_repository.ts";
import {
  SCHOOL_BRANDING_PROBE_SCHOOL_A,
  SCHOOL_BRANDING_PROBE_SCHOOL_B,
  SCHOOL_BRANDING_PROBE_SQL,
} from "./school_completion/branding_repository.ts";
import {
  SCHOOL_CONFIGURATION_PROBE_SCHOOL_A,
  SCHOOL_CONFIGURATION_PROBE_SCHOOL_B,
  SCHOOL_CONFIGURATION_PROBE_SQL,
} from "./school_config/school_config_repository.ts";
import {
  ORGANIZATION_SUBSCRIPTION_PROBE_SQL,
  SUBSCRIPTION_PROBE_ORG_A_ROW,
  SUBSCRIPTION_PROBE_ORG_B,
  SUBSCRIPTION_PROBE_ORG_B_ROW,
} from "./entitlements/entitlement_repository.ts";

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
// A second teacher in the SAME school — used to prove teacher_entities is now
// scoped per-teacher (not just per-school).
const STAFF_A2_SAME_SCHOOL = "a3000000-0000-4000-8000-000000000005";
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

// Org-scoped claim for a SECOND tenant (org B) — proves cross-org isolation of
// the org-keyed organization_subscriptions table (QA-R-003).
function orgBClaims(): AccessTokenClaims {
  return {
    sub: STAFF_A,
    tenant_id: SUBSCRIPTION_PROBE_ORG_B,
    organization_id: SUBSCRIPTION_PROBE_ORG_B,
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

function teacherClaims(schoolId: string, userId: string = STAFF_A): AccessTokenClaims {
  return {
    sub: userId,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: schoolId,
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions: ["viewAdminHub"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "probe",
  };
}

async function count(db: TenantQueryClient, sql: string, args: unknown[] = []): Promise<number> {
  return await db.queryCount(sql, args);
}

const PROBE_CONCURRENCY = 16;

async function runProbeTasks(
  tasks: (() => Promise<IsolationProbeResult>)[],
): Promise<IsolationProbeResult[]> {
  const results: IsolationProbeResult[] = new Array(tasks.length);
  let next = 0;
  async function worker() {
    while (true) {
      const index = next++;
      if (index >= tasks.length) break;
      results[index] = await tasks[index]!();
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(PROBE_CONCURRENCY, tasks.length) }, () => worker()),
  );
  return results;
}

/** Runs enforced RLS probes on an active erp_tenant connection (context already set per probe). */
export async function runEnforcedIsolationProbes(
  runWithClaims: (
    claims: AccessTokenClaims,
    fn: (db: TenantQueryClient) => Promise<IsolationProbeResult>,
  ) => Promise<IsolationProbeResult>,
): Promise<IsolationProbeReport> {
  const tasks: (() => Promise<IsolationProbeResult>)[] = [];

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM schools WHERE id = $1", [SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b", pass: n === 0, detail: `visible_schools=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM schools WHERE organization_id = $1", [ORG]);
    return { name: "org_scope_sees_school_metadata", pass: n >= 2, detail: `visible_schools=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM school_memberships");
    return { name: "org_scope_denied_raw_school_memberships", pass: n === 0, detail: `visible_memberships=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped SELECT on students within
    // its OWN org (organization_id = tenant). The isolation invariant is therefore
    // "sees NOTHING outside its org" — exclude the org's own rows and expect 0.
    const n = await count(db, "SELECT count(*)::text AS count FROM students WHERE organization_id <> $1", [ORG]);
    return { name: "org_scope_denied_raw_students", pass: n === 0, detail: `visible_students=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM org_school_summary WHERE tenant_id = $1", [ORG]);
    return { name: "org_scope_reads_aggregate_view", pass: n >= 2, detail: `summary_rows=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students WHERE id = $1", [STUDENT_A]);
    return { name: "parent_sees_linked_child", pass: n === 1, detail: `visible_students=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_B), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students WHERE id = $1", [STUDENT_B]);
    return { name: "parent_cannot_see_unlinked_student", pass: n === 0, detail: `visible_students=${n}` };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM students");
    return { name: "student_sees_self_only", pass: n === 1, detail: `visible_students=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped SELECT on admissions_leads
    // within its OWN org. Assert it sees NOTHING outside its org.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM admissions_leads WHERE organization_id <> $1",
      [ORG],
    );
    return {
      name: "org_scope_denied_raw_admissions_leads",
      pass: n === 0,
      detail: `visible_leads=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM admissions_fee_handoffs");
    return {
      name: "org_scope_denied_raw_admissions_fee_handoffs",
      pass: n === 0,
      detail: `visible_handoffs=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM admissions_fee_handoffs");
    return {
      name: "parent_scope_denied_admissions_fee_handoffs",
      pass: n === 0,
      detail: `visible_handoffs=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_structures");
    return {
      name: "organization_denied_fee_structures",
      pass: n === 0,
      detail: `visible_structures=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_structures");
    return {
      name: "parent_denied_fee_structures",
      pass: n === 0,
      detail: `visible_structures=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_structures");
    return {
      name: "student_denied_fee_structures",
      pass: n === 0,
      detail: `visible_structures=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_assignments");
    return {
      name: "organization_denied_fee_assignments",
      pass: n === 0,
      detail: `visible_assignments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_assignments");
    return {
      name: "parent_denied_fee_assignments",
      pass: n === 0,
      detail: `visible_assignments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_fee_assignments");
    return {
      name: "student_denied_fee_assignments",
      pass: n === 0,
      detail: `visible_assignments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_student_accounts");
    return {
      name: "organization_denied_student_accounts",
      pass: n === 0,
      detail: `visible_accounts=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped read of finance_invoices in
    // its OWN org. Assert it sees NOTHING outside its org.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_invoices WHERE organization_id <> $1",
      [ORG],
    );
    return {
      name: "organization_denied_finance_invoices",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    // Money-loop RLS grants the parent a scoped read of their OWN child's
    // (STUDENT_A) invoices. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_invoices WHERE student_id <> $1",
      [STUDENT_A],
    );
    return {
      name: "parent_denied_finance_invoices",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    // Money-loop RLS grants the student a scoped read of their OWN (STUDENT_A)
    // invoices. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_invoices WHERE student_id <> $1",
      [STUDENT_A],
    );
    return {
      name: "student_denied_finance_invoices",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped read of finance_collections
    // in its OWN org. Assert it sees NOTHING outside its org.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_collections WHERE organization_id <> $1",
      [ORG],
    );
    return {
      name: "organization_denied_collections",
      pass: n === 0,
      detail: `visible_collections=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    // Money-loop RLS grants the parent a scoped read of their OWN child's
    // (STUDENT_A) collections. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_collections WHERE student_id <> $1",
      [STUDENT_A],
    );
    return {
      name: "parent_denied_collections",
      pass: n === 0,
      detail: `visible_collections=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    // Money-loop RLS grants the student a scoped read of their OWN (STUDENT_A)
    // collections. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM finance_collections WHERE student_id <> $1",
      [STUDENT_A],
    );
    return {
      name: "student_denied_collections",
      pass: n === 0,
      detail: `visible_collections=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
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

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    // Money-loop RLS grants the parent a scoped read of their OWN child's
    // (STUDENT_A) invoices. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_invoices
       WHERE invoice_status IN ('issued', 'partially_paid', 'paid')
         AND student_id <> $1`,
      [STUDENT_A],
    );
    return {
      name: "parent_denied_daily_summary",
      pass: n === 0,
      detail: `visible_invoice_summary=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    // Money-loop RLS grants the student a scoped read of their OWN (STUDENT_A)
    // invoices. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_invoices
       WHERE invoice_status IN ('issued', 'partially_paid', 'paid')
         AND student_id <> $1`,
      [STUDENT_A],
    );
    return {
      name: "student_denied_daily_summary",
      pass: n === 0,
      detail: `visible_invoice_summary=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
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

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    // Money-loop RLS grants the student a scoped read of their OWN (STUDENT_A)
    // invoices. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      `SELECT count(*)::text AS count FROM finance_invoices
       WHERE invoice_status != 'cancelled'
         AND student_id <> $1`,
      [STUDENT_A],
    );
    return {
      name: "student_denied_finance_dashboard",
      pass: n === 0,
      detail: `visible_invoices=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_refunds");
    return {
      name: "organization_denied_refunds",
      pass: n === 0,
      detail: `visible_refunds=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_refunds");
    return {
      name: "parent_denied_refunds",
      pass: n === 0,
      detail: `visible_refunds=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM finance_refunds");
    return {
      name: "student_denied_refunds",
      pass: n === 0,
      detail: `visible_refunds=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const rows = await db.queryObject<{
      outstanding: string;
      account_outstanding: string;
      total: string;
    }>(
      `SELECT
         fi.outstanding_amount::text AS outstanding,
         fsa.outstanding_amount::text AS account_outstanding,
         fi.total_amount::text AS total
       FROM finance_refunds fr
       JOIN finance_invoices fi ON fi.id = fr.invoice_id
       JOIN finance_student_accounts fsa ON fsa.id = fr.student_account_id
       WHERE fr.id = $1 AND fr.refund_status = 'processed'`,
      [FINANCE_REFUND_SCHOOL_A_PROCESSED],
    );
    const row = rows[0];
    // Assert the balance-coupling INVARIANT that a processed refund must preserve,
    // NOT an absolute rupee figure (the live pilot invoice sees real payment
    // activity, so the seeded number drifts). The refund path keeps the invoice
    // outstanding and the student-account outstanding in lock-step; if that
    // coupling breaks, or outstanding goes negative / exceeds the invoice total,
    // this fails.
    const invoiceOutstanding = row != null ? parseFloat(row.outstanding) : NaN;
    const accountOutstanding = row != null ? parseFloat(row.account_outstanding) : NaN;
    const invoiceTotal = row != null ? parseFloat(row.total) : NaN;
    const pass = row != null &&
      Number.isFinite(invoiceOutstanding) &&
      Number.isFinite(accountOutstanding) &&
      Number.isFinite(invoiceTotal) &&
      invoiceOutstanding === accountOutstanding &&
      invoiceOutstanding >= 0 &&
      invoiceOutstanding <= invoiceTotal;
    return {
      name: "approved_refund_updates_balances",
      pass,
      detail: row
        ? `invoice_outstanding=${row.outstanding}, account_outstanding=${row.account_outstanding}, invoice_total=${row.total}`
        : "processed_refund_fixture_missing",
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM student_profiles");
    return {
      name: "organization_denied_student_profiles",
      pass: n === 0,
      detail: `visible_profiles=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM student_profiles");
    return {
      name: "parent_denied_student_profiles",
      pass: n === 0,
      detail: `visible_profiles=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, "SELECT count(*)::text AS count FROM student_profiles");
    return {
      name: "student_denied_student_profiles",
      pass: n === 0,
      detail: `visible_profiles=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped read of
    // sis_student_enrollments in its OWN org. Assert it sees NOTHING outside it.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sis_student_enrollments WHERE organization_id <> $1",
      [ORG],
    );
    return {
      name: "organization_denied_sis_enrollments",
      pass: n === 0,
      detail: `visible_enrollments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    // Exam/enrollment RLS grants the parent a scoped read of their OWN child's
    // (STUDENT_A) enrollments. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sis_student_enrollments WHERE student_id <> $1",
      [STUDENT_A],
    );
    return {
      name: "parent_denied_sis_enrollments",
      pass: n === 0,
      detail: `visible_enrollments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    // Exam/enrollment RLS grants the student a scoped read of their OWN
    // (STUDENT_A) enrollment. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sis_student_enrollments WHERE student_id <> $1",
      [STUDENT_A],
    );
    return {
      name: "student_denied_sis_enrollments",
      pass: n === 0,
      detail: `visible_enrollments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "organization_denied_sis_students_api",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "parent_denied_sis_students_api",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "student_denied_sis_students_api",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_STUDENT_DETAIL_PROBE_SQL, [STUDENT_B]);
    return {
      name: "school_a_cannot_fetch_school_b_student_detail",
      pass: n === 0,
      detail: `visible_cross_school_detail=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_STUDENT_CREATE_PROBE_SQL);
    return {
      name: "organization_denied_sis_student_create",
      pass: n === 0,
      detail: `visible_profiles_for_create=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_STUDENT_CREATE_PROBE_SQL);
    return {
      name: "parent_denied_sis_student_create",
      pass: n === 0,
      detail: `visible_profiles_for_create=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_STUDENT_CREATE_PROBE_SQL);
    return {
      name: "student_denied_sis_student_create",
      pass: n === 0,
      detail: `visible_profiles_for_create=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_STUDENT_UPDATE_PROBE_SQL, [STUDENT_B]);
    return {
      name: "school_a_cannot_update_school_b_student",
      pass: n === 0,
      detail: `visible_cross_school_update_target=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped read of the enrollments
    // API join within its OWN org. Scope out the org's own enrollments and assert
    // it sees NOTHING outside it. (SIS_ENROLLMENTS_API_PROBE_SQL has no WHERE.)
    const n = await count(
      db,
      `${SIS_ENROLLMENTS_API_PROBE_SQL} WHERE se.organization_id <> $1`,
      [ORG],
    );
    return {
      name: "organization_denied_sis_enrollments_api",
      pass: n === 0,
      detail: `visible_enrollment_api_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    // Exam/enrollment RLS grants the parent a scoped read of their OWN child's
    // (STUDENT_A) enrollment join. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      `${SIS_ENROLLMENTS_API_PROBE_SQL} WHERE se.student_id <> $1`,
      [STUDENT_A],
    );
    return {
      name: "parent_denied_sis_enrollments_api",
      pass: n === 0,
      detail: `visible_enrollment_api_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    // Exam/enrollment RLS grants the student a scoped read of their OWN
    // (STUDENT_A) enrollment join. Assert they see NOTHING for any other student.
    const n = await count(
      db,
      `${SIS_ENROLLMENTS_API_PROBE_SQL} WHERE se.student_id <> $1`,
      [STUDENT_A],
    );
    return {
      name: "student_denied_sis_enrollments_api",
      pass: n === 0,
      detail: `visible_enrollment_api_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_ENROLLMENT_UPDATE_PROBE_SQL, [SIS_ENROLLMENT_SCHOOL_B]);
    return {
      name: "school_a_cannot_update_school_b_enrollment",
      pass: n === 0,
      detail: `visible_cross_school_enrollment_update=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Director org-rollup RLS grants org-scope a scoped read of admissions
    // conversions within its OWN org. SIS_CONVERSION_PROBE_SQL already filters
    // `WHERE ae.conversion_status = 'pending'`, so AND-in the org exclusion and
    // assert it sees NOTHING outside its org.
    const n = await count(
      db,
      `${SIS_CONVERSION_PROBE_SQL} AND ae.organization_id <> $1`,
      [ORG],
    );
    return {
      name: "organization_denied_admissions_conversion",
      pass: n === 0,
      detail: `visible_pending_conversions=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_CONVERSION_PROBE_SQL);
    return {
      name: "parent_denied_admissions_conversion",
      pass: n === 0,
      detail: `visible_pending_conversions=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_CONVERSION_PROBE_SQL);
    return {
      name: "student_denied_admissions_conversion",
      pass: n === 0,
      detail: `visible_pending_conversions=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_CONVERSION_TARGET_PROBE_SQL, [ADMISSIONS_ENROLLMENT_SCHOOL_B]);
    return {
      name: "school_a_cannot_convert_school_b_enrollment",
      pass: n === 0,
      detail: `visible_cross_school_conversion_target=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
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

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "organization_denied_sis_dashboard",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "parent_denied_sis_dashboard",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, SIS_DIRECTORY_PROBE_SQL);
    return {
      name: "student_denied_sis_dashboard",
      pass: n === 0,
      detail: `visible_directory_rows=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM students WHERE school_id = $1",
      [SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_sis_dashboard",
      pass: n >= 1,
      detail: `visible_school_a_students=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_YEARS_PROBE_SQL);
    return {
      name: "organization_denied_academic_years",
      pass: n === 0,
      detail: `visible_academic_years=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_YEARS_PROBE_SQL);
    return {
      name: "parent_denied_academic_years",
      pass: n === 0,
      detail: `visible_academic_years=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_YEARS_PROBE_SQL);
    return {
      name: "student_denied_academic_years",
      pass: n === 0,
      detail: `visible_academic_years=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM academic_years WHERE id = $1",
      [ACADEMIC_YEAR_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_academic_years",
      pass: n === 0,
      detail: `visible_cross_school_year=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM academic_years WHERE id = $1",
      [ACADEMIC_YEAR_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_academic_years",
      pass: n === 1,
      detail: `visible_probe_year=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_CLASSES_PROBE_SQL);
    return {
      name: "organization_denied_academic_classes",
      pass: n === 0,
      detail: `visible_classes=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_CLASSES_PROBE_SQL);
    return {
      name: "parent_denied_academic_classes",
      pass: n === 0,
      detail: `visible_classes=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_CLASSES_PROBE_SQL);
    return {
      name: "student_denied_academic_classes",
      pass: n === 0,
      detail: `visible_classes=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM classes WHERE id = $1",
      [ACADEMIC_CLASS_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_academic_classes",
      pass: n === 0,
      detail: `visible_cross_school_class=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM classes WHERE id = $1",
      [ACADEMIC_CLASS_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_academic_classes",
      pass: n === 1,
      detail: `visible_probe_class=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_SECTIONS_PROBE_SQL);
    return {
      name: "organization_denied_academic_sections",
      pass: n === 0,
      detail: `visible_sections=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_SECTIONS_PROBE_SQL);
    return {
      name: "parent_denied_academic_sections",
      pass: n === 0,
      detail: `visible_sections=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_SECTIONS_PROBE_SQL);
    return {
      name: "student_denied_academic_sections",
      pass: n === 0,
      detail: `visible_sections=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sections WHERE id = $1",
      [ACADEMIC_SECTION_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_academic_sections",
      pass: n === 0,
      detail: `visible_cross_school_section=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM sections WHERE id = $1",
      [ACADEMIC_SECTION_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_academic_sections",
      pass: n === 1,
      detail: `visible_probe_section=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL);
    return {
      name: "organization_denied_academic_teacher_assignments",
      pass: n === 0,
      detail: `visible_teacher_assignments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL);
    return {
      name: "parent_denied_academic_teacher_assignments",
      pass: n === 0,
      detail: `visible_teacher_assignments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_TEACHER_ASSIGNMENTS_PROBE_SQL);
    return {
      name: "student_denied_academic_teacher_assignments",
      pass: n === 0,
      detail: `visible_teacher_assignments=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM teacher_assignments WHERE id = $1",
      [ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_see_school_b_academic_teacher_assignments",
      pass: n === 0,
      detail: `visible_cross_school_assignment=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      "SELECT count(*)::text AS count FROM teacher_assignments WHERE id = $1",
      [ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_A],
    );
    return {
      name: "school_a_sees_own_academic_teacher_assignments",
      pass: n === 1,
      detail: `visible_probe_assignment=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_YEARS_API_PROBE_SQL);
    return {
      name: "organization_denied_academic_years_api",
      pass: n === 0,
      detail: `visible_academic_years_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_YEARS_API_PROBE_SQL);
    return {
      name: "parent_denied_academic_years_api",
      pass: n === 0,
      detail: `visible_academic_years_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_YEARS_API_PROBE_SQL);
    return {
      name: "student_denied_academic_years_api",
      pass: n === 0,
      detail: `visible_academic_years_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_YEAR_DETAIL_PROBE_SQL, [ACADEMIC_YEAR_SCHOOL_B]);
    return {
      name: "school_a_cannot_fetch_school_b_academic_year",
      pass: n === 0,
      detail: `visible_cross_school_year_detail=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_CLASSES_API_PROBE_SQL);
    return {
      name: "organization_denied_academic_classes_api",
      pass: n === 0,
      detail: `visible_classes_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_CLASSES_API_PROBE_SQL);
    return {
      name: "parent_denied_academic_classes_api",
      pass: n === 0,
      detail: `visible_classes_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_CLASSES_API_PROBE_SQL);
    return {
      name: "student_denied_academic_classes_api",
      pass: n === 0,
      detail: `visible_classes_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_CLASS_DETAIL_PROBE_SQL, [ACADEMIC_CLASS_SCHOOL_B]);
    return {
      name: "school_a_cannot_fetch_school_b_class",
      pass: n === 0,
      detail: `visible_cross_school_class_detail=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_SECTIONS_API_PROBE_SQL);
    return {
      name: "organization_denied_academic_sections_api",
      pass: n === 0,
      detail: `visible_sections_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_SECTIONS_API_PROBE_SQL);
    return {
      name: "parent_denied_academic_sections_api",
      pass: n === 0,
      detail: `visible_sections_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_SECTIONS_API_PROBE_SQL);
    return {
      name: "student_denied_academic_sections_api",
      pass: n === 0,
      detail: `visible_sections_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_SECTION_DETAIL_PROBE_SQL, [ACADEMIC_SECTION_SCHOOL_B]);
    return {
      name: "school_a_cannot_fetch_school_b_section",
      pass: n === 0,
      detail: `visible_cross_school_section_detail=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL);
    return {
      name: "organization_denied_academic_teacher_assignments_api",
      pass: n === 0,
      detail: `visible_teacher_assignments_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL);
    return {
      name: "parent_denied_academic_teacher_assignments_api",
      pass: n === 0,
      detail: `visible_teacher_assignments_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, ACADEMIC_TEACHER_ASSIGNMENTS_API_PROBE_SQL);
    return {
      name: "student_denied_academic_teacher_assignments_api",
      pass: n === 0,
      detail: `visible_teacher_assignments_api=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(
      db,
      ACADEMIC_TEACHER_ASSIGNMENT_DETAIL_PROBE_SQL,
      [ACADEMIC_TEACHER_ASSIGNMENT_SCHOOL_B],
    );
    return {
      name: "school_a_cannot_fetch_school_b_teacher_assignment",
      pass: n === 0,
      detail: `visible_cross_school_assignment_detail=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, TRANSPORT_ROUTES_API_PROBE_SQL);
    return {
      name: "organization_denied_transport_routes_api",
      pass: n === 0,
      detail: `visible_transport_routes=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TRANSPORT_ROUTES_API_PROBE_SQL);
    return {
      name: "parent_denied_transport_routes_api",
      pass: n === 0,
      detail: `visible_transport_routes=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TRANSPORT_ROUTE_DETAIL_PROBE_SQL, [TRANSPORT_ROUTE_SCHOOL_B]);
    return {
      name: "school_a_cannot_see_school_b_transport_route",
      pass: n === 0,
      detail: `visible_cross_school_route=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TRANSPORT_ROUTE_DETAIL_PROBE_SQL, [TRANSPORT_ROUTE_SCHOOL_A]);
    return {
      name: "school_a_sees_own_transport_route",
      pass: n === 1,
      detail: `visible_probe_route=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, HR_EMPLOYEES_API_PROBE_SQL);
    return {
      name: "organization_denied_hr_employees_api",
      pass: n === 0,
      detail: `visible_hr_employees=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HR_EMPLOYEES_API_PROBE_SQL);
    return {
      name: "parent_denied_hr_employees_api",
      pass: n === 0,
      detail: `visible_hr_employees=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HR_EMPLOYEE_DETAIL_PROBE_SQL, [HR_EMPLOYEE_SCHOOL_B]);
    return {
      name: "school_a_cannot_see_school_b_hr_employee",
      pass: n === 0,
      detail: `visible_cross_school_employee=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HR_EMPLOYEE_DETAIL_PROBE_SQL, [HR_EMPLOYEE_SCHOOL_A]);
    return {
      name: "school_a_sees_own_hr_employee",
      pass: n === 1,
      detail: `visible_probe_employee=${n}`,
    };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, HOSTEL_STUDENTS_API_PROBE_SQL);
    return { name: "organization_denied_hostel_students_api", pass: n === 0, detail: `visible_hostel_students=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HOSTEL_STUDENTS_API_PROBE_SQL);
    return { name: "parent_denied_hostel_students_api", pass: n === 0, detail: `visible_hostel_students=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HOSTEL_STUDENT_DETAIL_PROBE_SQL, [HOSTEL_STUDENT_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_hostel_student", pass: n === 0, detail: `visible_cross_school_hostel_student=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HOSTEL_STUDENT_DETAIL_PROBE_SQL, [HOSTEL_STUDENT_SCHOOL_A]);
    return { name: "school_a_sees_own_hostel_student", pass: n === 1, detail: `visible_probe_hostel_student=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, LIBRARY_CATALOG_API_PROBE_SQL);
    return { name: "organization_denied_library_catalog_api", pass: n === 0, detail: `visible_library_catalog=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, LIBRARY_CATALOG_API_PROBE_SQL);
    return { name: "parent_denied_library_catalog_api", pass: n === 0, detail: `visible_library_catalog=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, LIBRARY_CATALOG_DETAIL_PROBE_SQL, [LIBRARY_BOOK_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_library_book", pass: n === 0, detail: `visible_cross_school_book=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, LIBRARY_CATALOG_DETAIL_PROBE_SQL, [LIBRARY_BOOK_SCHOOL_A]);
    return { name: "school_a_sees_own_library_book", pass: n === 1, detail: `visible_probe_book=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, INVENTORY_ASSETS_API_PROBE_SQL);
    return { name: "organization_denied_inventory_assets_api", pass: n === 0, detail: `visible_inventory_assets=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INVENTORY_ASSETS_API_PROBE_SQL);
    return { name: "parent_denied_inventory_assets_api", pass: n === 0, detail: `visible_inventory_assets=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INVENTORY_ASSET_DETAIL_PROBE_SQL, [INVENTORY_ASSET_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_inventory_asset", pass: n === 0, detail: `visible_cross_school_asset=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INVENTORY_ASSET_DETAIL_PROBE_SQL, [INVENTORY_ASSET_SCHOOL_A]);
    return { name: "school_a_sees_own_inventory_asset", pass: n === 1, detail: `visible_probe_asset=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ALUMNI_REGISTRY_API_PROBE_SQL);
    return { name: "organization_denied_alumni_registry_api", pass: n === 0, detail: `visible_alumni_registry=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ALUMNI_REGISTRY_API_PROBE_SQL);
    return { name: "parent_denied_alumni_registry_api", pass: n === 0, detail: `visible_alumni_registry=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ALUMNI_REGISTRY_DETAIL_PROBE_SQL, [ALUMNI_RECORD_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_alumni_record", pass: n === 0, detail: `visible_cross_school_alumni=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ALUMNI_REGISTRY_DETAIL_PROBE_SQL, [ALUMNI_RECORD_SCHOOL_A]);
    return { name: "school_a_sees_own_alumni_record", pass: n === 1, detail: `visible_probe_alumni=${n}` };
  }));

  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, MANAGEMENT_PROBE_DETAIL_SQL, [MANAGEMENT_PROBE_SCHOOL_A]);
    return { name: "organization_denied_management_probe", pass: n === 0, detail: `visible_management_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, MANAGEMENT_PROBE_DETAIL_SQL, [MANAGEMENT_PROBE_SCHOOL_A]);
    return { name: "parent_denied_management_probe", pass: n === 0, detail: `visible_management_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, MANAGEMENT_PROBE_DETAIL_SQL, [MANAGEMENT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_management_probe", pass: n === 0, detail: `visible_cross_school_mgmt=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, MANAGEMENT_PROBE_DETAIL_SQL, [MANAGEMENT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_management_probe", pass: n === 1, detail: `visible_probe_mgmt=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, CONTROL_CENTER_SCHOOLS_API_PROBE_SQL);
    return { name: "school_scope_denied_control_center_schools", pass: n === 0, detail: `visible_cc_schools=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, CONTROL_CENTER_SCHOOLS_API_PROBE_SQL);
    return { name: "parent_denied_control_center_schools", pass: n === 0, detail: `visible_cc_schools=${n}` };
  }));
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, CONTROL_CENTER_SCHOOL_DETAIL_PROBE_SQL, [CONTROL_CENTER_SCHOOL_A]);
    return { name: "org_sees_control_center_platform_school", pass: n === 1, detail: `visible_cc_school=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, CONTROL_CENTER_SCHOOL_DETAIL_PROBE_SQL, [CONTROL_CENTER_SCHOOL_A]);
    return { name: "school_scope_denied_control_center_school_detail", pass: n === 0, detail: `visible_cc_detail=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PARENT_PROBE_DETAIL_SQL, [PARENT_PROBE_SCHOOL_A]);
    return { name: "school_scope_denied_parent_probe", pass: n === 0, detail: `visible_parent_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PARENT_PROBE_DETAIL_SQL, [PARENT_PROBE_SCHOOL_B]);
    return { name: "parent_a_cannot_see_school_b_parent_probe", pass: n === 0, detail: `visible_cross_school_parent=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PARENT_PROBE_DETAIL_SQL, [PARENT_PROBE_SCHOOL_A]);
    return { name: "parent_a_sees_own_parent_probe", pass: n === 1, detail: `visible_parent_probe=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, STUDENT_PROBE_DETAIL_SQL, [STUDENT_PROBE_SCHOOL_A]);
    return { name: "school_scope_denied_student_probe", pass: n === 0, detail: `visible_student_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, STUDENT_PROBE_DETAIL_SQL, [STUDENT_PROBE_SCHOOL_B]);
    return { name: "student_a_cannot_see_school_b_student_probe", pass: n === 0, detail: `visible_cross_school_student=${n}` };
  }));
  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, STUDENT_PROBE_DETAIL_SQL, [STUDENT_PROBE_SCHOOL_A]);
    return { name: "student_a_sees_own_student_probe", pass: n === 1, detail: `visible_student_probe=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TEACHER_PROBE_DETAIL_SQL, [TEACHER_PROBE_SCHOOL_A]);
    return { name: "parent_denied_teacher_probe", pass: n === 0, detail: `visible_teacher_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(teacherClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TEACHER_PROBE_DETAIL_SQL, [TEACHER_PROBE_SCHOOL_B]);
    return { name: "teacher_a_cannot_see_school_b_teacher_probe", pass: n === 0, detail: `visible_cross_school_teacher=${n}` };
  }));
  tasks.push(() => runWithClaims(teacherClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TEACHER_PROBE_DETAIL_SQL, [TEACHER_PROBE_SCHOOL_A]);
    return { name: "teacher_a_sees_own_teacher_probe", pass: n === 1, detail: `visible_teacher_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(teacherClaims(SCHOOL_A, STAFF_A2_SAME_SCHOOL), async (db) => {
    const n = await count(db, TEACHER_PROBE_DETAIL_SQL, [TEACHER_PROBE_SCHOOL_A]);
    return { name: "teacher_b_cannot_see_other_teacher_probe_same_school", pass: n === 0, detail: `visible_other_teacher_probe=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AUDIT_PROBE_DETAIL_SQL, [AUDIT_PROBE_SCHOOL_A]);
    return { name: "parent_denied_audit_probe", pass: n === 0, detail: `visible_audit_probe=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AUDIT_PROBE_DETAIL_SQL, [AUDIT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_audit_probe", pass: n === 0, detail: `visible_cross_school_audit=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AUDIT_PROBE_DETAIL_SQL, [AUDIT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_audit_probe", pass: n === 1, detail: `visible_audit_probe=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, DOMAIN_EVENT_PROBE_DETAIL_SQL, [DOMAIN_EVENT_PROBE_SCHOOL_A]);
    return { name: "parent_denied_domain_event_probe", pass: n === 0, detail: `visible_domain_event=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, DOMAIN_EVENT_PROBE_DETAIL_SQL, [DOMAIN_EVENT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_domain_event", pass: n === 0, detail: `visible_cross_school_domain=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, DOMAIN_EVENT_PROBE_DETAIL_SQL, [DOMAIN_EVENT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_domain_event_probe", pass: n === 1, detail: `visible_domain_event=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PAYMENT_INTENT_PROBE_DETAIL_SQL, [PAYMENT_INTENT_PROBE_SCHOOL_B]);
    return { name: "parent_a_cannot_see_school_b_payment_intent", pass: n === 0, detail: `visible_cross_school_payment=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PAYMENT_INTENT_PROBE_DETAIL_SQL, [PAYMENT_INTENT_PROBE_SCHOOL_A]);
    return { name: "parent_a_sees_own_payment_intent", pass: n === 1, detail: `visible_payment_intent=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PAYMENT_INTENT_PROBE_DETAIL_SQL, [PAYMENT_INTENT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_payment_intent", pass: n === 0, detail: `visible_cross_school_payment=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PAYMENT_INTENT_PROBE_DETAIL_SQL, [PAYMENT_INTENT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_payment_intent", pass: n === 1, detail: `visible_payment_intent=${n}` };
  }));
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, PAYMENT_INTENT_PROBE_DETAIL_SQL, [PAYMENT_INTENT_PROBE_SCHOOL_A]);
    return { name: "organization_denied_payment_intent_probe", pass: n === 0, detail: `visible_payment_intent=${n}` };
  }));
  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, PAYMENT_INTENT_PROBE_DETAIL_SQL, [PAYMENT_INTENT_PROBE_SCHOOL_A]);
    return { name: "student_denied_payment_intent_probe", pass: n === 0, detail: `visible_payment_intent=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, NOTIFICATION_DELIVERY_PROBE_DETAIL_SQL, [NOTIFICATION_DELIVERY_PROBE_SCHOOL_B]);
    return { name: "parent_a_cannot_see_school_b_notification", pass: n === 0, detail: `visible_cross_school_notification=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, NOTIFICATION_DELIVERY_PROBE_DETAIL_SQL, [NOTIFICATION_DELIVERY_PROBE_SCHOOL_A]);
    return { name: "parent_a_sees_own_notification", pass: n === 1, detail: `visible_notification=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, COMM_THREAD_PROBE_DETAIL_SQL, [COMM_THREAD_PROBE_SCHOOL_B]);
    return { name: "parent_a_cannot_see_school_b_comm_thread", pass: n === 0, detail: `visible_cross_school_thread=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, COMM_THREAD_PROBE_DETAIL_SQL, [COMM_THREAD_PROBE_SCHOOL_A]);
    return { name: "parent_a_sees_own_comm_thread", pass: n === 1, detail: `visible_comm_thread=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, COMM_THREAD_PROBE_DETAIL_SQL, [COMM_THREAD_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_comm_thread", pass: n === 0, detail: `visible_cross_school_thread=${n}` };
  }));
  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, NOTIFICATION_DELIVERY_PROBE_DETAIL_SQL, [NOTIFICATION_DELIVERY_PROBE_SCHOOL_A]);
    return { name: "student_denied_parent_notification_probe", pass: n === 0, detail: `visible_notification=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ATTENDANCE_SESSION_PROBE_DETAIL_SQL, [ATTENDANCE_SESSION_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_attendance_session_probe", pass: n === 1, detail: `visible_attendance_session=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ATTENDANCE_SESSION_PROBE_DETAIL_SQL, [ATTENDANCE_SESSION_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_attendance_session", pass: n === 0, detail: `visible_cross_school_attendance=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ATTENDANCE_SESSION_PROBE_DETAIL_SQL, [ATTENDANCE_SESSION_PROBE_SCHOOL_B]);
    return { name: "parent_denied_attendance_session_probe", pass: n === 0, detail: `visible_attendance_session=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TIMETABLE_SLOT_PROBE_DETAIL_SQL, [TIMETABLE_SLOT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_timetable_slot_probe", pass: n === 1, detail: `visible_timetable_slot=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, TIMETABLE_SLOT_PROBE_DETAIL_SQL, [TIMETABLE_SLOT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_timetable_slot", pass: n === 0, detail: `visible_cross_school_timetable=${n}` };
  }));
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, TIMETABLE_SLOT_PROBE_DETAIL_SQL, [TIMETABLE_SLOT_PROBE_SCHOOL_A]);
    return { name: "organization_denied_timetable_slot_probe", pass: n === 0, detail: `visible_timetable_slot=${n}` };
  }));

  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, MOBILE_LEAVE_PROBE_DETAIL_SQL, [MOBILE_LEAVE_PROBE_SCHOOL_A]);
    return { name: "parent_a_sees_own_mobile_leave_probe", pass: n === 1, detail: `visible_mobile_leave=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, MOBILE_LEAVE_PROBE_DETAIL_SQL, [MOBILE_LEAVE_PROBE_SCHOOL_B]);
    return { name: "parent_a_cannot_see_school_b_mobile_leave", pass: n === 0, detail: `visible_cross_school_leave=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_B), async (db) => {
    const n = await count(db, MOBILE_LEAVE_PROBE_DETAIL_SQL, [MOBILE_LEAVE_PROBE_SCHOOL_A]);
    return { name: "school_b_cannot_see_school_a_mobile_leave", pass: n === 0, detail: `visible_cross_school_leave=${n}` };
  }));

  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, HOMEWORK_SUBMISSION_PROBE_DETAIL_SQL, [HOMEWORK_SUBMISSION_PROBE_SCHOOL_A]);
    return { name: "student_a_sees_own_homework_submission_probe", pass: n === 1, detail: `visible_homework_submission=${n}` };
  }));
  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, HOMEWORK_SUBMISSION_PROBE_DETAIL_SQL, [HOMEWORK_SUBMISSION_PROBE_SCHOOL_B]);
    return { name: "student_a_cannot_see_school_b_homework_submission", pass: n === 0, detail: `visible_cross_school_homework=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, HOMEWORK_SUBMISSION_PROBE_DETAIL_SQL, [HOMEWORK_SUBMISSION_PROBE_SCHOOL_B]);
    return { name: "parent_denied_homework_submission_probe", pass: n === 0, detail: `visible_homework_submission=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, EXAM_MARK_PROBE_DETAIL_SQL, [EXAM_MARK_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_exam_mark_probe", pass: n === 1, detail: `visible_exam_mark=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, EXAM_MARK_PROBE_DETAIL_SQL, [EXAM_MARK_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_exam_mark", pass: n === 0, detail: `visible_cross_school_exam_mark=${n}` };
  }));
  tasks.push(() => runWithClaims(studentClaims(), async (db) => {
    const n = await count(db, EXAM_MARK_PROBE_DETAIL_SQL, [EXAM_MARK_PROBE_SCHOOL_A]);
    return { name: "student_denied_exam_mark_probe", pass: n === 0, detail: `visible_exam_mark=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ONBOARDING_IMPORT_JOB_PROBE_SQL, [ONBOARDING_IMPORT_JOB_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_onboarding_import_probe", pass: n === 1, detail: `visible_import_job=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ONBOARDING_IMPORT_JOB_PROBE_SQL, [ONBOARDING_IMPORT_JOB_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_onboarding_import", pass: n === 0, detail: `visible_cross_import_job=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ONBOARDING_INVITE_PROBE_SQL, [ONBOARDING_INVITE_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_onboarding_invite_probe", pass: n === 1, detail: `visible_invite=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ONBOARDING_INVITE_PROBE_SQL, [ONBOARDING_INVITE_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_onboarding_invite", pass: n === 0, detail: `visible_cross_invite=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INVENTORY_VENDOR_PROBE_SQL, [INVENTORY_VENDOR_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_inventory_vendor_probe", pass: n === 1, detail: `visible_vendor=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INVENTORY_VENDOR_PROBE_SQL, [INVENTORY_VENDOR_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_inventory_vendor", pass: n === 0, detail: `visible_cross_vendor=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PURCHASE_ORDER_PROBE_SQL, [PURCHASE_ORDER_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_purchase_order_probe", pass: n === 1, detail: `visible_po=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PURCHASE_ORDER_PROBE_SQL, [PURCHASE_ORDER_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_purchase_order", pass: n === 0, detail: `visible_cross_po=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AP_COMMITMENT_PROBE_SQL, [AP_COMMITMENT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_ap_commitment_probe", pass: n === 1, detail: `visible_ap=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AP_COMMITMENT_PROBE_SQL, [AP_COMMITMENT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_ap_commitment", pass: n === 0, detail: `visible_cross_ap=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PAYMENT_WEBHOOK_PROBE_DETAIL_SQL, [PAYMENT_WEBHOOK_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_payment_webhook_probe", pass: n === 1, detail: `visible_webhook=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, PAYMENT_WEBHOOK_PROBE_DETAIL_SQL, [PAYMENT_WEBHOOK_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_payment_webhook", pass: n === 0, detail: `visible_cross_webhook=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AI_COPILOT_SESSION_PROBE_SQL, [AI_COPILOT_SESSION_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_ai_copilot_session_probe", pass: n === 1, detail: `visible_copilot_session=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, AI_COPILOT_SESSION_PROBE_SQL, [AI_COPILOT_SESSION_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_ai_copilot_session", pass: n === 0, detail: `visible_cross_copilot_session=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_TIMETABLE_PROBE_SQL, [ACADEMIC_TIMETABLE_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_academic_timetable_probe", pass: n === 1, detail: `visible_timetable=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ACADEMIC_TIMETABLE_PROBE_SQL, [ACADEMIC_TIMETABLE_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_academic_timetable", pass: n === 0, detail: `visible_cross_timetable=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ANALYTICS_SNAPSHOT_PROBE_SQL, [ANALYTICS_SNAPSHOT_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_analytics_snapshot_probe", pass: n === 1, detail: `visible_analytics_snapshot=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ANALYTICS_SNAPSHOT_PROBE_SQL, [ANALYTICS_SNAPSHOT_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_analytics_snapshot", pass: n === 0, detail: `visible_cross_analytics_snapshot=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, EDU_QUESTION_BANK_PROBE_SQL, [EDU_QUESTION_BANK_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_education_question_bank_probe", pass: n === 1, detail: `visible_edu_bank=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, EDU_QUESTION_BANK_PROBE_SQL, [EDU_QUESTION_BANK_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_education_question_bank", pass: n === 0, detail: `visible_cross_edu_bank=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, EDU_QUESTION_BANK_API_PROBE_SQL);
    return { name: "parent_denied_education_question_bank_api", pass: n === 0, detail: `visible_edu_bank_api=${n}` };
  }));

  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INTEL_RISK_PROBE_SQL, [INTEL_RISK_PROBE_SCHOOL_A]);
    return { name: "school_a_sees_own_intel_risk_probe", pass: n === 1, detail: `visible_intel_risk=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INTEL_RISK_PROBE_SQL, [INTEL_RISK_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_intel_risk", pass: n === 0, detail: `visible_cross_intel_risk=${n}` };
  }));
  tasks.push(() => runWithClaims(parentClaims(SCHOOL_A), async (db) => {
    const n = await count(db, INTEL_RISK_API_PROBE_SQL);
    return { name: "parent_denied_intel_risk_api", pass: n === 0, detail: `visible_intel_risk_api=${n}` };
  }));

  // ── Per-school branding isolation (QA-R-004) ───────────────────────────────
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    // Assert school-scope reads its OWN branding by natural key (school_id). The
    // real row's id varies, so key on school_id — never a synthetic fixture id.
    const n = await count(db, "SELECT count(*)::text AS count FROM school_branding WHERE school_id = $1", [SCHOOL_A]);
    return { name: "school_a_sees_own_branding", pass: n >= 1, detail: `visible_branding=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SCHOOL_BRANDING_PROBE_SQL, [SCHOOL_BRANDING_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_branding", pass: n === 0, detail: `visible_cross_school_branding=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_B), async (db) => {
    const n = await count(db, SCHOOL_BRANDING_PROBE_SQL, [SCHOOL_BRANDING_PROBE_SCHOOL_A]);
    return { name: "school_b_cannot_see_school_a_branding", pass: n === 0, detail: `visible_cross_school_branding=${n}` };
  }));
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SCHOOL_BRANDING_PROBE_SQL, [SCHOOL_BRANDING_PROBE_SCHOOL_A]);
    return { name: "organization_denied_school_branding", pass: n === 0, detail: `visible_branding=${n}` };
  }));

  // ── Per-school configuration isolation (QA-R-004) ──────────────────────────
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    // Assert school-scope reads its OWN configuration by natural key (school_id).
    const n = await count(db, "SELECT count(*)::text AS count FROM school_configuration WHERE school_id = $1", [SCHOOL_A]);
    return { name: "school_a_sees_own_configuration", pass: n >= 1, detail: `visible_configuration=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, SCHOOL_CONFIGURATION_PROBE_SQL, [SCHOOL_CONFIGURATION_PROBE_SCHOOL_B]);
    return { name: "school_a_cannot_see_school_b_configuration", pass: n === 0, detail: `visible_cross_school_configuration=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_B), async (db) => {
    const n = await count(db, SCHOOL_CONFIGURATION_PROBE_SQL, [SCHOOL_CONFIGURATION_PROBE_SCHOOL_A]);
    return { name: "school_b_cannot_see_school_a_configuration", pass: n === 0, detail: `visible_cross_school_configuration=${n}` };
  }));
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, SCHOOL_CONFIGURATION_PROBE_SQL, [SCHOOL_CONFIGURATION_PROBE_SCHOOL_A]);
    return { name: "organization_denied_school_configuration", pass: n === 0, detail: `visible_configuration=${n}` };
  }));

  // ── Per-org subscription isolation (QA-R-003) ──────────────────────────────
  // organization_subscriptions is org-keyed (no school_id): both probe schools
  // share org A's single subscription row, so the isolation axis is org A vs
  // org B. A claim in org A must never read org B's subscription row.
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    // Assert org-scope reads its OWN subscription by natural key (organization_id).
    const n = await count(db, "SELECT count(*)::text AS count FROM organization_subscriptions WHERE organization_id = $1", [ORG]);
    return { name: "org_a_sees_own_subscription", pass: n >= 1, detail: `visible_subscription=${n}` };
  }));
  tasks.push(() => runWithClaims(orgClaims(), async (db) => {
    const n = await count(db, ORGANIZATION_SUBSCRIPTION_PROBE_SQL, [SUBSCRIPTION_PROBE_ORG_B_ROW]);
    return { name: "org_a_cannot_see_org_b_subscription", pass: n === 0, detail: `visible_cross_org_subscription=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    // Assert school-scope reads its OWN org's subscription by natural key.
    const n = await count(db, "SELECT count(*)::text AS count FROM organization_subscriptions WHERE organization_id = $1", [ORG]);
    return { name: "school_a_sees_own_org_subscription", pass: n >= 1, detail: `visible_subscription=${n}` };
  }));
  tasks.push(() => runWithClaims(schoolClaims(SCHOOL_A), async (db) => {
    const n = await count(db, ORGANIZATION_SUBSCRIPTION_PROBE_SQL, [SUBSCRIPTION_PROBE_ORG_B_ROW]);
    return { name: "school_a_cannot_see_org_b_subscription", pass: n === 0, detail: `visible_cross_org_subscription=${n}` };
  }));
  tasks.push(() => runWithClaims(orgBClaims(), async (db) => {
    const n = await count(db, ORGANIZATION_SUBSCRIPTION_PROBE_SQL, [SUBSCRIPTION_PROBE_ORG_A_ROW]);
    return { name: "org_b_cannot_see_org_a_subscription", pass: n === 0, detail: `visible_cross_org_subscription=${n}` };
  }));

  const tests = await runProbeTasks(tasks);
  const pass = tests.every((t) => t.pass);
  return { pass, enforced: true, role: "erp_tenant", tests };
}
