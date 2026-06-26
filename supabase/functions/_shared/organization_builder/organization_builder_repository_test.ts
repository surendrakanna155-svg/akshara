import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildPreview,
  type InterviewDraftView,
  type OrgBuilderPack,
  provision,
  rolesForPack,
  widgetsForPack,
  workflowsForPack,
} from "./organization_builder_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { baselineRecommendation } from "./organization_builder_ai.ts";

const SCHOOL_PACK: OrgBuilderPack = {
  id: "pack_school",
  type: "school",
  name: "Education",
  description: "",
  primaryEntities: ["Students", "Classes"],
  moduleSeeds: ["SIS", "Finance", "Education Suite"],
  dashboardFocus: "",
  brandLabel: null,
};

const SALON_PACK: OrgBuilderPack = {
  ...SCHOOL_PACK,
  id: "pack_salon",
  type: "salon",
  name: "Salon",
  moduleSeeds: ["Appointments", "Loyalty"],
  brandLabel: "Velora",
};

function draft(packId: string): InterviewDraftView {
  return {
    id: "draft_1",
    packId,
    organizationName: "Acme",
    currentStep: 6,
    answers: {},
    recommendations: [],
    status: "ready_for_preview",
    createdAt: "2026-06-25T00:00:00.000Z",
    updatedAt: "2026-06-25T00:00:00.000Z",
  };
}

Deno.test("buildPreview includes seed modules plus universal-employee/auth/analytics", () => {
  const preview = buildPreview(draft("pack_school"), SCHOOL_PACK, "2026-06-25T10:00:00.000Z");
  const ids = preview.modules.map((m) => m.id);
  assertEquals(preview.draftId, "draft_1");
  assertEquals(preview.organizationName, "Acme");
  assertEquals(preview.packId, "pack_school");
  // seeds normalized to snake_case + the three appended modules
  assertEquals(ids.includes("sis"), true);
  assertEquals(ids.includes("education_suite"), true);
  assertEquals(ids.includes("universal_employee"), true);
  assertEquals(ids.includes("auth"), true);
  assertEquals(ids.includes("analytics"), true);
  // seed modules flagged new; auth/analytics are not
  assertEquals(preview.modules.find((m) => m.id === "sis")?.isNew, true);
  assertEquals(preview.modules.find((m) => m.id === "auth")?.isNew, false);
  assertEquals(preview.generatedAt, "2026-06-25T10:00:00.000Z");
});

Deno.test("preview roles/widgets/workflows vary by vertical", () => {
  assertEquals(rolesForPack("school")[0].name, "Principal");
  assertEquals(rolesForPack("salon")[0].name, "Salon Manager");
  assertEquals(rolesForPack("hospital")[0].name, "Hospital Admin");
  assertEquals(rolesForPack("restaurant")[0].name, "Restaurant Manager");
  // unknown vertical falls back to school
  assertEquals(rolesForPack("unknown")[0].name, "Principal");

  assertEquals(widgetsForPack("salon")[0].widgetName, "Chair utilization");
  assertEquals(workflowsForPack("hospital")[1].name, "Insurance claim");

  const salonPreview = buildPreview(draft("pack_salon"), SALON_PACK, "2026-06-25T10:00:00.000Z");
  assertEquals(salonPreview.roles[0].name, "Salon Manager");
});

// ─── provision(): real-tenant creation + failure path ───────────────────────

const ORG = "a1000000-0000-4000-8000-000000000001";
const NEW_ORG = "b1000000-0000-4000-8000-000000000099";
const NEW_SCHOOL = "b2000000-0000-4000-8000-000000000099";

interface MockOpts {
  /** Row returned by org_builder_provision_tenant. */
  provisionRow: Record<string, unknown>;
}

/** Mock db that dispatches by SQL fragment, capturing the writes provision() makes. */
class MockProvisionDb {
  jobInsertArgs: unknown[] | null = null;
  draftUpdateCalled = false;

  constructor(private readonly opts: MockOpts) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const has = (...frags: string[]) => frags.every((f) => sql.includes(f));

