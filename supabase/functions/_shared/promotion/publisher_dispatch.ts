// Publisher — destination dispatch (Phase 1).
//
// Fans a published promotion out to the selected channels, reusing the
// communication hub for in-ERP delivery. Social channels (facebook/instagram) are
// recorded as `pending_connection` here and made real in Phase 2 (Meta Graph API).

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createBroadcast,
  enqueueDeliveriesBatch,
  finalizeBroadcast,
  insertBroadcastRecipientsBatch,
  resolveBroadcastRecipients,
} from "../communication/communication_repository.ts";
import { publishToSocialChannel } from "../social/social_publish_service.ts";

/** PERF-1: bound a single publish fan-out the same way broadcasts are bounded
 * (see communication_service.ts MAX_BROADCAST_RECIPIENTS). */
const MAX_PUBLISH_RECIPIENTS = 5000;

export const PUBLISH_DESTINATIONS = [
  "parent_app",
  "student_app",
  "teacher_app",
  "staff_app",
  "whatsapp",
  "website",
  "facebook",
  "instagram",
] as const;
export type PublishDestination = typeof PUBLISH_DESTINATIONS[number];

const APP_AUDIENCE: Record<string, string> = {
  parent_app: "all_parents",
  student_app: "all_students",
  teacher_app: "all_teachers",
  staff_app: "all_staff",
};

export interface DispatchInput {
  promotionId: string;
  title: string;
  /** Short body used for the in-ERP notice + WhatsApp share text. */
  caption: string;
  assets: Record<string, unknown>;
  destinations: string[];
  orgId: string;
  schoolId: string;
  createdBy: string;
}

function captionFor(assets: Record<string, unknown>, channel: string, fallback: string): string {
  const node = assets[channel];
  if (node && typeof node === "object") {
    const caption = (node as Record<string, unknown>).caption;
    if (typeof caption === "string" && caption.trim()) return caption.trim();
  }
  return fallback;
}

/** Deliver to one in-ERP audience; returns the count of recipients queued. */
async function deliverToAudience(
  db: TenantQueryClient,
  input: DispatchInput,
  audience: string,
): Promise<number> {
  const broadcast = await createBroadcast(db, {
    organizationId: input.orgId,
    schoolId: input.schoolId,
    audience,
    title: input.title,
    body: input.caption,
    createdBy: input.createdBy,
  });
  // PERF-1: cap the cohort, then write recipients + push deliveries in two
  // multi-row INSERTs instead of 2 round-trips per recipient.
  const resolved = await resolveBroadcastRecipients(db, input.orgId, input.schoolId, audience);
  const recipients = resolved.slice(0, MAX_PUBLISH_RECIPIENTS);
  await insertBroadcastRecipientsBatch(db, broadcast.id, input.orgId, recipients);
  await enqueueDeliveriesBatch(db, {
    organizationId: input.orgId,
    schoolId: input.schoolId,
    recipientUserIds: recipients,
    channel: "push",
    category: "announcement",
    renderedSubject: input.title,
    renderedBody: input.caption,
  });
  await finalizeBroadcast(db, broadcast.id);
  return recipients.length;
}

/**
 * Dispatch to every selected destination. Returns a per-destination result map
 * stored on the promotion (`publish_results`). Unknown destinations are skipped.
 */
export async function dispatchPublish(
  db: TenantQueryClient,
  input: DispatchInput,
): Promise<Record<string, unknown>> {
  const results: Record<string, unknown> = {};
  const seen = new Set<string>();

  for (const destination of input.destinations) {
    if (seen.has(destination)) continue;
    seen.add(destination);

    if (APP_AUDIENCE[destination]) {
      const count = await deliverToAudience(db, input, APP_AUDIENCE[destination]!);
      results[destination] = { status: "sent", channel: "in_app", recipientCount: count };
    } else if (destination === "whatsapp") {
      results[destination] = {
        status: "ready",
        channel: "whatsapp_deeplink",
        shareText: captionFor(input.assets, "whatsapp", input.caption),
      };
    } else if (destination === "website") {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO school_website_posts
           (organization_id, school_id, source_promotion_id, title, body, image_caption, category)
         VALUES ($1, $2, $3, $4, $5, $6, 'news')
         RETURNING id`,
        [
          input.orgId,
          input.schoolId,
          input.promotionId,
          input.title,
          input.caption,
          captionFor(input.assets, "facebook", input.caption),
        ],
      );
      results[destination] = { status: "published", channel: "website", postId: rows[0]!.id };
    } else if (destination === "facebook" || destination === "instagram") {
      // Phase 2: post via Meta Graph using the school's connected account, or
      // `pending_connection` when none is linked.
      const posterNode = input.assets["poster"] as Record<string, unknown> | undefined;
      const imageUrl = (posterNode?.previewUrl ?? posterNode?.downloadUrl ?? null) as string | null;
      results[destination] = await publishToSocialChannel(
        db,
        destination,
        captionFor(input.assets, destination, input.caption),
        imageUrl,
      );
    } else {
      results[destination] = { status: "skipped", reason: "unknown_destination" };
    }
  }
  return results;
}
