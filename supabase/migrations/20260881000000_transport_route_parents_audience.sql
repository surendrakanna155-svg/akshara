-- BUS-002 — `route_parents` broadcast audience (transport delay/diversion alerts).
--
-- WHY: POST /transport/notify-delay carefully filtered allocations down to the
-- affected route, counted them into `recipientCount`, audited that count — and
-- then called sendBroadcastMessage with audience "parents", i.e. EVERY parent in
-- the school. A 10-minute delay on Route 8 pushed to parents of walkers and
-- car-drop children, while the API response and the audit trail both claimed it
-- reached only the 38 affected families.
--
-- Two separate defects: mis-targeting (alert fatigue → parents mute the app,
-- which also mutes fee reminders and exam notices) and an audit trail that did
-- not describe what actually happened.
--
-- This widens the audience CHECK with a dedicated `route_parents` token so a
-- transport cohort broadcast is stored HONESTLY — the broadcast row says what it
-- was, not "all_parents". Recipient resolution for this token is supplied
-- explicitly by the transport module (which owns allocations); communication
-- does not reach into transport's store. See BUS-107 for the permanent
-- route-cohort targeting infrastructure that replaces the interim path.
--
-- Same drop + re-add pattern as 20260838000000 (COM-2) and 20260851000000
-- (INV-7). Forward-only, idempotent, no tenant data touched.

ALTER TABLE comm_broadcasts DROP CONSTRAINT IF EXISTS comm_broadcasts_audience_check;
ALTER TABLE comm_broadcasts ADD CONSTRAINT comm_broadcasts_audience_check CHECK (
  audience IN (
    'all_parents', 'all_teachers', 'all_students', 'all_staff', 'school_wide',
    'class_parents', 'class_students', 'storekeepers', 'route_parents'
  )
);
