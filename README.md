# dupermarket

A Temu-style mobile shopping application that **simulates** the full e-commerce experience.
Users browse a large catalogue, fill a basket, "pay" with built-in demo cards, and track a
simulated delivery on a map. No real money moves, no real cards are stored, no goods ship.

Built spec-first with [GitHub Spec Kit](https://github.com/github/spec-kit). Every decision
lives in a document before it lives in code.

## Where things are

| Path | What |
|---|---|
| `claude/01_INITIAL_SPECS.md` | The original product brief, the input to everything below |
| `.specify/memory/constitution.md` | Project constitution v1.0.0 — seven principles, two of them non-negotiable |
| `specs/001-shopping-app-simulator/` | The feature: spec, plan, research, data model, API contract, tasks, analysis |
| `.claude/skills/speckit-*/` | The spec-kit workflow skills, plus a project-specific `speckit-verify` |
| `scripts/check_traceability.py` | The verification gate: requirement coverage and the simulation boundary |
| `backend/`, `mobile/`, `seed/` | Application code — scaffolding today, filled in by `/speckit-implement` |

Start with [the spec](specs/001-shopping-app-simulator/spec.md), then
[the plan](specs/001-shopping-app-simulator/plan.md). Setup and test instructions are in
[quickstart.md](specs/001-shopping-app-simulator/quickstart.md).

## Workflow

```text
/speckit-constitution → /speckit-specify → /speckit-clarify → /speckit-plan
  → /speckit-tasks → /speckit-analyze → /speckit-implement → /speckit-verify
```

Each arrow is a gate defined in the constitution. The last one is project-specific: it runs the
whole test suite, checks contract coverage against the OpenAPI document, verifies every
requirement maps to a passing test, and scans for anything that would breach the simulation
boundary.

Status: everything through `/speckit-analyze` is done — zero critical findings, so
`/speckit-implement` is unblocked.

## Verification, today

The gate runs before the application exists, and reports honestly on what it cannot yet check:

```bash
python3 scripts/check_traceability.py                    # requirement coverage + Principle I
cd backend && uv run --with pytest --with pyyaml \
  --with openapi-spec-validator pytest tests -q          # contract tests, no server needed
cd mobile && flutter test                                # client harness
uvx --from openapi-spec-validator openapi-spec-validator \
  specs/001-shopping-app-simulator/contracts/openapi.yaml
```

The contract tests assert the properties that are cheapest to state and easiest to erode: no
payment field anywhere in the API, only catalogue reads are public, another user's resource
returns 404 rather than 403, order lines are snapshots, and money is never a float.

CI runs all of it on every push — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Two non-negotiables

**Simulation boundary.** The app never collects, transmits, or stores payment card data, and
never integrates a payment processor. This keeps the project outside PCI-DSS scope and outside
GDPR obligations for payment data — free to hold, expensive to reinstate. An automated scan
enforces it rather than trusting anyone to remember.

**Test-first.** Tests are written before the code they cover, and every functional requirement
is machine-checked to have one. The traceability gate is built in Phase 2, before any feature.
