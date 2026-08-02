# Specification Analysis Report

**Feature**: Shopping App Simulator | **Date**: 2026-08-02 | **Analysis gate**: **CLEARED**

Artifacts analysed: [constitution](../../.specify/memory/constitution.md) v1.1.1,
[spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/openapi.yaml](./contracts/openapi.yaml),
[tasks.md](./tasks.md).

**Result**: 15 findings — 0 CRITICAL, 3 HIGH, 8 MEDIUM, 4 LOW. Zero CRITICAL findings means the
analysis gate in the constitution is cleared and `/speckit-implement` may proceed.

**Update, same day**: **all 3 HIGH and all 8 MEDIUM findings are RESOLVED** — see
[Resolutions](#resolutions) at the end of this report. The four LOW findings are recorded
deliberately and need no action (L2, L3 and L4 document correct behaviour; L1 notes intentional
redundancy). Resolving them expanded the spec from 76 to **79 requirements** and `tasks.md`
from 161 to **163 tasks**, and amended the constitution to **1.1.0**.

---

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| D1 | Constitution alignment | HIGH — **RESOLVED** | spec.md FR-054; constitution "Technology and Architecture Constraints"; research.md D6 | FR-054 says "**System** MUST send a notification when an order reaches a stage", and the constitution's stack table lists FCM for push. But FR-035 forbids any background job, so no server component ever observes a stage transition. Research D6 resolves this by scheduling local notifications on-device from the immutable timestamps — a better answer, but the spec text still describes the server doing it. | Reword FR-054 to "The app MUST deliver a notification…" so the requirement states the outcome, not the mechanism. Add a one-line note to the constitution's push row: "delivery-stage notifications are scheduled on-device; FCM carries promotional sends only." No code impact. |
| C1 | Coverage gap | HIGH — **RESOLVED** | spec.md SC-002, SC-003; tasks.md | Two measurable performance criteria — search p95 under 1 s, cached paint under 500 ms — have no task that measures them. Nothing in 161 tasks produces the number either criterion is judged on. A performance criterion with no measurement task is decoration. | Add to Phase 12: a backend load test asserting search p95 against a full-size seeded catalogue (SC-002), and a client trace assertion on time-to-first-paint from cache (SC-003). Both are small; the point is that they exist and run. |
| I1 | Inconsistency | HIGH — **RESOLVED** | spec.md FR-021; contracts/openapi.yaml `POST /orders` 409 | FR-021 says a cart line whose product has been withdrawn is flagged and excluded from the total "rather than failing checkout". The contract returns `409` when a product in the order is withdrawn. Both are defensible but they describe opposite behaviours, and the implementer will pick one at random. | They are not actually in conflict once stated properly: the *client* excludes the flagged line before submitting, and the `409` covers the race where a product is withdrawn between submission and commit. Say that explicitly — add the clause to FR-021 and to the `409` description in the contract. |
| C2 | Coverage gap | MEDIUM — **RESOLVED** | spec.md Edge Cases; tasks.md | "Search terms contain characters that are meaningful to the search engine" has no requirement and no task. Passing raw user input to a `tsquery` parser raises a syntax error, which surfaces as a 500 — a raw error reaching the user, violating Principle IV. | Add a task under US1: sanitise search input via `websearch_to_tsquery` (or equivalent) and add a test with `"` , `&`, `|`, `!`, `:*` and an unbalanced parenthesis. |
| C3 | Coverage gap | MEDIUM — **RESOLVED** | spec.md FR-017; Edge Cases | "A user requests account deletion while an order is still mid-delivery" is listed as an edge case, but FR-017 only requires that deletion can be *requested*. What happens to the in-flight order, the device registration, and the reviews they wrote is unspecified. | Either specify the retention outcome in FR-017 or state in Assumptions that deletion is a request queued for manual handling in v1. The second is honest and costs nothing. |
| C4 | Coverage gap | MEDIUM — **RESOLVED** | contracts/openapi.yaml `ProductSummary.original_price`; data-model.md `product.discount_percentage` | Discounts exist in the contract and the schema, and §17.5 of the source specification asks for struck-through original prices, but no `FR-xxx` governs them. A field with no requirement behind it has no test and no acceptance criterion. | Add a functional requirement: when a product carries a discount, the app MUST show the discounted price as primary and the original struck through, and the conversion MUST apply to both through the same currency seam. |
| A1 | Ambiguity | MEDIUM — **RESOLVED** | spec.md FR-033; research.md D5 | FR-033 requires stage timestamps "spread across a plausible window" without defining plausible. Research D5 pins it to 6 h / 54 h / 60 h with deterministic jitter, but the requirement itself remains untestable as written. | Cite the D5 figures in FR-033, or state the window as a constraint ("between 24 and 96 hours"). A test cannot assert "plausible". |
| U1 | Underspecification | MEDIUM — **RESOLVED** | spec.md FR-006, Edge Cases | `stock_status` is returned by the API and an edge case notes a product going out of stock mid-cart, but no requirement says what the UI does with `out_of_stock` — whether add-to-cart is disabled, or the product is hidden from listings. | Add a requirement, or state in Assumptions that out-of-stock products remain browsable with add-to-cart disabled. |
| U2 | Underspecification | MEDIUM — **RESOLVED** | contracts/openapi.yaml `Review.author_name`, `author_avatar_url` | Reviews expose the author's display name and avatar to unauthenticated callers. No requirement authorises this and no assumption covers it. It is the only place the app publishes one user's data to another. | Add a requirement stating what a review exposes, or return an initial-only display name. Worth a deliberate decision rather than an inherited default. |
| I2 | Inconsistency | MEDIUM — **RESOLVED** | plan.md "Verification Strategy" Layer 4; .claude/skills/speckit-verify/SKILL.md Layer 5; tasks.md T034 | Three documents give three paths for client unit tests: `mobile/test/`, `mobile/test/unit test/core`, and `mobile/test/core/currency_service_test.dart`. Minor, but `/speckit-verify` will run a path that does not exist and report a false BLOCKED. | Fix on the single convention `mobile/test/<feature>/…`, and update the verify skill's Layer 5 command to plain `flutter test`. |
| C5 | Coverage gap | MEDIUM — **RESOLVED** | spec.md SC-001, SC-004 | Two success criteria are journey-level and qualitative ("under three minutes without assistance", "zero screens show a raw error"). SC-004 is checkable and is effectively covered by T131–T135 plus the manual walk; SC-001 is not checked anywhere. | Bind SC-004 explicitly to T161's manual walk in the task text. For SC-001, either accept it as a manual-walk criterion and say so, or drop it — an unmeasured criterion invites a false claim later. |
| L1 | Duplication | LOW | spec.md FR-057 and FR-058; US8 acceptance scenarios 1, 2, 6 | Cache-then-network is stated twice at requirement level and three times at scenario level. Not contradictory, and arguably useful emphasis, but it inflates the traceability count without adding coverage. | Leave as is. Recorded so a future reader knows the redundancy is noticed, not accidental. |
| L2 | Inconsistency | LOW | data-model.md `app_user`; spec.md "User"; contracts `User` | The entity is `User` in the spec and contract, `app_user` in the schema. | Intentional — `user` is reserved in Postgres, and data-model.md says so. No action. |
| L3 | Constitution alignment | LOW | .specify/workflows/speckit/workflow.yml | The constitution names an eight-step workflow ending in `/speckit-verify`, but the upstream workflow file stops at `implement`. The workflow file ships with spec-kit and would be overwritten on upgrade. | Leave the upstream file alone. If automation is wanted, add a separate project workflow rather than editing the vendored one. |
| L4 | Ambiguity | LOW | scripts/check_traceability.py `CARD_LITERAL_ALLOWLIST` | SC-013 claims "zero user-entered payment card data … verified by an automated check", while the check allowlists one file that must contain a card-shaped literal, since the demo cards have to render something. | The allowlist is correct and the distinction is real — a displayed constant is not user-entered data. Worth one clarifying clause in SC-013 so the exception is not read as a hole. |

---

## Coverage Summary

Requirement-to-task coverage is machine-verified rather than asserted:

```console
$ python3 scripts/check_traceability.py
[PASS] requirement -> task coverage
       all 76 requirements referenced by at least one task
[SKIP] requirement -> test coverage
       10/76 requirements have a test across 3 test file(s)
       BOOTSTRAP: no product source found, so the gate is not yet enforced.
[PASS] simulation boundary
       clean — scanned no source files yet
RESULT: PASS
```

Two things this check caught during authoring, both worth recording:

1. The first run against the first draft of `tasks.md` found **six** requirements with no task —
   FR-006, FR-009, FR-040, FR-045, FR-046, FR-048 — including a missing review-creation task for
   `POST /products/{id}/reviews`, an endpoint that was already in the contract. Fixed. The prose
   in that draft claimed full coverage, and the prose was wrong.
2. The first run against the scaffolded test harness reported **25/76** covered. It was counting
   `FR-xxx` ids appearing in a planning comment inside a test file — a to-do list masquerading as
   coverage. The scanner now ignores whole-line comments, and the honest figure is 10/76, all of
   it from the contract-document tests that actually run today.

Neither would have been visible by reading the documents.

| Artifact pair | Coverage | Method |
|---|---|---|
| Requirements → tasks | 79 / 79 | `check_traceability.py`, blocking in CI |
| Requirements → tests | 10 / 79 | From the contract-document tests running today; gate begins blocking with the first source file |
| API operations → contract tests | 19 / 19 planned (T038, T060, T070, T094, T102, T109, T110, T124); 11 structural assertions run today | `backend/tests/contract/` |
| User stories → integration modules | 8 / 8 planned | tasks.md Phases 3–10 |
| Success criteria → tasks | 13 / 13 — 11 by automated task, SC-001 and SC-004 by the manual walk (T163), each now stating its own method | Manual cross-reference |
| Entities (data-model) → spec Key Entities | 11 / 11 | Manual cross-reference |

**Unmapped tasks**: none. Every task traces to a requirement, a research decision, or a
constitution principle.

---

## Constitution Alignment

| Principle | Status | Note |
|---|---|---|
| I. Simulation Boundary | ALIGNED | No payment field in the contract; no payment column in the schema; enforced mechanically by the boundary scan, which has one documented allowlist entry (L4) |
| II. Test-First | ALIGNED | Test tasks precede implementation in every phase; the traceability gate is task T011, built before any feature |
| III. Determinism | ALIGNED | Write-once trigger on stage columns, RNG seeded on product id, clock injected. Lint rule bans `datetime.now()` outside `deps.py` |
| IV. Never a Dead End | ALIGNED | Four-variant `AppFailure` maps 1:1 to FR-059; every empty state has a task. One gap found and reported (C2) |
| V. Single Seam | ALIGNED | Currency, geocoding, and route provision each have exactly one interface in the plan |
| VI. Offline-First | ALIGNED | Checkout is the only online-only path, stated in three places consistently |
| VII. Accessible & Adaptive | ALIGNED | Golden matrix at two text scales; accessibility is an acceptance criterion, not a polish task |

No principle is violated by any requirement, design decision, or task.

---

## Metrics

- Total requirements (FR): **79** (76 at first analysis; +3 from C4, U1, U2)
- Total success criteria (SC): **13**
- Total tasks: **163** across 12 phases (161 at first analysis, +2 from C1)
- Requirement → task coverage: **100%**
- Success criterion → task coverage: **9 / 13** explicit after C1 (was 7 / 13); SC-001 and
  SC-004 are judged in the manual walk (T163), SC-007 and SC-011 via their requirements
- API operations: **19** across 12 paths
- Entities: **11**
- Findings: **15** — 0 CRITICAL, 3 HIGH (**all resolved**), 8 MEDIUM (**all resolved**), 4 LOW
- Resolved: **11** of 15 | Open: 4 LOW, all deliberate (see Next Actions)
- Ambiguity findings: 2 | Duplication findings: 1 | Inconsistency findings: 3

---

## Resolutions

All three HIGH findings were fixed on 2026-08-02, after this report was first written.

### D1 — notification mechanism (RESOLVED)

- `spec.md` **FR-054** reworded from "System MUST send a notification…" to "The app MUST
  **deliver** a notification…", with an added clause: because FR-035 forbids background
  progression, the notification must be derivable from the timestamps assigned at order
  creation and must not depend on a scheduler watching for the transition. The requirement now
  states an outcome and a constraint, both testable, and names no mechanism.
- `constitution.md` push row now records that delivery-stage notifications are scheduled
  on-device, that FCM carries promotional and offline-catch-up sends only, and that a
  server-side stage scheduler is forbidden. Constitution bumped **1.0.0 → 1.1.0** (MINOR:
  guidance materially expanded, no principle removed or redefined), with the reason recorded
  in the Sync Impact Report.
- No task change needed — Phase 9 (T122, T123, T128) already implements the on-device
  mechanism, because it was written from research D6 rather than from FR-054.

### C1 — unmeasured performance criteria (RESOLVED)

Two tasks added to Phase 12, and the tail of that phase renumbered (161 → 163 tasks):

- **T158** — search latency benchmark in `backend/tests/performance/test_search_latency.py`:
  a representative term mix against a full-size seeded catalogue, asserting p95 under 1 s and
  failing with the measured figure (SC-002).
- **T159** — cached-paint benchmark in `mobile/integration_test/perf/cached_paint_test.dart`:
  warm caches, network stubbed to never respond, asserting time-to-first-content under 500 ms
  (SC-003).

**T163** (the manual smoke walk) now states explicitly that SC-001 and SC-004 are judged there,
which also closes the reporting half of finding C5. C5's underlying point — that SC-001 is
measured by a human rather than a test — stands, and is now stated rather than implied.

### I1 — withdrawn product at checkout (RESOLVED)

The two documents described opposite behaviour because they were describing two different
moments. Both now say so:

- `spec.md` **FR-021** extended: the client flags and excludes a withdrawn line and MUST NOT
  submit it; if a product is withdrawn between submission and the order being recorded, the
  **whole order** is rejected with the product named and the cart left intact. A line is never
  silently dropped from an order the user has already confirmed.
- `contracts/openapi.yaml` `POST /orders` **409** description now states that it covers the
  race only, that the order is never partially recorded, and that `detail` names the product.
- **T070** extended to assert the race case: whole-order rejection, no partial row written, and
  the product named in `detail`. This also gives FR-021 a backend test, where before it had only
  a client-side widget test.

### C2 — unsanitised search input (RESOLVED)

`to_tsquery` raises a syntax error on unbalanced parentheses, bare operators, and
punctuation-only input. Anyone typing `(` or `C++` would have got a 500 — a raw error reaching
the user, breaching Principle IV.

- `spec.md` **FR-003** extended: search input is treated as literal user text; characters
  meaningful to the search engine must not error, must not alter query semantics, and must not
  surface as a failure. A no-match search returns the FR-063 empty state, never an error state.
- The corresponding **edge case** now enumerates what "meaningful characters" means: quotes,
  boolean operators, prefix wildcards, unbalanced parentheses, punctuation-only terms.
- `research.md` **D2** now specifies `websearch_to_tsquery` and says why — it never raises, and
  it accepts the Google-ish syntax users already expect rather than discarding it.
- **T050** names the parser explicitly. **T041** extended to assert the hostile-input matrix:
  `"`, `&`, `|`, `!`, `:*`, `<->`, an unbalanced `(`, a punctuation-only term, and a
  200-character term each return 200 with results or the empty state.

### I2 — client test path drift (RESOLVED)

Three documents gave three different paths for client unit tests, and `/speckit-verify` would
have run one that does not exist and reported a false BLOCKED.

One convention now, stated in `plan.md` and repeated in `quickstart.md` and the verify skill:
`mobile/test/` mirrors `mobile/lib/` one directory per area, plus `test/goldens/`, and holds
everything the Dart VM can run; `mobile/integration_test/` holds only what needs a device, one
driver per user story plus `integration_test/perf/`.

The operational consequence is the point: **`flutter test` with no arguments is always the whole
host-side suite.** The verify skill's `flutter test test/unit test/core` is gone, and all three
documents now say never to pass a path list — a mistyped path makes `flutter test` report "no
tests ran", which reads as success. The plan's structure tree, which previously showed
`integration_test/` nested inside `test/`, is corrected.

### C3 — account deletion semantics (RESOLVED)

The edge case existed; the requirement behind it did not. Deletion needed a v1 answer that is
honest about having no purge pipeline while still specifying the parts a user would notice.

- **FR-017** extended: the request is recorded with its timestamp, the user is told what happens
  next, and their notification devices are deregistered **immediately** so no further push can
  reach them. In-flight orders complete and stay readable; the account remains usable meanwhile;
  a request made mid-delivery is accepted, never rejected.
- **Assumptions** now state plainly that deletion is a request handled manually in v1, and that
  reviews are **anonymised rather than deleted** — deleting them would retroactively change
  every affected product's rating average and count, making historical catalogue data
  irreproducible and contradicting Principle III.
- `data-model.md` records the mechanism: `review.user_id` set to NULL, which the partial unique
  index already excludes; order history survives on its snapshot columns.
- **T065** deletes device rows in the same transaction; **T060** asserts `202` with an order
  mid-delivery, every device row gone, and the order still readable.

### C4 — discount display (RESOLVED)

`original_price` and `discount_percentage` existed in the contract and the schema with no
requirement behind them, so no test and no acceptance criterion.

- New **FR-077**: when a product carries a discount, both prices are exposed, the discounted one
  is shown primary with the original struck through, and **both convert through the same
  currency call** — so a discount can never appear in one currency and its original in another.
- **T034** asserts the shared-conversion property in the currency service unit tests, **T048**
  carries it in the schema, **T057** renders it.

### A1 — untestable delivery window (RESOLVED)

**FR-033** replaced "spread across a plausible window" with: the four stages are non-decreasing
and the creation-to-delivery window falls between **24 and 96 hours**. Research D5's 6 h / 54 h
/ 60 h sits inside that range, so the decision is unchanged — but the requirement is now
something a test can assert, which "plausible" never was. **T092** asserts both properties for
every destination in the warehouse table.

### U1 — out-of-stock behaviour (RESOLVED)

New **FR-078**: out-of-stock products stay browsable and searchable, are labelled, and cannot be
added to the cart; one that goes out of stock while already in a cart is flagged and excluded
from the total exactly as FR-021 handles a withdrawn one. This also draws the line the data
model implied but nothing stated: **withdrawn** products disappear from the catalogue,
**out-of-stock** ones do not. **T044** asserts the visibility half, **T077** the cart half,
**T057** the disabled control.

### U2 — what a review exposes (RESOLVED)

Reviews are readable anonymously, so `Review` is the one schema that publishes one user's data
to the world — and it had reached that state by inheritance rather than decision.

New **FR-079** makes it a **closed set**: rating, comment, creation time, and the author's
provider-supplied display name and avatar. Nothing else, to anyone. The contract schema now
carries that warning at the point of edit. **T038** asserts it on the **full key set** rather
than on the absence of any particular field, so a field added later cannot leak silently — the
usual way this kind of guarantee decays.

### C5 — SC-001 measurement (RESOLVED)

**SC-001** now states its own method: measured by a human with a stopwatch, with a participant
who has not used the app before, during the release smoke walk, and **recorded as a number in
the release notes** so a regression is visible. **T163** carries the same instruction. The
criterion is no longer automated-looking prose that nothing measures; it is an explicitly manual
check with an owner and an artifact.

---

## Next Actions

No CRITICAL findings, so implementation is not blocked. Recommended order:

1. ~~**Resolve D1, C1, I1**~~ — done.
2. ~~**Fix C2 and I2**~~ — done.
3. ~~**Fold C3, C4, C5, U1, U2, A1 into the spec**~~ — done. See [Resolutions](#resolutions).
4. **Run `/speckit-implement`**, starting with Phase 1 and Phase 2. Note that Phase 2 puts the
   verification infrastructure (T011–T015) before the application infrastructure, deliberately —
   the gate that judges the work is built before the work.
5. **Finish with `/speckit-verify`.**

Nothing blocks implementation. The four LOW findings stay open on purpose: L1 records
intentional redundancy, L2 and L3 document correct behaviour, and L4 notes that the one
allowlisted card-shaped literal is a displayed constant rather than user-entered data — a
distinction worth one clarifying clause in SC-013 if anyone wants it, and no more.

## Amendment — sign-up made explicit (2026-08-02, during implementation)

The source specification's §3.1 was updated to read "Sign in **AND Sign up** with Apple". The
first draft of this spec treated sign-up as implied by sign-in, which for social providers is
*almost* right — the same authorisation call both creates and returns an account. Propagating it
properly surfaced one thing that is not merely cosmetic:

> **Apple returns the user's name only on the very first authorisation.** Every later sign-in
> carries no name at all, and it is not in the ID token. An implementation that treats sign-up
> as "just sign-in" and reads the profile lazily never gets a name, and the account stays
> unnamed permanently unless the user revokes the app in iOS Settings and re-authorises.

Google and Facebook return the profile on every sign-in, so they forgive this. Apple does not,
and Apple is mandatory on iOS whenever another social provider is offered — so the distinction
had to be modelled rather than assumed.

Changes made:

| Artifact | Change |
|---|---|
| `spec.md` | US2 retitled and rewritten with sign-up scenarios; **FR-011** now covers account creation with no password, form, or verification step; **FR-012** covers Apple for both flows; new **FR-080** (first-run distinction, no duplicate account) and **FR-081** (capture the one-time name; never overwrite a stored name with an empty one) |
| `research.md` | New decision **D13**, including why a dedicated `POST /users` endpoint was rejected — lazy provisioning already creates the row, and a second path can disagree with the first about how an account comes to exist |
| `contracts/openapi.yaml` | `PATCH /me` now accepts `display_name`. This is the whole contract consequence: without it there is no way to record a name the client learned but the backend never saw |
| `data-model.md` | No change — `app_user.display_name` already existed |
| `tasks.md` | T066 extended to both flows; new **T164** (capture at sign-up + the merge unit test), **T165** (first-run welcome), **T166** (contract test), **T167** (no duplicate account) |

Spec is now **81 requirements**; `tasks.md` is **167 tasks**. The merge rule is already
implemented and unit-tested — `merge_provider_profile` in `auth/user_provisioning.py`, six tests
in `tests/unit/test_user_provisioning.py`, including the one that matters: a second sign-in
carrying no name leaves the stored name intact.

---

## Re-verification after remediation

```console
$ python3 scripts/check_traceability.py
Traceability gate — 79 requirements in specs/001-shopping-app-simulator/spec.md
[PASS] requirement -> task coverage    all 79 requirements referenced by at least one task
[SKIP] requirement -> test coverage    10/79 — activates with the first source file
[PASS] simulation boundary             clean
RESULT: PASS

$ uvx --from openapi-spec-validator openapi-spec-validator .../contracts/openapi.yaml
OK
$ cd backend && uv run pytest tests -q          11 passed
$ cd mobile  && flutter test                    All tests passed!
```
