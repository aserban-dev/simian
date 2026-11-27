# Compliance register

- **Maintained by:** Aglaia (Knowledge Keeper), from rows that Veronel (Security & Compliance) drafts at stage 7
- **Verified by:** Veronel (Security & Compliance) at stages 3, 4 and 7
- **Purpose:** link every compliance requirement to the control that enforces it and the evidence that the control works. If a row has no evidence by the end of the epic that introduces it, that epic is not done.

## Columns

- **Requirement:** where the obligation comes from.
- **Control:** the rule ID in `docs/standards/` and where it is enforced.
- **Evidence:** a test, a CI job, a file or a verdict that shows the control works. Use a path or a link, never prose alone.
- **Status:** `Planned` (no code yet) → `Implemented` (code merged) → `Verified` (evidence exists and passes). Use `Retired` for a requirement that no longer applies. Never delete a row.

## Register

Empty. Veronel (Security & Compliance) drafts the first rows at stage 3 (PRD), one per compliance requirement in the spec.

| ID | Requirement | Control | Enforced in | Evidence | Status |
|---|---|---|---|---|---|
