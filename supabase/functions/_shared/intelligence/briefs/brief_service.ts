// Adaptive AI — P3-AI-3 / W2.1: the brief/digest platform.
//
// "The pulse/brief/digest family is one platform feature (pre-warm + shared
// generation + T0 assembly) instantiated per persona — build once, configure
// five times" (doc 07 §6). This module is that platform:
//
//   • T1 sections — ALWAYS present, assembled live from the SAME scored feed
//     the priority route serves (one engine, doc 07 §6.1). Numbers never come
//     from a cache (doc 03 §3.5: facts and phrasing are separable).
//   • T3 narrative — OPTIONAL warm prose over the sections, generated through
//     the governed gateway and stored as a SHARED generation (doc 03 §3.3):
//     one row per (school, persona, scope, IST day) serves every same-scope
//     user until the next 04:00 IST pre-warm window. No key / any failure →
//     the T1 brief renders alone (doc 03 §3.4).
//   • Pre-warm — the same generation invoked off-peak so morning logins hit
//     T2. The endpoint exists now; the nightly auto-fire inherits the COM-4
//     INTERNAL_CRON_TOKEN ops gate (owner-activated, like the XCT-2 rail).
//
// v1 instantiates teacher (own-classes brief; narrative shared per teacher —
// per-class-section sharing arrives with the class-brief pre-warm wave) and
// principal (daily pulse; narrative shared school-wide, which is the doc-09
// "one generation serves N same-scope users" proof). Parent/student/director
// digests ride the same shape later.

import type { AccessTokenClaims } from "../../jwt.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { organizationIdFromClaims, schoolIdFromClaims } from "../../permission_middleware.ts";
import { governedTextFor } from "../../ai/model_gateway.ts";
import {
  lookupResponseCache,
  writeResponseCache,
} from "../../ai/ai_response_cache_repository.ts";
import { fenceUntrusted, UNTRUSTED_DATA_PREAMBLE } from "../../ai/prompt_safety.ts";
import { loadPersonaFeedContext } from "../priority/priority_feed_service.ts";
import { buildFeed } from "../priority/priority_engine.ts";
import { istDateOf } from "../priority/feed_dates.ts";
import type { PriorityItemType, ScoredPriorityItem } from "../priority/priority_types.ts";

/** The personas the brief platform serves today. */
export type BriefPersona = "teacher" | "principal";

export interface BriefSection {
  title: string;
  /** Bounded headline lines (the item titles), most urgent first. */
  lines: string[];
  /** Full count behind the lines (lines are capped, the count is honest). */
  count: number;
}

export interface DailyBrief {
  persona: BriefPersona;
  /** School-local (IST) calendar day the brief describes. */
  dateIst: string;
  /** T1 — always present, computed live this request. */
  sections: BriefSection[];
  /** T3 — cached shared prose, or null (no key / failure / cold cache miss
   * that could not be filled). The client renders sections either way. */
  narrative: string | null;
  narrativeFromCache: boolean;
  generatedAt: string;
}

const SECTION_ORDER: Array<{ type: PriorityItemType; title: string }> = [
  { type: "exception", title: "Needs attention today" },
  { type: "deadline", title: "Deadlines" },
  { type: "approval", title: "Approvals waiting" },
  { type: "follow_up", title: "Follow-ups" },
  { type: "opportunity", title: "Opportunities" },
];

const MAX_LINES_PER_SECTION = 5;

/** PURE: fold the scored feed into ordered brief sections. Items arrive
 * already scored + sorted by the engine, so each section's lines are its most
 * urgent entries. Empty sections are omitted — an honest quiet day is short. */
export function assembleBriefSections(items: ScoredPriorityItem[]): BriefSection[] {
  const sections: BriefSection[] = [];
  for (const { type, title } of SECTION_ORDER) {
    const matching = items.filter((i) => i.type === type);
    if (matching.length === 0) continue;
    sections.push({
      title,
      lines: matching.slice(0, MAX_LINES_PER_SECTION).map((i) => i.title),
      count: matching.length,
    });
  }
  return sections;
}

/** The per-source permissions the school-persona brief composes from. The
 * narrative a caller may READ must have been generated under the same source
 * set — this is the RBAC dimension of the shared-generation key (audit round
 * 4 P1: "AI inherits ERP RBAC EXACTLY" means the reader's permissions, not
 * the generator's). */
export const BRIEF_SOURCE_PERMISSIONS: readonly string[] = [
  "viewAnalytics",
  "viewStudentRisk",
  "viewFinance",
  "viewInventory",
  "viewTransport",
  "viewHr",
  "viewLibrary",
] as const;

/** Stable short signature of the caller's brief-relevant permission subset.
 * Same subset ⇒ same signature ⇒ shared narrative; any difference ⇒ a
 * separate cache entry generated from that caller's OWN gated sections. */
export async function briefPermissionSignature(permissions: string[]): Promise<string> {
  const subset = BRIEF_SOURCE_PERMISSIONS.filter((p) => permissions.includes(p));
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(subset.join(",")),
  );
  return Array.from(new Uint8Array(digest))
    .slice(0, 6)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** PURE: the shared-generation cache key. NO user id for the principal pulse
 * — sharing is bounded by (school, persona, IST day, PERMISSION SIGNATURE),
 * so prose is only ever served to readers whose own RBAC spans the exact
 * source set it was generated from. Teacher briefs additionally carry the
 * user id in scopeKey (personal class set). */
