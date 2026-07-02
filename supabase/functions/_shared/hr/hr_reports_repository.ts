// HR reporting / export computation layer (HR-1, HR-2, HR-4, HR-5, HR-6, HR-7).
//
// Every report here is DERIVED from the school's REAL rows inside the tenant RLS
// context — payroll/leave JSONB snapshots (hr_entities), the `employees` table,
// the `staff_check_ins` ledger, and `school_calendar_events`. The pure transforms
// (register totals, muster status inference, headcount grouping) are exported and
// unit-tested DB-free; the DB reads are thin wrappers around them.
//
// All amounts are whole rupees. No schema change: reads only.

import type { TenantQueryClient } from "../tenant_db.ts";

// ---------------------------------------------------------------------------
// Shared numeric coercion (mirrors hr_write_handlers.money — a JSONB field may
// arrive as a number OR a numeric string).
// ---------------------------------------------------------------------------

/** Coerces a JSONB field to a finite number (0 when absent/non-numeric). */
export function num(entry: Record<string, unknown>, ...keys: string[]): number {
  for (const key of keys) {
    if (key in entry && entry[key] != null) {
      const n = Number(entry[key]);
      if (Number.isFinite(n)) return n;
    }
  }
  return 0;
}

function text(entry: Record<string, unknown>, ...keys: string[]): string {
  for (const key of keys) {
    if (key in entry && entry[key] != null) {
      const s = String(entry[key]).trim();
      if (s.length > 0) return s;
    }
  }
  return "";
}

function asArray(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value as Array<Record<string, unknown>> : [];
}

// ===========================================================================
// HR-1 — Salary register
// ===========================================================================

export interface SalaryRegisterRow {
  employeeId: string;
  code: string;
  name: string;
  dept: string;
  basicPay: number;
  allowances: number;
  deductions: number;
  netPay: number;
}

export interface SalaryRegisterTotals {
  basicPay: number;
  allowances: number;
  deductions: number;
  netPay: number;
}

export interface SalaryRegister {
  runId: string;
  period: string;
  rows: SalaryRegisterRow[];
  totals: SalaryRegisterTotals;
}

/**
 * Pure: builds the salary register for one run from a `snapshot_payroll` payload.
 * Selects the entries for `runId` (or, when entries carry no runId, ALL entries —
 * legacy single-run snapshots), maps them to per-employee rows and sums the four
 * money columns. netPay is taken as-recorded (the write path already guards
 * netPay === basic + allowances - deductions), so the register never re-derives.
 */
export function buildSalaryRegister(
  payroll: Record<string, unknown>,
  runId: string,
): SalaryRegister {
  const runs = asArray(payroll.runs);
  const run = runs.find((r) => String(r.id ?? "") === runId);
  const entries = asArray(payroll.entries).filter((e) => {
    const entryRun = text(e, "runId", "run_id", "payrollRunId", "payroll_run_id");
    // Entries tagged with a run only belong to that run; untagged entries are the
    // legacy single-run shape and belong to whichever run is requested.
    return entryRun === "" || entryRun === runId;
  });

  const rows: SalaryRegisterRow[] = entries.map((e) => {
    const basicPay = num(e, "basicPay", "basic_pay");
    const allowances = num(e, "allowances");
    const deductions = num(e, "deductions");
    // Prefer the recorded net; fall back to the derived net only when absent.
    const netPay = ("netPay" in e || "net_pay" in e)
      ? num(e, "netPay", "net_pay")
      : basicPay + allowances - deductions;
    return {
      employeeId: text(e, "employeeId", "employee_id", "id"),
      code: text(e, "employeeCode", "employee_code", "code"),
      name: text(e, "employeeName", "employee_name", "name"),
      dept: text(e, "department", "dept"),
      basicPay,
      allowances,
      deductions,
      netPay,
    };
  });

  const totals: SalaryRegisterTotals = rows.reduce(
    (acc, r) => ({
      basicPay: acc.basicPay + r.basicPay,
      allowances: acc.allowances + r.allowances,
      deductions: acc.deductions + r.deductions,
      netPay: acc.netPay + r.netPay,
    }),
    { basicPay: 0, allowances: 0, deductions: 0, netPay: 0 },
  );

  return {
    runId,
    period: run ? text(run, "period", "label") : "",
    rows,
    totals,
  };
}

// ===========================================================================
// HR-2 — Payslips
// ===========================================================================

