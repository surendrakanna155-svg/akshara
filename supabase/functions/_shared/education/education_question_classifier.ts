// CI-C4-schema (Curriculum Intelligence) — Tier-1 rule-first classification
// assist (IMPLEMENTATION_SEQUENCE.md CI-C4: "Tier-1 classification assist
// (rule-first, AI-suggest, teacher-confirm — D3 doctrine)"; ACCEPTANCE_TEST_PLAN
// AT-C4.1: "Tagging assist proposes outcome/competency for a bank item
// (rule-first); teacher confirm persists; unconfirmed suggestions never affect
// generation").
//
// Pure, deterministic, ZERO AI, ZERO network, ZERO DB access, ZERO side effects.
// Given a bank item's OWN fields (subject, chapter, topic, cognitive level,
// question text), it SUGGESTS a competency descriptor and a learning-outcome
// phrase for a teacher to review, edit, or discard. It composes only facts
// already present on the item — chapter/topic/subject text is carried through
// verbatim, never invented (D3 "never fabricate" / invariant I4) — and every
// suggestion is explicitly low/medium confidence with the matched signals
// attached, never "certain": Tier-1 is a starting draft, not an authority.
//
// This module NEVER writes to the bank. A caller persists a suggestion (as-is
// or teacher-edited) only by explicitly passing it to `updateQuestionBankItem`
// (`competency` / `learningOutcome` fields, CI-C4-schema migration
// 20260857000000) — exactly the same "candidate only, human confirms" contract
// already certified for AI gap-fill (`education_ai_question_gapfill.ts`,
// invariant I3). An unconfirmed suggestion sitting in a caller's hand can never
// affect paper generation: the solver only ever reads columns that were
// actually persisted (AT-C4.1).
//
// Rule signals (exactly the three named in IMPLEMENTATION_SEQUENCE CI-C4 —
// "keywords/chapter/Bloom"):
//   1. `cognitiveLevel` (Bloom), when the item already carries one.
//   2. Else, a deterministic keyword scan of `questionText` against a fixed
//      Bloom-verb vocabulary (define/list/state → remember; explain/describe →
//      understand; calculate/solve/find → apply; compare/differentiate →
//      analyze; justify/evaluate/design → hots). First (most specific) match
//      wins; checked from `hots` down to `remember` so a richer verb ("justify
//      and calculate") is not swallowed by a more generic one.
//   3. `chapter` + `topic` (verbatim) are composed into the phrase text.
// With no Bloom signal at all, the classifier still returns a suggestion (never
// silently nothing) but pins it to the lowest confidence band and names the
// fallback in `signals` so a teacher knows to tag Bloom level directly.

import type { EduCognitiveLevel } from "./education_types.ts";

export interface ClassificationInput {
  subjectName: string;
  chapter: string;
  topic?: string | null;
  questionText: string;
  /** Bloom level already recorded on the item, if any (preferred signal). */
  cognitiveLevel?: EduCognitiveLevel | null;
}

export type ClassificationConfidence = "low" | "medium";

export interface ClassificationSuggestion {
  /** Draft competency descriptor — teacher reviews/edits before it is saved. */
  suggestedCompetency: string;
  /** Draft learning-outcome phrase — teacher reviews/edits before it is saved. */
  suggestedLearningOutcome: string;
  /** The Bloom level the suggestion was built from (explicit or inferred). */
  inferredCognitiveLevel: EduCognitiveLevel | null;
  /** Never "high"/"certain" — Tier-1 rule-first output is a draft, not fact. */
  confidence: ClassificationConfidence;
  /** Human-readable trace of which rule signals produced this suggestion. */
  signals: string[];
}

