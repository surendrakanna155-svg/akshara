import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { COMPLAINT_STATUSES, LEGAL_TRANSITIONS } from "./complaints_sla.ts";
import {
  assignComplaint,
  attachPhoto,
  attachVendor,
  type ComplaintRow,
  ComplaintConflictError,
  ComplaintNotFoundError,
  findVendorInScope,
  getComplaint,
  IllegalAssignError,
  IllegalTransitionError,
  listComplaintEvents,
  listComplaints,
  markFirstResponse,
  raiseComplaint,
  recordEvent,
  ResolutionNoteRequiredError,
  transitionStatus,
} from "./complaints_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const OTHER_SCHOOL = "a2000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const ASSIGNEE = "a3000000-0000-4000-8000-000000000002";
const PARENT_A = "a5000000-0000-4000-8000-000000000001";
const PARENT_B = "a5000000-0000-4000-8000-000000000002";
const SCOPE = { organizationId: ORG, schoolId: SCHOOL };

let clock = 0;
function nextTimestamp(): string {
  clock += 1;
  return new Date(2026, 6, 15, 0, 0, clock).toISOString();
}

/**
 * Faithful in-memory model of the exact SQL the complaints repository issues.
 * Every UPDATE branch honors the SAME status guard the real SQL carries (a
 * lost race yields zero rows, exactly like the real `AND status = $n`), so
 * the concurrency tests below prove the same thing a live Postgres would.
 */
class ComplaintsMockDb {
  complaints = new Map<string, ComplaintRow>();
  events: Array<{
    id: string;
    organization_id: string;
    school_id: string;
    complaint_id: string;
    event_type: string;
    actor_id: string;
    actor_name: string;
    note: string | null;
    metadata: Record<string, unknown>;
    occurred_at: string;
  }> = [];
  vendors = new Map<string, { id: string; organization_id: string; school_id: string; display_name: string }>();

  seedComplaint(row: Partial<ComplaintRow> & { id: string }) {
    const base: ComplaintRow = {
      organization_id: ORG,
      school_id: SCHOOL,
      category: "facilities",
      title: "Broken fan",
      description: "",
      severity: "medium",
      status: "open",
      raised_by: STAFF,
      raised_by_role: "teacher",
      related_student_id: null,
      assigned_to: null,
      assigned_at: null,
      assigned_by: null,
      sla_due_at: "2026-07-20T00:00:00.000Z",
      first_response_at: null,
      resolved_at: null,
      resolved_by: null,
      resolution_note: null,
      reopened_count: 0,
      vendor_id: null,
      repair_cost: null,
      photo_path: null,
      created_at: nextTimestamp(),
      updated_at: nextTimestamp(),
      ...row,
    };
    this.complaints.set(row.id, base);
    return base;
  }

