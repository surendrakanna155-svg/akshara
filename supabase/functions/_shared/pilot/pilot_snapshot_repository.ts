import type { TenantQueryClient } from "../tenant_db.ts";
import { listPublishedResultsForStudent } from "../academics/exam_administration/exam_administration_repository.ts";
import { periodTimeRange } from "./pilot_operations_shared.ts";

const TIMETABLE_DAY_META = [
  { id: "mon", shortLabel: "Mon", fullLabel: "Monday", dayOfWeek: 1 },
  { id: "tue", shortLabel: "Tue", fullLabel: "Tuesday", dayOfWeek: 2 },
  { id: "wed", shortLabel: "Wed", fullLabel: "Wednesday", dayOfWeek: 3 },
  { id: "thu", shortLabel: "Thu", fullLabel: "Thursday", dayOfWeek: 4 },
  { id: "fri", shortLabel: "Fri", fullLabel: "Friday", dayOfWeek: 5 },
  { id: "sat", shortLabel: "Sat", fullLabel: "Saturday", dayOfWeek: 6 },
  { id: "sun", shortLabel: "Sun", fullLabel: "Sunday", dayOfWeek: 7 },
] as const;

function mondayOfCurrentWeek(reference = new Date()): Date {
  const date = new Date(Date.UTC(reference.getUTCFullYear(), reference.getUTCMonth(), reference.getUTCDate()));
  const weekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
  date.setUTCDate(date.getUTCDate() - (weekday - 1));
  return date;
}

function formatIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function weekRangeLabel(reference = new Date()): string {
  const monday = mondayOfCurrentWeek(reference);
  const friday = new Date(monday);
  friday.setUTCDate(friday.getUTCDate() + 4);
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${monday.getUTCDate()}–${friday.getUTCDate()} ${monthNames[friday.getUTCMonth()]}`;
}

export type TimetableViewScope = "parent" | "student" | "teacher";

async function loadTimetableSlotRows(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  filter: { classLabel?: string; teacherUserId?: string },
): Promise<Array<{
  day_of_week: number;
  period_number: number;
  subject_label: string;
  room_label: string | null;
  class_label: string;
  substitute_teacher_user_id: string | null;
  teacher_name: string | null;
}>> {
  return await db.queryObject<{
    day_of_week: number;
    period_number: number;
    subject_label: string;
    room_label: string | null;
    class_label: string;
    substitute_teacher_user_id: string | null;
    teacher_name: string | null;
  }>(
    `SELECT ts.day_of_week, ts.period_number, ts.subject_label, ts.room_label, ts.class_label,
            ts.substitute_teacher_user_id, u.display_name AS teacher_name
     FROM timetable_slots ts
     LEFT JOIN users u ON u.id = COALESCE(ts.substitute_teacher_user_id, ts.teacher_user_id)
     WHERE ts.organization_id = $1 AND ts.school_id = $2
       AND ($3::text IS NULL OR ts.class_label = $3)
       AND (
         $4::uuid IS NULL
         OR ts.teacher_user_id = $4
         OR ts.substitute_teacher_user_id = $4
       )
     ORDER BY ts.day_of_week, ts.period_number`,
    [orgId, schoolId, filter.classLabel ?? null, filter.teacherUserId ?? null],
  );
}

export async function overlayTimetableSnapshotFromSlots(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  snapshot: Record<string, unknown>,
  options: {
    view: TimetableViewScope;
    classLabel?: string;
    teacherUserId?: string;
  },
): Promise<Record<string, unknown>> {
  const classLabel = options.classLabel ??
    String(snapshot.childClass ?? snapshot.classLabel ?? "");
  const rows = await loadTimetableSlotRows(db, orgId, schoolId, {
    classLabel: options.view === "teacher" ? undefined : (classLabel || undefined),
    teacherUserId: options.view === "teacher" ? options.teacherUserId : undefined,
  });

  if (rows.length === 0) {
    return snapshot;
  }

  const todayIso = formatIsoDate(new Date());
  const monday = mondayOfCurrentWeek();
  const slotsByDay = new Map<number, typeof rows>();
  for (const row of rows) {
    const bucket = slotsByDay.get(row.day_of_week) ?? [];
    bucket.push(row);
    slotsByDay.set(row.day_of_week, bucket);
  }

  const days: Record<string, unknown>[] = [];
  let totalPeriods = 0;
  const completedToday = 0;
  let upcomingToday = 0;

  for (const meta of TIMETABLE_DAY_META) {
    const daySlots = slotsByDay.get(meta.dayOfWeek) ?? [];
    if (daySlots.length === 0) continue;

    const dayDate = new Date(monday);
    dayDate.setUTCDate(dayDate.getUTCDate() + (meta.dayOfWeek - 1));
    const dateIso = formatIsoDate(dayDate);
    const isToday = dateIso === todayIso;

    const periods: Record<string, unknown>[] = [];
    for (const slot of daySlots) {
      totalPeriods += 1;
      const status = "upcoming";
      if (isToday) upcomingToday += 1;

      const basePeriod = {
        id: `${meta.id}-p${slot.period_number}`,
        periodLabel: `Period ${slot.period_number}`,
        timeRange: periodTimeRange(slot.period_number),
        subject: slot.subject_label,
        roomLabel: slot.room_label ?? "",
        status,
      };

      periods.push(
        options.view === "teacher"
          ? { ...basePeriod, classLabel: slot.class_label }
          : {
            ...basePeriod,
            teacherName: slot.teacher_name ?? "Teacher",
            isRoomChanged: slot.substitute_teacher_user_id != null,
          },
      );
    }

    days.push({
      id: meta.id,
      shortLabel: meta.shortLabel,
      fullLabel: meta.fullLabel,
      date: dateIso,
      isSelected: isToday,
      isToday,
      periods,
    });
  }

  const merged: Record<string, unknown> = {
    ...snapshot,
    weekRangeLabel: weekRangeLabel(),
    days,
  };

  if (options.view !== "teacher") {
    merged.totalPeriodsThisWeek = totalPeriods;
    merged.completedPeriodsToday = completedToday;
    merged.upcomingPeriodsToday = upcomingToday;
  }

  return merged;
}

export interface ParentSnapshotContext {
  childName: string;
  childClass: string;
}

export async function loadStudentParentSnapshotContext(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<ParentSnapshotContext> {
  const rows = await db.queryObject<{
    display_name: string;
    class_name: string | null;
    section_name: string | null;
  }>(
    `SELECT s.display_name, e.class_name, e.section_name
     FROM students s
     LEFT JOIN sis_student_enrollments e
       ON e.student_id = s.id
      AND e.organization_id = s.organization_id
      AND e.school_id = s.school_id
      AND e.is_current = true
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3
     LIMIT 1`,
    [orgId, schoolId, studentId],
  );
  const row = rows[0];
  if (!row) {
    return { childName: "Student", childClass: "" };
  }
  const className = row.class_name ?? "";
  const sectionName = row.section_name ?? "";
  const childClass = className
    ? sectionName
      ? `${className}-${sectionName}`
      : className
    : "";
  return { childName: row.display_name, childClass };
}

export function buildDefaultParentSnapshot(
  entityType: string,
  context: ParentSnapshotContext,
): Record<string, unknown> {
  const base = {
    childName: context.childName,
    childClass: context.childClass,
    unreadNotifications: 0,
  };
  switch (entityType) {
    case "snapshot_attendance":
      return {
        ...base,
        month: new Date().toISOString().slice(0, 7),
        kpi: { attendancePercent: 0, absentDays: 0, lateDays: 0 },
        calendarDays: [],
        recentLogs: [],
      };
    case "snapshot_timetable":
      return {
        ...base,
        weekRangeLabel: weekRangeLabel(),
        totalPeriodsThisWeek: 0,
        completedPeriodsToday: 0,
        upcomingPeriodsToday: 0,
        days: [],
      };
    case "snapshot_fees":
      return {
        ...base,
        summaryLabel: "Fees",
        totalDue: 0,
        installments: [],
      };
    default:
      return base;
  }
}

// ─── P0-1 — student-scope default-snapshot fallback ──────────────────────────
//
// The student app must NOT 404 for a real student who has no seeded
// `student_entities` row (only the 2-UUID demo seed carries one). Mirrors the
// parent fallback (loadStudentParentSnapshotContext / buildDefaultParentSnapshot
// above): build a default from real `students` + `sis_student_enrollments`
// rows, shaped to the EXACT keys `lib/core/repositories/api/student/mapper/
// student_mapper.dart` reads (verified against that file) — this also fixes the
// pre-existing seed-contract mismatch (seed shipped `rollNumber`/`guardianName`,
// the client reads `rollNo`; seed never carried `attendanceKpi`/`homeworkDue`/
// `examReminder`/`todaySchedule`/`quickActions`/`admissionNo`/`dateOfBirth`/
// `bloodGroup`/`parentContacts`/`academicSummary` at all).
//
// KNOWN LIMITATION (out of this fix's file-ownership — entity_read/pilot only):
// `student_profiles` and `student_guardians` currently carry NO student-scope
// RLS read policy (only 'school' / 'parent' branches — see
// 20260613000000_sis_slice0_foundation.sql and 20260609100000_phase2_rls_scope.sql).
// The queries below are written to pick these fields up correctly the moment
// that follow-up RLS grant lands; until then `admissionNo`/`dateOfBirth`/
// `bloodGroup`/`parentContacts` gracefully read back empty (evidenced-missing,
// not fabricated) rather than erroring — `students` + `sis_student_enrollments`
// already grant student-scope self-read (20260703100000_parent_student_exam_read_rls.sql),
// so `studentName`/`classLabel`/`rollNo` DO populate for a real student today.

export interface StudentSnapshotContext {
  studentName: string;
  classLabel: string;
  rollNo: string;
  admissionNo: string;
  dateOfBirth: string;
  bloodGroup: string;
  schoolName: string;
  parentContacts: Array<
    { name: string; relation: string; phoneLabel: string; email: string }
  >;
}

export async function loadStudentSnapshotContext(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<StudentSnapshotContext> {
  const rows = await db.queryObject<{
    display_name: string;
    class_name: string | null;
    section_name: string | null;
    roll_number: string | null;
    admission_number: string | null;
    date_of_birth: string | null;
    blood_group: string | null;
  }>(
    `SELECT s.display_name,
            e.class_name, e.section_name, e.roll_number,
            sp.admission_number,
            sp.date_of_birth::text AS date_of_birth,
            sp.blood_group
     FROM students s
     LEFT JOIN sis_student_enrollments e
       ON e.student_id = s.id
      AND e.organization_id = s.organization_id
      AND e.school_id = s.school_id
      AND e.is_current = true
     LEFT JOIN student_profiles sp
       ON sp.student_id = s.id
      AND sp.organization_id = s.organization_id
      AND sp.school_id = s.school_id
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3
     LIMIT 1`,
    [orgId, schoolId, studentId],
  );

  const schoolRows = await db.queryObject<{ name: string }>(
    `SELECT name FROM schools WHERE id = $1 LIMIT 1`,
    [schoolId],
  );
  const schoolName = schoolRows[0]?.name ?? "NIKSHA Public School";

  const guardianRows = await db.queryObject<{
    name: string;
    relation: string;
    phone: string | null;
    email: string | null;
  }>(
    `SELECT u.display_name AS name, sg.relationship AS relation, u.phone, u.email
     FROM student_guardians sg
     JOIN users u ON u.id = sg.guardian_user_id
     WHERE sg.organization_id = $1 AND sg.school_id = $2 AND sg.student_id = $3
       AND sg.status = 'active'
     ORDER BY sg.is_primary DESC`,
    [orgId, schoolId, studentId],
  );
  const parentContacts = guardianRows.map((g) => ({
    name: g.name,
    relation: g.relation,
    phoneLabel: g.phone ?? "",
    email: g.email ?? "",
  }));

  const row = rows[0];
  if (!row) {
    return {
      studentName: "Student",
      classLabel: "",
      rollNo: "",
      admissionNo: "",
      dateOfBirth: "",
      bloodGroup: "",
      schoolName,
      parentContacts,
    };
  }
  const className = row.class_name ?? "";
  const sectionName = row.section_name ?? "";
  const classLabel = className
    ? sectionName
      ? `${className}-${sectionName}`
      : className
    : "";
  return {
    studentName: row.display_name,
    classLabel,
    rollNo: row.roll_number ?? "",
    admissionNo: row.admission_number ?? "",
    dateOfBirth: row.date_of_birth ?? "",
    bloodGroup: row.blood_group ?? "",
    schoolName,
    parentContacts,
  };
}

export function buildDefaultStudentSnapshot(
  entityType: string,
  context: StudentSnapshotContext,
): Record<string, unknown> {
  const base = {
    studentName: context.studentName,
    classLabel: context.classLabel,
    // Mirrors the parent/attendance/timetable overlay naming convention
    // (childName/childClass) so overlayAttendanceSnapshotFromRecords /
    // overlayTimetableSnapshotFromSlots — which read `childClass ?? classLabel`
    // — resolve the real class label either way.
    childName: context.studentName,
    childClass: context.classLabel,
    unreadNotifications: 0,
  };
  switch (entityType) {
    case "snapshot_dashboard":
      return {
        ...base,
        greetingHeadline: context.studentName
          ? `Welcome, ${context.studentName}`
          : "Welcome",
        greetingSubtitle: "",
        todaySchedule: [],
        attendanceKpi: {
          label: "Attendance",
          value: "--",
          detail: "No attendance recorded yet",
          tone: "neutral",
        },
        homeworkDue: [],
        examReminder: { id: "", title: "", subject: "", dateLabel: "", daysUntil: 0 },
        quickActions: [],
        aiInsight: { message: "", actionLabel: "" },
      };
    case "snapshot_attendance":
      return {
        ...base,
        month: new Date().toISOString().slice(0, 7),
        kpi: { attendancePercent: 0, absentDays: 0, lateDays: 0 },
        calendarDays: [],
        recentLogs: [],
      };
    case "snapshot_exams":
      return {
        ...base,
        averagePercent: 0,
        upcomingExams: [],
        examResults: [],
        subjectScores: [],
      };
    case "snapshot_timetable":
      return {
        ...base,
        weekRangeLabel: weekRangeLabel(),
        totalPeriodsThisWeek: 0,
        completedPeriodsToday: 0,
        upcomingPeriodsToday: 0,
        days: [],
      };
    case "snapshot_profile":
      return {
        ...base,
        rollNo: context.rollNo,
        admissionNo: context.admissionNo,
        dateOfBirth: context.dateOfBirth,
        bloodGroup: context.bloodGroup,
        schoolName: context.schoolName,
        parentContacts: context.parentContacts,
        academicSummary: [],
      };
    default:
      return base;
  }
}

export async function overlayFeesSnapshotFromFinance(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{
    id: string;
    outstanding_amount: string;
    invoice_status: string;
    due_date: string;
  }>(
    `SELECT id, outstanding_amount, invoice_status, due_date::text AS due_date
     FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
       AND invoice_status NOT IN ('cancelled', 'draft')
     ORDER BY due_date ASC
     LIMIT 12`,
    [orgId, schoolId, studentId],
  );
  // Correct child identity from real records (seed snapshot may be stale), mirroring
  // the exam/receipt overlays so the parent never sees another child's name.
  let childName = snapshot.childName;
  let childClass = snapshot.childClass;
  try {
    const context = await loadStudentParentSnapshotContext(db, orgId, schoolId, studentId);
    if (context.childName) childName = context.childName;
    if (context.childClass) childClass = context.childClass;
  } catch {
    // keep snapshot identity on any lookup failure
  }

  if (rows.length === 0) {
    return { ...snapshot, childName, childClass };
  }

  const installments = rows.map((row, index) => ({
    id: row.id,
    label: `Invoice ${index + 1}`,
    amountDue: parseFloat(row.outstanding_amount),
    dueDateLabel: row.due_date.slice(0, 10),
    statusLabel: row.invoice_status,
  }));
  const totalDue = installments.reduce((sum, item) => sum + item.amountDue, 0);
  const hasOutstanding = installments.some((item) =>
    item.statusLabel === "issued" || item.statusLabel === "partially_paid"
  );

  return {
    ...snapshot,
    childName,
    childClass,
    summaryLabel: hasOutstanding ? "Outstanding fees" : "Fees",
    totalDue,
    installments,
  };
}

const RECEIPT_STATUS_LABELS: Record<string, string> = {
  completed: "Paid",
  cancelled: "Cancelled",
  partially_refunded: "Partially refunded",
  refunded: "Refunded",
  draft: "Draft",
};

export interface FinanceReceiptsPage {
  items: Record<string, unknown>[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/**
 * List the child's REAL fee receipts (from finance_receipts → finance_collections)
 * shaped exactly as the parent/student receipts list expects. Replaces the stale
 * `parent_entities` seed cache so a collection recorded by the office actually
 * surfaces as a receipt in the parent app. Returns an empty page when the child
 * has no receipts yet (RLS restricts visibility to the caller's own children).
 */
export async function overlayReceiptsFromFinance(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  pagination: { page: number; pageSize: number },
): Promise<FinanceReceiptsPage> {
  const pageSize = Math.min(100, Math.max(1, pagination.pageSize));
  const page = Math.max(1, pagination.page);
  const offset = (page - 1) * pageSize;

  const countRows = await db.queryObject<{ total: string }>(
    `SELECT count(*)::text AS total
       FROM finance_receipts r
       JOIN finance_collections c ON c.id = r.collection_id
      WHERE r.organization_id = $1 AND r.school_id = $2 AND c.student_id = $3`,
    [orgId, schoolId, studentId],
  );
  const total = parseInt(countRows[0]?.total ?? "0", 10);

  let childName = "Student";
  let childClass = "";
  try {
    const context = await loadStudentParentSnapshotContext(db, orgId, schoolId, studentId);
    if (context.childName) childName = String(context.childName);
    if (context.childClass) childClass = String(context.childClass);
  } catch {
    // fall back to defaults on any lookup failure
  }

  const schoolRows = await db.queryObject<{ name: string }>(
    `SELECT name FROM schools WHERE id = $1 LIMIT 1`,
    [schoolId],
  );
  const schoolName = schoolRows[0]?.name ?? "NIKSHA Public School";

  const rows = await db.queryObject<{
    id: string;
    receipt_number: string;
    date_label: string;
    amount: string;
    payment_method: string;
    collection_status: string;
    invoice_number: string;
  }>(
    `SELECT r.id,
            r.receipt_number,
            to_char(r.receipt_date, 'DD Mon YYYY') AS date_label,
            r.amount::text AS amount,
            c.payment_method,
            c.collection_status,
            i.invoice_number
       FROM finance_receipts r
       JOIN finance_collections c ON c.id = r.collection_id
       JOIN finance_invoices i ON i.id = c.invoice_id
      WHERE r.organization_id = $1 AND r.school_id = $2 AND c.student_id = $3
      ORDER BY r.receipt_date DESC, r.created_at DESC, r.id DESC
      LIMIT $4 OFFSET $5`,
    [orgId, schoolId, studentId, pageSize, offset],
  );

  const items = rows.map((row) => {
    const amount = Math.round(parseFloat(row.amount));
    const statusLabel = RECEIPT_STATUS_LABELS[row.collection_status] ??
      row.collection_status;
    return {
      id: row.id,
      receiptNumber: row.receipt_number,
      title: `Fee payment · ${row.invoice_number}`,
      dateLabel: row.date_label,
      amount,
      paymentMethod: row.payment_method,
      statusLabel,
      childName,
      childClass,
      category: "Fees",
      lineItems: [{ label: `Invoice ${row.invoice_number}`, amount }],
      schoolName,
    } as Record<string, unknown>;
  });

  return {
    items,
    total,
    page,
    pageSize,
    hasMore: offset + rows.length < total,
  };
}

// ─── PAR-D3 — annual / 80C fee-payment certificate DATA ─────────────────────
//
// Aggregates the child's REAL fee payments (finance_receipts → finance_collections)
// for one financial/academic year into the data an 80C tax certificate needs. The
// PDF itself is rendered client-side in a later wave; this endpoint only returns
// the honest, tenant-authoritative numbers. Signatory title is a per-school
// setting (schools.settings->>'feeCertificateSignatoryTitle'), defaulting to the
// owner-ruled "Principal" — read-with-default, no settings subsystem added.
//
// Only `completed` collections count toward the certificate: a cancelled or
// refunded payment is not a valid tax-deductible amount, so it must not inflate
// the 80C total. Own-child scoping is enforced twice — the caller's JWT child_ids
// at the handler, and the finance_receipts/collections parent RLS policy
// (20260704000000_parent_student_finance_read_rls.sql, keyed on student_guardians)
// underneath — so a child not linked to the parent yields zero rows either way.

export interface FeeCertificatePayment {
  date: string;
  receiptNo: string;
  amount: number;
  paymentMethod: string;
  description: string;
}

export interface FeeCertificateData {
  schoolName: string;
  guardianName: string;
  studentName: string;
  publicStudentId: string;
  admissionNumber: string;
  academicYear: string;
  totalPaidAmount: number;
  payments: FeeCertificatePayment[];
  signatoryTitle: string;
}

/**
 * Parse an academic/financial year label ("2025-2026", "2025-26" or a single
 * "2025") into the [start, endExclusive) date window an Indian financial year
 * spans: 1 Apr of the start year → 1 Apr of the next year. Returns null for an
 * unparseable / missing input so the caller can fall back to the current FY.
 */
export function financialYearWindow(
  academicYear: string | null | undefined,
): { startYear: number; label: string; start: string; endExclusive: string } | null {
  if (!academicYear) return null;
  const match = academicYear.match(/^(\d{4})(?:\s*-\s*(\d{2,4}))?$/);
  if (!match) return null;
  const startYear = parseInt(match[1], 10);
  if (!Number.isFinite(startYear)) return null;
  const endYear = startYear + 1;
  return {
    startYear,
    label: `${startYear}-${endYear}`,
    start: `${startYear}-04-01`,
    endExclusive: `${endYear}-04-01`,
  };
}

/** The financial year (Apr–Mar) that `now` falls in. */
export function currentFinancialYear(now = new Date()): {
  startYear: number;
  label: string;
  start: string;
  endExclusive: string;
} {
  const month = now.getUTCMonth(); // 0=Jan
  const startYear = month >= 3 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return financialYearWindow(String(startYear))!;
}

export async function buildFeeCertificateData(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  academicYear: string | null | undefined,
): Promise<FeeCertificateData> {
  const window = financialYearWindow(academicYear) ?? currentFinancialYear();

  // School name + the per-school configurable signatory title. Both live on the
  // schools row, which parent scope may read for its own active school (RLS
  // schools_scope_access). Default signatory is the owner-ruled "Principal".
  const schoolRows = await db.queryObject<{ name: string; signatory_title: string | null }>(
    `SELECT name,
            NULLIF(TRIM(settings->>'feeCertificateSignatoryTitle'), '') AS signatory_title
       FROM schools
      WHERE id = $1
      LIMIT 1`,
    [schoolId],
  );
  const schoolName = schoolRows[0]?.name ?? "NIKSHA Public School";
  const signatoryTitle = schoolRows[0]?.signatory_title ?? "Principal";

  // Child identity: display name (students), PSID + admission number
  // (student_profiles). Scoped to org+school+student; parent RLS restricts the
  // student/profile rows to the caller's own children.
  const studentRows = await db.queryObject<{
    display_name: string;
    public_student_id: string | null;
    admission_number: string | null;
  }>(
    `SELECT s.display_name,
            sp.public_student_id,
            sp.admission_number
       FROM students s
       LEFT JOIN student_profiles sp
         ON sp.student_id = s.id
        AND sp.organization_id = s.organization_id
        AND sp.school_id = s.school_id
      WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3
      LIMIT 1`,
    [orgId, schoolId, studentId],
  );
  const studentRow = studentRows[0];
  const studentName = studentRow?.display_name ?? "Student";
  const publicStudentId = studentRow?.public_student_id ?? "";
  const admissionNumber = studentRow?.admission_number ?? "";

  // Guardian (the parent making the request) — their own users row, readable
  // under RLS users_self_access (id = app_current_user_id() = the parent's sub).
  // A parent-scoped context sets parent_user_id; we read the caller's name for
  // the certificate's "paid by" line.
  const guardianRows = await db.queryObject<{ display_name: string }>(
    `SELECT display_name FROM users WHERE id = app_current_user_id() LIMIT 1`,
  );
  const guardianName = guardianRows[0]?.display_name ?? "";

  // The year's payments for THIS child. finance_receipts.receipt_date is the
  // payment date the parent needs for 80C; join finance_collections for the
  // student scope + payment method, and finance_invoices for a description.
  // Only completed collections count (a cancelled/refunded one is not deductible).
  const rows = await db.queryObject<{
    date_label: string;
    receipt_number: string;
    amount: string;
    payment_method: string;
    invoice_number: string | null;
  }>(
    `SELECT to_char(r.receipt_date, 'DD Mon YYYY') AS date_label,
            r.receipt_number,
            r.amount::text AS amount,
            c.payment_method,
            i.invoice_number
       FROM finance_receipts r
       JOIN finance_collections c ON c.id = r.collection_id
       LEFT JOIN finance_invoices i ON i.id = c.invoice_id
      WHERE r.organization_id = $1 AND r.school_id = $2 AND c.student_id = $3
        AND c.collection_status = 'completed'
        AND r.receipt_date >= $4::date AND r.receipt_date < $5::date
      ORDER BY r.receipt_date ASC, r.created_at ASC, r.id ASC`,
    [orgId, schoolId, studentId, window.start, window.endExclusive],
  );

  const payments: FeeCertificatePayment[] = rows.map((row) => ({
    date: row.date_label,
    receiptNo: row.receipt_number,
    amount: parseFloat(row.amount),
    paymentMethod: row.payment_method,
    description: row.invoice_number
      ? `Fee payment · ${row.invoice_number}`
      : "Fee payment",
  }));
  const totalPaidAmount = payments.reduce((sum, p) => sum + p.amount, 0);

  return {
    schoolName,
    guardianName,
    studentName,
    publicStudentId,
    admissionNumber,
    academicYear: window.label,
    totalPaidAmount,
    payments,
    signatoryTitle,
  };
}

/**
 * Overlay the parent/student "exams" snapshot with the child's REAL published
 * exam results (and correct child identity). Mirrors the attendance/fees
 * overlays so published marks reach the parent durably instead of stale seed
 * snapshot data. Returns the snapshot untouched (minus identity fix) when no
 * results are published yet.
 */
export async function overlayExamsSnapshotFromResults(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  // Correct child identity from real records (seed snapshot may be stale).
  let childName = snapshot.childName;
  let childClass = snapshot.childClass;
  try {
    const context = await loadStudentParentSnapshotContext(db, orgId, schoolId, studentId);
    if (context.childName) childName = context.childName;
    if (context.childClass) childClass = context.childClass;
  } catch {
    // keep snapshot identity on any lookup failure
  }

  // P2 cosmetic-correctness fix — the report-card PDF (parent + student both
  // export off this exams snapshot) must brand with the REAL per-tenant school,
  // never a seeded/hardcoded label. `schools` is the single source of truth;
  // always overlay it live, same precedent query as loadStudentSnapshotContext.
  let schoolName = snapshot.schoolName;
  try {
    const schoolRows = await db.queryObject<{ name: string }>(
      `SELECT name FROM schools WHERE id = $1 LIMIT 1`,
      [schoolId],
    );
    if (schoolRows[0]?.name) schoolName = schoolRows[0].name;
  } catch {
    // keep snapshot schoolName on any lookup failure
  }

  const published = await listPublishedResultsForStudent(db, orgId, schoolId, studentId);

  if (published.length === 0) {
    return { ...snapshot, childName, childClass, schoolName };
  }

  const examResults = published.map((r) => ({
    id: String(r.markEntryId ?? ""),
    title: String(r.subject ?? r.examTitle ?? ""),
    termLabel: String(r.termLabel ?? ""),
    dateLabel: String(r.dateLabel ?? ""),
    scoreObtained: Number(r.scoreObtained ?? 0),
    maxScore: Number(r.maxScore ?? 0),
    grade: String(r.grade ?? ""),
  }));

  return { ...snapshot, childName, childClass, schoolName, examResults };
}
