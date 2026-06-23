import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

const writeStore = createEntityWriteStore("alumni_entities", "Alumni");
const { runWrite } = createModuleWriteHandlers("manageAlumni");

/** POST /alumni/registry — add a graduate to the alumni registry. */
export async function handleAddAlumni(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = {
      id,
      name: requireStr(body, "name"),
      batchYear: requireStr(body, "batchYear", "batch_year"),
      program: str(body, "program") ?? "",
      currentRole: str(body, "currentRole", "current_role") ?? "",
      city: str(body, "city") ?? "",
      email: str(body, "email") ?? "",
      phone: str(body, "phone") ?? "",
      engagementStatus: str(body, "engagementStatus", "engagement_status") ?? "active",
      sisStudentId: str(body, "sisStudentId", "sis_student_id") ?? "",
      totalDonated: str(body, "totalDonated", "total_donated") ?? "₹0",
      lastEventAttended: str(body, "lastEventAttended", "last_event_attended") ?? "—",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "alumni", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("alumni.registry.added", "alumni_record", id, { name: payload.name }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /alumni/events — create an alumni event. */
export async function handleCreateEvent(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = {
      id,
      title: requireStr(body, "title"),
      date: requireStr(body, "date"),
      venue: str(body, "venue") ?? "",
      registrations: 0,
      capacity: intOr(body, 0, "capacity"),
      status: str(body, "status") ?? "upcoming",
      organizer: str(body, "organizer") ?? "",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "event", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("alumni.event.created", "alumni_event", id, { title: payload.title }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /alumni/campaigns — launch a fundraising campaign. */
export async function handleCreateCampaign(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = {
      id,
      name: requireStr(body, "name"),
      goalAmount: requireStr(body, "goalAmount", "goal_amount"),
      raisedAmount: str(body, "raisedAmount", "raised_amount") ?? "₹0",
      donorCount: 0,
      deadline: str(body, "deadline") ?? "",
      status: str(body, "status") ?? "active",
      financeAccountCode: str(body, "financeAccountCode", "finance_account_code") ?? "",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "campaign", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("alumni.campaign.created", "alumni_campaign", id, { name: payload.name }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /alumni/mentorship — pair a mentor alumnus with a mentee. */
export async function handleAddMentorshipPair(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = {
      id,
      mentorName: requireStr(body, "mentorName", "mentor_name"),
      mentorAlumniId: requireStr(body, "mentorAlumniId", "mentor_alumni_id"),
      menteeName: requireStr(body, "menteeName", "mentee_name"),
      menteeBatch: str(body, "menteeBatch", "mentee_batch") ?? "",
      focusArea: str(body, "focusArea", "focus_area") ?? "",
      status: str(body, "status") ?? "active",
      sessionsCompleted: 0,
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "mentorship", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("alumni.mentorship.added", "alumni_mentorship", id, {
        mentorAlumniId: payload.mentorAlumniId,
        menteeName: payload.menteeName,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}
