// Adaptive AI — P3-AI-3 / W2.7: OPS-MODULE WORKLIST priority-item generators
// (design doc 06: FIN-R2/R3 · INV-4 · TRN-2/TRN-8 · HR doc/probation radar ·
// LIB-1/LIB-5).
//
// Each ops module already owns a deterministic worklist read (recovery call
// queue, low-stock list, document-expiry scans, overdue loans). W2.7 does NOT
// rebuild them — it surfaces each worklist as ONE bounded summary item on the
// school-persona priority feed, deep-linking into the module's existing
// worklist screen where the rows and one-click writes live. Zero model calls.
//
// Feed-flood rule: a school can have 200 defaulters; the feed's job (doc 04
// §3) is "what matters now", so every generator emits at most a summary item
// or two per module, never a row per entity — the module screen is the queue.
//
// Split, matching teacher_sources.ts: PURE generators (structural input →
// RawPriorityItem, no DB / no clock — unit-tested) + one async loader that
// does the permission-gated DB reads (reusing each module's existing
// repository/pure functions, per-source gate + degraded flag exactly like
// loadSchoolFeedSources).

import type { AccessTokenClaims } from "../../jwt.ts";
import { organizationIdFromClaims, schoolIdFromClaims } from "../../permission_middleware.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { listCallQueue, recoveryAggregates } from "../../finance/finance_recovery_repository.ts";
import { callQueuePriority, callQueueReason } from "../../finance/finance_recovery_handlers.ts";
import { listLowStock } from "../../inventory_finance/inventory_stock_repository.ts";
import { collectDocumentExpiries } from "../../transport/transport_write_handlers.ts";
import { listEntities as listTransportEntities } from "../../transport/transport_read_repository.ts";
import {
  buildExpiringDocuments,
  buildProbationEnding,
  loadEmployeePayloads,
} from "../../hr/hr_reports_repository.ts";
import { FINE_PER_DAY, listAllEntities, overdueList } from "../../library/library_aggregations.ts";
import type { Persona, RawPriorityItem } from "./priority_types.ts";

/** Ops worklists are school-operational surfaces: principal + admin. Director
 * is aggregate-only by law (doc 07 §5) and never receives them. */
const SCHOOL_OPS: Persona[] = ["principal", "admin"];
/** Finance worklists additionally serve the finance persona. */
const FINANCE_OPS: Persona[] = ["principal", "finance", "admin"];

const INR = (minor: number) => `₹${Math.round(minor / 100).toLocaleString("en-IN")}`;

// ─── Structural inputs (the loader maps module rows onto these) ──────────────

export interface OpsCallQueueEntryInput {
  studentName: string;
  outstandingMinor: number;
  /** callQueuePriority ranking: 0 broken promise … 5 future promise. */
  priority: number;
  /** callQueueReason human string for the same signals. */
  reason: string;
}

export interface OpsPtpAggregateInput {
  brokenPromises: number;
  promisesDueToday: number;
  promisesOverdue: number;
}

export interface OpsLowStockInput {
  itemName: string;
  quantityOnHand: number;
  reorderLevel: number;
}

export interface OpsDocumentExpiryInput {
  /** "Vehicle KA-01-…" / "Driver Ramesh" / employee name. */
  subject: string;
  /** "insurance" / "fitness" / "licence" / "contract" … */
  document: string;
  /** Days until expiry; negative = already expired. */
  inDays: number;
}

export interface OpsProbationInput {
  employee: string;
  daysToEnd: number;
}

export interface OpsOverdueLoanInput {
  daysOverdue: number;
  fineRupees: number;
}

// ─── Pure generators ─────────────────────────────────────────────────────────

/** FIN-R2 — the telecaller call queue, summarized. Only entries actionable
 * today (priority ≤ 3: broken promise, promise due, uncontacted arrears, or
 * 7+ days since contact) count — families who already promised a future date
 * are deliberately left alone (same rule as the queue screen). */
export function opsRecoveryItems(entries: OpsCallQueueEntryInput[]): RawPriorityItem[] {
  const actionable = entries.filter((e) => e.priority <= 3);
  if (actionable.length === 0) return [];
  const totalMinor = actionable.reduce((sum, e) => sum + Math.max(0, e.outstandingMinor), 0);
  const top = actionable.reduce((a, b) =>
    a.priority !== b.priority
      ? (a.priority < b.priority ? a : b)
      : (a.outstandingMinor >= b.outstandingMinor ? a : b)
  );
  const n = actionable.length;
  return [{
    itemKey: "ops:finance:call_queue",
    type: "follow_up",
    title: `Fee recovery — ${n} famil${n === 1 ? "y" : "ies"} to contact`,
    detail: `${INR(totalMinor)} outstanding across ${n} account${n === 1 ? "" : "s"}. ` +
      `Top: ${top.studentName} (${INR(top.outstandingMinor)} — ${top.reason}).`,
    personas: FINANCE_OPS,
    entityTags: ["school:fees", "ops:worklist"],
    factors: { moneyAtStakeMinor: totalMinor, peopleAffected: n },
    source: "ops_finance_recovery",
  }];
}

