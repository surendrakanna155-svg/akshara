# Verified Gaps (Web Track)

The Unified Web Platform is a **continuous ERP verification layer** (owner-locked).
Any gap discovered while building a page — Bug / Missing Feature / Architecture / UX /
API / Security / Performance / Validation / RBAC / Report / Data Contract / Audit /
Integration — is recorded, classified, prioritized, and synced to the ERP roadmap.

➡ **Canonical register:** [`docs/roadmap/WEB_TRACK_BACKEND_GAPS.md`](../docs/roadmap/WEB_TRACK_BACKEND_GAPS.md)

Rule: never hide a gap behind fake data or a silent workaround. Build the surrounding
UI, disable only the blocked interaction (honest state), log the gap, wire fully once
the backend/feature lands.

Open (as of last build): **WEB-001** (API · P1 · school overview aggregation) ·
**WEB-002** (Performance · P2 · 4.6 MB icon font → subset).
