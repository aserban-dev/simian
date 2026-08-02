# Implementation Plan: Shopping App Simulator

**Branch**: `001-shopping-app-simulator` | **Date**: 2026-08-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-shopping-app-simulator/spec.md`

## Summary

A Flutter mobile client and a FastAPI backend deliver a Temu-style shopping experience whose
transactions are entirely simulated. The client owns everything stateful that can be owned
locally — cart, caches, parcel position — while the backend owns the catalogue, identity
mapping, orders, and the immutable delivery timeline. Firebase supplies identity and push;
the backend validates Firebase ID tokens as a resource server and never mints its own. Product
imagery is served to devices straight from Cloudflare R2, so the Azure-hosted API carries no
image bandwidth. Delivery is simulated by writing all four stage timestamps at order creation
and computing everything downstream — current stage, parcel position — as a pure function of
those timestamps and the current time, which is what makes it exactly testable.

## Technical Context

**Language/Version**: Python 3.12 (backend, seed pipeline); Dart 3.x on Flutter latest stable
(client)

**Primary Dependencies**: Backend — FastAPI, SQLAlchemy 2.x, Alembic, Pydantic v2, `python-jose`
or `PyJWT` with a cached JWKS client, `httpx`, `boto3` (R2 is S3-compatible). Client — Riverpod
(state), `dio` (HTTP), `drift` (local cache), `cached_network_image`, `google_maps_flutter`,
`firebase_auth`, `firebase_messaging`, `flutter_localizations` + `intl`.

**Storage**: PostgreSQL 16 for catalogue, users, addresses, orders. Drift (SQLite) on device for
the catalogue and order-history cache. Cloudflare R2 for image objects.

**Testing**: Backend — `pytest`, `pytest-asyncio`, `httpx.AsyncClient` against the ASGI app,
`testcontainers` or a disposable Postgres for integration, `schemathesis` for contract tests
driven from `contracts/openapi.yaml`. Client — `flutter_test` for unit and widget tests,
`integration_test` for user journeys, `golden_toolkit` for responsive and font-scale goldens.
Cross-cutting — a traceability checker binding every `FR-xxx` to at least one test.

**Target Platform**: iOS 15+ and Android 8+ (API 26+); backend on Linux containers on Azure.

**Project Type**: Mobile app plus REST API (Option 3 in the structure template).

**Performance Goals**: Cached screen paint under 500 ms (SC-003); search p95 under 1 s
(SC-002); 60 fps scrolling in product grids; API p95 under 300 ms excluding image bytes.

**Constraints**: Catalogue, cart, and order history usable offline; checkout online-only;
zero user-entered card data anywhere; geocoding exactly once per address on write; images never
proxied by the backend; delivery position computed on-device.

**Scale/Scope**: ~10k–45k products, ~20 categories, single region, demo-scale concurrency
(low hundreds). Roughly 20 client screens.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Gate | Pre-research | Post-design |
|---|---|---|---|
| I. Simulation Boundary | No payment SDK dependency; no schema column, request field, or log line can hold card data; demo cards are a client-side constant | PASS | PASS — `contracts/openapi.yaml` has no card field; `POST /orders` takes only `demo_card_id`, an enum of built-in identifiers |
| II. Test-First | Every FR maps to a test; contract tests generated from the OpenAPI document; test tasks precede implementation tasks | PASS | PASS — `tasks.md` orders tests first; `scripts/check_traceability.py` enforces the FR mapping in CI |
| III. Determinism | Stage timestamps written once; seed RNG keyed on product ID; time injectable in tests | PASS | PASS — `clock` dependency injected into the FastAPI app; `Order` stage columns are write-once |
| IV. Never a Dead End | Typed error taxonomy in the client; every empty state has copy and an action | PASS | PASS — `AppFailure` sealed class with four variants maps 1:1 to FR-059 |
| V. Single Seam | One currency service, one geocoding call site, one route provider, no image proxying | PASS | PASS — `CurrencyService`, `GeocodingService`, `RouteProvider` are the sole interfaces; no backend route serves image bytes |
| VI. Offline-First | Cache-then-network repositories; checkout the sole online-only path | PASS | PASS — repository layer returns a cached-then-fresh stream; checkout bypasses it deliberately |
| VII. Accessible & Adaptive | Breakpoint-driven layout; golden tests at 1.0× and 2.0× text scale; semantics on every interactive widget | PASS | PASS — golden test matrix defined in `quickstart.md` |

No violations. Complexity Tracking is therefore empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-shopping-app-simulator/
├── plan.md              # This file (/speckit-plan command output)
├── spec.md              # Feature specification (/speckit-specify)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── openapi.yaml     # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md  # Spec quality checklist (/speckit-specify)
├── tasks.md             # Phase 2 output (/speckit-tasks command)
└── analysis-report.md   # Cross-artifact analysis (/speckit-analyze)
```

