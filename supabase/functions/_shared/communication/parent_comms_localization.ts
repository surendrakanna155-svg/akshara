import { renderTemplate } from "./template_renderer.ts";

/**
 * QW7 · QA-C-016 — Parent Communication Localization (DETERMINISTIC, no LLM).
 *
 * Owner architecture (2026-06-30): parent-facing communication is localized via
 * **predefined multilingual template catalogs with placeholders only** — NEVER
 * an LLM/translation API (those stay for AI *features* like Parent Guidance,
 * which generate natively in-language). This module is that catalog + a pure
 * renderer: pick the parent-language variant of a fixed template, substitute
 * `{{placeholders}}`, and fall back to English when a language or code is absent.
 * Free-text (teacher remarks, custom messages) is NOT translated — it stays
 * English and rides inside a `{{message}}`-style placeholder when needed.
 *
 * English-first product: only PARENT-facing comms use this. Staff/teacher/admin
 * notifications are unaffected (no catalog entry → caller renders the English
 * DB template as before).
 */

export type ParentLanguage = "en" | "te" | "hi" | "ta" | "kn" | "ml" | "ur";

export const PARENT_LANGUAGES: readonly ParentLanguage[] = [
  "en",
  "te",
  "hi",
  "ta",
  "kn",
  "ml",
  "ur",
] as const;

/** Normalizes any code to a supported parent language; defaults to English. */
export function normalizeParentLanguage(code: string | null | undefined): ParentLanguage {
  const c = (code ?? "").toLowerCase().trim();
  return (PARENT_LANGUAGES as readonly string[]).includes(c) ? (c as ParentLanguage) : "en";
}

/**
 * Maps a stored language NAME (the `parent_language_preferences.language` value,
 * e.g. "telugu") to a [ParentLanguage] code. Also accepts an ISO code directly.
 * Anything unsupported → English. This is the bridge between the existing
 * preference store (names) and the send-path catalog (codes).
 */
export function parentLanguageCodeFromName(name: string | null | undefined): ParentLanguage {
  const n = (name ?? "").toLowerCase().trim();
  const byName: Record<string, ParentLanguage> = {
    english: "en",
    telugu: "te",
    hindi: "hi",
    tamil: "ta",
    kannada: "kn",
    malayalam: "ml",
    urdu: "ur",
  };
  return byName[n] ?? normalizeParentLanguage(n);
}

interface LocalizedTemplate {
  subject?: string;
  body: string;
}

/**
 * The catalog: parent-facing template `code` → language → fixed text with
 * `{{placeholders}}`. Every code MUST define `en` (the fallback). Add a new
 * parent-facing template by adding one entry here — no schema change, no LLM.
 */
