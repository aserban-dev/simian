# Source register

- **Owner:** Adrian (the only person who approves an external system)
- **Maintained by:** Aglaia (Knowledge Keeper), who changes facts only; rows drafted by Veronel (Security & Compliance)
- **Read by:** the guard hook (`.claude/hooks/guard.py`, rule G4), Zamolxe (Orchestrator) when it decides whether a story may run, Veronel (Security & Compliance) at stages 3, 4 and 7, and the app's integration config
- **Sources:** `docs/initial-spec.md`, and the PRD and architecture once they exist

Not legal advice. This register records what was checked, when, and who decided.

An **external system** is anything the product calls at runtime that the team does not own: a third-party API, a website, a SaaS, a payment or identity provider, a maps or AI service. Build-time tools (package registries, GitHub, CI) are not listed here.

## How an external system gets approved

1. Veronel (Security & Compliance) or Claude checks the system's terms of use, pricing and quotas, authentication model, and data-protection terms. Each fact is marked [V] (read at the source), [S] (search snippet) or [?] (not confirmed).
2. If every check passes, the row's Status becomes `Proposed`. Otherwise it stays `Not checked`, or becomes `Rejected` with a reason.
3. **Only the owner** changes Status to `Approved YYYY-MM-DD`, by editing this file by hand. Agents are blocked from doing it (guard rule G5, `security-compliance.md` S-1).
4. Until a row says `Approved`, every network call to that domain from an agent session is blocked (guard rule G4), and stories that list it in `sources` stay blocked. The app must not call it either (S-1).
5. To stop using a system, set Status to `Retired YYYY-MM-DD` and turn on its kill switch (S-8). Never delete a row.

| Status | Meaning |
|---|---|
| `Not checked` | No complete check yet. Blocked |
| `Proposed` | All checks passed; waiting for the owner. Blocked |
| `Approved YYYY-MM-DD` | The owner approved it. Code may call it |
| `Rejected` | Fails a check; the reason is in Notes. Blocked |
| `Retired YYYY-MM-DD` | Was approved, no longer used. Blocked |

## External systems

The guard and the orchestrator read the `Domain` and `Status` columns. Keep one domain per row, with no scheme and no `www.`. Fill `Limits` (for example `60/min, 2 concurrent`) for every system the product calls at runtime (S-3).

| System | Domain | Status | Purpose | Terms | Auth | Personal data sent | Limits | Checked | Notes |
|---|---|---|---|---|---|---|---|---|---|
