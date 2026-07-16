import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { type BrandAsset, selectRelevantAssets } from "./brand_asset_selection.ts";
import { buildPosterBrief, generatePoster, posterProviderConfigured } from "./poster_engine.ts";

const assets: BrandAsset[] = [
  { id: "logo1", type: "logo", url: "u/logo", tags: [] },
  { id: "sports1", type: "photo", url: "u/s1", tags: ["sports", "achievement", "trophy"] },
  { id: "campus1", type: "campus", url: "u/c1", tags: ["campus", "building"] },
  { id: "festival1", type: "photo", url: "u/f1", tags: ["festival", "diwali"] },
  { id: "class1", type: "photo", url: "u/cl1", tags: ["classroom", "students"] },
];

// ─── selectRelevantAssets ────────────────────────────────────────────────────

Deno.test("Batch 10: selection returns the minimum relevant set, never the whole library", () => {
  const out = selectRelevantAssets(assets, { subject: "achievement", keywords: ["sports"] });
  assert(out.length <= 3, `expected <=3, got ${out.length}`);
  assert(out.length < assets.length, "must not return all assets");
});

Deno.test("Batch 10: the most relevant asset (by tag overlap) is selected", () => {
  const out = selectRelevantAssets(assets, { subject: "achievement", keywords: ["sports"] });
  assert(out.some((a) => a.id === "sports1"), "the sports/achievement asset must be picked");
});

Deno.test("Batch 10: the logo is always included first (brand identity)", () => {
  const out = selectRelevantAssets(assets, { subject: "festival" });
  assertEquals(out[0].type, "logo");
});

Deno.test("Batch 10: an empty asset library yields an empty selection", () => {
  assertEquals(selectRelevantAssets([], { subject: "anything" }), []);
});

Deno.test("Batch 10: with no tag match, selection falls back (logo + first) — never empty", () => {
  const out = selectRelevantAssets(assets, { subject: "zzz-nomatch" });
  assert(out.length > 0, "must not be empty when assets exist");
  assertEquals(out[0].type, "logo");
});

Deno.test("Batch 10: maxAssets caps the selection", () => {
  const out = selectRelevantAssets(assets, { subject: "achievement", keywords: ["sports"], maxAssets: 1 });
  assertEquals(out.length, 1);
});

Deno.test("Batch 10: selection is deterministic (same input → same output)", () => {
  const a = selectRelevantAssets(assets, { subject: "festival", keywords: ["diwali"] });
  const b = selectRelevantAssets(assets, { subject: "festival", keywords: ["diwali"] });
  assertEquals(a.map((x) => x.id), b.map((x) => x.id));
});

// ─── poster engine (honest dark provider) ────────────────────────────────────

Deno.test("Batch 10: with no image-gen provider, generatePoster is honestly not-configured (no fabricated URL)", () => {
  const r = generatePoster({ purpose: "achievement", title: "Gold Medal!", theme: {}, assets: [] });
  assertEquals(r.status, "provider_not_configured");
  assertEquals(r.imageUrl, null);
  assert(r.brief.length > 0, "the brief is always returned for the eventual render");
});

Deno.test("Batch 10: posterProviderConfigured is false by default (dark)", () => {
  assertEquals(posterProviderConfigured(), false);
});

Deno.test("Batch 10: the poster brief carries the purpose, headline, and asset refs", () => {
  const brief = buildPosterBrief({
    purpose: "admission",
    title: "Admissions Open 2026",
    theme: { primaryColor: "#0a7" },
    assets: [{ id: "logo1", type: "logo", url: "u", tags: [] }],
  });
  assert(brief.includes("admission"));
  assert(brief.includes("Admissions Open 2026"));
  assert(brief.includes("logo:logo1"));
});
