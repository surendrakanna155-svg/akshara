// Adaptive AI — P3-AI-1 / W1.5: intent fingerprint (Stage-1 semantic cache).
//
// Deterministic question normalization so paraphrases collapse to one cache key
// (design doc 03 §3.2) — "when is Aarav's fee due" ≈ "fee due for Aarav?" —
// with zero embeddings/model calls. Reuses the principal_query_service style of
// keyword-bucket intent detection, extended with stopword stripping + token
// sort. Used as the last-message component of the copilot cache key, so two
// phrasings of the same question over the same context share one generation.

// Small, conservative English stopword set — enough to fold common paraphrase
// scaffolding without touching entity words (names, "fee", "attendance").
const STOPWORDS = new Set([
  "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
  "do", "does", "did", "of", "for", "to", "in", "on", "at", "by", "with",
  "and", "or", "as", "so", "if", "then", "than", "that", "this", "these",
  "those", "it", "its", "i", "me", "my", "we", "us", "you", "your",
  "please", "kindly", "can", "could", "would", "will", "shall", "may",
  "what", "whats", "when", "whens", "who", "whos", "how", "why", "which",
  "show", "tell", "give", "list", "about", "any", "there", "here",
]);

/** Normalize free-text into a canonical fingerprint: lowercase → strip
 * punctuation → drop stopwords → sort remaining tokens → join. Deterministic
 * and idempotent; empty input yields "". */
export function fingerprintQuestion(text: string): string {
  const tokens = text
    .toLowerCase()
    .replace(/['’]s\b/gu, "") // possessive: "aarav's" → "aarav"
    .replace(/[^\p{L}\p{N}\s]/gu, " ") // drop punctuation (unicode-aware)
    .split(/\s+/)
    .filter((t) => t.length > 0 && !STOPWORDS.has(t));
  // Sort so word-order paraphrases collapse; de-dup repeated tokens.
  return Array.from(new Set(tokens)).sort().join(" ");
}
