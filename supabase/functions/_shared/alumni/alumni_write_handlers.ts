import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { formatRupees, parseRupees } from "./alumni_read_repository.ts";

const writeStore = createEntityWriteStore("alumni_entities", "Alumni");
const { runWrite } = createModuleWriteHandlers("manageAlumni");

/**
 * Apply a new donation's contribution to a campaign payload: bump its raised
 * amount by the donated rupees and increment the donor count. The current
 * `raisedAmount`/`donorCount` are seeded constants with no increment path; this
 * is the only writer that advances them. Returns a fresh payload (no mutation).
 */
export function applyDonationToCampaign(
  campaign: Record<string, unknown>,
  donationAmount: string,
): Record<string, unknown> {
  const currentRaised = parseRupees(campaign.raisedAmount);
  const nextRaised = currentRaised + parseRupees(donationAmount);
  const currentDonors = typeof campaign.donorCount === "number" ? campaign.donorCount : 0;
  return {
    ...campaign,
    raisedAmount: formatRupees(nextRaised),
    donorCount: currentDonors + 1,
  };
}

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

/**
 * POST /alumni/donations — record a donation against the alumni ledger.
 *
 * Inserts a `donation` entity in the shape the donations ledger + dashboard
 * read (alumniName/alumniId/amount/date/campaign/status/financeReceiptId/
 * paymentMode). When the donation references a campaign by id, that campaign
 * entity is found and replaced with its `raisedAmount` advanced and
 * `donorCount` incremented — the only path that grows these seeded constants.
 */
export async function handleRecordDonation(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const amount = requireStr(body, "amount");
    const campaignId = str(body, "campaignId", "campaign_id") ?? "";

    let campaignName = str(body, "campaign") ?? "";
    if (campaignId !== "") {
      const campaign = await writeStore.find(
        db,
        organizationId,
        schoolId,
        "campaign",
        campaignId,
      );
      if (campaign !== null) {
        if (campaignName === "") campaignName = str(campaign, "name") ?? "";
        const updatedCampaign = applyDonationToCampaign(campaign, amount);
        await writeStore.replace(
          db,
          organizationId,
          schoolId,
          "campaign",
          campaignId,
          updatedCampaign,
        );
        // Campaign totals (raisedAmount/donorCount) are money-adjacent state — audit
        // the change at the campaign level too, not only the donation (gap sweep).
        await emitMutationAudit(
          db,
          claims,
          moduleEntityAudit("alumni.campaign.donation_applied", "alumni_campaign", campaignId, {
            donationId: id,
            amount,
            raisedAmount: updatedCampaign.raisedAmount,
            donorCount: updatedCampaign.donorCount,
          }),
          request,
        );
      }
    }

    const payload = {
      id,
      alumniName: requireStr(body, "alumniName", "alumni_name"),
      alumniId: str(body, "alumniId", "alumni_id") ?? "",
      amount,
      date: str(body, "date") ?? "",
      campaignId,
      campaign: campaignName || "—",
      status: str(body, "status") ?? "received",
      financeReceiptId: str(body, "financeReceiptId", "finance_receipt_id") ?? "—",
      financeAccountCode: str(body, "financeAccountCode", "finance_account_code") ?? "",
      paymentMode: str(body, "paymentMode", "payment_mode") ?? "",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "donation", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("alumni.donation.recorded", "alumni_donation", id, {
        alumniId: payload.alumniId,
        amount: payload.amount,
        campaignId,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}
