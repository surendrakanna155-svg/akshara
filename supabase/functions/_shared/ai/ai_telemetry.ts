// Adaptive AI — P3-AI-3 / P2-8: fail-closed telemetry for the AI plumbing.
//
// The gateway's governance philosophy is "never fail the user's request over
// an accounting problem" — but the audit found every such degradation was a
// bare `catch {}`: config unreadable, usage unreadable (limits silently seen
// as zero!), cache read/write failures, and even the ai_call_log INSERT
// itself could fail with no trace anywhere, so the cost panel undercounted
// and no operator could know. Every swallow now emits ONE structured line on
// stderr (the edge runtime's log stream) with a stable grep-able tag. Logging
// stays best-effort and must itself never throw.

const TAG = "ai_telemetry_failure";

/** Record that an AI-plumbing step degraded (was swallowed). `area` is a
 * stable machine key, e.g. "gateway.record" / "gateway.read_usage". */
export function logAiDegradation(
  area: string,
  detail: unknown,
  extra?: Record<string, string | number | boolean | null>,
): void {
  try {
    const message = detail instanceof Error ? detail.message : String(detail);
    console.error(JSON.stringify({ tag: TAG, area, message, ...extra }));
  } catch {
    // Logging must never become a second failure.
  }
}