/** FIN-R3 — promise-to-pay lifecycle exceptions: broken promises are an
 * exception (trust signal), due/overdue promises are a today-deadline. */
export function opsPtpItems(agg: OpsPtpAggregateInput): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  if (agg.brokenPromises > 0) {
    items.push({
      itemKey: "ops:finance:ptp_broken",
      type: "exception",
      title: `${agg.brokenPromises} broken promise${agg.brokenPromises === 1 ? "" : "s"} to pay`,
      detail: `${agg.brokenPromises} payment promise${agg.brokenPromises === 1 ? "" : "s"} ` +
        `passed without collection. These families move to the top of the call queue.`,
      personas: FINANCE_OPS,
      entityTags: ["school:fees", "ops:worklist"],
      factors: { peopleAffected: agg.brokenPromises, impactClass: "elevated" },
      source: "ops_finance_ptp",
    });
  }
  const due = agg.promisesDueToday + agg.promisesOverdue;
  if (due > 0) {
    items.push({
      itemKey: "ops:finance:ptp_due",
      type: "deadline",
      title: `${due} payment promise${due === 1 ? "" : "s"} due`,
      detail: `${agg.promisesDueToday} due today, ${agg.promisesOverdue} past date and ` +
        `awaiting confirmation. Confirm collection or mark broken.`,
      personas: FINANCE_OPS,
      entityTags: ["school:fees", "ops:worklist"],
      factors: { dueInDays: 0, peopleAffected: due },
      source: "ops_finance_ptp",
    });
  }
  return items;
}

/** INV-4 — SKUs at/below reorder level, summarized. The low-stock screen rows
 * already carry a pre-filled draft PO (qty + last vendor) into the existing
 * procurement route — the feed only points there. */
export function opsInventoryItems(rows: OpsLowStockInput[]): RawPriorityItem[] {
  if (rows.length === 0) return [];
  const top = rows[0]!; // repo orders by largest gap first
  const n = rows.length;
  return [{
    itemKey: "ops:inventory:reorder",
    type: "exception",
    title: `${n} item${n === 1 ? "" : "s"} below reorder level`,
    detail: `Top: ${top.itemName} (on hand ${top.quantityOnHand}, reorder at ` +
      `${top.reorderLevel}). Raise pre-filled purchase orders from the low-stock list.`,
    personas: SCHOOL_OPS,
    entityTags: ["school:inventory", "ops:worklist"],
    factors: { impactClass: n >= 10 ? "serious" : "elevated" },
    source: "ops_inventory_reorder",
  }];
}

/** TRN-2/TRN-8 — vehicle document + driver licence expiry radar, summarized.
 * Anything already expired escalates the severity class. */
export function opsTransportItems(expiries: OpsDocumentExpiryInput[]): RawPriorityItem[] {
  if (expiries.length === 0) return [];
  const soonest = expiries.reduce((a, b) => (a.inDays <= b.inDays ? a : b));
  const expired = expiries.filter((e) => e.inDays < 0).length;
  const n = expiries.length;
  const soonestLabel = soonest.inDays < 0
    ? `${soonest.subject} ${soonest.document} expired ${-soonest.inDays} day${
      soonest.inDays === -1 ? "" : "s"
    } ago`
    : `${soonest.subject} ${soonest.document} expires in ${soonest.inDays} day${
      soonest.inDays === 1 ? "" : "s"
    }`;
  return [{
    itemKey: "ops:transport:doc_expiry",
    type: "deadline",
    title: expired > 0
      ? `${expired} transport document${expired === 1 ? "" : "s"} expired`
      : `${n} transport document${n === 1 ? "" : "s"} expiring soon`,
    detail: `${soonestLabel}. ${n} document${n === 1 ? "" : "s"} within the 30-day window.`,
    personas: SCHOOL_OPS,
    entityTags: ["school:transport", "ops:worklist"],
    factors: {
      dueInDays: soonest.inDays,
      impactClass: expired > 0 ? "serious" : "elevated",
    },
    source: "ops_transport_expiry",
  }];
}

/** HR document-expiry radar (contract/police-verification/medical/licence),
 * summarized — same C9 deadline family as transport. */
