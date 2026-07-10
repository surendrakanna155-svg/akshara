-- Adaptive AI — P3-AI-1 / W1-completion F3: output-guard telemetry outcome.
--
-- The Model Gateway now validates a model reply (output_guard.ts) before it is
-- served or cached; a reply that fails (un-provided URL, injection echo, a
-- ₹amount/percentage absent from the injected facts, or over length) is
-- discarded in favour of the caller's deterministic fallback. That discard is
-- recorded as a distinct outcome so the cost panel can surface how often a paid
-- call was guarded (the model WAS consulted — tokens/cost are still logged).
-- Additive: widens the existing CHECK; no row is touched.

ALTER TABLE ai_call_log DROP CONSTRAINT IF EXISTS ai_call_log_outcome_check;

ALTER TABLE ai_call_log ADD CONSTRAINT ai_call_log_outcome_check
  CHECK (outcome IN (
    'ok',
    'refused',
    'fallback_no_key',
    'fallback_rate_user',
    'fallback_rate_school',
    'fallback_spend_cap',
    'fallback_timeout',
    'fallback_error',
    'fallback_guard'
  ));
