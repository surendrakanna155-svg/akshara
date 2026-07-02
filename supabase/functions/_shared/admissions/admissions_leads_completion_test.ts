import {
  assertEquals,
  assertObjectMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  bulkAssignLeads,
  bulkChangeLeadStage,
  completeFollowUp,
  findLeadsByPhone,
  isValidLostReason,
  LEAD_LOST_REASONS,
  markLeadLost,
  rescheduleFollowUp,
} from "./admissions_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class MockLeadsDb {
  leads: Row[];
  followUps: Row[];

  constructor() {
    this.leads = [
      {
        id: "lead-1",
        organization_id: ORG,
        school_id: SCHOOL,
        student_name: "Asha",
        parent_name: "Ravi",
        phone: "9000000001",
        stage: "new_enquiry",
        counselor: "",
        lost_reason: null,
        next_follow_up_label: "Not scheduled",
      },
      {
        id: "lead-2",
        organization_id: ORG,
        school_id: SCHOOL,
        student_name: "Bina",
        parent_name: "Sita",
        phone: "9000000001",
        stage: "contacted",
        counselor: "",
        lost_reason: null,
        next_follow_up_label: "Not scheduled",
      },
    ];
    this.followUps = [
      {
        id: "fu-1",
        organization_id: ORG,
        school_id: SCHOOL,
        lead_id: "lead-1",
        task: "Call parent",
        scheduled_label: "Tomorrow",
        completed_label: "",
        counselor: "Meera",
        status: "pending",
        outcome: "Scheduled",
        updated_at: "2026-07-01T00:00:00.000Z",
      },
    ];
  }

  private findLead(id: unknown): Row | undefined {
    return this.leads.find((l) =>
      l.id === id && l.organization_id === ORG && l.school_id === SCHOOL
    );
  }

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("UPDATE admissions_leads SET") && sql.includes("counselor = $4")) {
      const lead = this.findLead(args[0]);
      if (!lead) return Promise.resolve([] as T[]);
      lead.counselor = args[3];
      return Promise.resolve([lead] as T[]);
    }
    if (
      sql.includes("UPDATE admissions_leads SET") &&
      sql.includes("stage = $4") &&
      !sql.includes("lost_reason")
    ) {
      const lead = this.findLead(args[0]);
      if (!lead) return Promise.resolve([] as T[]);
      lead.stage = args[3];
      return Promise.resolve([lead] as T[]);
    }
    if (
      sql.includes("UPDATE admissions_leads SET") &&
      sql.includes("stage = 'lost'") &&
      sql.includes("lost_reason = $4")
    ) {
      const lead = this.findLead(args[0]);
      if (!lead) return Promise.resolve([] as T[]);
      lead.stage = "lost";
      lead.lost_reason = args[3];
      return Promise.resolve([lead] as T[]);
    }
    if (
      sql.includes("UPDATE admissions_leads SET") &&
      sql.includes("next_follow_up_label = $4")
    ) {
      const lead = this.findLead(args[0]);
      if (lead) lead.next_follow_up_label = args[3];
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("FROM admissions_leads") && sql.includes("phone = $3")) {
      const rows = this.leads.filter((l) =>
        l.organization_id === args[0] && l.school_id === args[1] &&
        l.phone === args[2]
      );
      return Promise.resolve(
        rows.map((l) => ({
          id: l.id,
          student_name: l.student_name,
          parent_name: l.parent_name,
          stage: l.stage,
        })) as T[],
      );
    }
    if (
      sql.includes("UPDATE admissions_lead_follow_ups SET") &&
      sql.includes("status = 'completed'")
    ) {
      const fu = this.followUps.find((f) => f.id === args[0]);
      if (!fu) return Promise.resolve([] as T[]);
      fu.status = "completed";
      fu.completed_label = args[3];
      const outcome = String(args[4] ?? "");
      if (outcome) fu.outcome = outcome;
      return Promise.resolve([fu] as T[]);
    }
    if (
      sql.includes("UPDATE admissions_lead_follow_ups SET") &&
      sql.includes("scheduled_label = $4")
    ) {
      const fu = this.followUps.find((f) => f.id === args[0]);
      if (!fu) return Promise.resolve([] as T[]);
      fu.scheduled_label = args[3];
      fu.status = "pending";
      return Promise.resolve([fu] as T[]);
    }
    throw new Error(`Unhandled SQL in MockLeadsDb: ${sql.slice(0, 80)}`);
  }
}

