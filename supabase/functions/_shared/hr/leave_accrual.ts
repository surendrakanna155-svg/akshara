// PRA-P1-34 (Owner decision #10, FINAL) — leave accrual + carry-forward: the PURE
// computation core. NO database, NO I/O — given a config-driven policy + the
// employee join date + an as-of date (+ prior deductions), it computes the days
// accrued, applies the carry-forward cap + lapse + max-balance rules, and returns
// the exact ledger entries that SHOULD exist. The repository writes those entries
// idempotently (period-key guard); this module owns the math and is exhaustively
// unit-testable on its own.
//
// ── Accrual model (deterministic) ────────────────────────────────────────────
// Accrual is granted for each accrual period the employee is in service:
//   • monthly — one 'accrual' entry per calendar month from the JOIN month through
//     the AS-OF month (inclusive), each worth the full `accrualRate`. A mid-YEAR
//     join is therefore naturally prorated: an employee who joins in July accrues
//     only 6 monthly entries in that first year (period keys '2026-07'…'2026-12').
//   • annual — one 'accrual' entry per calendar YEAR, worth
//     `accrualRate * monthsInService(year) / 12`. A mid-year join prorates the
//     first year (join July → 6/12 → half the annual rate); full years get the
//     full rate.
// Both cadences reduce to the same identity: days accrued in a year =
//   perMonthRate * monthsInService(year),  where perMonthRate = accrualRate      (monthly)
//                                                             = accrualRate / 12  (annual)
//
// ── Carry-forward + lapse (year boundaries) ──────────────────────────────────
// At the end of every COMPLETED accrual year (any year before the as-of year) the
// balance transitions into the next year:
//   • carried  = (carryForwardCap != null && lapses) ? min(balance, cap) : balance
//   • lapsed   = balance − carried
// So:
//   – cap set + lapses      → excess above the cap is FORFEITED (cap hit).
//   – cap 0  + lapses       → use-it-or-lose-it: the whole balance lapses.
//   – cap null (unlimited)  → nothing lapses, the full balance rolls.
//   – lapses = false        → nothing lapses regardless of cap, the full balance rolls.
// A lapse is recorded as a NEGATIVE 'lapse' ledger entry (period key 'lapse:YYYY'),
// so the derivable balance (Σ amount) stays exact. Carry-forward needs no entry —
// the retained balance simply persists into the next year.
//
// ── Max balance (running cap) ────────────────────────────────────────────────
// `maxBalance` (when set) caps the balance DURING accrual: an accrual entry is
// reduced so the running balance never exceeds the cap (a period may accrue less
// than the full rate, or nothing). This is independent of the year-end
// carry-forward cap.

export type AccrualPeriod = "monthly" | "annual";

/** A config-driven accrual policy — read from `leave_accrual_policies`, never hardcoded. */
export interface LeaveAccrualPolicy {
  /** Free-form leave-type ref (e.g. 'casual', 'sick', 'earned') — NOT an enum. */
  leaveType: string;
  /** Days accrued per accrual period (per month for monthly, per year for annual). */
  accrualRate: number;
  accrualPeriod: AccrualPeriod;
  /** Days granted once when accrual begins. */
  openingBalance: number;
  /** Max days carried into the next year; `null` = unlimited carry-forward. */
  carryForwardCap: number | null;
  /** Running cap on the balance; `null` = unlimited. */
  maxBalance: number | null;
  /** Whether the excess above the carry-forward cap is forfeited at year end. */
  lapses: boolean;
}

export type LedgerEntryType =
  | "opening"
  | "accrual"
  | "lapse"
  | "deduction"
  | "adjustment";

/** A ledger entry the accrual run intends to write (idempotent on period_key). */
export interface PlannedLedgerEntry {
  entryType: LedgerEntryType;
  leaveType: string;
  /** Signed day amount: positive credits (opening/accrual), negative debits (lapse). */
  amount: number;
  /** Idempotency dimension: '2026-07' (monthly), '2026' (annual), 'opening', 'lapse:2026'. */
  periodKey: string;
  /** ISO yyyy-mm-dd the entry is effective. */
  asOfDate: string;
  note: string;
}

