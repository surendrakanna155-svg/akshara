# Resource Storage Policy (LOCKED)

**Effective:** 2026-07-09  
**Status:** Mandatory for all future development  
**Scope:** JEE / NEET Intelligence Platform — all downloaded learning assets

---

## Principle

All downloaded learning resources are **LOCAL DEVELOPMENT ASSETS ONLY**.

They exist to fuel internal parsing, metadata extraction, concept extraction, and knowledge graph generation. They are **never** part of the production runtime and **never** enter version control.

---

## Covered resources (non-exhaustive)

- NCERT textbooks
- JEE Main / JEE Advanced previous year papers
- NEET / AIPMT / AIIMS previous year papers
- NTA sample papers
- DPPs, question banks, mock tests, chapter tests
- Formula sheets, revision material
- Any other downloaded educational PDFs, zips, or binaries

---

## Rules

1. **Never commit** these resources to Git.
2. **Never push** these resources to GitHub or any remote repository.
3. **All resource folders** are listed in `curriculum/.gitignore` (and mirrored in root `.gitignore`).
4. Resources exist **only on the local development machine**.
5. Used **only** for internal research: parsing → metadata → concepts → knowledge graph.
6. **Production must never depend** on raw source files on disk.
7. After the Knowledge Base, metadata, concept graph, and intelligence database are generated and verified, raw resources **may be archived or permanently removed** locally.
8. **Only our own generated artifacts** may be committed:
   - Metadata JSON (derived, non-copyright)
   - Knowledge graph exports
   - Concept database schemas / seeds (original)
   - Parsed structured data (extracted, original representation)
   - Generated questions (original)
   - AI model weights (if owned/licensed)
   - Verification and processing reports
   - Source code, tests, configs, manifests
9. **Under no circumstances** include copyrighted source documents in the project repository.

---

## Local paths (gitignored)

| Path | Purpose |
|------|---------|
| `curriculum/resources/foundation/` | JEE/NEET/NCERT STEM fuel |
| `curriculum/resources/archive/` | Archived non-STEM + duplicates |
| `curriculum/resources/curriculum/` | Legacy board acquisition (out of scope) |
| `curriculum/downloads/` | Download staging |
| `curriculum/cache/` | URL/search cache |
| `curriculum/archives/` | Deprecated local copies |
| `curriculum/knowledge/` | Derived knowledge (local until commit decision) |
| `curriculum/acquisition/*.log` | Download runtime logs |

---

## What MAY be committed

- `curriculum/configs/` — rules, schemas, paths
- `curriculum/scripts/` — acquisition, parsing, verification code
- `curriculum/discovery/` — source catalogues (URLs, not PDFs)
- `docs/curriculum-intelligence/` — specs, reports, this policy
- Derived manifests with **hashes and URLs only** (no binary payloads)
- Test fixtures that are **original, minimal, and owned** (not full NCERT/PYQ copies)

---

## Enforcement

- `.gitignore` guards are the first line of defense.
- Before any commit touching `curriculum/`, verify: `git status` shows **no** PDF/zip/ecar under `resources/`.
- CI should fail if copyrighted binaries are staged (future gate).
- Agents and developers must treat this policy as **non-negotiable**.

---

## Related documents

- `docs/curriculum-intelligence/README.md` — D-2 local-storage lock
- `docs/curriculum-intelligence/planning/CONTENT_DEPENDENCY_MAP.md` §6
- `curriculum/resources/foundation/INDEX.md` — local layout only (gitignored)
