# simian

Built by a BMAD agent team and Zamolxe (Orchestrator), copied from price-checker (`docs/agent-team-reuse.md`).

## Status

Factory set up; product not started. The spec template is `docs/initial-spec.md`.

## How to start a run

1. Fill in `docs/initial-spec.md` (every `TODO`) and the product decisions in `docs/automation-plan.md` §1. Merge them to `main`.
2. Check the factory:
   - `python3 .claude/hooks/test_guard.py`
   - `python3 scripts/apply-persona-names.py --check`
   - `cd orchestrator && uv run pytest -q && uv run sdlc run --dry-run`
3. Make sure `ANTHROPIC_API_KEY` is not set and "extra usage" credits are off on the Claude account.
4. In a separate terminal: `cd orchestrator && uv run sdlc run`. Watch it with `uv run sdlc status`.
5. **Stop after the planning PR (stage 5).** Once the product scaffold is on `main`, add its build, lint and test commands to the `sdlc-commands` block in `AGENTS.md` through your own PR, then `uv run sdlc resume <run-id>`.

## Your role during a run

| When | What you do |
|---|---|
| An external system is proposed | Review its row in `docs/source-register.md` and set `Status` to `Approved YYYY-MM-DD` by hand |
| After stage 6 | Run `terraform apply` yourself; agents only plan |
| An issue labelled `escalation` opens | Fix the input (spec, story, config or register), then `uv run sdlc resume <run-id>` |
| A PR labelled `owner-review` opens | Review and merge it; agents never merge factory changes |

Project instructions for agents: `AGENTS.md`. Standards: `docs/standards/`. Decisions: `docs/adr/`.
