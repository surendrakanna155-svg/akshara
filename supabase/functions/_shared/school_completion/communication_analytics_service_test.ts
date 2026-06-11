import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeCampaignAnalytics,
  computeCommunicationEffectiveness,
  computeParentAdoptionAnalytics,
  computeParentEngagementAnalytics,
} from "./communication_analytics_service.ts";

Deno.test("computeCampaignAnalytics aggregates delivery and engagement rates", () => {
  const result = computeCampaignAnalytics([
    {
      id: "c1",
      campaign_code: "FEE_REM",
      campaign_name: "Fee Reminder",
      channel: "whatsapp",
      template_code: "fee_reminder",
      target_audience: "all_parents",
      status: "completed",
      sent_count: 100,
      delivered_count: 95,
      failed_count: 5,
      opened_count: 60,
      responded_count: 20,
      scheduled_at: null,
      created_at: "2026-06-01",
    },
  ]);
  assertEquals(result.totalCampaigns, 1);
  assertEquals(result.aggregateDeliveryRate, 95);
  assertEquals(result.aggregateOpenRate, 60);
  assertEquals(result.aggregateResponseRate, 20);
});

Deno.test("computeCommunicationEffectiveness scores open and response rates", () => {
  const result = computeCommunicationEffectiveness({
    deliveries: [
      { template_code: "attendance", channel: "whatsapp", status: "sent" },
      { template_code: "attendance", channel: "whatsapp", status: "delivered" },
      { template_code: "homework", channel: "in_app", status: "sent" },
    ],
    engagements: [
      { event_type: "opened", channel: "whatsapp" },
      { event_type: "responded", channel: "whatsapp" },
    ],
  });
  assertEquals(result.openRate, 33);
  assertEquals(result.responseRate, 33);
  assertEquals(result.effectivenessScore, 33);
});

Deno.test("computeParentEngagementAnalytics ranks top parents", () => {
  const result = computeParentEngagementAnalytics([
    {
      parent_user_id: "p1",
      engagement_score: 85,
      messages_read_30d: 12,
      app_sessions_30d: 8,
      last_active_at: "2026-06-10",
    },
    {
      parent_user_id: "p2",
      engagement_score: 30,
      messages_read_30d: 2,
      app_sessions_30d: 0,
      last_active_at: null,
    },
  ]);
  assertEquals(result.averageEngagementScore, 58);
  assertEquals(result.lowEngagementParents, 1);
  assertEquals(result.topEngagedParents[0]!.parentUserId, "p1");
});

Deno.test("computeParentAdoptionAnalytics calculates adoption by grade", () => {
  const result = computeParentAdoptionAnalytics({
    total: 100,
    active: 75,
    newActivations30d: 10,
    byGrade: [
      { grade_label: "Grade 7", total: "50", active: "40" },
      { grade_label: "Grade 8", total: "50", active: "35" },
    ],
  });
  assertEquals(result.adoptionRate, 75);
  assertEquals(result.pendingParents, 25);
  assertEquals(result.adoptionByGrade[0]!.rate, 80);
});