export interface PayslipLine {
  label: string;
  amount: number;
}

export interface Payslip {
  employeeId: string;
  code: string;
  name: string;
  dept: string;
  earnings: PayslipLine[];
  deductionLines: PayslipLine[];
  grossEarnings: number;
  totalDeductions: number;
  netPay: number;
}

export interface PayslipBundle {
  runId: string;
  period: string;
  payslips: Payslip[];
}

/**
 * Pure: builds per-employee payslip data for one run. Each payslip carries an
 * earnings breakdown (basic + allowances) and a deductions breakdown; the client
 * renders one PDF per employee + an all-in-one bundle from this. Reuses the same
 * per-run entry selection as the register so the two reports never disagree.
 */
export function buildPayslips(
  payroll: Record<string, unknown>,
  runId: string,
): PayslipBundle {
  const register = buildSalaryRegister(payroll, runId);
  const payslips: Payslip[] = register.rows.map((r) => {
    const earnings: PayslipLine[] = [
      { label: "Basic pay", amount: r.basicPay },
      { label: "Allowances", amount: r.allowances },
    ];
    const deductionLines: PayslipLine[] = [
      { label: "Deductions", amount: r.deductions },
    ];
    const grossEarnings = r.basicPay + r.allowances;
    return {
      employeeId: r.employeeId,
      code: r.code,
      name: r.name,
      dept: r.dept,
      earnings,
      deductionLines,
      grossEarnings,
      totalDeductions: r.deductions,
      netPay: r.netPay,
    };
  });
  return { runId, period: register.period, payslips };
}

// ===========================================================================
// HR-6 — Monthly attendance muster
// ===========================================================================

/** Per-day muster status codes. */
export type MusterStatus = "P" | "L" | "A" | "-";

export interface MusterRow {
  employeeId: string;
  code: string;
  name: string;
  dept: string;
  /** Index 0 == day 1 of the month. Length == days in month. */
  dailyStatus: MusterStatus[];
  presentCount: number;
  /** Present or Late days as a % of working days (rounded). */
  percent: number;
}

export interface AttendanceMuster {
  month: string; // YYYY-MM
  daysInMonth: number;
  /** Minutes-of-day cutoff; a first check-in after this is Late (default 09:15). */
  lateAfter: string;
  /** Day numbers (1-based) treated as non-working (holiday). */
  holidayDays: number[];
  rows: MusterRow[];
}

/** A single check-in ledger row projected for the muster. */
export interface CheckInEvent {
  userId: string;
  employeeRef: string;
  eventType: string; // check_in | check_out
  eventTime: string; // ISO timestamp
}

/** An employee identity the muster iterates over. */
export interface MusterEmployee {
  id: string;
  userId: string;
  code: string;
  name: string;
  dept: string;
}