const BLOOM_PHRASING: Record<EduCognitiveLevel, { competencyVerb: string; outcomeVerb: string }> = {
  remember: { competencyVerb: "Recall and identify", outcomeVerb: "recall" },
  understand: { competencyVerb: "Explain and interpret", outcomeVerb: "explain" },
  apply: { competencyVerb: "Apply and solve problems using", outcomeVerb: "apply" },
  analyze: { competencyVerb: "Analyze and differentiate", outcomeVerb: "analyze" },
  hots: {
    competencyVerb: "Evaluate, justify and synthesize (higher-order thinking on)",
    outcomeVerb: "critically evaluate",
  },
};

// Checked in this order (most-specific/highest Bloom level first) so a question
// text that matches more than one bucket resolves to the deeper cognitive
// demand rather than a shallower one.
const KEYWORD_BLOOM: Array<{ level: EduCognitiveLevel; keywords: string[] }> = [
  {
    level: "hots",
    keywords: ["justify", "evaluate", "critique", "design", "predict", "assess", "formulate", "argue"],
  },
  {
    level: "analyze",
    keywords: ["compare", "differentiate", "classify", "analyze", "analyse", "distinguish", "contrast"],
  },
  {
    level: "apply",
    keywords: ["calculate", "solve", "find", "construct", "determine", "compute", "derive", "apply"],
  },
  {
    level: "understand",
    keywords: ["explain", "describe", "summarize", "summarise", "illustrate", "interpret", "outline"],
  },
  {
    level: "remember",
    keywords: ["define", "list", "state", "name", "label", "identify", "recall"],
  },
];

/** Deterministic keyword scan; returns the level + matched keyword, or null. */
function inferBloomFromText(questionText: string): { level: EduCognitiveLevel; keyword: string } | null {
  const lower = questionText.toLowerCase();
  for (const bucket of KEYWORD_BLOOM) {
    for (const keyword of bucket.keywords) {
      // Word-boundary match so e.g. "identify" doesn't match inside "identifying"
      // differently across calls — deterministic, locale-free.
      const re = new RegExp(`\\b${keyword}\\b`);
      if (re.test(lower)) {
        return { level: bucket.level, keyword };
      }
    }
  }
  return null;
}

function topicLabel(input: ClassificationInput): string {
  const topic = input.topic?.trim();
  return topic && topic.length > 0 ? topic : input.chapter.trim();
}

/**
 * Suggest a competency + learning-outcome tag for a bank item from rule
 * signals only. Pure — same input always yields the same output. Suggestion
 * only: callers must route the (possibly teacher-edited) result through
 * `updateQuestionBankItem` for it to ever take effect (AT-C4.1).
 */
export function suggestClassification(input: ClassificationInput): ClassificationSuggestion {
  const signals: string[] = [`chapter=${input.chapter}`];
  const topic = topicLabel(input);
  if (input.topic?.trim()) signals.push(`topic=${input.topic.trim()}`);

  let level: EduCognitiveLevel | null = null;
  let confidence: ClassificationConfidence = "low";

  if (input.cognitiveLevel) {
    level = input.cognitiveLevel;
    confidence = "medium";
    signals.push(`cognitive_level=${input.cognitiveLevel}`);
  } else {
    const inferred = inferBloomFromText(input.questionText);
    if (inferred) {
      level = inferred.level;
      confidence = "medium";
      signals.push(`keyword_match=${inferred.keyword}`, `inferred_cognitive_level=${inferred.level}`);
    } else {
      // No signal at all: fall back to the most common exam Bloom level
      // ("understand") but keep confidence low and say so explicitly, so a
      // teacher knows this one needs a direct Bloom tag, not just a glance.
      level = "understand";
      confidence = "low";
      signals.push("no_signal_default=understand");
    }
  }

  const { competencyVerb, outcomeVerb } = BLOOM_PHRASING[level];

  return {
    suggestedCompetency: `${competencyVerb} ${topic} (${input.chapter})`,
    suggestedLearningOutcome:
      `Student is able to ${outcomeVerb} ${topic} within ${input.chapter} (${input.subjectName}).`,
    inferredCognitiveLevel: level,
    confidence,
    signals,
  };
}