/** The full result of an accrual computation. */
export interface AccrualResult {
  leaveType: string;
  /** The opening balance granted (policy.openingBalance). */
  openingBalance: number;
  /** Gross days accrued across all periods (before lapse), net of max-balance capping. */
  totalAccrued: number;
  /** Total days forfeited across year boundaries. */
  totalLapsed: number;
  /** Days consumed by prior leave (passed in from the existing ledger). */
  priorDeductions: number;
  /**
   * The derivable balance as of `asOfDate`:
   *   openingBalance + totalAccrued − totalLapsed − priorDeductions.
   * Equals SUM(amount) over the full ledger (accrual entries + the prior
   * deduction entries the caller accounted for).
   */
  balance: number;
  /** The ledger entries the run should upsert (opening + accruals + lapses). */
  entries: PlannedLedgerEntry[];
}

const MS_PER_DAY = 86_400_000;

/** Parses an ISO yyyy-mm-dd into a UTC Date at midnight (no timezone drift). */
function parseIsoDate(iso: string): Date {
  const [y, m, d] = iso.slice(0, 10).split("-").map((n) => parseInt(n, 10));
  return new Date(Date.UTC(y, (m || 1) - 1, d || 1));
}

/** Rounds to 2 decimals (day amounts are NUMERIC(8,2)); avoids float drift. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Absolute month index (year*12 + monthIndex) for month arithmetic. */
function monthOrdinal(date: Date): number {
  return date.getUTCFullYear() * 12 + date.getUTCMonth();
}

/**
 * Number of accrual months of service in `year`, bounded by the employment
 * window [joinDate, asOfDate]. A month counts when the employee was in service
 * during it: from the join month (in the join year) through the as-of month (in
 * the as-of year). Returns 0 for years fully before the join or after as-of.
 */
export function monthsInServiceForYear(
  joinDate: string,
  asOfDate: string,
  year: number,
): number {
  const join = parseIsoDate(joinDate);
  const asOf = parseIsoDate(asOfDate);
  if (asOf.getTime() < join.getTime()) return 0;

  // First in-service month in this year.
  const startMonth = join.getUTCFullYear() === year ? join.getUTCMonth() : 0;
  // Last in-service month in this year.
  const endMonth = asOf.getUTCFullYear() === year ? asOf.getUTCMonth() : 11;

  // Year entirely outside the [join, asOf] window.
  if (year < join.getUTCFullYear() || year > asOf.getUTCFullYear()) return 0;

  return Math.max(0, endMonth - startMonth + 1);
}

/** The per-MONTH accrual rate: annual policies spread their rate across 12 months. */
export function perMonthRate(policy: LeaveAccrualPolicy): number {
  return policy.accrualPeriod === "annual"
    ? policy.accrualRate / 12
    : policy.accrualRate;
}

/** Zero-padded 'YYYY-MM' period key for a monthly accrual. */
function monthKey(year: number, monthIndex0: number): string {
  return `${year}-${String(monthIndex0 + 1).padStart(2, "0")}`;
}

/** Last calendar day (yyyy-mm-dd) of a month, used as a monthly accrual's as-of date. */
function monthEndIso(year: number, monthIndex0: number): string {
  // Day 0 of next month = last day of this month.
  const d = new Date(Date.UTC(year, monthIndex0 + 1, 0));
  return d.toISOString().slice(0, 10);
}

/** Min that treats `null` cap as "no cap" (unlimited). */
function capOrInfinity(cap: number | null): number {
  return cap == null ? Number.POSITIVE_INFINITY : cap;
}

/**
 * The pure accrual computation. Deterministic in its inputs; emits the exact
 * ledger the run should hold. See the module header for the full model.
 *
 * @param policy         config-driven policy (read from the DB, never hardcoded)
 * @param joinDate       employment start (drives proration), ISO yyyy-mm-dd
 * @param asOfDate       compute accrual through this date, ISO yyyy-mm-dd
 * @param opts.priorDeductions  days already consumed by approved leave (from the
 *   existing ledger) — netted into the returned balance. Default 0.
 */
