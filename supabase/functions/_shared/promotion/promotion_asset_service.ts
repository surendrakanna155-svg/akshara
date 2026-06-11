export type PromotionAssetFormat = "image/png" | "image/jpeg" | "text/plain";

export interface PromotionAssetMetadata {
  id: string;
  label: string;
  format: PromotionAssetFormat;
  width?: number;
  height?: number;
  aspectRatio?: string;
  caption: string;
  headline: string;
  previewUrl: string | null;
  downloadUrl: string | null;
  generatedAt: string;
  imageGenerationReady: boolean;
}

export interface PromotionAssetBundle {
  poster: PromotionAssetMetadata;
  banner: PromotionAssetMetadata;
  appCard: PromotionAssetMetadata;
  whatsapp: PromotionAssetMetadata;
  instagram: PromotionAssetMetadata;
  facebook: PromotionAssetMetadata;
}

function assetMeta(
  id: string,
  label: string,
  title: string,
  caption: string,
  opts: {
    format?: PromotionAssetFormat;
    width?: number;
    height?: number;
    aspectRatio?: string;
  } = {},
): PromotionAssetMetadata {
  const now = new Date().toISOString();
  return {
    id,
    label,
    format: opts.format ?? "text/plain",
    width: opts.width,
    height: opts.height,
    aspectRatio: opts.aspectRatio,
    caption,
    headline: title,
    previewUrl: null,
    downloadUrl: null,
    generatedAt: now,
    imageGenerationReady: true,
  };
}

export function generatePromotionAssetBundle(title: string): PromotionAssetBundle {
  return {
    poster: assetMeta(
      "poster",
      "Poster",
      `Celebrating ${title}`,
      `Official achievement poster for ${title}. Ready for print at 1080×1920.`,
      { format: "image/png", width: 1080, height: 1920, aspectRatio: "9:16" },
    ),
    banner: assetMeta(
      "banner",
      "School Banner",
      `${title} — Akshara School`,
      `Wide banner for school displays and website hero.`,
      { format: "image/jpeg", width: 1920, height: 600, aspectRatio: "16:5" },
    ),
    appCard: assetMeta(
      "appCard",
      "App Card",
      title,
      `In-app achievement card for parent and student feeds.`,
      { format: "image/png", width: 800, height: 450, aspectRatio: "16:9" },
    ),
    whatsapp: assetMeta(
      "whatsapp",
      "WhatsApp Banner",
      title,
      `🎉 ${title}! Proud moment for our school family. Share the joy!`,
      { format: "image/jpeg", width: 1200, height: 630, aspectRatio: "1.91:1" },
    ),
    instagram: assetMeta(
      "instagram",
      "Instagram Post",
      title,
      `${title} ✨ #AksharaPride #StudentSuccess #SchoolAchievements`,
      { format: "image/jpeg", width: 1080, height: 1080, aspectRatio: "1:1" },
    ),
    facebook: assetMeta(
      "facebook",
      "Facebook Post",
      title,
      `Congratulations on ${title}! Share the joy with our community.`,
      { format: "image/jpeg", width: 1200, height: 630, aspectRatio: "1.91:1" },
    ),
  };
}

export function promotionAssetsToRecord(bundle: PromotionAssetBundle): Record<string, unknown> {
  return { ...bundle };
}
