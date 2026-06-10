import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { overlayTimetableSnapshotFromSlots } from "./pilot_operations_repository.ts";

type SlotRow = {
  day_of_week: number;
  period_number: number;
  subject_label: string;
  room_label: string | null;
  class_label: string;
  substitute_teacher_user_id: string | null;
  teacher_name: string | null;
};

function mockDb(rows: SlotRow[]): TenantQueryClient {
  return {
    queryObject: async <T>() => rows as T[],
  } as unknown as TenantQueryClient;
}

Deno.test("overlayTimetableSnapshotFromSlots returns snapshot when no slots", async () => {
  const snapshot = { childClass: "8-A", days: [], weekRangeLabel: "legacy" };
  const result = await overlayTimetableSnapshotFromSlots(
    mockDb([]),
    "org",
    "school",
    snapshot,
    { view: "parent", classLabel: "8-A" },
  );
  assertEquals(result, snapshot);
});

Deno.test("overlayTimetableSnapshotFromSlots builds parent days from operational rows", async () => {
  const snapshot = {
    childName: "Ravi",
    childClass: "8-A",
    days: [],
    weekRangeLabel: "legacy",
    unreadNotifications: 0,
  };
  const result = await overlayTimetableSnapshotFromSlots(
    mockDb([{
      day_of_week: 1,
      period_number: 1,
      subject_label: "Mathematics",
      room_label: "Room 201",
      class_label: "8-A",
      substitute_teacher_user_id: null,
      teacher_name: "Staging School Admin",
    }]),
    "org",
    "school",
    snapshot,
    { view: "parent", classLabel: "8-A" },
  );

  assert(Array.isArray(result.days));
  assertEquals((result.days as unknown[]).length, 1);
  const day = (result.days as Record<string, unknown>[])[0]!;
  assertEquals(day.id, "mon");
  const periods = day.periods as Record<string, unknown>[];
  assertEquals(periods[0]?.subject, "Mathematics");
  assertEquals(periods[0]?.teacherName, "Staging School Admin");
  assertEquals(result.totalPeriodsThisWeek, 1);
});

Deno.test("overlayTimetableSnapshotFromSlots builds teacher class periods", async () => {
  const snapshot = { teacherName: "Priya", days: [], weekRangeLabel: "legacy" };
  const result = await overlayTimetableSnapshotFromSlots(
    mockDb([{
      day_of_week: 2,
      period_number: 3,
      subject_label: "Science",
      room_label: "Lab 1",
      class_label: "8-A",
      substitute_teacher_user_id: null,
      teacher_name: "Staging School Admin",
    }]),
    "org",
    "school",
    snapshot,
    { view: "teacher", teacherUserId: "teacher-1" },
  );

  const day = (result.days as Record<string, unknown>[])[0]!;
  assertEquals(day.id, "tue");
  const periods = day.periods as Record<string, unknown>[];
  assertEquals(periods[0]?.classLabel, "8-A");
});
