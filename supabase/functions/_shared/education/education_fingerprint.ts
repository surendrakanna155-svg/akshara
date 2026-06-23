// Deterministic content fingerprint for question-bank dedup.
//
// A stable hash over the normalized identity of a question (subject + chapter +
// type + the question text). Used to detect duplicate imports and to stop the
// blueprint solver from placing the same question twice in one paper. Not a
// security primitive — just a collision-resistant-enough dedup key (FNV-1a/32),
// computed synchronously with no dependencies.

function normalizeText(value: string): string {
  return value
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/[^\p{L}\p{N} ]/gu, "")
    .trim();
}

/** FNV-1a 32-bit hash, returned as zero-padded hex. */
function fnv1a(input: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    // 32-bit FNV prime multiply via shifts, kept in unsigned range.
    hash = (hash + ((hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24))) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}

export function computeQuestionFingerprint(parts: {
  subjectName: string;
  chapter: string;
  questionType: string;
  questionText: string;
}): string {
  const canonical = [
    normalizeText(parts.subjectName),
    normalizeText(parts.chapter),
    parts.questionType.trim().toLowerCase(),
    normalizeText(parts.questionText),
  ].join("|");
  return fnv1a(canonical);
}