### Source Code (repository root)

```text
backend/
├── src/dupermarket_api/
│   ├── main.py                 # FastAPI app factory, middleware, error handlers
│   ├── config.py               # Settings (env-driven: dev / staging / prod)
│   ├── deps.py                 # DI: db session, current_user, clock
│   ├── auth/
│   │   ├── firebase.py         # JWKS fetch + cache, token verification
│   │   └── user_provisioning.py# Lazy user row creation on first authed call
│   ├── models/                 # SQLAlchemy: category, product, product_image,
│   │                           #   review, user, address, wishlist, order,
│   │                           #   order_item, device
│   ├── schemas/                # Pydantic request/response models
│   ├── services/
│   │   ├── catalogue.py        # Search, filter, sort, pagination
│   │   ├── orders.py           # Order creation, stage timestamp assignment
│   │   ├── delivery.py         # Warehouse assignment, window computation
│   │   ├── currency.py         # THE single conversion seam (fixed rates in v1)
│   │   ├── geocoding.py        # THE single geocoding seam, write-path only
│   │   └── notifications.py    # FCM dispatch on stage transitions
│   ├── api/                    # Routers: categories, products, reviews, me,
│   │                           #   addresses, wishlist, orders, devices
│   └── errors.py               # Problem-detail responses, no raw exceptions
├── alembic/                    # Migrations
└── tests/
    ├── contract/               # One module per API operation (schemathesis + explicit)
    ├── integration/            # One module per user story (US1..US8)
    ├── unit/                   # Services in isolation, clock injected
    └── conftest.py             # App fixture, disposable DB, fake clock, fake auth

mobile/
├── lib/
│   ├── main_dev.dart / main_staging.dart / main_prod.dart   # Flavor entrypoints
│   ├── core/
│   │   ├── network/            # dio client, auth interceptor, failure mapping
│   │   ├── errors/             # AppFailure taxonomy (FR-059)
│   │   ├── currency/           # Client half of the currency seam
│   │   ├── cache/              # Drift database, TTL policy
│   │   └── layout/             # Breakpoints, adaptive scaffolds
│   ├── features/
│   │   ├── catalogue/          # Home, category, list, search, product detail
│   │   ├── auth/               # Sign-in, session, sign-out cache purge
│   │   ├── cart/               # Local-authoritative cart
│   │   ├── checkout/           # Address pick, demo cards, confirmation
│   │   ├── orders/             # History, detail, delivery map
│   │   ├── profile/            # Addresses, wishlist, preferences, credits
│   │   └── notifications/      # Permission prompt, deep links
│   └── l10n/                   # ARB files, English fallback
├── test/                       # unit + widget, mirroring lib/ one directory per area
│   ├── core/                   #   e.g. currency_service_test.dart
│   ├── catalogue/ cart/ ...    #   one directory per feature under lib/features/
│   └── goldens/                # responsive x text-scale matrix (platform-sensitive)
└── integration_test/           # on-device drivers
    ├── us1_browse_test.dart    #   one per user story
    └── perf/                   #   benchmark drivers (SC-003)

seed/
├── src/dupermarket_seed/
│   ├── ingest/                 # DummyJSON, Kaggle CSV readers
│   ├── normalise.py            # Source taxonomy → app taxonomy, exclusions
│   ├── prices.py               # Deterministic price synthesis (RNG keyed on ID)
│   ├── images/                 # Pexels pool fetch, resize/WebP, R2 upload
│   ├── overrides.csv           # Operator product_id → image_url overrides
│   └── verify.py               # Post-run assertions (FR-074)
└── tests/

scripts/
└── check_traceability.py       # FR-xxx → test mapping enforcement (SC-005)

.github/workflows/ci.yml        # Lint, backend tests, flutter tests, traceability
docker-compose.yml              # Postgres + API for local development
```