  seedVendor(id: string, schoolId: string, displayName: string) {
    this.vendors.set(id, { id, organization_id: ORG, school_id: schoolId, display_name: displayName });
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // ── raise ──────────────────────────────────────────────────────────
    if (sql.includes("INSERT INTO complaints")) {
      const id = crypto.randomUUID();
      const row: ComplaintRow = {
        organization_id: String(args[0]),
        school_id: String(args[1]),
        category: String(args[2]),
        title: String(args[3]),
        description: String(args[4]),
        severity: String(args[5]),
        status: "open",
        raised_by: String(args[6]),
        raised_by_role: String(args[7]),
        related_student_id: (args[8] as string | null) ?? null,
        assigned_to: null,
        assigned_at: null,
        assigned_by: null,
        sla_due_at: String(args[9]),
        first_response_at: null,
        resolved_at: null,
        resolved_by: null,
        resolution_note: null,
        reopened_count: 0,
        vendor_id: null,
        repair_cost: null,
        photo_path: (args[10] as string | null) ?? null,
        created_at: nextTimestamp(),
        updated_at: nextTimestamp(),
        id,
      } as ComplaintRow;
      this.complaints.set(id, row);
      return [row] as T[];
    }

    // ── list (has ORDER BY created_at DESC + a dynamic LIMIT $n) ────────
    if (sql.includes("FROM complaints") && sql.includes("ORDER BY created_at DESC")) {
      let idx = 2;
      let statusF: string | undefined, categoryF: string | undefined, severityF: string | undefined;
      let assignedToF: string | undefined, raisedByF: string | undefined;
      if (sql.includes("AND status = $")) statusF = String(args[idx++]);
      if (sql.includes("AND category = $")) categoryF = String(args[idx++]);
      if (sql.includes("AND severity = $")) severityF = String(args[idx++]);
      if (sql.includes("AND assigned_to = $")) assignedToF = String(args[idx++]);
      if (sql.includes("AND raised_by = $")) raisedByF = String(args[idx++]);
      const limit = Number(args[idx]);
      const orgId = String(args[0]);
      const schoolId = String(args[1]);
      const rows = [...this.complaints.values()]
        .filter((c) =>
          c.organization_id === orgId && c.school_id === schoolId &&
          (!statusF || c.status === statusF) &&
          (!categoryF || c.category === categoryF) &&
          (!severityF || c.severity === severityF) &&
          (!assignedToF || c.assigned_to === assignedToF) &&
          (!raisedByF || c.raised_by === raisedByF)
        )
        .sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
        .slice(0, limit);
      return rows as T[];
    }

    // ── detail (LIMIT 1, optional raised_by restriction as the 4th arg) ─
    if (sql.includes("FROM complaints") && sql.includes("LIMIT 1")) {
      const [orgId, schoolId, id, raisedBy] = args as [string, string, string, string?];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      if (sql.includes("raised_by = $4") && c.raised_by !== raisedBy) return [] as T[];
      return [c] as T[];
    }

    // ── events timeline ──────────────────────────────────────────────
    if (sql.includes("FROM complaint_events")) {
      const [orgId, schoolId, complaintId] = args as [string, string, string];
      return this.events
        .filter((e) =>
          e.organization_id === orgId && e.school_id === schoolId && e.complaint_id === complaintId
        )
        .sort((a, b) => (a.occurred_at < b.occurred_at ? -1 : 1)) as unknown as T[];
    }

    if (sql.includes("INSERT INTO complaint_events")) {
      const [orgId, schoolId, complaintId, eventType, actorId, actorName, note, metadataJson] = args as [
        string,
        string,
        string,
        string,
        string,
        string,
        string | null,
        string,
      ];
      const row = {
        id: crypto.randomUUID(),
        organization_id: orgId,
        school_id: schoolId,
        complaint_id: complaintId,
        event_type: eventType,
        actor_id: actorId,
        actor_name: actorName,
        note,
        metadata: JSON.parse(metadataJson),
        occurred_at: nextTimestamp(),
      };
      this.events.push(row);
      return [row] as T[];
    }

    // ── assign (guarded on status IN (...), parsed from the SQL itself) ─
    if (sql.includes("SET assigned_to") && sql.includes("status = 'assigned'")) {
      const [orgId, schoolId, id, assignedTo, assignedBy] = args as [string, string, string, string, string];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      const m = sql.match(/status IN \(([^)]+)\)/);
      const allowed = m ? m[1].split(",").map((s) => s.trim().replace(/'/g, "")) : [];
      if (!allowed.includes(c.status)) return [] as T[];
      c.assigned_to = assignedTo;
      c.assigned_by = assignedBy;
      c.assigned_at = nextTimestamp();
      c.status = "assigned";
      c.updated_at = nextTimestamp();
      return [c] as T[];
    }

    // ── status transition: resolved branch ──────────────────────────
    if (sql.includes("resolved_at = timezone")) {
      const [orgId, schoolId, id, to, resolvedBy, note, expectedFrom] = args as [
        string,
        string,
        string,
        string,
        string,
        string,
        string,
      ];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      if (c.status !== expectedFrom) return [] as T[]; // lost the race
      c.status = to;
      c.resolved_at = nextTimestamp();
      c.resolved_by = resolvedBy;
      c.resolution_note = note;
      c.updated_at = nextTimestamp();
      return [c] as T[];
    }

    // ── status transition: reopened branch ──────────────────────────
    if (sql.includes("reopened_count = reopened_count + 1")) {
      const [orgId, schoolId, id, to, expectedFrom] = args as [string, string, string, string, string];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      if (c.status !== expectedFrom) return [] as T[];
      c.status = to;
      c.reopened_count += 1;
      c.resolved_at = null;
      c.resolved_by = null;
      c.updated_at = nextTimestamp();
      return [c] as T[];
    }

    // ── status transition: generic branch ─────────────────────────────
    if (sql.includes("SET status = $4, updated_at")) {
      const [orgId, schoolId, id, to, expectedFrom] = args as [string, string, string, string, string];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      if (c.status !== expectedFrom) return [] as T[];
      c.status = to;
      c.updated_at = nextTimestamp();
      return [c] as T[];
    }

    // ── first-response marker ────────────────────────────────────────
    if (sql.includes("first_response_at = timezone") && sql.includes("first_response_at IS NULL")) {
      const [orgId, schoolId, id] = args as [string, string, string];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      if (c.first_response_at != null) return [] as T[];
      c.first_response_at = nextTimestamp();
      c.updated_at = nextTimestamp();
      return [{ id: c.id }] as T[];
    }

    // ── vendor lookup ─────────────────────────────────────────────────
    if (sql.includes("FROM inventory_vendors")) {
      const [orgId, schoolId, vendorId] = args as [string, string, string];
      const v = this.vendors.get(vendorId);
      if (!v || v.organization_id !== orgId || v.school_id !== schoolId) return [] as T[];
      return [{ id: v.id, display_name: v.display_name }] as T[];
    }

    // ── vendor attach ─────────────────────────────────────────────────
    if (sql.includes("SET vendor_id")) {
      const [orgId, schoolId, id, vendorId, repairCost] = args as [
        string,
        string,
        string,
        string,
        number | null,
      ];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      c.vendor_id = vendorId;
      c.repair_cost = repairCost == null ? null : String(repairCost);
      c.updated_at = nextTimestamp();
      return [c] as T[];
    }

    // ── photo attach ──────────────────────────────────────────────────
    if (sql.includes("SET photo_path")) {
      const [orgId, schoolId, id, photoPath] = args as [string, string, string, string];
      const c = this.complaints.get(id);
      if (!c || c.organization_id !== orgId || c.school_id !== schoolId) return [] as T[];
      c.photo_path = photoPath;
      c.updated_at = nextTimestamp();
      return [c] as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
}

function client(mock: ComplaintsMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ── raise / list / detail ────────────────────────────────────────────────

Deno.test("raiseComplaint: inserts an 'open' complaint with the given sla_due_at", async () => {
  const mock = new ComplaintsMockDb();
  const slaDueAt = new Date("2026-07-16T04:00:00.000Z");
  const row = await raiseComplaint(client(mock), SCOPE, {
    category: "facilities",
    title: "Broken classroom fan",
    description: "Fan in room 4B stopped working",
    severity: "high",
    raisedBy: PARENT_A,
    raisedByRole: "parent",
    slaDueAt,
  });
  assertEquals(row.status, "open");
  assertEquals(row.sla_due_at, slaDueAt.toISOString());
  assertEquals(row.raised_by, PARENT_A);
  assertEquals(mock.complaints.size, 1);
});

Deno.test("listComplaints: no filters returns the whole school queue, newest first", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", raised_by: STAFF });
  mock.seedComplaint({ id: "c2", raised_by: PARENT_A });
  mock.seedComplaint({ id: "c3", school_id: OTHER_SCHOOL }); // different school — excluded
  const rows = await listComplaints(client(mock), SCOPE, {});
  assertEquals(rows.length, 2);
  assertEquals(rows[0].id, "c2"); // newest first (seeded later => later created_at)
});

Deno.test("listComplaints: status filter narrows the queue", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "open" });
  mock.seedComplaint({ id: "c2", status: "resolved" });
  const rows = await listComplaints(client(mock), SCOPE, { status: "resolved" });
  assertEquals(rows.length, 1);
  assertEquals(rows[0].id, "c2");
});

