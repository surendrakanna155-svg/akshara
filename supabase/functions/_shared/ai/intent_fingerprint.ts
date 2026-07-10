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

// Relational / comparative / transitive markers whose OPERAND ORDER carries
// meaning (audit F1). When any is present, sorting the token bag would collide
// opposite-meaning questions — e.g. "is class 5 bigger than class 6?" vs the
// reverse, or "did the vendor pay the school?" vs "…the school pay the vendor?"
// — and serve a confidently-wrong cached answer. For these we preserve token
// order instead of sorting, so the two directions mint distinct cache keys.
// Detected on the RAW token stream (before stopword removal) so markers that
// are also stopwords ("than", "over", "under", "before", "after") still count.
const RELATIONAL_MARKERS = new Set([
  "more", "less", "fewer", "greater", "greatest", "higher", "highest",
  "lower", "lowest", "bigger", "biggest", "smaller", "smallest", "larger",
  "largest", "longer", "shorter", "better", "worse", "best", "worst",
  "faster", "slower", "than", "versus", "vs",
  "before", "after", "over", "under", "above", "below", "ahead", "behind",
  "pay", "pays", "paid", "owe", "owes", "owed", "beat", "beats",
  "exceed", "exceeds", "exceeded", "outperform", "outperforms", "outperformed",
  "compare", "compared", "difference", "gap", "between",
]);

/** Normalize free-text into a canonical fingerprint (design doc 03 §3.2).
 * Lowercase → strip punctuation → drop stopwords, then:
 *   • order-independent lookups → sort + de-dup so paraphrases collapse
 *     ("when is Aarav's fee due" ≈ "fee due for Aarav")
 *   • order-sensitive relational questions → preserve token order so operand
 *     swaps mint distinct keys (audit F1 — never serve a wrong cached answer).
 * Deterministic and idempotent; empty input yields "". */
export function fingerprintQuestion(text: string): string {
  const rawTokens = text
    .toLowerCase()
    .replace(/['’]s\b/gu, "") // possessive: "aarav's" → "aarav"
    .replace(/[^\p{L}\p{N}\s]/gu, " ") // drop punctuation (unicode-aware)
    .split(/\s+/)
    .filter((t) => t.length > 0);
  const orderSensitive = rawTokens.some((t) => RELATIONAL_MARKERS.has(t));
  const content = rawTokens.filter((t) => !STOPWORDS.has(t));
  if (orderSensitive) {
    // Preserve order + repeats: positional distinctness is the whole point.
    return content.join(" ");
  }
  // Sort so word-order paraphrases collapse; de-dup repeated tokens.
  return Array.from(new Set(content)).sort().join(" ");
}
