// COM-2 (class/section audience + saved segments) + COM-D1 (acknowledge /
// signed-receipt) + integrity fix (new thread must have a counterparty).
//
// DB-free unit coverage against a capturing fake TenantQueryClient (same in-file
// fake-db pattern as broadcast_batch_test.ts / broadcast_report_test.ts). The
// fake dispatches on SQL substrings so we can assert which resolver branch runs,
// the acknowledge update + 404, the new-thread counterparty guard, segment CRUD,
// and that the report now surfaces the acknowledged count + requiresAck.
//
// Real row-level RLS / real membership counts are covered by the live cert; this
// pins SQL-building + branch selection + response shape + validation.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  acknowledgeDelivery,
  createAudienceSegment,
  deleteAudienceSegment,
  getBroadcastDeliveryReport,
  listAudienceSegments,
  resolveBroadcastRecipients,
} from "./communication_repository.ts";
import {
  acknowledgeNotification,
  createAudienceSegmentEntry,
  deleteAudienceSegmentEntry,
  deliveryToNotificationApi,
  listAudienceSegmentEntries,
  NotificationNotFoundError,
  sendDirectMessage,
} from "./communication_service.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

function fakeDb(
  responders: { match: RegExp; rows: unknown[] }[] = [],
): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      for (const r of responders) {
        if (r.match.test(sql)) return Promise.resolve(r.rows);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

function schoolClaims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u-admin",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: ["sendBroadcast", "viewCommunications"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

// ── COM-2: class/section resolver branch selection ────────────────────────────

Deno.test("COM-2: resolveBroadcastRecipients class_parents joins enrollments→guardians", async () => {
  const { db, calls } = fakeDb([
    {
      match: /JOIN student_guardians/,
      rows: [{ guardian_user_id: "g-1" }, { guardian_user_id: "g-2" }],
    },
  ]);
  const ids = await resolveBroadcastRecipients(db, "org-1", "school-1", "class_parents", {
    className: "5",
    sectionName: "A",
  });
  assertEquals(ids, ["g-1", "g-2"]);
  const q = calls.find((c) => /JOIN student_guardians/.test(c.sql))!;
  assert(q.sql.includes("FROM sis_student_enrollments e"));
  assert(q.sql.includes("sg.guardian_user_id"));
  assert(q.sql.includes("e.is_current = true"));
  assert(q.sql.includes("sg.status = 'active'"));
  // args: school, className, sectionName, org
  assertEquals(q.args, ["school-1", "5", "A", "org-1"]);
});

Deno.test("COM-2: resolveBroadcastRecipients class_parents with no section passes NULL (whole class)", async () => {
  const { db, calls } = fakeDb([{ match: /JOIN student_guardians/, rows: [] }]);
  await resolveBroadcastRecipients(db, "org-1", "school-1", "class_parents", {
    className: "5",
    sectionName: null,
  });
  const q = calls.find((c) => /JOIN student_guardians/.test(c.sql))!;
  assertEquals(q.args, ["school-1", "5", null, "org-1"]);
});

Deno.test("COM-2: resolveBroadcastRecipients class_students selects enrollment student_id", async () => {
  const { db, calls } = fakeDb([
    { match: /SELECT DISTINCT e\.student_id/, rows: [{ user_id: "s-1" }] },
  ]);
  const ids = await resolveBroadcastRecipients(db, "org-1", "school-1", "class_students", {
    className: "6",
  });
  assertEquals(ids, ["s-1"]);
  const q = calls.find((c) => /SELECT DISTINCT e\.student_id/.test(c.sql))!;
  assert(q.sql.includes("FROM sis_student_enrollments e"));
  assert(!q.sql.includes("student_guardians"));
  assertEquals(q.args, ["school-1", "6", null]);
});

Deno.test("COM-2: class audience with empty className returns [] and issues NO query", async () => {
  const { db: db1, calls: c1 } = fakeDb();
  assertEquals(await resolveBroadcastRecipients(db1, "org-1", "school-1", "class_parents", { className: "" }), []);
  assertEquals(c1.length, 0);

  const { db: db2, calls: c2 } = fakeDb();
  assertEquals(await resolveBroadcastRecipients(db2, "org-1", "school-1", "class_students", { className: "   " }), []);
  assertEquals(c2.length, 0);
});

// ── COM-D1: acknowledge delivery (repo + service) ─────────────────────────────

Deno.test("COM-D1: acknowledgeDelivery sets acknowledged_at + is_read scoped to the recipient", async () => {
  const { db, calls } = fakeDb([
    {
      match: /UPDATE notification_deliveries/,
      rows: [{ id: "d-1", acknowledged_at: "2026-07-02T11:00:00.000Z" }],
    },
  ]);
  const row = await acknowledgeDelivery(db, "org-1", "u-parent", "d-1");
  assertEquals(row, { id: "d-1", acknowledged_at: "2026-07-02T11:00:00.000Z" });
  const q = calls[0];
  assert(q.sql.includes("acknowledged_at = timezone('utc', now())"));
  assert(q.sql.includes("is_read = true"));
  assert(q.sql.includes("recipient_user_id = $2"));
  assert(q.sql.includes("organization_id = $3"));
  assertEquals(q.args, ["d-1", "u-parent", "org-1"]);
});

Deno.test("COM-D1: acknowledgeDelivery returns null when no owned row matches", async () => {
  const { db } = fakeDb([{ match: /UPDATE notification_deliveries/, rows: [] }]);
  assertEquals(await acknowledgeDelivery(db, "org-1", "u-parent", "missing"), null);
});

Deno.test("COM-D1: acknowledgeNotification returns receipt + writes the signed-receipt audit", async () => {
  const { db, calls } = fakeDb([
    {
      match: /UPDATE notification_deliveries/,
      rows: [{ id: "d-1", acknowledged_at: "2026-07-02T11:00:00.000Z" }],
    },
  ]);
  const result = await acknowledgeNotification(
    db,
    schoolClaims({ scope: "parent", role: "parent" }),
    "d-1",
  );
  assertEquals(result, { deliveryId: "d-1", acknowledgedAt: "2026-07-02T11:00:00.000Z" });
  // The signed receipt is the mutation-audit event (actor+target+timestamp).
  assert(calls.some((c) => c.sql.includes("INSERT INTO audit_events")));
});

Deno.test("COM-D1: acknowledgeNotification throws NotFound (→404) when the delivery is not the caller's", async () => {
  const { db } = fakeDb([{ match: /UPDATE notification_deliveries/, rows: [] }]);
  await assertRejects(
    () => acknowledgeNotification(db, schoolClaims({ scope: "parent" }), "missing"),
    NotificationNotFoundError,
  );
});

// ── COM-D1: report now includes acknowledged + requiresAck ────────────────────

Deno.test("COM-D1: getBroadcastDeliveryReport surfaces requires_ack + acknowledged count", async () => {
  const { db, calls } = fakeDb([
    {
      match: /FROM comm_broadcasts/,
      rows: [{
        id: "bcast-1",
        title: "Fee policy",
        audience: "class_parents",
        status: "sent",
        requires_ack: true,
        sent_at: "2026-07-02T10:00:00.000Z",
        scheduled_at: null,
      }],
    },
    {
      match: /count\(\*\) FILTER/,
      rows: [{ total: "3", sent: "3", failed: "0", pending: "0", read: "2", unread: "1", acknowledged: "2" }],
    },
    { match: /LEFT JOIN users/, rows: [] },
  ]);
  const report = await getBroadcastDeliveryReport(db, "org-1", "school-1", "bcast-1");
  assertEquals(report.broadcast.requires_ack, true);
  assertEquals(report.counts.acknowledged, 2);
  // The count query filters on acknowledged_at IS NOT NULL off the ledger.
  const countSql = calls.find((c) => /count\(\*\) FILTER/.test(c.sql))!;
  assert(countSql.sql.includes("acknowledged_at IS NOT NULL"));
  assert(countSql.sql.includes("FROM notification_deliveries"));
});

// ── COM-2: saved segments CRUD ────────────────────────────────────────────────

Deno.test("COM-2: createAudienceSegmentEntry persists + validates the class-audience class", async () => {
  const { db, calls } = fakeDb([
    {
      match: /INSERT INTO comm_audience_segments/,
      rows: [{
        id: "seg-1",
        organization_id: "org-1",
        school_id: "school-1",
        name: "Grade 5-A parents",
        audience_type: "class_parents",
        class_name: "5",
        section_name: "A",
        created_by: "u-admin",
        created_at: "2026-07-02T09:00:00.000Z",
      }],
    },
  ]);
  const seg = await createAudienceSegmentEntry(db, schoolClaims(), {
    name: "Grade 5-A parents",
    audienceType: "class_parents",
    className: "5",
    sectionName: "A",
  });
  assertEquals(seg, {
    id: "seg-1",
    name: "Grade 5-A parents",
    audienceType: "class_parents",
    className: "5",
    sectionName: "A",
    createdAt: "2026-07-02T09:00:00.000Z",
  });
  const insert = calls.find((c) => c.sql.includes("INSERT INTO comm_audience_segments"))!;
  assertEquals(insert.args, ["org-1", "school-1", "Grade 5-A parents", "class_parents", "5", "A", "u-admin"]);
});

Deno.test("COM-2: createAudienceSegmentEntry rejects a class segment with no class (422)", async () => {
  const { db, calls } = fakeDb();
  await assertRejects(
    () =>
      createAudienceSegmentEntry(db, schoolClaims(), {
        name: "bad",
        audienceType: "class_students",
        className: "",
      }),
    Error,
    "class_name is required",
  );
  // No INSERT attempted when validation fails.
  assert(!calls.some((c) => c.sql.includes("INSERT INTO comm_audience_segments")));
});

Deno.test("COM-2: createAudienceSegmentEntry rejects an empty name (422)", async () => {
  const { db } = fakeDb();
  await assertRejects(
    () => createAudienceSegmentEntry(db, schoolClaims(), { name: "   ", audienceType: "all_parents" }),
    Error,
    "Segment name is required",
  );
});

Deno.test("COM-2: listAudienceSegmentEntries maps rows to the API shape", async () => {
  const { db } = fakeDb([
    {
      match: /FROM comm_audience_segments/,
      rows: [{
        id: "seg-1",
        organization_id: "org-1",
        school_id: "school-1",
        name: "All parents",
        audience_type: "all_parents",
        class_name: null,
        section_name: null,
        created_by: "u-admin",
        created_at: "2026-07-02T09:00:00.000Z",
      }],
    },
  ]);
  const items = await listAudienceSegmentEntries(db, schoolClaims());
  assertEquals(items, [{
    id: "seg-1",
    name: "All parents",
    audienceType: "all_parents",
    className: null,
    sectionName: null,
    createdAt: "2026-07-02T09:00:00.000Z",
  }]);
});

Deno.test("COM-2: deleteAudienceSegment returns the id, or null when nothing matched", async () => {
  const { db: hit } = fakeDb([{ match: /DELETE FROM comm_audience_segments/, rows: [{ id: "seg-1" }] }]);
  assertEquals(await deleteAudienceSegment(hit, "org-1", "school-1", "seg-1"), "seg-1");

  const { db: miss } = fakeDb([{ match: /DELETE FROM comm_audience_segments/, rows: [] }]);
  assertEquals(await deleteAudienceSegment(miss, "org-1", "school-1", "gone"), null);
});

Deno.test("COM-2: deleteAudienceSegmentEntry maps a miss to NotFound (→404)", async () => {
  const { db } = fakeDb([{ match: /DELETE FROM comm_audience_segments/, rows: [] }]);
  await assertRejects(
    () => deleteAudienceSegmentEntry(db, schoolClaims(), "gone"),
    NotificationNotFoundError,
  );
});

Deno.test("COM-2: createAudienceSegment repo issues the INSERT with created_by", async () => {
  const { db, calls } = fakeDb([{ match: /INSERT INTO comm_audience_segments/, rows: [{ id: "seg-1" }] }]);
  await createAudienceSegment(db, {
    organizationId: "org-1",
    schoolId: "school-1",
    name: "n",
    audienceType: "all_teachers",
    className: null,
    sectionName: null,
    createdBy: "u-admin",
  });
  assert(calls[0].sql.includes("INSERT INTO comm_audience_segments"));
  assertEquals(calls[0].args, ["org-1", "school-1", "n", "all_teachers", null, null, "u-admin"]);
});

Deno.test("COM-2: listAudienceSegments repo scopes to org+school", async () => {
  const { db, calls } = fakeDb([{ match: /FROM comm_audience_segments/, rows: [] }]);
  await listAudienceSegments(db, "org-1", "school-1");
  assertEquals(calls[0].args, ["org-1", "school-1"]);
  assert(calls[0].sql.includes("organization_id = $1"));
  assert(calls[0].sql.includes("school_id = $2"));
});

// ── Integrity fix: a NEW thread must name its counterparty ─────────────────────

Deno.test("integrity: parent starting a NEW thread without a teacher counterparty → 422", async () => {
  const { db, calls } = fakeDb();
  await assertRejects(
    () =>
      sendDirectMessage(db, schoolClaims({ scope: "parent", role: "parent" }), {
        body: "Hello",
        senderRole: "parent",
        // no counterpartyUserId
      }),
    Error,
    "A recipient teacher is required",
  );
  // Guard fires before any thread is created.
  assert(!calls.some((c) => c.sql.includes("INSERT INTO comm_threads")));
});

Deno.test("integrity: teacher starting a NEW thread without a parent counterparty → 422", async () => {
  const { db } = fakeDb();
  await assertRejects(
    () =>
      sendDirectMessage(db, schoolClaims(), {
        body: "Hello",
        senderRole: "teacher",
      }),
    Error,
    "A recipient parent is required",
  );
});

Deno.test("integrity: a REPLY (with threadId) is unaffected by the counterparty guard", async () => {
  const { db, calls } = fakeDb([
    {
      match: /SELECT \* FROM comm_threads WHERE organization_id/,
      rows: [{
        id: "t-1",
        organization_id: "org-1",
        school_id: "school-1",
        thread_type: "direct",
        subject: "Re",
        parent_user_id: "p-1",
        teacher_user_id: "u-admin",
        student_id: null,
        last_message_preview: "",
        unread_parent_count: 0,
        unread_teacher_count: 0,
        created_at: "2026-07-02T09:00:00.000Z",
        updated_at: "2026-07-02T09:00:00.000Z",
      }],
    },
    { match: /INSERT INTO comm_messages/, rows: [{ id: "m-1" }] },
    { match: /SELECT \* FROM comm_messages WHERE thread_id/, rows: [] },
  ]);
  // Teacher replying on an existing thread WITHOUT a counterparty must succeed.
  const res = await sendDirectMessage(db, schoolClaims(), {
    threadId: "t-1",
    body: "Reply",
    senderRole: "teacher",
  });
  assertEquals((res as { id: string }).id, "t-1");
  // No new thread was created (reply path).
  assert(!calls.some((c) => c.sql.includes("INSERT INTO comm_threads")));
});

Deno.test("COM-D1: notification projection surfaces requiresAck + acknowledgedAt", () => {
  const base = {
    id: "d-1",
    rendered_subject: "Fee policy",
    rendered_body: "Please acknowledge.",
    category: "announcement",
    is_read: false,
    child_context: null,
    created_at: "2026-07-02T00:00:00Z",
  };
  // Ack-required, not yet acknowledged.
  const pending = deliveryToNotificationApi({ ...base, requires_ack: true, acknowledged_at: null });
  assertEquals(pending.requiresAck, true);
  assertEquals(pending.acknowledgedAt, null);
  // Acknowledged.
  const done = deliveryToNotificationApi({
    ...base,
    requires_ack: true,
    acknowledged_at: "2026-07-02T01:00:00Z",
  });
  assertEquals(done.acknowledgedAt, "2026-07-02T01:00:00Z");
  // Legacy row without the columns defaults to false/null (back-compat).
  const legacy = deliveryToNotificationApi(base);
  assertEquals(legacy.requiresAck, false);
  assertEquals(legacy.acknowledgedAt, null);
});