**Structure Decision**: Mobile + API (template Option 3), with a third top-level `seed/`
package. `seed/` is separate from `backend/` deliberately: it has different dependencies
(image processing, S3 upload, dataset readers), runs as a one-off operator tool rather than a
service, and must never be importable from request-handling code. `scripts/` holds
repository-level verification that spans all three.

## Phase 0 — Research

See [research.md](./research.md). Ten decisions were open at the start of planning; all ten are
resolved there, each with the alternatives rejected and why. No `NEEDS CLARIFICATION` items
remain in Technical Context.

## Phase 1 — Design

- [data-model.md](./data-model.md) — eleven entities, their columns, constraints, and the four
  indexes that matter. Includes the write-once constraint on delivery timestamps and the
  snapshot columns on `order_item`.
- [contracts/openapi.yaml](./contracts/openapi.yaml) — the full API surface from spec §15,
  including auth requirements per operation. This document is the input to the contract test
  suite, not a description of it.
- [quickstart.md](./quickstart.md) — how to bring the stack up, seed it, and run every layer of
  the test suite.

## Verification Strategy

This section exists because verification is the stated priority for this project. It is the
contract between `plan.md` and `/speckit-verify`.

**Layer 1 — Unit.** Services in isolation with the clock and all external calls injected.
Targets the pure logic: currency conversion and fallback (FR-050 – FR-052), stage derivation
from timestamps (FR-035), elapsed-fraction clamping (FR-038), price synthesis determinism
(FR-073).

**Layer 2 — Contract.** Driven from `contracts/openapi.yaml`. For every operation: a success
case asserting the response validates against the declared schema, a failure case, and — for
every non-public operation — an unauthenticated case asserting 401 and a cross-tenant case
asserting a user cannot read another user's resource (FR-013, FR-032). Schemathesis provides
property-based coverage; explicit tests cover the auth matrix, which property testing will not
find on its own.

**Layer 3 — Integration.** One module per user story, US1 through US8, each runnable in
isolation against a disposable database seeded with a small fixture catalogue. These are the
executable form of each story's "Independent Test".

**Layer 4 — Client.** Widget tests for the error and empty-state taxonomy (FR-059 – FR-064).
Golden tests at 1.0× and 2.0× text scale across phone-portrait, tablet-portrait, and
tablet-landscape (FR-065 – FR-070). `integration_test` drivers for the P1–P4 journeys against a
locally running backend.

**Client test layout — one convention, no exceptions.** `mobile/test/` mirrors `mobile/lib/`,
one directory per area (`test/core/`, `test/catalogue/`, …), and holds everything the Dart VM
can run: unit and widget tests, plus `test/goldens/` for the responsive matrix.
`mobile/integration_test/` holds only what needs a device or emulator: one driver per user
story, and `integration_test/perf/` for benchmarks. Consequently `flutter test` with no
arguments runs the entire host-side suite, which is what CI and `/speckit-verify` invoke — no
path lists to drift out of date.

**Layer 5 — Seed verification.** The seed run itself asserts FR-074 and fails the run on
violation, and re-runs assert zero changed rows and zero uploads (SC-012).

**Layer 6 — Traceability and boundary.** `scripts/check_traceability.py` parses every `FR-xxx`
out of `spec.md`, scans test files for `FR-xxx` markers, and fails if any requirement has no
test. The same script greps the schema, source, and log formatters for card-number-shaped
patterns and payment-processor imports to enforce the Simulation Boundary (SC-013). Both run in
CI on every push.

## Complexity Tracking

No Constitution Check violations. This section is intentionally empty.