export function opsHrDocumentItems(rows: OpsDocumentExpiryInput[]): RawPriorityItem[] {
  if (rows.length === 0) return [];
  const soonest = rows.reduce((a, b) => (a.inDays <= b.inDays ? a : b));
  const expired = rows.filter((r) => r.inDays < 0).length;
  const n = rows.length;
  return [{
    itemKey: "ops:hr:doc_expiry",
    type: "deadline",
    title: expired > 0
      ? `${expired} staff document${expired === 1 ? "" : "s"} expired`
      : `${n} staff document${n === 1 ? "" : "s"} expiring soon`,
    detail: `${soonest.subject}: ${soonest.document} ${
      soonest.inDays < 0
        ? `expired ${-soonest.inDays} day${soonest.inDays === -1 ? "" : "s"} ago`
        : `expires in ${soonest.inDays} day${soonest.inDays === 1 ? "" : "s"}`
    }. ${n} in the 30-day window.`,
    personas: SCHOOL_OPS,
    entityTags: ["school:hr", "ops:worklist"],
    factors: {
      dueInDays: soonest.inDays,
      peopleAffected: n,
      impactClass: expired > 0 ? "serious" : "elevated",
    },
    source: "ops_hr_expiry",
  }];
}

/** Probation reviews falling due — a missed confirmation is never hidden
 * (lapsed reviews stay in the list, matching the report builder). */
export function opsProbationItems(rows: OpsProbationInput[]): RawPriorityItem[] {
  if (rows.length === 0) return [];
  const soonest = rows.reduce((a, b) => (a.daysToEnd <= b.daysToEnd ? a : b));
  const n = rows.length;
  return [{
    itemKey: "ops:hr:probation",
    type: "follow_up",
    title: `${n} probation review${n === 1 ? "" : "s"} due`,
    detail: `${soonest.employee}'s probation ${
      soonest.daysToEnd < 0
        ? `ended ${-soonest.daysToEnd} day${soonest.daysToEnd === -1 ? "" : "s"} ago`
        : `ends in ${soonest.daysToEnd} day${soonest.daysToEnd === 1 ? "" : "s"}`
    }. Confirm or extend from the probation list.`,
    personas: SCHOOL_OPS,
    entityTags: ["school:hr", "ops:worklist"],
    factors: { dueInDays: soonest.daysToEnd, peopleAffected: n },
    source: "ops_hr_probation",
  }];
}

/** LIB-1 — overdue loans worklist, summarized with accrued fines. Reminders
 * (LIB-5) fire from the overdue screen via the XCT-2 rail, not from here. */
export function opsLibraryItems(rows: OpsOverdueLoanInput[]): RawPriorityItem[] {
  if (rows.length === 0) return [];
  const finesMinor = rows.reduce((sum, r) => sum + Math.max(0, r.fineRupees) * 100, 0);
  const longest = rows.reduce((max, r) => Math.max(max, r.daysOverdue), 0);
  const n = rows.length;
  return [{
    itemKey: "ops:library:overdue",
    type: "follow_up",
    title: `${n} library book${n === 1 ? "" : "s"} overdue`,
    detail: `${INR(finesMinor)} in fines accrued; longest overdue ${longest} day${
      longest === 1 ? "" : "s"
    }. Send reminders from the overdue list.`,
    personas: SCHOOL_OPS,
    entityTags: ["school:library", "ops:worklist"],
    factors: { moneyAtStakeMinor: finesMinor, peopleAffected: n },
    source: "ops_library_overdue",
  }];
}

export interface OpsSourceInputs {
  callQueue?: OpsCallQueueEntryInput[];
  ptp?: OpsPtpAggregateInput;
  lowStock?: OpsLowStockInput[];
  transportExpiries?: OpsDocumentExpiryInput[];
  hrDocuments?: OpsDocumentExpiryInput[];
  probation?: OpsProbationInput[];
  libraryOverdue?: OpsOverdueLoanInput[];
}

/** Assemble every ops generator's output. Order is irrelevant — buildFeed
 * scores + sorts deterministically. */
export function collectOpsRawItems(inputs: OpsSourceInputs): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  if (inputs.callQueue) items.push(...opsRecoveryItems(inputs.callQueue));
  if (inputs.ptp) items.push(...opsPtpItems(inputs.ptp));
  if (inputs.lowStock) items.push(...opsInventoryItems(inputs.lowStock));
  if (inputs.transportExpiries) items.push(...opsTransportItems(inputs.transportExpiries));
  if (inputs.hrDocuments) items.push(...opsHrDocumentItems(inputs.hrDocuments));
  if (inputs.probation) items.push(...opsProbationItems(inputs.probation));
  if (inputs.libraryOverdue) items.push(...opsLibraryItems(inputs.libraryOverdue));
  return items;
}

// ─── Loader (permission-gated DB reads; reuses each module's own reads) ──────

/** Which ops sources a persona is entitled to see at all (relevance, before
 * RBAC): finance persona = finance worklists only; principal/admin = all. */