Deno.test("listComplaints: raisedBy filter restricts to a single raiser's own complaints (parent / bare raiser view)", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", raised_by: PARENT_A });
  mock.seedComplaint({ id: "c2", raised_by: PARENT_B });
  const rows = await listComplaints(client(mock), SCOPE, { raisedBy: PARENT_A });
  assertEquals(rows.length, 1);
  assertEquals(rows[0].raised_by, PARENT_A);
});

Deno.test("listComplaints: assignedTo filter drives the assignee's queue", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", assigned_to: ASSIGNEE, status: "assigned" });
  mock.seedComplaint({ id: "c2", assigned_to: STAFF, status: "assigned" });
  const rows = await listComplaints(client(mock), SCOPE, { assignedTo: ASSIGNEE });
  assertEquals(rows.length, 1);
  assertEquals(rows[0].id, "c1");
});

Deno.test("getComplaint: returns the row when it exists in scope", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1" });
  const row = await getComplaint(client(mock), SCOPE, "c1");
  assertEquals(row.id, "c1");
});

Deno.test("getComplaint: throws NotFound for a missing id", async () => {
  const mock = new ComplaintsMockDb();
  await assertRejects(() => getComplaint(client(mock), SCOPE, "missing"), ComplaintNotFoundError);
});

Deno.test("getComplaint: a raisedBy-restricted lookup 404s on someone else's complaint (parent isolation — no enumeration leak)", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", raised_by: PARENT_B });
  await assertRejects(
    () => getComplaint(client(mock), SCOPE, "c1", PARENT_A),
    ComplaintNotFoundError,
  );
  // But the actual raiser CAN see it.
  const row = await getComplaint(client(mock), SCOPE, "c1", PARENT_B);
  assertEquals(row.id, "c1");
});

