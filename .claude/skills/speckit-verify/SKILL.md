---
name: "speckit-verify"
description: "Run the project's verification gate end to end: full test suite, contract coverage against the OpenAPI document, seed-pipeline assertions, requirement-to-test traceability, and the simulation-boundary scan. Report findings, never silently pass."
argument-hint: "Optional: a layer name (unit, contract, integration, client, seed, traceability) to run only that layer"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "dupermarket"
  source: "project-specific — not part of upstream spec-kit"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

If the input names a layer, run only that layer and report on it. If it is empty, run every
layer in order.

## Purpose

This is the **verification gate** named in `.specify/memory/constitution.md` under
*Development Workflow and Quality Gates*. It runs after `/speckit-implement` and is the last
gate before work is considered done.

It is not a test runner wrapper. Running tests tells you the tests that exist pass. This gate
also asks whether the *right* tests exist — whether every requirement is covered, whether every
API operation is exercised, and whether the constitution's non-negotiables still hold. Those are
the failures a green suite hides.

## Scope Guard

- This command **verifies**. It MUST NOT modify application source, tests, specs, or the
  constitution to make a check pass.
- If a check fails, report it. Do not fix it in the same run — a gate that repairs its own
  input is not a gate.
- The one permitted write is the report file described under Reporting.
- If the user asks for fixes, finish the full verification run first, report, and then ask
  whether to proceed with fixes as a separate step.

## Execution Flow

Resolve the feature directory from `.specify/feature.json` (fall back to the highest-numbered
directory under `specs/`). Read `spec.md`, `plan.md`, `tasks.md`, and
`contracts/openapi.yaml` before running anything — the layers below are checked *against* those
documents, so a stale reading produces a meaningless report.

Run the layers in order. **Do not stop at the first failure.** Run every layer, collect every
finding, and report once — a developer fixing three things wants to know about all three now.
Mark a layer `BLOCKED` only when a genuine prerequisite failed (no database, no dependencies
installed) and say what would unblock it.

### Layer 1 — Static and structural

1. Validate the contract document:
   `uvx --from openapi-spec-validator openapi-spec-validator <feature-dir>/contracts/openapi.yaml`
2. Lint where source exists: `uvx ruff check backend seed`, `(cd mobile && flutter analyze)`.
3. Confirm every task in `tasks.md` marked `[x]` names a file path that exists. A completed
   task pointing at a missing file is either a lie or a stale path.

### Layer 2 — Unit

```bash
cd backend && uv run pytest tests/unit -q
```

The client's host-side tests all run together in Layer 5 — `mobile/test/` holds unit, widget,
and golden tests under one root, so there is no separate client unit command. Never pass a path
list to `flutter test`: paths drift, and a mistyped one reports "no tests ran" as success.

Report the count, and separately report anything **skipped** — a skip is an untested
requirement wearing a green tick.

### Layer 3 — Contract

```bash
cd backend && uv run pytest tests/contract -q
```

Then check contract *coverage*, which is the part a test run will not tell you:

- Enumerate every operation in `contracts/openapi.yaml` (path × method).
- For each, confirm a contract test references it.
- For each operation that is not declared public (`security: []`), confirm a test asserts the
  anonymous case returns 401, and — where the resource is user-owned — that another user's
  request returns **404, not 403** (FR-013, FR-032).
- Report any operation missing any of these as a finding, one line each.

If a live server is available, also run the property-based pass:

```bash
uv run schemathesis run <feature-dir>/contracts/openapi.yaml --url <base-url> --checks all
```

### Layer 4 — Integration

```bash
cd backend && uv run pytest tests/integration -q
```

Then confirm each user story in `spec.md` has an integration module that can run alone:

```bash
uv run pytest tests/integration/test_us3_checkout.py -q
```

A story whose test only passes as part of the full suite is not independently testable, which is
what its "Independent Test" line claims. Report that as a finding.

### Layer 5 — Client