export function briefCacheKey(
  persona: BriefPersona,
  scopeKey: string,
  istDate: string,
  permissionSignature: string,
): string {
  return `brief:${persona}:${scopeKey}:${permissionSignature}:${istDate}`;
}

const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const PREWARM_HOUR_IST = 4;

/** PURE: seconds until the next 04:00 IST — the "Daily" volatility-class TTL
 * (doc 03 §3.5): the nightly pre-warm replaces the entry; the TTL is only the
 * backstop that stops yesterday's prose surviving a missed pre-warm. */
export function secondsToNextIstPrewarm(nowIso: string): number {
  const now = Date.parse(nowIso);
  const istNow = now + IST_OFFSET_MS;
  const istMidnight = Math.floor(istNow / DAY_MS) * DAY_MS;
  let next = istMidnight + PREWARM_HOUR_IST * 3_600_000;
  if (next <= istNow) next += DAY_MS;
  return Math.max(60, Math.round((next - istNow) / 1000));
}

const NARRATIVE_MAX_TOKENS = 400;

const NARRATIVE_SYSTEM = `
You are Akshara's morning-brief writer for a school.
You are given today's already-computed brief sections; every count is final.
Write a warm, 2-to-4-sentence morning summary a busy educator can absorb in
ten seconds. Strict rules:
- NEVER change, add, or invent any number or name. Use only what is provided.
- Lead with what needs attention first; end on an encouraging, practical note.
- Output ONLY the summary prose. No headings, no lists, no preamble.

${UNTRUSTED_DATA_PREAMBLE}
`.trim();

/** Serialize sections for the narrative prompt — titles and counts only. */
function sectionsForPrompt(sections: BriefSection[]): unknown {
  return sections.map((s) => ({ section: s.title, count: s.count, items: s.lines }));
}

/**
 * Load (or pre-warm) the persona's daily brief. Sections are always computed
 * live from the same engine as the priority feed; the narrative is a shared
 * generation read through ai_response_cache. `warmOnly` skips the sections in
 * the response shape being used (the pre-warm caller only wants the cache
 * side effect). Deterministic except the single governed narrative call.
 */
export async function loadDailyBrief(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  persona: BriefPersona,
  nowIso: string,
): Promise<DailyBrief> {
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const istDate = istDateOf(nowIso);

  const ctx = await loadPersonaFeedContext(db, claims, persona, nowIso);
  const feed = buildFeed(ctx.rawItems, persona, nowIso, {
    weights: ctx.weights,
    dismissedKeys: ctx.dismissedKeys,
  });
  const sections = assembleBriefSections(feed.items);

  // Shared-generation boundary: principal pulse is school-shared WITHIN a
  // permission cohort; the teacher brief shares per teacher (their class set
  // is personal in v1). The permission signature keeps a reader from ever
  // being served prose derived from sources their own RBAC excludes.
  const scopeKey = persona === "principal" ? "school" : `user:${claims.sub}`;
  const signature = await briefPermissionSignature(claims.permissions);
  const cacheKey = briefCacheKey(persona, scopeKey, istDate, signature);
  const scope = { organizationId: orgId, schoolId };

  let narrative: string | null = null;
  let narrativeFromCache = false;

  if (sections.length > 0) {
    const hit = await lookupResponseCache(db, scope, cacheKey);
    if (hit) {
      narrative = hit.payload;
      narrativeFromCache = true;
    } else {
      // One governed call fills the shared entry; every failure mode inside
      // the gateway returns null and the T1 brief stands alone.
      narrative = await governedTextFor(
        { db, organizationId: orgId, schoolId, userId: claims.sub },
        "daily_brief",
        {
          system: NARRATIVE_SYSTEM,
          messages: [{
            role: "user",
            content: [
              `Persona: ${persona}. School-local date: ${istDate}.`,
              fenceUntrusted("Brief sections", sectionsForPrompt(sections)),
            ].join("\n"),
          }],
          maxTokens: NARRATIVE_MAX_TOKENS,
          guard: { allowDerivedPercents: true },
        },
      );
      if (narrative) {
        // Inherit the sections' entity tags so event-coupled invalidation
        // (doc 03 §3.5) kills the prose when its underlying facts change —
        // the 04:00 TTL is only the backstop (audit round 4, P3-b).
        const factTags = Array.from(
          new Set(feed.items.flatMap((i) => i.entityTags)),
        ).slice(0, 32);
        await writeResponseCache(db, scope, {
          cacheKey,
          surface: "daily_brief",
          language: "english",
          payload: narrative,
          entityTags: ["brief:daily", ...factTags],
          model: "",
          tokensSaved: 0,
          ttlSeconds: secondsToNextIstPrewarm(nowIso),
        });
      }
    }
  }

  return {
    persona,
    dateIst: istDate,
    sections,
    narrative,
    narrativeFromCache,
    generatedAt: nowIso,
  };
}
