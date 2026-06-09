/** API-facing student lifecycle statuses (Phase 5A2). */
export type SisApiStudentStatus = "active" | "inactive" | "graduated" | "transferred";

/** Database `students.status` values (Phase 2 schema — `alumni` stores graduated). */
export type SisDbStudentStatus = "active" | "inactive" | "alumni" | "transferred";

const TERMINAL_DB_STATUSES = new Set<SisDbStudentStatus>(["transferred", "alumni"]);

const ALLOWED_API = new Set<SisApiStudentStatus>([
  "active",
  "inactive",
  "graduated",
  "transferred",
]);

/**
 * Lifecycle rules (Phase 5A2):
 * - `active` ↔ `inactive` (reactivation allowed)
 * - `active` / `inactive` → `graduated` or `transferred` (terminal)
 * - `graduated` and `transferred` are terminal — no further transitions
 * - DB stores graduated as `alumni`
 */
export function statusToDb(status: string): SisDbStudentStatus {
  const normalized = status.trim().toLowerCase();
  if (normalized === "graduated" || normalized === "alumni") return "alumni";
  if (normalized === "transferred") return "transferred";
  if (normalized === "inactive") return "inactive";
  if (normalized === "active") return "active";
  throw new InvalidStudentStatusError(`Invalid student status: ${status}`);
}

export function statusFromDb(status: string): SisApiStudentStatus {
  const normalized = status.trim().toLowerCase();
  if (normalized === "alumni") return "graduated";
  if (normalized === "transferred") return "transferred";
  if (normalized === "inactive") return "inactive";
  if (normalized === "active") return "active";
  return "active";
}

export function parseApiStatus(status: string | undefined, fallback: SisApiStudentStatus = "active"): SisApiStudentStatus {
  if (!status?.trim()) return fallback;
  const normalized = status.trim().toLowerCase();
  if (normalized === "alumni") return "graduated";
  if (ALLOWED_API.has(normalized as SisApiStudentStatus)) {
    return normalized as SisApiStudentStatus;
  }
  throw new InvalidStudentStatusError(`Invalid student status: ${status}`);
}

export function assertValidStatusTransition(
  currentDbStatus: string,
  nextApiStatus: string,
): void {
  const current = statusToDb(statusFromDb(currentDbStatus));
  const next = statusToDb(nextApiStatus);

  if (current === next) return;

  if (TERMINAL_DB_STATUSES.has(current)) {
    throw new InvalidStudentStatusTransitionError(
      `Cannot transition from ${statusFromDb(current)} to ${statusFromDb(next)}`,
    );
  }
}

export class InvalidStudentStatusError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidStudentStatusError";
  }
}

export class InvalidStudentStatusTransitionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidStudentStatusTransitionError";
  }
}

export async function generateStudentCode(
  db: { queryObject<T>(sql: string, args?: unknown[]): Promise<T[]> },
  schoolId: string,
  year: number = new Date().getFullYear(),
): Promise<string> {
  const prefix = `STU-${year}-`;
  const rows = await db.queryObject<{ student_code: string }>(
    `SELECT student_code
     FROM students
     WHERE school_id = $1 AND student_code LIKE $2
     ORDER BY student_code DESC
     LIMIT 1`,
    [schoolId, `${prefix}%`],
  );
  const last = rows[0]?.student_code;
  let next = 1;
  if (last?.startsWith(prefix)) {
    const suffix = last.slice(prefix.length);
    const parsed = parseInt(suffix, 10);
    if (Number.isFinite(parsed)) next = parsed + 1;
  }
  return `${prefix}${String(next).padStart(5, "0")}`;
}