Deno.test("getComplaint: a different school's complaint is invisible even with the right id", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", school_id: OTHER_SCHOOL });
  await assertRejects(() => getComplaint(client(mock), SCOPE, "c1"), ComplaintNotFoundError);
});

// ── append-only timeline ────────────────────────────────────────────────

Deno.test("recordEvent + listComplaintEvents: the timeline accumulates in occurred_at order (append-only)", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1" });
  await recordEvent(client(mock), SCOPE, { complaintId: "c1", eventType: "raised", actorId: PARENT_A });
  await recordEvent(client(mock), SCOPE, {
    complaintId: "c1",
    eventType: "assigned",
    actorId: STAFF,
    metadata: { assignedTo: ASSIGNEE },
  });
  await recordEvent(client(mock), SCOPE, { complaintId: "c1", eventType: "commented", actorId: ASSIGNEE, note: "on it" });
  const events = await listComplaintEvents(client(mock), SCOPE, "c1");
  assertEquals(events.length, 3);
  assertEquals(events.map((e) => e.event_type), ["raised", "assigned", "commented"]);
  // Earlier events are never mutated by a later append.
  assertEquals(events[0].actor_id, PARENT_A);
  assertEquals(events[1].metadata, { assignedTo: ASSIGNEE });
});

// ── assign ──────────────────────────────────────────────────────────────

Deno.test("assignComplaint: legal from 'open' — sets assignment fields and status", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "open" });
  const row = await assignComplaint(client(mock), SCOPE, "c1", { assignedTo: ASSIGNEE, assignedBy: STAFF });
  assertEquals(row.status, "assigned");
  assertEquals(row.assigned_to, ASSIGNEE);
  assertEquals(row.assigned_by, STAFF);
  assertEquals(row.assigned_at != null, true);
});

Deno.test("assignComplaint: legal from 'reopened'", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "reopened", reopened_count: 1 });
  const row = await assignComplaint(client(mock), SCOPE, "c1", { assignedTo: ASSIGNEE, assignedBy: STAFF });
  assertEquals(row.status, "assigned");
});

