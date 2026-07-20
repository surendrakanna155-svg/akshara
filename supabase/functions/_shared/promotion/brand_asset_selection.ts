// PRC-A Batch 10 — minimum-relevant-asset selection (owner decision #4).
//
// Pure, deterministic. Owner #4 requires "minimum-relevant-asset selection (never
// send all assets)". Given a promotion context, score each brand asset by tag /
// keyword overlap and return only the top few — never the whole library.

export interface BrandAsset {
  id: string;
  type: string; // logo | photo | campus | banner | ...
  url: string;
  tags: string[];
  description?: string;
}

export interface AssetSelectionContext {
  /** The promotion subject/purpose, e.g. "achievement", "admission", "festival". */
  subject: string;
  /** Extra free-text keywords from the promotion details. */
  keywords?: string[];
  /** Cap on how many assets to return. Defaults to 3 — a poster needs a few, not all. */
  maxAssets?: number;
}

function norm(s: string): string {
  return s.trim().toLowerCase();
}

/**
 * Select the minimum relevant asset set for a promotion. Assets are scored by how
 * many of their tags (or type) match the subject + keywords; ties break by id for
 * determinism. Returns at most `maxAssets` (default 3). A logo, if present, is
 * always included first (brand identity) and counts toward the cap. When nothing
 * matches, falls back to the logo + the first assets up to the cap — never the
 * whole library, and never empty when assets exist.
 */
export function selectRelevantAssets(
  assets: BrandAsset[],
  ctx: AssetSelectionContext,
): BrandAsset[] {
  const cap = Math.max(1, ctx.maxAssets ?? 3);
  if (!Array.isArray(assets) || assets.length === 0) return [];

  const needles = new Set<string>([norm(ctx.subject), ...(ctx.keywords ?? []).map(norm)].filter(Boolean));

  const scored = assets.map((a, index) => {
    const hay = new Set<string>([norm(a.type), ...(a.tags ?? []).map(norm)]);
    let score = 0;
    for (const n of needles) {
      if (hay.has(n)) score += 2;
      else {
        // partial: a needle contained in a tag (or vice-versa) is a weaker match.
        for (const h of hay) {
          if (h.includes(n) || n.includes(h)) {
            score += 1;
            break;
          }
        }
      }
    }
    return { a, score, index };
  });

  // Logo first (brand identity), then by score desc, then original order for stability.
  scored.sort((x, y) => {
    const xLogo = x.a.type === "logo" ? 1 : 0;
    const yLogo = y.a.type === "logo" ? 1 : 0;
    if (xLogo !== yLogo) return yLogo - xLogo;
    if (x.score !== y.score) return y.score - x.score;
    return x.index - y.index;
  });

  return scored.slice(0, cap).map((s) => s.a);
}