const CATALOG: Record<string, Partial<Record<ParentLanguage, LocalizedTemplate>>> = {
  attendance_absence: {
    en: {
      subject: "Attendance Alert",
      body:
        "Dear Parent, {{studentName}} was marked absent on {{date}}. Kindly ensure regular attendance.",
    },
    te: {
      subject: "హాజరు హెచ్చరిక",
      body:
        "ప్రియమైన తల్లిదండ్రులారా, {{studentName}} {{date}} నాడు గైర్హాజరుగా గుర్తించబడ్డారు. దయచేసి క్రమం తప్పకుండా హాజరు కావాలని నిర్ధారించండి.",
    },
    hi: {
      subject: "उपस्थिति सूचना",
      body:
        "प्रिय अभिभावक, {{studentName}} को {{date}} को अनुपस्थित दर्ज किया गया। कृपया नियमित उपस्थिति सुनिश्चित करें।",
    },
    ta: {
      subject: "வருகை எச்சரிக்கை",
      body:
        "அன்புள்ள பெற்றோரே, {{studentName}} {{date}} அன்று வரவில்லை எனக் குறிக்கப்பட்டார். தயவுசெய்து வழக்கமான வருகையை உறுதிசெய்யுங்கள்.",
    },
    kn: {
      subject: "ಹಾಜರಾತಿ ಎಚ್ಚರಿಕೆ",
      body:
        "ಆತ್ಮೀಯ ಪೋಷಕರೇ, {{studentName}} ಅವರನ್ನು {{date}} ರಂದು ಗೈರುಹಾಜರಾಗಿ ಗುರುತಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ನಿಯಮಿತ ಹಾಜರಾತಿ ಖಚಿತಪಡಿಸಿ.",
    },
    ml: {
      subject: "ഹാജർ അറിയിപ്പ്",
      body:
        "പ്രിയ രക്ഷിതാവേ, {{studentName}} {{date}}-ന് ഹാജരായില്ലെന്ന് രേഖപ്പെടുത്തി. ദയവായി നിയമിത ഹാജർ ഉറപ്പാക്കുക.",
    },
    ur: {
      subject: "حاضری انتباہ",
      body:
        "محترم والدین، {{studentName}} کو {{date}} کو غیر حاضر درج کیا گیا۔ براہ کرم باقاعدہ حاضری یقینی بنائیں۔",
    },
  },
  fee_reminder: {
    en: {
      subject: "Fee Reminder",
      body:
        "Dear Parent, a fee of {{amount}} for {{studentName}} is due by {{dueDate}}. Kindly complete the payment.",
    },
    te: {
      subject: "ఫీజు రిమైండర్",
      body:
        "ప్రియమైన తల్లిదండ్రులారా, {{studentName}} కోసం {{amount}} ఫీజు {{dueDate}} లోపు చెల్లించాలి. దయచేసి చెల్లింపు పూర్తి చేయండి.",
    },
    hi: {
      subject: "शुल्क अनुस्मारक",
      body:
        "प्रिय अभिभावक, {{studentName}} के लिए {{amount}} शुल्क {{dueDate}} तक देय है। कृपया भुगतान पूरा करें।",
    },
    ta: {
      subject: "கட்டண நினைவூட்டல்",
      body:
        "அன்புள்ள பெற்றோரே, {{studentName}}-க்கான {{amount}} கட்டணம் {{dueDate}}-க்குள் செலுத்த வேண்டும். தயவுசெய்து செலுத்துங்கள்.",
    },
    kn: {
      subject: "ಶುಲ್ಕ ಜ್ಞಾಪನೆ",
      body:
        "ಆತ್ಮೀಯ ಪೋಷಕರೇ, {{studentName}} ಗಾಗಿ {{amount}} ಶುಲ್ಕವನ್ನು {{dueDate}} ರೊಳಗೆ ಪಾವತಿಸಬೇಕು. ದಯವಿಟ್ಟು ಪಾವತಿ ಪೂರ್ಣಗೊಳಿಸಿ.",
    },
    ml: {
      subject: "ഫീസ് ഓർമ്മപ്പെടുത്തൽ",
      body:
        "പ്രിയ രക്ഷിതാവേ, {{studentName}}-നായി {{amount}} ഫീസ് {{dueDate}}-നകം അടയ്ക്കണം. ദയവായി പേയ്മെന്റ് പൂർത്തിയാക്കുക.",
    },
    ur: {
      subject: "فیس یاد دہانی",
      body:
        "محترم والدین، {{studentName}} کے لیے {{amount}} فیس {{dueDate}} تک واجب الادا ہے۔ براہ کرم ادائیگی مکمل کریں۔",
    },
  },
  exam_results_published: {
    en: {
      subject: "Exam Results Published",
      body:
        "Dear Parent, the {{examName}} results for {{studentName}} have been published. Please view them in the app.",
    },
    te: {
      subject: "పరీక్ష ఫలితాలు ప్రచురించబడ్డాయి",
      body:
        "ప్రియమైన తల్లిదండ్రులారా, {{studentName}} యొక్క {{examName}} ఫలితాలు ప్రచురించబడ్డాయి. దయచేసి యాప్‌లో చూడండి.",
    },
    hi: {
      subject: "परीक्षा परिणाम प्रकाशित",
      body:
        "प्रिय अभिभावक, {{studentName}} के {{examName}} परिणाम प्रकाशित हो गए हैं। कृपया ऐप में देखें।",
    },
    ta: {
      subject: "தேர்வு முடிவுகள் வெளியிடப்பட்டன",
      body:
        "அன்புள்ள பெற்றோரே, {{studentName}}-இன் {{examName}} முடிவுகள் வெளியிடப்பட்டன. செயலியில் பார்க்கவும்.",
    },
    kn: {
      subject: "ಪರೀಕ್ಷಾ ಫಲಿತಾಂಶ ಪ್ರಕಟ",
      body:
        "ಆತ್ಮೀಯ ಪೋಷಕರೇ, {{studentName}} ಅವರ {{examName}} ಫಲಿತಾಂಶ ಪ್ರಕಟವಾಗಿದೆ. ದಯವಿಟ್ಟು ಆಪ್‌ನಲ್ಲಿ ನೋಡಿ.",
    },
    ml: {
      subject: "പരീക്ഷാ ഫലം പ്രസിദ്ധീകരിച്ചു",
      body:
        "പ്രിയ രക്ഷിതാവേ, {{studentName}}-ന്റെ {{examName}} ഫലം പ്രസിദ്ധീകരിച്ചു. ദയവായി ആപ്പിൽ കാണുക.",
    },
    ur: {
      subject: "امتحان کے نتائج شائع",
      body:
        "محترم والدین، {{studentName}} کے {{examName}} نتائج شائع ہو گئے ہیں۔ براہ کرم ایپ میں دیکھیں۔",
    },
  },
};

export interface LocalizedNotification {
  subject: string | null;
  body: string;
  /** The language actually used (the requested one, or "en" on fallback). */
  languageUsed: ParentLanguage;
}

/**
 * Returns the localized subject/body for a parent-facing template, with
 * placeholders substituted. Returns `null` when the code has no catalog entry —
 * the caller then renders the existing English DB template (staff/teacher comms
 * and any non-catalogued parent comms are unaffected). Never calls an LLM.
 */
export function localizeNotification(
  code: string,
  language: string | null | undefined,
  variables: Record<string, string>,
): LocalizedNotification | null {
  const entry = CATALOG[code];
  if (!entry) return null;
  const requested = normalizeParentLanguage(language);
  const variant = entry[requested] ?? entry.en;
  if (!variant) return null;
  const languageUsed: ParentLanguage = entry[requested] ? requested : "en";
  return {
    subject: variant.subject ? renderTemplate(variant.subject, variables) : null,
    body: renderTemplate(variant.body, variables),
    languageUsed,
  };
}

/** Whether a template code has any parent-facing localized variant. */
export function hasLocalizedTemplate(code: string): boolean {
  return code in CATALOG;
}