export function daysInMonth(month: string): number {
  const [y, m] = month.split("-").map((v) => parseInt(v, 10));
  if (!y || !m) return 0;
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

/** Parses "HH:MM" into minutes-of-day; returns null on a malformed value. */
function parseHhMm(value: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  const h = parseInt(match[1]!, 10);
  const min = parseInt(match[2]!, 10);
  if (h < 0 || h > 23 || min < 0 || min > 59) return null;
  return h * 60 + min;
}

/** UTC minutes-of-day of an ISO timestamp (matches how event_time is stored). */
function minutesOfDayUtc(iso: string): number | null {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}

/** UTC yyyy-mm-dd of an ISO timestamp. */
function isoDateUtc(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return d.toISOString().slice(0, 10);
}

/**
 * Pure: infers the employee × day muster from the raw check-in ledger.
 *
 * Status inference per working day:
 *   • a day with a `check_in` → Present ('P'), unless the earliest check-in is
 *     after `lateAfter` (default 09:15) → Late ('L');
 *   • a working day with NO check_in → Absent ('A').
 * Weekends/holidays: a day whose (1-based) number is in `holidayDays` is marked
 * non-working ('-') and excluded from the % denominator. When `holidayDays` is
 * empty EVERY day is treated as working (documented default — see the handler).
 *
 * `percent` = (Present + Late) / workingDays × 100, rounded; 0 when no working
 * days. Employees are matched to ledger rows by userId, falling back to
 * employee_code/id via `employeeRef` so pre-`user_id` ledgers still attribute.
 */
export function inferMuster(
  month: string,
  employees: MusterEmployee[],
  events: CheckInEvent[],
  options: { lateAfter?: string; holidayDays?: number[] } = {},
): AttendanceMuster {
  const lateAfter = options.lateAfter ?? "09:15";
  const lateCutoff = parseHhMm(lateAfter) ?? (9 * 60 + 15);
  const holidayDays = options.holidayDays ?? [];
  const holidaySet = new Set(holidayDays);
  const dim = daysInMonth(month);

  // Group the earliest check-in minute per (matchKey, day).
  // matchKey is the userId when present, else the employeeRef, so an employee is
  // reachable by either identifier.
  const earliestByKeyDay = new Map<string, Map<number, number>>();
  const recordEarliest = (key: string, day: number, minute: number) => {
    if (key === "") return;
    let byDay = earliestByKeyDay.get(key);
    if (!byDay) {
      byDay = new Map<number, number>();
      earliestByKeyDay.set(key, byDay);
    }
    const prev = byDay.get(day);
    if (prev === undefined || minute < prev) byDay.set(day, minute);
  };

  for (const ev of events) {
    if (ev.eventType !== "check_in") continue;
    const date = isoDateUtc(ev.eventTime);
    if (!date.startsWith(month + "-")) continue;
    const day = parseInt(date.slice(8, 10), 10);
    if (!(day >= 1 && day <= dim)) continue;
    const minute = minutesOfDayUtc(ev.eventTime);
    if (minute === null) continue;
    if (ev.userId) recordEarliest(ev.userId, day, minute);
    if (ev.employeeRef) recordEarliest(ev.employeeRef, day, minute);
  }

  const rows: MusterRow[] = employees.map((emp) => {
    const byUser = emp.userId ? earliestByKeyDay.get(emp.userId) : undefined;
    const byCode = emp.code ? earliestByKeyDay.get(emp.code) : undefined;
    const byId = emp.id ? earliestByKeyDay.get(emp.id) : undefined;

    const dailyStatus: MusterStatus[] = [];
    let presentCount = 0;
    let workingDays = 0;

    for (let day = 1; day <= dim; day++) {
      if (holidaySet.has(day)) {
        dailyStatus.push("-");
        continue;
      }
      workingDays++;
      const earliest = firstDefined(
        byUser?.get(day),
        byCode?.get(day),
        byId?.get(day),
      );
      if (earliest === undefined) {
        dailyStatus.push("A");
      } else if (earliest > lateCutoff) {
        dailyStatus.push("L");
        presentCount++;
      } else {
        dailyStatus.push("P");
        presentCount++;
      }
    }

    const percent = workingDays > 0
      ? Math.round((presentCount / workingDays) * 100)
      : 0;

    return {
      employeeId: emp.id,
      code: emp.code,
      name: emp.name,
      dept: emp.dept,
      dailyStatus,
      presentCount,
      percent,
    };
  });

  return {
    month,
    daysInMonth: dim,
    lateAfter,
    holidayDays: [...holidaySet].sort((a, b) => a - b),
    rows,
  };
}

function firstDefined(...values: Array<number | undefined>): number | undefined {
  let best: number | undefined;
  for (const v of values) {
    if (v !== undefined && (best === undefined || v < best)) best = v;
  }
  return best;
}

// ===========================================================================
// HR-4 — Leave-balance report
// ===========================================================================

export interface LeaveBalanceCell {
  leaveType: string;
  available: number;
  used: number;
  remaining: number;
}

export interface LeaveBalanceRow {
  employeeId: string;
  code: string;
  name: string;
  dept: string;
  balances: LeaveBalanceCell[];
}

export interface LeaveBalanceReport {
  leaveTypes: string[];
  rows: LeaveBalanceRow[];
}

/** ORG-policy leave entitlements (days/year); mirrors DEFAULT_LEAVE_POLICY. */
export const DEFAULT_LEAVE_ENTITLEMENTS: Array<{ leaveType: string; entitlement: number }> = [
  { leaveType: "casual", entitlement: 12 },
  { leaveType: "sick", entitlement: 12 },
  { leaveType: "earned", entitlement: 15 },
];

/**
 * Pure: per employee × leave type {available, used, remaining}. `available` is the
 * org entitlement (same for everyone); `used` is that employee's own APPROVED
 * leave days of that type from `snapshot_leave.requests`; `remaining` = max(0,
 * available - used). Employees with no leave history show 0 used / full remaining.
 */
export function buildLeaveBalanceReport(
  leave: Record<string, unknown>,
  employees: MusterEmployee[],
  policy: Array<{ leaveType: string; entitlement: number }> = DEFAULT_LEAVE_ENTITLEMENTS,
): LeaveBalanceReport {
  const effectivePolicy = policy.length > 0 ? policy : DEFAULT_LEAVE_ENTITLEMENTS;
  const requests = asArray(leave.requests);
  const leaveTypes = effectivePolicy.map((p) => p.leaveType);

  const rows: LeaveBalanceRow[] = employees.map((emp) => {
    const approved = requests.filter((r) =>
      String(r.status ?? "") === "approved" &&
      (text(r, "employeeId", "employee_id") === emp.id ||
        text(r, "employeeCode", "employee_code") === emp.code ||
        (emp.userId !== "" && text(r, "userId", "user_id") === emp.userId))
    );
    const balances: LeaveBalanceCell[] = effectivePolicy.map((p) => {
      const used = approved
        .filter((r) => String(r.leaveType ?? r.leave_type ?? "") === p.leaveType)
        .reduce((sum, r) => sum + num(r, "days"), 0);
      const remaining = Math.max(0, p.entitlement - used);
      return { leaveType: p.leaveType, available: p.entitlement, used, remaining };
    });
    return {
      employeeId: emp.id,
      code: emp.code,
      name: emp.name,
      dept: emp.dept,
      balances,
    };
  });

  return { leaveTypes, rows };
}

// ===========================================================================
// HR-5 — Headcount by department
// ===========================================================================

export interface HeadcountRow {
  department: string;
  count: number;
}

export interface HeadcountReport {
  rows: HeadcountRow[];
  total: number;
}

interface HeadcountEmployee {
  status: string;
  department: string;
}

/**
 * Pure: counts ACTIVE employees grouped by primary_department. Inactive /
 * on_leave employees are excluded from the headcount (an active-strength view).
 * A blank department groups under "Unassigned". Rows are sorted by count desc,
 * then name asc, so the largest team is first and ties are stable.
 */
export function buildHeadcount(employees: HeadcountEmployee[]): HeadcountReport {
  const counts = new Map<string, number>();
  let total = 0;
  for (const e of employees) {
    if (String(e.status ?? "active") !== "active") continue;
    const dept = e.department.trim() === "" ? "Unassigned" : e.department.trim();
    counts.set(dept, (counts.get(dept) ?? 0) + 1);
    total++;
  }
  const rows: HeadcountRow[] = [...counts.entries()]
    .map(([department, count]) => ({ department, count }))
    .sort((a, b) => b.count - a.count || a.department.localeCompare(b.department));
  return { rows, total };
}

// ===========================================================================
// HR-7 — Employee directory export
// ===========================================================================

export interface DirectoryRow {
  employeeId: string;
  code: string;
  name: string;
  dept: string;
  designation: string;
  phone: string;
  joinDate: string;
  status: string;
}

// ---------------------------------------------------------------------------
// DB reads — thin wrappers that fetch the real rows and hand them to the pure
// transforms above. All queries are school-scoped by the tenant RLS context.
// ---------------------------------------------------------------------------

async function getSnapshotOrEmpty(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  entityType: string,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload
     FROM hr_entities
     WHERE organization_id = $1
       AND school_id = $2
       AND entity_type = $3
       AND id = 'default'`,
    [organizationId, schoolId, entityType],
  );
  return rows[0]?.payload ?? {};
}

/** Loads this school's employees from the real `employees` table. */
export async function loadDirectoryEmployees(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<DirectoryRow[]> {
  const rows = await db.queryObject<{
    id: string;
    employee_code: string;
    display_name: string;
    phone: string | null;
    status: string;
    primary_department: string | null;
    designation: string | null;
    join_date: string | null;
  }>(
    `SELECT id::text AS id,
            employee_code,
            display_name,
            phone,
            status,
            primary_department,
            NULL::text AS designation,
            to_char(created_at, 'YYYY-MM-DD') AS join_date
     FROM employees
     WHERE organization_id = $1
       AND school_id = $2
     ORDER BY display_name`,
    [organizationId, schoolId],
  );
  return rows.map((r) => ({
    employeeId: r.id,
    code: r.employee_code,
    name: r.display_name,
    dept: r.primary_department ?? "",
    designation: r.designation ?? "",
    phone: r.phone ?? "",
    joinDate: r.join_date ?? "",
    status: r.status,
  }));
}

/** Loads employees as the muster/leave identity view (id + userId + code). */
export async function loadMusterEmployees(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<MusterEmployee[]> {
  const rows = await db.queryObject<{
    id: string;
    user_id: string | null;
    employee_code: string;
    display_name: string;
    primary_department: string | null;
  }>(
    `SELECT id::text AS id,
            user_id::text AS user_id,
            employee_code,
            display_name,
            primary_department
     FROM employees
     WHERE organization_id = $1
       AND school_id = $2
     ORDER BY display_name`,
    [organizationId, schoolId],
  );
  return rows.map((r) => ({
    id: r.id,
    userId: r.user_id ?? "",
    code: r.employee_code,
    name: r.display_name,
    dept: r.primary_department ?? "",
  }));
}

/** Loads the check-in events for a YYYY-MM window from the staff ledger. */
export async function loadCheckInEvents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  month: string,
): Promise<CheckInEvent[]> {
  const rows = await db.queryObject<{
    user_id: string | null;
    employee_ref: string | null;
    event_type: string;
    event_time: string;
  }>(
    `SELECT user_id::text AS user_id,
            employee_ref,
            event_type,
            to_char(event_time, 'YYYY-MM-DD"T"HH24:MI:SSOF') AS event_time
     FROM staff_check_ins
     WHERE organization_id = $1
       AND school_id = $2
       AND event_type = 'check_in'
       AND to_char(event_time, 'YYYY-MM') = $3`,
    [organizationId, schoolId, month],
  );
  return rows.map((r) => ({
    userId: r.user_id ?? "",
    employeeRef: r.employee_ref ?? "",
    eventType: r.event_type,
    eventTime: r.event_time,
  }));
}

/** Loads the (1-based) holiday day numbers for a YYYY-MM from the calendar. */
export async function loadHolidayDays(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  month: string,
): Promise<number[]> {
  const rows = await db.queryObject<{ day: string }>(
    `SELECT DISTINCT to_char(gs.d, 'DD') AS day
     FROM school_calendar_events e
     CROSS JOIN LATERAL generate_series(
       e.event_date,
       COALESCE(e.end_date, e.event_date),
       interval '1 day'
     ) AS gs(d)
     WHERE e.organization_id = $1
       AND e.school_id = $2
       AND e.event_type = 'holiday'
       AND to_char(gs.d, 'YYYY-MM') = $3`,
    [organizationId, schoolId, month],
  );
  return rows
    .map((r) => parseInt(r.day, 10))
    .filter((n) => Number.isFinite(n))
    .sort((a, b) => a - b);
}

/** Reads the org leave policy from `snapshot_settings.leavePolicy`, if set. */
export async function loadLeavePolicy(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Array<{ leaveType: string; entitlement: number }>> {
  const settings = await getSnapshotOrEmpty(db, organizationId, schoolId, "snapshot_settings");
  const policy = settings.leavePolicy;
  if (!Array.isArray(policy)) return DEFAULT_LEAVE_ENTITLEMENTS;
  const parsed = policy
    .map((p) => p as Record<string, unknown>)
    .filter((p) => text(p, "leaveType", "leave_type") !== "")
    .map((p) => ({
      leaveType: text(p, "leaveType", "leave_type"),
      entitlement: num(p, "entitlement", "days"),
    }));
  return parsed.length > 0 ? parsed : DEFAULT_LEAVE_ENTITLEMENTS;
}

/** Reads the payroll snapshot (or {} for a fresh school). */
export function loadPayrollSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  return getSnapshotOrEmpty(db, organizationId, schoolId, "snapshot_payroll");
}

/** Reads the leave snapshot (or {} for a fresh school). */
export function loadLeaveSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  return getSnapshotOrEmpty(db, organizationId, schoolId, "snapshot_leave");
}

/** Loads active/all employees for the headcount view. */
export async function loadHeadcountEmployees(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Array<{ status: string; department: string }>> {
  const rows = await db.queryObject<{ status: string; primary_department: string | null }>(
    `SELECT status, primary_department
     FROM employees
     WHERE organization_id = $1
       AND school_id = $2`,
    [organizationId, schoolId],
  );
  return rows.map((r) => ({ status: r.status, department: r.primary_department ?? "" }));
}