Deno.test("assignComplaint: illegal from 'resolved' throws IllegalAssignError, nothing written", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "resolved" });
  await assertRejects(
    () => assignComplaint(client(mock), SCOPE, "c1", { assignedTo: ASSIGNEE, assignedBy: STAFF }),
    IllegalAssignError,
  );
  assertEquals(mock.complaints.get("c1")!.assigned_to, null);
});

Deno.test("assignComplaint: illegal from 'closed' throws IllegalAssignError", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "closed" });
  await assertRejects(
    () => assignComplaint(client(mock), SCOPE, "c1", { assignedTo: ASSIGNEE, assignedBy: STAFF }),
    IllegalAssignError,
  );
});

Deno.test("assignComplaint: a missing complaint 404s (not IllegalAssign)", async () => {
  const mock = new ComplaintsMockDb();
  await assertRejects(
    () => assignComplaint(client(mock), SCOPE, "missing", { assignedTo: ASSIGNEE, assignedBy: STAFF }),
    ComplaintNotFoundError,
  );
});

// ── status transition: the FULL legal table, edge by edge ──────────────

Deno.test("transitionStatus: every legal edge in the table actually applies", async () => {
  for (const [from, targets] of Object.entries(LEGAL_TRANSITIONS)) {
    for (const to of targets) {
      const mock = new ComplaintsMockDb();
      mock.seedComplaint({
        id: "c1",
        status: from,
        reopened_count: from === "resolved" || from === "closed" ? 0 : 0,
      });
      const resolutionNote = to === "resolved" ? "Fixed the fan motor" : undefined;
      const row = await transitionStatus(client(mock), SCOPE, "c1", {
        to: to as (typeof COMPLAINT_STATUSES)[number],
        expectedFrom: from,
        resolutionNote,
        actorId: STAFF,
      });
      assertEquals(row.status, to, `${from} -> ${to}`);
      if (to === "resolved") {
        assertEquals(row.resolved_at != null, true, `${from} -> resolved sets resolved_at`);
        assertEquals(row.resolution_note, resolutionNote);
      }
      if (to === "reopened") {
        assertEquals(row.resolved_at, null, `${from} -> reopened clears resolved_at`);
        assertEquals(row.resolved_by, null);
      }
    }
  }
});

Deno.test("transitionStatus: reopen increments reopened_count on EVERY reopen (not just once)", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "resolved", resolved_at: "2026-07-15T00:00:00.000Z", resolved_by: STAFF });
  const first = await transitionStatus(client(mock), SCOPE, "c1", {
    to: "reopened",
    expectedFrom: "resolved",
    actorId: STAFF,
  });
  assertEquals(first.reopened_count, 1);
  assertEquals(first.resolved_at, null);

  // Resolve again, then reopen again.
  await transitionStatus(client(mock), SCOPE, "c1", {
    to: "resolved",
    expectedFrom: "reopened",
    resolutionNote: "Fixed again",
    actorId: STAFF,
  });
  const second = await transitionStatus(client(mock), SCOPE, "c1", {
    to: "reopened",
    expectedFrom: "resolved",
    actorId: STAFF,
  });
  assertEquals(second.reopened_count, 2);
});

Deno.test("transitionStatus: EVERY illegal pair in the full status x status matrix is rejected, no write", async () => {
  let illegalChecked = 0;
  for (const from of COMPLAINT_STATUSES) {
    for (const to of COMPLAINT_STATUSES) {
      const legal = (LEGAL_TRANSITIONS[from] as readonly string[]).includes(to);
      if (legal) continue;
      illegalChecked++;
      const mock = new ComplaintsMockDb();
      mock.seedComplaint({ id: "c1", status: from });
      await assertRejects(
        () =>
          transitionStatus(client(mock), SCOPE, "c1", {
            to,
            expectedFrom: from,
            resolutionNote: to === "resolved" ? "note" : undefined,
            actorId: STAFF,
          }),
        IllegalTransitionError,
        undefined,
        `${from} -> ${to} must be rejected`,
      );
      // Nothing changed — the guarded UPDATE never even ran.
      assertEquals(mock.complaints.get("c1")!.status, from);
    }
  }
  assertEquals(illegalChecked > 0, true);
});

