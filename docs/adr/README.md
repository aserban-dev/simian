# Architecture decision records

- **Written by:** Loredan (Architect) at stage 4, and by any agent whose story makes or changes an architecture decision
- **Index maintained by:** Aglaia (Knowledge Keeper) (`docs/standards/documentation.md` D-2)

## Rules

- One decision per file: `NNNN-<slug>.md`, numbered in order, starting from a copy of [`0000-template.md`](0000-template.md).
- Never delete an ADR or reuse a number. When a decision changes, write a new ADR and set the old one's Status to `Superseded by NNNN`.
- Add every new ADR to the index below in the same change.

## Index

ADRs 0001–0025 below were inherited from price-checker with the agent factory (`docs/agent-team-reuse.md`). They record how Zamolxe (Orchestrator), the gates and CI work, and keep their numbers because the code and prompts cite them. Numbers missing from the list were price-checker product decisions and were not copied. **simian's own ADRs start at 0027.**

| # | Title | Status | Date |
|---|---|---|---|
| [0001](0001-orchestrator-functional-core.md) | Build Zamolxe (Orchestrator) as a functional-core Python CLI that drives headless `claude -p` | Accepted | 2026-11-16 |
| [0002](0002-orchestrator-run-state-and-resume.md) | Keep run state in a single-writer `state.json`, and resume by resetting to the scope's last passed head | Accepted | 2026-11-16 |
| [0003](0003-orchestrator-git-integration.md) | Integrate only through merged PRs, and let the orchestrator own the shared bookkeeping files | Accepted | 2026-11-16 |
| [0004](0004-gate-commands-in-agents-md.md) | Declare gate commands in an `sdlc-commands` block in `AGENTS.md`, trusted only as it is on `origin/main` | Accepted | 2026-11-16 |
| [0005](0005-orchestrator-subscription-limits-and-budget.md) | Run on the subscription: pause on plan limits, wait on budget reservations, refuse per-token credentials | Accepted | 2026-11-17 |
| [0019](0019-orchestrator-usage-ledger-per-agent.md) | Measure every agent step's usage in a ledger derived from the run state, with optional OpenTelemetry export | Accepted | 2026-11-17 |
| [0021](0021-gate-commands-change-only-by-owner-pr.md) | Restore the gate-command block on every agent branch, so gate commands change only through an owner PR | Accepted | 2026-11-18 |
| [0022](0022-factory-changes-by-proposal-and-issue.md) | Agents propose factory changes and build them from owner issues; the owner only reviews and merges | Accepted | 2026-11-18 |
| [0023](0023-gate-block-compared-at-branch-point.md) | Compare the gate block with the story's branch point on main, not with today's main | Accepted | 2026-11-18 |
| [0024](0024-ci-secret-and-vulnerability-scanners.md) | Scan each event's commit range with gitleaks and runtime dependencies with Trivy, both pinned binaries with a canary | Proposed | 2026-11-18 |
| [0025](0025-model-and-effort-per-step.md) | Let a step set its own model, effort and max turns, so read-only reviewers can run cheaper than the developer | Proposed | 2026-11-18 |
