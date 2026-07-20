// PRC-A Batch 6 — Communication Channel Orchestrator: escalation policy.
//
// Pure, deterministic fallback logic, kept free of DB/IO so it can be unit-tested
// exhaustively. The drain (processDeliveryQueue) consults this when a delivery
// fails TERMINALLY to decide whether — and to which channel — to escalate.

import type { NotificationChannel } from "./notification_provider_config.ts";

export const KNOWN_CHANNELS: readonly NotificationChannel[] = [
  "sms",
  "email",
  "push",
  "whatsapp",
];

/** A per-school ordered escalation chain (as stored in
 * communication_channel_policies). null = the school has no active policy, so
 * escalation is disabled and existing behaviour is preserved exactly. */
export interface ChannelPolicy {
  escalationChain: string[];
  isActive: boolean;
}

/**
 * Given a school's policy and a delivery that just failed terminally on
 * `failedChannel` at `currentDepth` hops from the primary send, return the next
 * channel to escalate to — or null when escalation must stop.
 *
 * Escalation follows the CHAIN POSITION of the failed channel (not the depth),
 * so a delivery that started mid-chain (e.g. a push enqueued directly while the
 * chain is [whatsapp, sms, push]) never escalates "backwards". `currentDepth`
 * is an independent hard bound: it can never exceed the chain length, so the
 * fallback sequence always terminates.
 *
 * Returns null when: no policy / inactive policy; chain absent or malformed; the
 * failed channel is not in the chain; the failed channel is the last link; or
 * the loop-guard depth has been reached.
 */
export function computeEscalationTarget(
  policy: ChannelPolicy | null,
  failedChannel: string,
  currentDepth: number,
): string | null {
  if (!policy || !policy.isActive) return null;
  const chain = policy.escalationChain;
  if (!Array.isArray(chain) || chain.length < 2) return null;

  // Loop guard: total hops can never reach the number of links in the chain.
  if (currentDepth >= chain.length - 1) return null;

  const idx = chain.indexOf(failedChannel);
  if (idx === -1 || idx >= chain.length - 1) return null;

  const next = chain[idx + 1];
  // Defensive: never escalate to an unknown channel (the DB CHECK already keeps
  // the chain within vocabulary, but the drain must never enqueue an un-routable
  // delivery even if a row slipped past).
  if (!KNOWN_CHANNELS.includes(next as NotificationChannel)) return null;
  return next;
}

/**
 * Validate a proposed escalation chain before it is persisted. A chain must be
 * non-empty, contain only known channels, and have no duplicates (a repeated
 * channel would make the position-based escalation ambiguous). Returns an error
 * string, or null when the chain is valid.
 */
export function validateEscalationChain(chain: unknown): string | null {
  if (!Array.isArray(chain) || chain.length === 0) {
    return "escalationChain must be a non-empty array of channels";
  }
  const seen = new Set<string>();
  for (const ch of chain) {
    if (typeof ch !== "string" || !KNOWN_CHANNELS.includes(ch as NotificationChannel)) {
      return `escalationChain contains an unknown channel: ${String(ch)}`;
    }
    if (seen.has(ch)) {
      return `escalationChain contains a duplicate channel: ${ch}`;
    }
    seen.add(ch);
  }
  return null;
}
