// Adaptive AI — P3-AI-2 / W2-GATE: the school-only Domain Gate (design doc 10 §3,
// owner-locked rule 6).
//
// The FIRST of the five AI firewall gates (doc 10 §2). Deterministic, ZERO
// tokens: it decides whether a free-text request is in the school domain BEFORE
// any context load and BEFORE the model gateway. Off-domain requests (politics,
// movies, sports, programming, medical advice, recipes, travel, general
// knowledge, creative writing…) are refused for free — they never reach the LLM.
//
// Calibration (doc 10 §3): the SCHOOL lexicon WINS TIES. A message carrying a
// clear school signal is in-domain even if a block word appears ("sports DAY
// attendance", "MOVIE permission slip", "MEDICAL leave"), so legitimate school
// phrasing is never wrongly rejected. The block lexicon only decides when there
// is NO school signal. A no-signal ambiguous message is allowed through (rare;
// still bounded by RBAC + the system prompt + the W1 output guard) rather than
// frustrating a legitimate short question.

/** The canned, localizable refusal served to off-domain requests (0 tokens). */
export const SCHOOL_ASSISTANT_REFUSAL =
  "I'm the Akshara School Assistant — I can only help with school activities " +
  "like attendance, homework, exams, fees, transport, and student progress.";

export interface DomainVerdict {
  inDomain: boolean;
  /** Why the gate decided this way (telemetry / debugging; never shown raw). */
  reason: "school_signal" | "off_domain" | "ambiguous_allowed" | "empty";
}

// Broad school-operations vocabulary. Presence of ANY term = a school signal.
// Word-boundary matched, so "class" ≠ "classical" and "exam" ≠ "example".
const SCHOOL_LEXICON: readonly string[] = [
  "school", "student", "students", "pupil", "teacher", "teachers", "staff",
  "principal", "parent", "parents", "guardian", "class", "classes", "classroom",
  "section", "sections", "grade", "grades", "subject", "subjects", "syllabus",
  "curriculum", "lesson", "chapter", "topic", "attendance", "absent", "present",
  "homework", "assignment", "assignments", "exam", "exams", "test", "marks",
  "mark", "score", "scores", "result", "results", "report card", "grading",
  "fee", "fees", "invoice", "invoices", "defaulter", "defaulters", "payment",
  "collection", "scholarship", "concession", "admission", "admissions",
  "enrollment", "enrol", "enroll", "roll number", "admission number",
  "timetable", "schedule", "period", "substitution", "substitute", "transport",
  "bus", "route", "driver", "vehicle", "library", "textbook", "overdue",
  "hostel", "inventory", "stock", "reorder", "complaint",
  "complaints", "discipline", "leave", "approval", "approvals", "circular",
  "notice", "ptm", "meeting", "event", "holiday", "term", "semester", "academic",
  "risk", "at-risk", "at risk", "dropout", "promotion", "promote", "certificate",
  "transfer certificate", "id card", "biometric", "sis", "erp", "campus",
  "headmaster", "coordinator", "warden", "counselor", "counsellor",
  // P2-4 hardening: common Indian school-operations vocabulary the first cut
  // missed — all unambiguous school terms (the allow side is safe to widen;
  // a false allow is still bounded by RBAC + system prompt + output guard).
  "tuition", "marksheet", "hall ticket", "question paper", "answer sheet",
  "unit test", "worksheet", "revision", "assembly", "sports day", "annual day",
  "payroll", "payslip", "salary", "invigilator", "staffroom", "uniform",
  "prefect", "house points", "school diary", "pickup point",
];

// Off-domain categories (owner's list + general-knowledge / creative-writing).
// Only consulted when there is NO school signal.
const BLOCK_LEXICON: readonly string[] = [
  // politics
  "politics", "election", "elections", "minister", "president", "parliament",
  "government policy", "vote", "voting", "democrat", "republican",
  // movies / entertainment
  "movie", "movies", "film", "films", "cinema", "actor", "actress", "netflix",
  "song", "songs", "music album", "celebrity", "bollywood", "hollywood",
  // sports (as spectator content)
  "cricket", "football", "soccer", "ipl", "match score", "world cup",
  "tournament score", "nba", "fifa", "olympics medal",
  // programming
  "python", "javascript", "java code", "programming", "algorithm", "function code",
  "compile", "regex", "html", "css", "sql query for", "write code", "debug my code",
  // medical advice
  "symptom", "symptoms", "diagnosis", "diagnose", "prescription", "medicine for",
  "disease", "treatment for", "cure for", "dosage",
  // recipes / cooking
  "recipe", "recipes", "cook", "cooking", "ingredient", "ingredients", "biryani",
  // travel
  "flight", "flights", "hotel booking", "tourist", "visa", "itinerary", "airport",
  // finance-markets / crypto
  "stock market", "share price", "crypto", "bitcoin", "forex",
  // general knowledge / creative writing
  "capital of", "translate", "meaning of life", "who won", "weather forecast",
  "write me a poem", "write a story", "write an essay", "tell me a joke",
  "quantum physics", "history of the world", "population of",
  // P2-4 hardening: further off-domain categories seen in copilot abuse tests
  "gambling", "betting", "lottery", "horoscope", "astrology", "dating",
  "girlfriend", "boyfriend", "song lyrics", "video game", "gaming",
];

/** P2-4: deployment-tunable lexicon extensions — comma-separated terms in
 * `AI_DOMAIN_ALLOW_TERMS` / `AI_DOMAIN_BLOCK_TERMS`. Lets the pilot widen
 * either list without a code change while staying fully deterministic. Terms
 * under 3 chars are ignored (an accidental "a" must never open the gate). */
function envTerms(name: string): string[] {
  const raw = Deno.env.get(name) ?? "";
  if (raw.trim().length === 0) return [];
  return raw
    .split(",")
    .map((t) => t.trim().toLowerCase())
    .filter((t) => t.length >= 3);
}

function hasTerm(haystack: string, terms: readonly string[]): boolean {
  for (const term of terms) {
    // Word-boundary match for single tokens; substring for multi-word phrases.
    if (term.includes(" ")) {
      if (haystack.includes(term)) return true;
    } else {
      const re = new RegExp(`\\b${term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`);
      if (re.test(haystack)) return true;
    }
  }
  return false;
}

/**
 * Classify a free-text message as in- or out-of the school domain.
 * Deterministic and side-effect-free. Empty input is treated as in-domain
 * (validated separately upstream).
 */
export function classifyDomain(message: string): DomainVerdict {
  const text = (message ?? "").toLowerCase().trim();
  if (text.length === 0) return { inDomain: true, reason: "empty" };

  // The school lexicon (built-in + deployment extension) WINS TIES — checked
  // first, so legitimate school phrasing is never rejected by a block term.
  if (hasTerm(text, SCHOOL_LEXICON) || hasTerm(text, envTerms("AI_DOMAIN_ALLOW_TERMS"))) {
    return { inDomain: true, reason: "school_signal" };
  }
  if (hasTerm(text, BLOCK_LEXICON) || hasTerm(text, envTerms("AI_DOMAIN_BLOCK_TERMS"))) {
    return { inDomain: false, reason: "off_domain" };
  }
  // No school signal, no clear off-domain signal → allow (rare, and still
  // bounded by RBAC + the school-scoped system prompt + the W1 output guard).
  return { inDomain: true, reason: "ambiguous_allowed" };
}