Deno.test("transitionStatus: resolving without a resolution note is rejected (422), nothing written", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "assigned" });
  await assertRejects(
    () =>
      transitionStatus(client(mock), SCOPE, "c1", {
        to: "resolved",
        expectedFrom: "assigned",
        resolutionNote: "",
        actorId: STAFF,
      }),
    ResolutionNoteRequiredError,
  );
  await assertRejects(
    () =>
      transitionStatus(client(mock), SCOPE, "c1", {
        to: "resolved",
        expectedFrom: "assigned",
        actorId: STAFF,
        // resolutionNote omitted entirely
      }),
    ResolutionNoteRequiredError,
  );
  assertEquals(mock.complaints.get("c1")!.status, "assigned");
  assertEquals(mock.complaints.get("c1")!.resolved_at, null);
});

Deno.test("transitionStatus: a whitespace-only resolution note is also rejected", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "in_progress" });
  await assertRejects(
    () =>
      transitionStatus(client(mock), SCOPE, "c1", {
        to: "resolved",
        expectedFrom: "in_progress",
        resolutionNote: "   ",
        actorId: STAFF,
      }),
    ResolutionNoteRequiredError,
  );
});

Deno.test("transitionStatus: the concurrent double-transition LOSER writes nothing (guarded UPDATE, 0 rows -> throws)", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "assigned" });

  // Winner: assigned -> resolved commits first.
  const winner = await transitionStatus(client(mock), SCOPE, "c1", {
    to: "resolved",
    expectedFrom: "assigned",
    resolutionNote: "Fixed",
    actorId: STAFF,
  });
  assertEquals(winner.status, "resolved");
  assertEquals(winner.resolved_by, STAFF);

  // Loser: read the complaint BEFORE the winner committed (stale expectedFrom
  // = 'assigned'), races in AFTER — the guarded UPDATE affects 0 rows because
  // the real status is now 'resolved', not 'assigned'.
  await assertRejects(
    () =>
      transitionStatus(client(mock), SCOPE, "c1", {
        to: "resolved",
        expectedFrom: "assigned",
        resolutionNote: "Also fixed (racing)",
        actorId: ASSIGNEE,
      }),
    ComplaintConflictError,
  );

  // The row still reflects ONLY the winner — no double-apply, no
  // overwritten resolved_by/resolution_note from the loser.
  const current = mock.complaints.get("c1")!;
  assertEquals(current.resolved_by, STAFF);
  assertEquals(current.resolution_note, "Fixed");
});

Deno.test("transitionStatus: a lost race also throws for the generic (non-resolved/reopened) branch", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1", status: "open" });
  // Winner: open -> in_progress.
  await transitionStatus(client(mock), SCOPE, "c1", {
    to: "in_progress",
    expectedFrom: "open",
    actorId: STAFF,
  });
  // Loser races in with a stale expectedFrom of 'open'.
  await assertRejects(
    () =>
      transitionStatus(client(mock), SCOPE, "c1", {
        to: "closed",
        expectedFrom: "open",
        actorId: ASSIGNEE,
      }),
    ComplaintConflictError,
  );
  assertEquals(mock.complaints.get("c1")!.status, "in_progress");
});

// ── first response marker ────────────────────────────────────────────────

Deno.test("markFirstResponse: sets it on the first call, idempotent no-op (not a throw) after", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1" });
  const first = await markFirstResponse(client(mock), SCOPE, "c1");
  assertEquals(first, true);
  assertEquals(mock.complaints.get("c1")!.first_response_at != null, true);
  const stamped = mock.complaints.get("c1")!.first_response_at;

  const second = await markFirstResponse(client(mock), SCOPE, "c1");
  assertEquals(second, false); // lost the race harmlessly, does not throw
  assertEquals(mock.complaints.get("c1")!.first_response_at, stamped); // unchanged
});

// ── vendor attach ─────────────────────────────────────────────────────

