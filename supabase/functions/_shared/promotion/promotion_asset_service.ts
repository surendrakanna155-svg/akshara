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
    // AI-4: honest flag — no poster image is rendered yet (previewUrl/downloadUrl
    // stay null). Image rendering + hosting is owner-gated (Phase 2); flip to
    // true only when a real rendered asset URL is produced.
    imageGenerationReady: false,
  };
}

export interface AssetBundleOptions {
  subjectType?: string;
  description?: string;
}

/** Subject-appropriate wording so a festival/holiday reads as a greeting, not an "achievement". */
function tone(subjectType: string | undefined): {
  poster: (t: string) => string;
  whatsapp: (t: string) => string;
  instagram: (t: string) => string;
  facebook: (t: string) => string;
  hashtags: string;
} {
  switch (subjectType) {
    case "holiday":
      return {
        poster: (t) => `Holiday notice: ${t}. School remains closed.`,
        whatsapp: (t) => `📅 Holiday: ${t}. Our school will remain closed. — Akshara School`,
        instagram: (t) => `${t} 📅 Enjoy the break!`,
        facebook: (t) => `Holiday announcement: ${t}. The school will remain closed.`,
        hashtags: "#Holiday #SchoolNotice",
      };
    case "festival":
      return {
        poster: (t) => `Warm greetings on ${t} from all of us.`,
        whatsapp: (t) => `🪔 Happy ${t}! Warm wishes to our school family. — Akshara School`,
        instagram: (t) => `Happy ${t} ✨ from our school family`,
        facebook: (t) => `Wishing everyone a joyful ${t} from our school family!`,
        hashtags: "#Festival #Greetings",
      };
    case "event":
    case "exam":
    case "result":
    case "admission":
      return {
        poster: (t) => `${t} — details inside.`,
        whatsapp: (t) => `📣 ${t}. Please see the details shared by the school.`,
        instagram: (t) => `${t} 📣`,
        facebook: (t) => `${t} — see the details from our school.`,
        hashtags: "#SchoolUpdate",
      };
    default: // achievement / general
      return {
        poster: (t) => `Celebrating ${t}.`,
        whatsapp: (t) => `🎉 ${t}! Proud moment for our school family. Share the joy!`,
        instagram: (t) => `${t} ✨ #AksharaPride #StudentSuccess`,
        facebook: (t) => `Congratulations on ${t}! Share the joy with our community.`,
        hashtags: "#AksharaPride",
      };
  }
}

export function generatePromotionAssetBundle(
  title: string,
  opts: AssetBundleOptions = {},
): PromotionAssetBundle {
  const t = tone(opts.subjectType);
  const tail = opts.description ? ` ${opts.description}` : "";
  return {
    poster: assetMeta(
      "poster",
      "Poster",
      title,
      `${t.poster(title)}${tail} Ready for print at 1080×1920.`,
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
      `In-app card for parent and student feeds.`,
      { format: "image/png", width: 800, height: 450, aspectRatio: "16:9" },
    ),
    whatsapp: assetMeta(
      "whatsapp",
      "WhatsApp Banner",
      title,
      t.whatsapp(title),
      { format: "image/jpeg", width: 1200, height: 630, aspectRatio: "1.91:1" },
    ),
    instagram: assetMeta(
      "instagram",
      "Instagram Post",
      title,
      `${t.instagram(title)} ${t.hashtags}`,
      { format: "image/jpeg", width: 1080, height: 1080, aspectRatio: "1:1" },
    ),
    facebook: assetMeta(
      "facebook",
      "Facebook Post",
      title,
      t.facebook(title),
      { format: "image/jpeg", width: 1200, height: 630, aspectRatio: "1.91:1" },
    ),
  };
}

export function promotionAssetsToRecord(bundle: PromotionAssetBundle): Record<string, unknown> {
  return { ...bundle };
}