export function computeAccrual(
  policy: LeaveAccrualPolicy,
  joinDate: string,
  asOfDate: string,
  opts: { priorDeductions?: number } = {},
): AccrualResult {
  const priorDeductions = Math.max(0, opts.priorDeductions ?? 0);
  const openingBalance = Math.max(0, policy.openingBalance);
  const maxCap = capOrInfinity(policy.maxBalance);
  const entries: PlannedLedgerEntry[] = [];

  const join = parseIsoDate(joinDate);
  const asOf = parseIsoDate(asOfDate);

  // Nothing accrues before employment starts: opening only (still granted once).
  let balance = 0;
  if (openingBalance > 0) {
    // The opening grant is itself bounded by the running max balance.
    const openingCredited = round2(Math.min(openingBalance, maxCap));
    balance = openingCredited;
    entries.push({
      entryType: "opening",
      leaveType: policy.leaveType,
      amount: openingCredited,
      periodKey: "opening",
      asOfDate: joinDate,
      note: "Opening balance",
    });
  }

  let totalAccrued = 0;
  let totalLapsed = 0;

  if (asOf.getTime() >= join.getTime()) {
    const rate = perMonthRate(policy);
    const joinYear = join.getUTCFullYear();
    const asOfYear = asOf.getUTCFullYear();

    for (let year = joinYear; year <= asOfYear; year++) {
      const months = monthsInServiceForYear(joinDate, asOfDate, year);

      if (policy.accrualPeriod === "annual") {
        // One accrual entry for the whole year, prorated by months of service.
        const gross = rate * months;
        const headroom = Math.max(0, maxCap - balance);
        const credited = round2(Math.min(gross, headroom));
        if (credited > 0) {
          balance = round2(balance + credited);
          totalAccrued = round2(totalAccrued + credited);
          entries.push({
            entryType: "accrual",
            leaveType: policy.leaveType,
            amount: credited,
            periodKey: String(year),
            asOfDate: year === asOfYear ? asOfDate : `${year}-12-31`,
            note: `Annual accrual (${months} month${months === 1 ? "" : "s"} of service)`,
          });
        }
      } else {
        // Monthly: one accrual entry per in-service month of this year.
        const startMonth = year === joinYear ? join.getUTCMonth() : 0;
        for (let i = 0; i < months; i++) {
          const monthIndex0 = startMonth + i;
          const headroom = Math.max(0, maxCap - balance);
          const credited = round2(Math.min(rate, headroom));
          if (credited > 0) {
            balance = round2(balance + credited);
            totalAccrued = round2(totalAccrued + credited);
            const isAsOfMonth = year === asOfYear &&
              monthIndex0 === asOf.getUTCMonth();
            entries.push({
              entryType: "accrual",
              leaveType: policy.leaveType,
              amount: credited,
              periodKey: monthKey(year, monthIndex0),
              asOfDate: isAsOfMonth ? asOfDate : monthEndIso(year, monthIndex0),
              note: "Monthly accrual",
            });
          }
        }
      }

      // Year-end carry-forward / lapse transition — only for COMPLETED years
      // (every year strictly before the as-of year).
      if (year < asOfYear) {
        const cap = capOrInfinity(policy.carryForwardCap);
        const carried = policy.lapses ? Math.min(balance, cap) : balance;
        const lapsed = round2(balance - carried);
        if (lapsed > 0) {
          totalLapsed = round2(totalLapsed + lapsed);
          balance = round2(balance - lapsed);
          entries.push({
            entryType: "lapse",
            leaveType: policy.leaveType,
            amount: -lapsed,
            periodKey: `lapse:${year}`,
            asOfDate: `${year}-12-31`,
            note: policy.carryForwardCap != null
              ? `Year-end lapse above carry-forward cap ${policy.carryForwardCap}`
              : "Year-end lapse",
          });
        }
      }
    }
  }

  const finalBalance = round2(openingBalance > 0
    ? round2(Math.min(openingBalance, maxCap)) + totalAccrued - totalLapsed - priorDeductions
    : totalAccrued - totalLapsed - priorDeductions);

  return {
    leaveType: policy.leaveType,
    openingBalance,
    totalAccrued,
    totalLapsed,
    priorDeductions,
    balance: finalBalance,
    entries,
  };
}

/**
 * Derives the current balance from a set of ledger entries — the exact TS mirror
 * of the SQL `SUM(amount)` the read path uses. Amounts are signed, so this nets
 * opening + accrual − lapse − deduction with no separate bookkeeping.
 */
export function deriveBalance(entries: Array<{ amount: number }>): number {
  return round2(entries.reduce((sum, e) => sum + (Number(e.amount) || 0), 0));
}
