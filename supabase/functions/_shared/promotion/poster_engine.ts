// PRC-A Batch 10 — provider-neutral poster engine (owner decision #4).
//
// A canonical image-gen interface with a DARK default provider. Structurally
// mirrors anthropic_client.ts (provider union + single entry point) and
// meta_graph_client.metaDryRun() ("no config ⇒ structured, never fabricate").
//
// Owner #4: build the internal poster ENGINE now, isolate only the external
// activation. Until a paid image-gen provider is provisioned, generatePoster
// returns an HONEST 'provider_not_configured' result with imageUrl=null — it never
// fabricates a poster URL. The rest of the flow (brand profile + asset selection +
// preview) is fully functional around it.

import type { BrandAsset } from "./brand_asset_selection.ts";

export type PosterProvider = "none" | "external";

export interface PosterRequest {
  purpose: string;
  title: string;
  details?: string | null;
  theme: Record<string, unknown>;
  assets: BrandAsset[];
}

export interface PosterResult {
  status: "generated" | "provider_not_configured";
  provider: string;
  imageUrl: string | null;
  /** The prompt/brief the engine WOULD send to a provider — useful for preview and
   * for the eventual real integration; never a fabricated image. */
  brief: string;
  detail: string;
}

/** The configured poster image-gen provider, or 'none'. */
export function posterProvider(): PosterProvider {
  try {
    const p = (Deno.env.get("POSTER_IMAGE_PROVIDER") ?? "").trim().toLowerCase();
    return p && p !== "none" ? "external" : "none";
  } catch {
    return "none";
  }
}

/** True only when a real image-gen provider AND its key are configured. */
export function posterProviderConfigured(): boolean {
  try {
    return posterProvider() === "external" && !!Deno.env.get("POSTER_IMAGE_API_KEY");
  } catch {
    return false;
  }
}

/** Build the deterministic image brief from the request (what a provider would render). */
export function buildPosterBrief(req: PosterRequest): string {
  const parts = [
    `Purpose: ${req.purpose}`,
    `Headline: ${req.title}`,
    req.details ? `Details: ${req.details}` : null,
    req.theme?.primaryColor ? `Primary colour: ${String(req.theme.primaryColor)}` : null,
    req.assets.length > 0
      ? `Assets: ${req.assets.map((a) => `${a.type}:${a.id}`).join(", ")}`
      : "Assets: none",
  ].filter((p): p is string => !!p);
  return parts.join(" · ");
}

/**
 * Generate a poster. DARK by default: with no external image-gen provider
 * configured, returns an honest 'provider_not_configured' result (imageUrl=null) —
 * never a fabricated poster. The `brief` is always returned so the preview flow and
 * the eventual real integration have the exact render instructions.
 *
 * NOTE: the actual external-provider HTTP call is the owner-gated follow-up. Even
 * with a provider name set, until that integration lands this returns the honest
 * dark result rather than pretending to have rendered an image.
 */
export function generatePoster(req: PosterRequest): PosterResult {
  const brief = buildPosterBrief(req);
  if (!posterProviderConfigured()) {
    return {
      status: "provider_not_configured",
      provider: "none",
      imageUrl: null,
      brief,
      detail:
        "Poster image generation requires an external image-gen provider (owner-gated). The brand assets, theme, and brief are ready; only the render step is pending.",
    };
  }
  // A provider is configured but the external render integration is a separate
  // owner-gated deliverable — never fabricate an image URL here.
  return {
    status: "provider_not_configured",
    provider: posterProvider(),
    imageUrl: null,
    brief,
    detail: "External image-gen provider configured; render integration pending activation.",
  };
}