Deno.test("findVendorInScope: returns null for a vendor id that does not exist", async () => {
  const mock = new ComplaintsMockDb();
  const found = await findVendorInScope(client(mock), SCOPE, "no-such-vendor");
  assertEquals(found, null);
});

Deno.test("findVendorInScope: returns null for a vendor that belongs to a DIFFERENT school (cross-tenant reject)", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedVendor("v1", OTHER_SCHOOL, "Acme Repairs");
  const found = await findVendorInScope(client(mock), SCOPE, "v1");
  assertEquals(found, null);
});

Deno.test("findVendorInScope: returns the vendor when it is in the same org+school", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedVendor("v1", SCHOOL, "Acme Repairs");
  const found = await findVendorInScope(client(mock), SCOPE, "v1");
  assertEquals(found?.display_name, "Acme Repairs");
});

Deno.test("attachVendor: sets vendor_id + repair_cost", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1" });
  const row = await attachVendor(client(mock), SCOPE, "c1", { vendorId: "v1", repairCost: 1500 });
  assertEquals(row.vendor_id, "v1");
  assertEquals(row.repair_cost, "1500");
});

Deno.test("attachVendor: a missing complaint 404s", async () => {
  const mock = new ComplaintsMockDb();
  await assertRejects(
    () => attachVendor(client(mock), SCOPE, "missing", { vendorId: "v1", repairCost: null }),
    ComplaintNotFoundError,
  );
});

// ── photo attach ─────────────────────────────────────────────────────

Deno.test("attachPhoto: records the storage path on the complaint", async () => {
  const mock = new ComplaintsMockDb();
  mock.seedComplaint({ id: "c1" });
  const row = await attachPhoto(client(mock), SCOPE, "c1", `${ORG}/${SCHOOL}/c1/abc_photo.jpg`);
  assertStringIncludes(row.photo_path!, "abc_photo.jpg");
});

Deno.test("attachPhoto: a missing complaint 404s", async () => {
  const mock = new ComplaintsMockDb();
  await assertRejects(
    () => attachPhoto(client(mock), SCOPE, "missing", "x.jpg"),
    ComplaintNotFoundError,
  );
});

// ── migration content ───────────────────────────────────────────────────

Deno.test("complaints migration: tables, append-only grant, RLS parent isolation, RBAC present", async () => {
  const migration = await Deno.readTextFile(
    new URL("../../../migrations/20260886000000_complaints.sql", import.meta.url),
  );

  assertStringIncludes(migration, "CREATE TABLE complaints");
  assertStringIncludes(migration, "CREATE TABLE complaint_events");
  assertStringIncludes(migration, "ALTER TABLE complaints FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "ALTER TABLE complaint_events FORCE ROW LEVEL SECURITY");

  // Append-only: complaint_events gets SELECT+INSERT only, never UPDATE/DELETE.
  assertStringIncludes(migration, "GRANT SELECT, INSERT ON complaint_events TO erp_tenant");
  assertEquals(migration.includes("UPDATE, DELETE ON complaint_events"), false);
  assertEquals(migration.includes("DELETE ON complaint_events"), false);

  // Parent isolation: raised_by = app_current_user_id(), never another parent's.
  assertStringIncludes(migration, "complaints_parent_select");
  assertStringIncludes(migration, "raised_by = app_current_user_id()");
  // No parent UPDATE policy at all.
  assertEquals(migration.includes("complaints_parent_update"), false);

  // No F2 approval type wired in.
  assertEquals(migration.toLowerCase().includes("approval_types"), false);

  // Required indexes.
  assertStringIncludes(migration, "idx_complaints_assignee");
  assertStringIncludes(migration, "idx_complaints_school_queue");
  assertStringIncludes(migration, "idx_complaints_sla_breach");
  assertStringIncludes(migration, "idx_complaint_events_complaint");

  // RBAC.
  assertStringIncludes(migration, "raiseComplaint");
  assertStringIncludes(migration, "manageComplaints");
  assertStringIncludes(migration, "viewComplaintsPrincipal");
});
