-- AI Copilot — widen assistant_type CHECK to match copilot_types.ts.
--
-- The original ai_copilot migration (20260614950000) only allowed 5 assistant
-- types. The code (supabase/functions/_shared/copilot/copilot_types.ts) later
-- added parentGuidance / teacher / principal, but no migration updated the DB
-- CHECK constraint — so creating a session for any of the 3 new types failed with
-- "violates check constraint ai_copilot_sessions_assistant_type_check" (HTTP 500).
-- The Deno tests use a constraint-free fake DB, so this was never caught until
-- live AI verification. Additive + idempotent.

ALTER TABLE ai_copilot_sessions
  DROP CONSTRAINT IF EXISTS ai_copilot_sessions_assistant_type_check;

ALTER TABLE ai_copilot_sessions
  ADD CONSTRAINT ai_copilot_sessions_assistant_type_check
    CHECK (assistant_type IN (
      'admissions', 'finance', 'sis', 'academic', 'communication',
      'parentGuidance', 'teacher', 'principal'
    ));
