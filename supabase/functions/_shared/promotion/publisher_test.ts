import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generatePromotionAssetBundle } from "./promotion_asset_service.ts";
import { dispatchPublish, PUBLISH_DESTINATIONS } from "./publisher_dispatch.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

Deno.test("asset captions are subject-aware (festival greeting, not achievement)", () => {
  const festival = generatePromotionAssetBundle("Diwali", { subjectType: "festival" });
  assertEquals(festival.whatsapp.caption.includes("Happy Diwali"), true);
  const holiday = generatePromotionAssetBundle("Republic Day", { subjectType: "holiday" });
  assertEquals(holiday.whatsapp.caption.toLowerCase().includes("holiday"), true);
  const ach = generatePromotionAssetBundle("State Champions", { subjectType: "achievement" });
  assertEquals(ach.whatsapp.caption.includes("Proud moment"), true);
});

// Minimal fake tenant client: returns canned rows by SQL fingerprint.
function fakeDb(): TenantQueryClient {
  return {
    // deno-lint-ignore no-explicit-any
    queryObject: async (sql: string): Promise<any> => {
      if (sql.includes("INSERT INTO comm_broadcasts")) return [{ id: "broadcast-1" }];
      if (sql.includes("guardian_user_id")) return [{ guardian_user_id: "p1" }, { guardian_user_id: "p2" }];
      if (sql.includes("school_memberships")) return [{ user_id: "s1" }];
      if (sql.includes("JOIN students")) return [{ user_id: "st1" }, { user_id: "st2" }, { user_id: "st3" }];
      if (sql.includes("INSERT INTO comm_recipients")) return [];
      if (sql.includes("INSERT INTO notification_deliveries")) return [{ id: "d1" }];
      if (sql.includes("UPDATE comm_broadcasts")) return [];
      if (sql.includes("INSERT INTO school_website_posts")) return [{ id: "web-1" }];
      return [];
    },
    // deno-lint-ignore no-explicit-any
  } as any;
}

Deno.test("dispatch fans out per destination with correct statuses", async () => {
  const assets = generatePromotionAssetBundle("Annual Day", { subjectType: "event" }) as unknown as Record<
    string,
    unknown
  >;
  const results = await dispatchPublish(fakeDb(), {
    promotionId: "promo-1",
    title: "Annual Day",
    caption: "Annual Day is here.",
    assets,
    destinations: ["parent_app", "student_app", "staff_app", "whatsapp", "website", "facebook", "instagram"],
    orgId: "org-1",
    schoolId: "school-1",
    createdBy: "user-1",
  });

  assertEquals((results.parent_app as Record<string, unknown>).status, "sent");
  assertEquals((results.parent_app as Record<string, unknown>).recipientCount, 2);
  assertEquals((results.student_app as Record<string, unknown>).recipientCount, 3);
  assertEquals((results.staff_app as Record<string, unknown>).recipientCount, 1);
  assertEquals((results.whatsapp as Record<string, unknown>).status, "ready");
  assertEquals((results.website as Record<string, unknown>).status, "published");
  assertEquals((results.website as Record<string, unknown>).postId, "web-1");
  assertEquals((results.facebook as Record<string, unknown>).status, "pending_connection");
  assertEquals((results.instagram as Record<string, unknown>).status, "pending_connection");
});

Deno.test("PUBLISH_DESTINATIONS covers app + social + website + whatsapp", () => {
  for (const d of ["parent_app", "student_app", "teacher_app", "staff_app", "whatsapp", "website", "facebook", "instagram"]) {
    assertEquals((PUBLISH_DESTINATIONS as readonly string[]).includes(d), true, d);
  }
});
