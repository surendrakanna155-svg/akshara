import type { AppConfig } from "../config.ts";
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import { alumniDetailToApi, alumniStore } from "./alumni_read_repository.ts";

const { handleSnapshot, handleList, handleDetail } = createModuleReadHandlers(
  "viewAlumni",
  alumniStore,
);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load alumni dashboard");
}

export async function handleRegistry(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "alumni", "Failed to load alumni registry");
}

export async function handleAlumniDetail(
  req: Request,
  config: AppConfig,
  alumniId: string,
): Promise<Response> {
  return await handleDetail(
    req,
    config,
    "alumni",
    alumniId,
    `Alumni not found: ${alumniId}`,
    alumniDetailToApi,
  );
}

export async function handleEvents(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "event", "Failed to load alumni events");
}

export async function handleDonations(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "donation", "Failed to load alumni donations");
}

export async function handleCampaigns(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "campaign", "Failed to load alumni campaigns");
}

export async function handleMentorship(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "mentorship", "Failed to load mentorship pairs");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_reports", "Failed to load alumni reports");
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load alumni settings");
}