```bash
cd mobile && flutter analyze
cd mobile && flutter test          # all host-side tests: unit, widget, goldens
```

`mobile/test/` mirrors `mobile/lib/` one directory per area and holds everything the Dart VM
can run. `mobile/integration_test/` holds only what needs a device — one driver per user story,
plus `integration_test/perf/`. Run those when a device or emulator is attached, and report them
as BLOCKED rather than passed when one is not:

```bash
cd mobile && flutter test integration_test/ -d <device>
```

Golden tests specifically: confirm the matrix covers three layouts (phone portrait, tablet
portrait, tablet landscape) at both 1.0× and 2.0× text scale. Report any missing combination.
If goldens were regenerated in the same change as a layout edit, say so — a golden that updated
silently proves nothing.

### Layer 6 — Seed pipeline

```bash
cd seed && uv run pytest tests -q
cd seed && uv run python -m dupermarket_seed.verify
```

`verify.py` asserts every product has at least one image and every stored CDN path resolves
(FR-074). If a seeded database is available, also run the seed twice and confirm the second run
reports zero rows changed and zero uploads (FR-072, SC-012).

### Layer 7 — Traceability and simulation boundary

```bash
python3 scripts/check_traceability.py
```

Three checks: every `FR-xxx` has a task, every `FR-xxx` has a test, and no card-shaped literal,
card field name, or payment-processor import exists outside the single allowlisted demo-card
file. The middle check is bootstrap-aware and activates once product source exists; pass
`--strict` to enforce it unconditionally.

Report the coverage figure explicitly even when it passes. "76/76 requirements covered" is
information; "traceability: PASS" is not.

### Layer 8 — Constitution re-check

Re-evaluate the Constitution Check table in `plan.md` against what was actually built, not
against what the plan said would be built. For each principle, one line: PASS, or FAIL with the
file and line that violates it. Pay particular attention to the ones that erode quietly:

- **I. Simulation Boundary** — covered mechanically by Layer 7, but also read any new
  checkout code by eye.
- **III. Determinism** — grep for `datetime.now()`, `DateTime.now()`, `random.` without a seed,
  and `Math.random`. Each hit outside the injection points is a finding.
- **V. Single Seam** — confirm currency conversion, geocoding, and route provision each still
  have exactly one call site cluster. A second conversion helper is the failure mode.
- **VI. Offline-First** — confirm checkout is still the only online-only path.

## Reporting

Write the report to `<feature-dir>/verification-report.md`, overwriting any previous run, and
summarise it in the response. Structure:

```markdown
# Verification Report

**Date**: YYYY-MM-DD | **Feature**: <name> | **Result**: PASS | FAIL

## Summary

| Layer | Result | Detail |
|---|---|---|
| 1. Static & structural | PASS | ... |
| ... | | |

## Findings

### CRITICAL
<constitution violations, unmapped requirements, uncovered operations>

### HIGH
<failing tests, skipped tests standing in for missing coverage>

### MEDIUM / LOW
<gaps that do not block, with the requirement each relates to>

## Coverage

- Requirements: N/M have a passing test
- API operations: N/M have a contract test
- User stories: N/M have an independently runnable integration module

## Not Verified

<Anything this run could not check, and what it would take to check it.>
```

Rules for the report:

- **Never report PASS with an unrunnable layer.** If the database was unavailable, the result
  is `BLOCKED`, and the overall result is not PASS.
- The `Not Verified` section is mandatory and MUST NOT be empty when anything was skipped,
  blocked, or out of reach. A verification report that hides its own blind spots is worse than
  no report.
- Quote the actual failing output for each finding. Do not paraphrase a stack trace.
- State counts, not adjectives.

## Done When

- [ ] Every layer ran, or is explicitly marked BLOCKED with a reason
- [ ] Report written to `<feature-dir>/verification-report.md`
- [ ] Every finding carries the file, the requirement, and the observed output
- [ ] `Not Verified` reflects reality
- [ ] Overall result stated plainly as PASS or FAIL, with no hedging