    // getOrCreateDraft → getDraftRow (existing draft).
    if (has("FROM org_builder_interview_drafts", "WHERE id = $1 AND organization_id = $2")) {
      return [{
        id: "draft_1",
        pack_id: "pack_school",
        organization_name: "Acme Trust",
        current_step: 7,
        answers: {},
        recommendations: [],
        status: "ready_for_preview",
        created_at: "2026-06-26T00:00:00.000Z",
        updated_at: "2026-06-26T00:00:00.000Z",
      }] as T[];
    }
    // getPack.
    if (has("FROM org_builder_packs WHERE id = $1")) {
      return [{
        id: "pack_school",
        type: "school",
        name: "Education",
        description: "",
        primary_entities: ["Students"],
        module_seeds: ["SIS", "Finance"],
        dashboard_focus: "",
        brand_label: null,
      }] as T[];
    }
    // currentActorId.
    if (has("current_setting('app.user_id'")) {
      return [{ user_id: "a3000000-0000-4000-8000-000000000001" }] as T[];
    }
    // The privileged SECURITY DEFINER provisioning call.
    if (has("FROM org_builder_provision_tenant(")) {
      return [this.opts.provisionRow] as T[];
    }
    // Job INSERT — capture status (arg index 3) + steps json (arg index 4).
    if (has("INSERT INTO org_builder_provisioning_jobs")) {
      this.jobInsertArgs = args;
      const status = String(args[3]);
      return [{
        id: "job_1",
        draft_id: "draft_1",
        organization_name: "Acme Trust",
        status,
        steps: JSON.parse(String(args[4])),
        started_at: "2026-06-26T00:00:00.000Z",
        completed_at: status === "completed" || status === "failed"
          ? "2026-06-26T00:00:00.000Z"
          : null,
      }] as T[];
    }
    // Draft flip to provisioned.
    if (has("UPDATE org_builder_interview_drafts", "SET status = 'provisioned'")) {
      this.draftUpdateCalled = true;
      return [] as T[];
    }
    throw new Error(`Unexpected SQL in MockProvisionDb: ${sql}`);
  }
}

Deno.test("provision() records a completed job + flips draft when the SECURITY DEFINER call succeeds", async () => {
  const db = new MockProvisionDb({
    provisionRow: {
      new_org_id: NEW_ORG,
      new_school_id: NEW_SCHOOL,
      roles_seeded: 3,
      permissions_granted: 8,
      seeds_loaded: 0,
      reused: false,
      failed_step: null,
      error_message: null,
    },
  });

  const result = await provision(
    db as unknown as TenantQueryClient,
    ORG,
    "draft_1",
    "2026-06-26T00:00:00.000Z",
  );

  assertEquals(result.job.status, "completed");
  assertEquals(result.job.steps.length, 6);
  // Every step really ran.
  assertEquals(result.job.steps.every((s) => s.status === "completed"), true);
  // Real counts surfaced into labels.
  assertEquals(result.job.steps[2].label, "Seed roles (3)");
  assertEquals(result.job.steps[3].label, "Assign permissions (8)");
  // Job persisted with status 'completed' (arg index 3).
  assertEquals(String(db.jobInsertArgs?.[3]), "completed");
  // Draft flipped to provisioned only on success.
  assertEquals(db.draftUpdateCalled, true);
});

Deno.test("provision() records a FAILED job, no draft flip, when a step fails", async () => {
  const db = new MockProvisionDb({
    provisionRow: {
      new_org_id: null,
      new_school_id: null,
      roles_seeded: 0,
      permissions_granted: 0,
      seeds_loaded: 0,
      reused: false,
      failed_step: "step_branch",
      error_message: "duplicate key value violates unique constraint",
    },
  });

  const result = await provision(
    db as unknown as TenantQueryClient,
    ORG,
    "draft_1",
    "2026-06-26T00:00:00.000Z",
  );

  assertEquals(result.job.status, "failed");
  // step_org ran-then-rolled-back → skipped; step_branch → failed; rest → pending.
  assertEquals(result.job.steps[0].status, "skipped");
  assertEquals(result.job.steps[1].status, "failed");
  assertEquals(result.job.steps[1].error, "duplicate key value violates unique constraint");
  assertEquals(result.job.steps[2].status, "pending");
  assertEquals(result.job.steps[5].status, "pending");
  // Job persisted with status 'failed'.
  assertEquals(String(db.jobInsertArgs?.[3]), "failed");
  // Draft NOT flipped to provisioned.
  assertEquals(db.draftUpdateCalled, false);
});

Deno.test("baselineRecommendation is deterministic, valid, and stable per step", () => {
  const a = baselineRecommendation("pack_salon", "salon", 2);
  const b = baselineRecommendation("pack_salon", "salon", 2);
  assertEquals(a.id, b.id);
  assertEquals(a.id, "rec_pack_salon_2");
  assertEquals(a.title.length > 0, true);
  assertEquals(a.detail.length > 0, true);
  assertEquals(a.confidence, 0.8);
  // unknown vertical → school baseline
  assertEquals(baselineRecommendation("pack_x", "unknown", 0).title, "Fee reminder workflow");
});