Deno.test("bulkAssignLeads assigns matched leads and skips unknown ones", async () => {
  const db = new MockLeadsDb();
  const { outcome, rows } = await bulkAssignLeads(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    ["lead-1", "lead-2", "missing"],
    "Meera",
  );
  assertEquals(outcome.updated, ["lead-1", "lead-2"]);
  assertEquals(outcome.skipped, [{ leadId: "missing", reason: "not_found" }]);
  assertEquals(rows.length, 2);
  assertEquals(db.leads[0].counselor, "Meera");
  assertEquals(db.leads[1].counselor, "Meera");
});

Deno.test("bulkChangeLeadStage moves matched leads and reports skips", async () => {
  const db = new MockLeadsDb();
  const { outcome } = await bulkChangeLeadStage(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    ["lead-1", "nope"],
    "school_visit",
  );
  assertEquals(outcome.updated, ["lead-1"]);
  assertEquals(outcome.skipped, [{ leadId: "nope", reason: "not_found" }]);
  assertEquals(db.leads[0].stage, "school_visit");
});

Deno.test("markLeadLost sets stage=lost + reason; picklist is enforced", async () => {
  const db = new MockLeadsDb();
  const lead = await markLeadLost(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "lead-1",
    "competitor",
  );
  assertObjectMatch(lead as unknown as Row, { stage: "lost", lost_reason: "competitor" });

  // Picklist guard.
  assertEquals(LEAD_LOST_REASONS.length, 4);
  assertEquals(isValidLostReason("fees_high"), true);
  assertEquals(isValidLostReason("competitor"), true);
  assertEquals(isValidLostReason("distance"), true);
  assertEquals(isValidLostReason("other"), true);
  assertEquals(isValidLostReason("random"), false);
});

Deno.test("findLeadsByPhone returns warn-only duplicate matches", async () => {
  const db = new MockLeadsDb();
  const matches = await findLeadsByPhone(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "9000000001",
  );
  assertEquals(matches.length, 2);
  assertEquals(matches[0].leadId, "lead-1");
  assertEquals(matches[1].leadId, "lead-2");
});

Deno.test("completeFollowUp marks it completed with an outcome", async () => {
  const db = new MockLeadsDb();
  const fu = await completeFollowUp(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "fu-1",
    "Parent confirmed visit",
  );
  assertObjectMatch(fu as unknown as Row, {
    status: "completed",
    outcome: "Parent confirmed visit",
  });
  assertEquals(String(db.followUps[0].completed_label).length > 0, true);
});

Deno.test("rescheduleFollowUp updates due label + syncs lead scalar", async () => {
  const db = new MockLeadsDb();
  const fu = await rescheduleFollowUp(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL,
    "fu-1",
    "Next Monday",
  );
  assertObjectMatch(fu as unknown as Row, { scheduled_label: "Next Monday", status: "pending" });
  // Lead's scalar next-follow-up label kept in sync.
  assertEquals(db.leads[0].next_follow_up_label, "Next Monday");
});

Deno.test("completeFollowUp / rescheduleFollowUp return null for unknown id", async () => {
  const db = new MockLeadsDb();
  assertEquals(
    await completeFollowUp(db as unknown as TenantQueryClient, ORG, SCHOOL, "x", ""),
    null,
  );
  assertEquals(
    await rescheduleFollowUp(db as unknown as TenantQueryClient, ORG, SCHOOL, "x", "L"),
    null,
  );
});