function applicableSources(persona: Persona): { finance: boolean; others: boolean } {
  if (persona === "finance") return { finance: true, others: false };
  if (persona === "principal" || persona === "admin") return { finance: true, others: true };
  return { finance: false, others: false };
}

const EXPIRY_WINDOW_DAYS = 30;
const PROBATION_WINDOW_DAYS = 15;

/** Load the school ops-worklist raw items under the current tenant
 * transaction. Every source is gated on its module's own view permission
 * (exactly the W2.0a pattern) and skipped-for-permission sources flip
 * `degraded`. Director gets nothing here by design (aggregate-only law) and is
 * NOT degraded. Reads are sequential — TenantQueryClient wraps one pooled
 * connection inside one transaction. Deterministic, zero model calls. */
export async function loadOpsWorklistSources(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  persona: Persona,
  nowIso: string,
): Promise<{ rawItems: RawPriorityItem[]; degraded: boolean }> {
  const applicable = applicableSources(persona);
  if (!applicable.finance && !applicable.others) {
    return { rawItems: [], degraded: false };
  }

  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const perms = claims.permissions;
  const today = nowIso.slice(0, 10);
  const now = new Date(nowIso);

  const inputs: OpsSourceInputs = {};
  let degraded = false;

  if (applicable.finance) {
    if (perms.includes("viewFinance")) {
      const queue = await listCallQueue(db, orgId, schoolId, 100);
      inputs.callQueue = queue.map((row) => {
        const signals = {
          daysOverdue: parseInt(row.days_overdue, 10) || 0,
          hasBrokenPromise: row.has_broken_promise === true,
          pendingPromiseDate: row.pending_promise_date,
          lastContactAt: row.last_contact_at,
          today,
        };
        return {
          studentName: row.student_name,
          // outstanding_amount is NUMERIC(12,2) rupees — convert to paise.
          outstandingMinor: Math.round((parseFloat(row.outstanding) || 0) * 100),
          priority: callQueuePriority(signals),
          reason: callQueueReason(signals),
        };
      });
      const monthStart = `${nowIso.slice(0, 7)}-01`;
      const agg = await recoveryAggregates(db, orgId, schoolId, monthStart);
      inputs.ptp = {
        brokenPromises: parseInt(agg.ptp_broken, 10) || 0,
        promisesDueToday: parseInt(agg.ptp_due_today, 10) || 0,
        promisesOverdue: parseInt(agg.ptp_overdue, 10) || 0,
      };
    } else {
      degraded = true;
    }
  }

  if (applicable.others) {
    if (perms.includes("viewInventory")) {
      const lowStock = await listLowStock(db, orgId, schoolId);
      inputs.lowStock = lowStock.map((r) => ({
        itemName: r.itemName,
        quantityOnHand: r.quantityOnHand,
        reorderLevel: r.reorderLevel,
      }));
    } else {
      degraded = true;
    }

    if (perms.includes("viewTransport")) {
      // Fleet reads are paginated at 100/page; one page covers any realistic
      // single-school fleet (a >100-vehicle fleet would only soften the radar,
      // never break it).
      const wide = { page: 1, pageSize: 100 };
      const vehicles = await listTransportEntities(db, orgId, schoolId, "vehicle", wide);
      const drivers = await listTransportEntities(db, orgId, schoolId, "driver", wide);
      inputs.transportExpiries = collectDocumentExpiries(
        vehicles.items,
        drivers.items,
        EXPIRY_WINDOW_DAYS,
        now,
      ).map((e) => ({ subject: e.subject, document: e.document, inDays: e.inDays }));
    } else {
      degraded = true;
    }

    if (perms.includes("viewHr")) {
      const employees = await loadEmployeePayloads(db, orgId, schoolId);
      const docs = buildExpiringDocuments(employees, EXPIRY_WINDOW_DAYS, today);
      const probation = buildProbationEnding(employees, PROBATION_WINDOW_DAYS, today);
      inputs.hrDocuments = docs.rows.map((r) => ({
        subject: r.employee,
        document: r.docType,
        inDays: r.daysToExpiry,
      }));
      inputs.probation = probation.rows.map((r) => ({
        employee: r.employee,
        daysToEnd: r.daysToEnd,
      }));
    } else {
      degraded = true;
    }

    if (perms.includes("viewLibrary")) {
      const issues = await listAllEntities(db, orgId, schoolId, "issue");
      inputs.libraryOverdue = overdueList(issues, now).map((row) => {
        const days = Number(row.daysOverdue ?? 0);
        return { daysOverdue: days, fineRupees: days * FINE_PER_DAY };
      });
    } else {
      degraded = true;
    }
  }

  return { rawItems: collectOpsRawItems(inputs), degraded };
}
