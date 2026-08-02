---
description: "Task list for Shopping App Simulator implementation"
---

# Tasks: Shopping App Simulator

**Input**: Design documents from `/specs/001-shopping-app-simulator/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/openapi.yaml](./contracts/openapi.yaml)

**Tests**: MANDATORY. The upstream template marks test tasks optional; constitution
Principle II overrides that for this project. Test tasks appear before the implementation they
cover, and a task is not done while its tests fail, are skipped, or are absent.

**Organization**: Grouped by user story so each can be implemented, tested, and demoed
independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on another incomplete task
- **[Story]**: The user story this serves (US1–US8), or blank for shared work
- Every task names concrete file paths
- `FR-xxx` references bind the task to the requirement it satisfies; the same marker goes in the
  test docstring so `scripts/check_traceability.py` can verify the link
- Task IDs, like requirement IDs, are **append-only and never reused**. A task added later to an
  earlier phase takes the next free number and sits with its phase, so `T164` appearing in
  Phase 4 is intentional — renumbering would invalidate every reference in the plan, the
  research decisions, and the completed-task markers the gate reads.

## Path Conventions

Mobile + API layout per [plan.md](./plan.md#project-structure): `backend/`, `mobile/`, `seed/`,
`scripts/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository skeleton and toolchain. Nothing here depends on the design docs.

- [X] T001 Create the three-package layout: `backend/`, `mobile/`, `seed/`, `scripts/`
- [X] T002 [P] Initialise the backend Python package with `uv` in `backend/pyproject.toml` — FastAPI, SQLAlchemy 2.x, Alembic, Pydantic v2, PyJWT, httpx
- [X] T003 [P] Initialise the seed package in `seed/pyproject.toml` — httpx, Pillow, boto3, pandas
- [ ] T004 [P] Initialise the Flutter app in `mobile/pubspec.yaml` — riverpod, dio, drift, cached_network_image, google_maps_flutter, firebase_auth, firebase_messaging, intl
- [X] T005 [P] Configure ruff + mypy in `backend/pyproject.toml` and `seed/pyproject.toml`, including the lint rule forbidding `datetime.now()` outside `backend/src/dupermarket_api/deps.py` (research D12)
- [ ] T006 [P] Configure `analysis_options.yaml` in `mobile/` with `flutter_lints` plus a rule banning hardcoded font sizes (FR-067)
- [X] T007 `docker-compose.yml` at repo root — Postgres 16 with a healthcheck
- [X] T008 [P] `.env.example` at repo root listing every required variable; the API must refuse to start on a missing one
- [ ] T009 [P] Flutter flavors `ios`/`android` × `dev`/`staging`/`prod` with entrypoints `mobile/lib/main_{dev,staging,prod}.dart`
- [X] T010 `.github/workflows/ci.yml` — lint, backend tests with a Postgres service container, flutter test, traceability check

**Checkpoint**: `docker compose up -d postgres` succeeds and CI runs green on an empty test suite.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Verification infrastructure first

Principle II means the machinery that checks the work exists before the work does.

- [X] T011 `scripts/check_traceability.py` — parse `FR-xxx` from `spec.md`, scan tests for markers, fail on any unmapped requirement (SC-005)
- [X] T012 Extend `scripts/check_traceability.py` with the simulation-boundary scan: card-shaped literals, PAN-like field names, payment-processor imports (SC-013, Principle I)
- [X] T013 [P] `backend/tests/conftest.py` — ASGI app fixture, disposable Postgres with per-test transaction rollback, `FrozenClock`, fake token verifier
- [X] T014 [P] `backend/tests/contract/conftest.py` — load `contracts/openapi.yaml`, expose the operation list, and provide two distinct authenticated users for cross-user assertions
- [ ] T015 [P] Contract-coverage meta-test in `backend/tests/contract/test_contract_coverage.py` — fail if any of the 19 operations has no contract test module (SC-006)

### Shared backend infrastructure

- [X] T016 `backend/src/dupermarket_api/config.py` — env-driven settings, fail fast on missing required values
- [X] T017 `backend/src/dupermarket_api/deps.py` — DB session, `Clock` protocol + `SystemClock`, `current_user` dependency
- [X] T018 [P] `backend/src/dupermarket_api/errors.py` — RFC 9457 problem responses; a global handler that guarantees no stack trace or driver error escapes (FR-060)
- [X] T019 Unit test then implement `backend/src/dupermarket_api/auth/firebase.py` — JWKS fetch with cache, verify `iss`/`aud`/`exp`/signature. Tests in `backend/tests/unit/test_firebase_auth.py` cover expired, wrong-audience, wrong-issuer, tampered, and valid (FR-013)
- [X] T020 `backend/src/dupermarket_api/auth/user_provisioning.py` — lazily create `app_user` on first authenticated request (FR-014)
- [X] T021 `backend/src/dupermarket_api/main.py` — app factory, routers, CORS, error handlers, `/healthz`

### Schema

- [X] T022 Alembic init in `backend/alembic/` wired to `config.py`
- [X] T023 [P] Migration: `category` with the self-referential FK and the cycle-guard trigger, per [data-model.md](./data-model.md#category) (FR-001)
- [X] T024 [P] Migration: `product` including the generated `search_vector` column, GIN index, and the three keyset indexes (FR-002, FR-003)
- [X] T025 [P] Migration: `product_image` with `content_sha256` and the `(product_id, sort_order)` unique constraint
- [X] T026 [P] Migration: `review` with the partial unique index enforcing one review per user per product (FR-008)
- [X] T027 [P] Migration: `app_user`, `address` with the partial unique default index (FR-041), `wishlist_item`, `device` with the globally unique token
- [X] T028 Migration: `order` and `order_item` — monotonic-timeline CHECK, snapshot columns, and the write-once trigger on the stage/origin/destination columns (FR-027, FR-034)
- [X] T029 Test then implement the write-once trigger assertion in `backend/tests/integration/test_order_immutability.py` — attempt to update each stage column and expect the write to be rejected (FR-034)

### Shared client infrastructure

- [X] T030 [P] `mobile/lib/core/errors/app_failure.dart` — sealed `AppFailure` with exactly four variants: no connectivity, unreachable, service error, asset failure (FR-059)
- [X] T031 [P] Widget tests then implementation for `mobile/lib/core/errors/` retry-capable error widgets — every variant renders copy plus an action (FR-060)
- [X] T032 [P] `mobile/lib/core/network/` — dio client, auth interceptor attaching the Firebase ID token, response-to-`AppFailure` mapping
- [X] T033 [P] `mobile/lib/core/cache/` — Drift database, schema version, TTL policy, and a version-bump path that rebuilds rather than deserialising an incompatible cache
- [X] T034 [P] `mobile/lib/core/currency/currency_service.dart` — the single conversion seam, fixed rates in v1, base-currency fallback. Unit tests first in `mobile/test/core/currency_service_test.dart`, including that a discounted price and its original always convert through the same call so they cannot end up in different currencies (FR-050, FR-051, FR-052, FR-077)
- [X] T035 [P] `mobile/lib/core/layout/breakpoints.dart` — breakpoint constants and adaptive scaffold (FR-065)
- [ ] T036 [P] `mobile/lib/l10n/` — ARB setup, English fallback, `flutter gen-l10n` wired into the build (FR-047)
- [ ] T037 [P] Golden test harness in `mobile/test/goldens/` — three layouts × two text scales, per [quickstart.md](./quickstart.md#layer-4--client)

**Checkpoint**: Migrations apply, the app boots, an authenticated call provisions a user, and
`scripts/check_traceability.py` passes — enforcing every requirement whose task is marked `[X]`
and reporting the rest as pending. (The gate is scoped to completed work rather than to the
whole spec; a gate that fails from the first commit of implementation to the last is one people
learn to ignore. `--strict` enforces everything and is what the final `/speckit-verify` uses.)

---

## Phase 3: User Story 1 — Browse and discover the catalogue (Priority: P1) 🎯 MVP

**Goal**: A signed-out user can browse categories, page a product list, search, filter, sort,
and open a product detail with images and reviews.

**Independent Test**: Seed the catalogue, launch signed out, complete category → list → filter →
sort → search → detail without authenticating.

### Tests for User Story 1 ⚠️ Write first, watch fail

- [X] T038 [P] [US1] Contract tests for `GET /categories`, `GET /products`, `GET /products/{id}`, `GET /products/{id}/reviews` in `backend/tests/contract/test_catalogue.py` — including that all four succeed with no `Authorization` header (FR-010), and for `POST /products/{id}/reviews`: `201`, `401` anonymous, `409` on a second review by the same user (FR-008), with the rating average and count asserted to have changed (FR-009). Also assert that a review returned to an anonymous caller carries exactly the permitted author fields — assert on the full key set, not on the absence of one field, so a later addition cannot leak silently (FR-079)
- [X] T039 [P] [US1] Unit tests for keyset cursor encode/decode in `backend/tests/unit/test_cursor.py` (FR-002)
- [X] T040 [P] [US1] Integration test `backend/tests/integration/test_us1_browse.py::test_paging_is_stable_under_concurrent_insert` — page a category while inserting a product that sorts into an already-served page; assert no duplicate and no missing id (FR-002)
- [X] T041 [P] [US1] Integration test — search matches a term present only in the description, **and** hostile input is handled as literal text: `"`, `&`, `|`, `!`, `:*`, `<->`, an unbalanced `(`, a punctuation-only term, and a 200-character term each return 200 with results or the empty state, never a 4xx/5xx (FR-003)
- [X] T042 [P] [US1] Integration test — the filter matrix: price bounds and minimum rating in every combination (FR-004)
- [X] T043 [P] [US1] Integration test — each of the five sort modes returns correctly ordered results (FR-005)
- [X] T044 [P] [US1] Integration test — withdrawn products never appear in any catalogue response (data-model); out-of-stock products **do** appear and are labelled (FR-078)
- [X] T045 [P] [US1] Widget test — the no-results empty state shows explanatory copy and a clear-filters action (FR-063)
- [X] T046 [P] [US1] Widget test — a failed image shows a placeholder in its own tile while siblings render (FR-061)

### Implementation for User Story 1

- [X] T047 [P] [US1] SQLAlchemy models `category`, `product`, `product_image`, `review` in `backend/src/dupermarket_api/models/`
- [X] T048 [P] [US1] Pydantic schemas matching `Category`, `ProductSummary`, `ProductDetail`, `ProductImage`, `Review` in `backend/src/dupermarket_api/schemas/catalogue.py` — `ProductSummary` carries `original_price` only when discounted (FR-077), and `Review` exposes rating, comment, created_at, author display name and avatar and nothing else (FR-079)
- [X] T049 [US1] `backend/src/dupermarket_api/services/cursor.py` — opaque keyset cursor encode/decode (T039 covers it)
- [X] T050 [US1] `backend/src/dupermarket_api/services/catalogue.py` — tree assembly (FR-001), keyset paging (FR-002), full-text search parsing user input as literal text via `websearch_to_tsquery` rather than `to_tsquery` so operator characters cannot raise a parse error (FR-003), filtering (FR-004), sorting (FR-005), the product detail payload (FR-006), and review paging (FR-007)
- [X] T051 [US1] `backend/src/dupermarket_api/services/currency.py` — the backend half of the single conversion seam, with the base-currency fallback flag (FR-050–FR-052)
- [X] T052 [US1] Router `backend/src/dupermarket_api/api/categories.py` — `GET /categories`
- [X] T053 [US1] Router `backend/src/dupermarket_api/api/products.py` — list, detail, reviews list, and `POST /products/{id}/reviews` writing one review per user per product (FR-008) and recomputing the product's rating average and count in the same transaction (FR-009)
- [X] T054 [P] [US1] `mobile/lib/features/catalogue/data/` — repository returning a cached-then-fresh stream over Drift + dio
- [X] T055 [P] [US1] `mobile/lib/features/catalogue/presentation/home_screen.dart` — category grid
- [X] T056 [P] [US1] `mobile/lib/features/catalogue/presentation/product_list_screen.dart` — infinite scroll, filter sheet, sort control, skeletons (FR-064)
- [X] T057 [P] [US1] `mobile/lib/features/catalogue/presentation/product_detail_screen.dart` — image carousel, rating summary, paginated reviews, discounted price primary with the original struck through (FR-077), out-of-stock label with add-to-cart disabled (FR-078)
- [ ] T058 [P] [US1] `mobile/lib/features/catalogue/presentation/search_screen.dart`
- [ ] T059 [US1] Golden tests for the product grid: two columns on phone, four to five on tablet, both orientations, both text scales (FR-065, FR-066, FR-067)

**Checkpoint**: US1 is independently demoable against a seeded database with no account.

---

## Phase 4: User Story 2 — Sign in and be recognised (Priority: P2)

**Goal**: Social sign-in, automatic profile provisioning, transparent token refresh, and a
sign-out that clears user-scoped caches.

**Independent Test**: Sign in with each provider, relaunch, confirm persistence, sign out,
confirm user-scoped screens reset while the catalogue survives.

### Tests for User Story 2 ⚠️

- [X] T060 [P] [US2] Contract tests for `GET /me`, `PATCH /me`, `DELETE /me` in `backend/tests/contract/test_me.py` — success, `401` anonymous, validation failure (FR-013); and for `DELETE /me`, that requesting deletion with an order mid-delivery returns `202` rather than being rejected, removes every device row, and leaves the order readable (FR-017)
- [X] T061 [P] [US2] Integration test — a first authenticated call creates exactly one `app_user`; a second call creates none (FR-014)
- [X] T062 [P] [US2] Integration test — user B requesting user A's resource receives `404`, never `403` (FR-013, research D10)
- [X] T063 [P] [US2] Widget test — sign-out clears orders, addresses, wishlist, and cart from Drift while the catalogue cache survives (FR-016)
- [X] T166 [P] [US2] Contract test for `PATCH /me` with `display_name` in `backend/tests/contract/test_me.py` — a name is stored; a subsequent request omitting it or sending null leaves it unchanged rather than clearing it (FR-081)
- [X] T167 [P] [US2] Integration test — authorising twice with the same provider identity signs in to the existing account and creates no second `app_user` row (FR-080)

### Implementation for User Story 2

- [X] T064 [P] [US2] `app_user` model and `User` schema in `backend/src/dupermarket_api/`
- [X] T065 [US2] Router `backend/src/dupermarket_api/api/me.py` — get, patch, and deletion request: record `deletion_requested_at`, delete the user's `device` rows in the same transaction so no further push can reach them, and leave the account usable with in-flight orders intact (FR-017)
- [X] T066 [P] [US2] `mobile/lib/features/auth/` — Firebase **sign-up and sign-in** for Google, Facebook, Apple, with no password, form, or email verification on either path; Apple offered for both on iOS whenever another provider is (FR-011, FR-012)
- [X] T164 [US2] Capture the provider display name on the sign-up path in `mobile/lib/features/auth/` and write it via `PATCH /me` before leaving the flow. Unit test first in `backend/tests/unit/test_user_provisioning.py`: provision with a name, provision again with the same UID and no name, assert the stored name survives (FR-081, research D13)
- [X] T165 [P] [US2] First-run welcome in `mobile/lib/features/auth/presentation/` gated on `isNewUser`, shown to a new account and not to a returning one; widget test asserts both paths (FR-080)
- [X] T067 [US2] Token attachment and transparent refresh in the dio interceptor (FR-015)
- [X] T068 [US2] Sign-out cache purge in `mobile/lib/features/auth/` — clears user-scoped Drift tables, retains the catalogue (FR-016)
- [X] T069 [P] [US2] Profile screen showing display name and avatar in `mobile/lib/features/profile/`

**Checkpoint**: US1 and US2 both work independently.

**Deviations recorded at implementation (constitution: "Development Workflow", last rule)**:

- **T063** — the four tables it names (orders, addresses, wishlist, cart) do not exist yet; they
  land with T108 and T120. Rather than assert nothing, `CacheDatabase` now classifies every table
  as user-scoped or public, `clearUserScopedData()` iterates the user-scoped list, and
  `test/core/cache_sign_out_test.dart` asserts the catalogue survives **and** that the two lists
  together cover `allTables`. A table added later that nobody classifies fails that test. The
  literal four-table assertion becomes real when those tables land.
- **T062** — "user B requesting user A's resource" has no target in this phase: `/me` is resolved
  from the credential, so there is no id to tamper with. Covered as far as it can be (per-user
  isolation, plus a contract-wide assertion that no operation declares `403`); the cross-user
  request itself becomes testable with the first id-addressable user-scoped resource, at T084.
- **T066** — the Firebase gateway is implemented and unit-tested behind `AuthGateway`, but no
  Firebase project is configured in this checkout (`firebase_options.dart`, `google-services.json`
  and `GoogleService-Info.plist` are all gitignored and absent), so it has not been exercised
  against live Firebase. `Firebase.initializeApp()` is deliberately not yet called in
  `bootstrap.dart` — it would crash at launch without that config. Belongs with T004/T009.

---

## Phase 5: User Story 3 — Cart and simulated checkout (Priority: P3)

**Goal**: A local-authoritative cart and an order-creating checkout with demo cards only.

**Independent Test**: Signed in with an address, add items, adjust, check out with the success
card and confirm the order; repeat with the decline card and confirm nothing is created.

### Tests for User Story 3 ⚠️

- [X] T070 [P] [US3] Contract tests for `POST /orders` in `backend/tests/contract/test_orders_create.py` — `201`, `402` decline, `404` foreign address, `401` anonymous, and `409` when a product is withdrawn between submission and commit, asserting the whole order is rejected with no partial row written and the product named in `detail` (FR-021)
- [X] T071 [P] [US3] Contract-document assertion in `backend/tests/contract/test_no_payment_fields.py` — walk every schema in `openapi.yaml` and fail on any property matching card-field patterns (FR-023, Principle I)
- [X] T072 [P] [US3] Integration test — a declined checkout creates no order row and returns a retryable problem (FR-024, FR-025)
- [X] T073 [P] [US3] Integration test — after ordering, mutate the product's title and price, re-read the order, assert the snapshot values are unchanged (FR-027)
- [X] T074 [P] [US3] Integration test — repeating `POST /orders` with the same `idempotency_key` returns the original order and creates no duplicate
- [X] T075 [P] [US3] Unit test — subtotal arithmetic in integer minor units across quantities and discounts, with no float anywhere in the path (research D4)
- [X] T076 [P] [US3] Widget test — the cart survives an app restart and is fully mutable offline (FR-019)
- [X] T077 [P] [US3] Widget test — a cart line whose product is withdrawn is flagged and excluded from the total rather than blocking checkout (FR-021); the same applies to a product that goes out of stock while in the cart, and add-to-cart is disabled for an out-of-stock product (FR-078)
- [X] T078 [P] [US3] Widget test — attempting checkout offline shows an explicit connection message and queues nothing (FR-029)
- [X] T079 [P] [US3] Widget test — the empty cart state shows copy and a browse action (FR-063)

### Implementation for User Story 3

- [X] T080 [P] [US3] `order`, `order_item` models in `backend/src/dupermarket_api/models/`
- [X] T081 [P] [US3] Order request/response schemas in `backend/src/dupermarket_api/schemas/orders.py`
- [X] T082 [US3] `backend/src/dupermarket_api/services/orders.py` — validate address ownership and stock, snapshot line items, compute totals through the currency seam, record `fx_rate` (FR-026, FR-027)
- [X] T083 [US3] Demo card outcome resolution in `backend/src/dupermarket_api/services/orders.py` — `decline` returns `402` before any write (FR-024, FR-025)
- [X] T084 [US3] Router `backend/src/dupermarket_api/api/orders.py` — `POST /orders`
- [X] T085 [P] [US3] `mobile/lib/features/cart/` — Drift-backed local cart: add, change quantity, remove (FR-018), persistence across restarts and offline mutability (FR-019), running subtotal through the currency seam (FR-020)
- [X] T086 [P] [US3] `mobile/lib/features/checkout/demo_cards.dart` — the built-in card constants, the only place cards exist
- [X] T087 [US3] `mobile/lib/features/checkout/presentation/` — review, address pick, card pick, confirm, confirmation screen with order number and window (FR-022, FR-030)
- [X] T088 [US3] Connectivity precondition on the checkout action — explicit message, no queueing (FR-029)
- [X] T089 [US3] Clear the cart on a successful order (FR-028)

**Checkpoint**: The core simulated transaction works end to end.

**Deviations recorded at implementation**:

- **T080** — `order` and `order_item` already existed from T028. What this task added is
  `order.idempotency_key` and its per-user partial unique index (migration
  `0002_order_idempotency_key`), without which T074 has nothing to key a replay on.
- **T087** — built as one screen (review, address, card, confirm) plus a separate confirmation
  screen, rather than four sequential steps. With a preselected address and three cosmetic
  cards there are two decisions to make; a four-page wizard over two decisions is ceremony.
  Every element the task names is present and tested.
- **Migration baseline flaw, found while adding 0002.** `0001_initial` builds from
  `Base.metadata`, so it creates whatever the models say *today* — adding a column to a model
  silently changes the baseline, and a plain `ADD COLUMN` in 0002 then fails on a fresh
  database. 0002 checks before it alters so both paths work, and says why. The real fix is to
  rewrite 0001 as explicit DDL, which is a change to an already-applied migration and is left
  as its own task.

---

## Phase 6: User Story 4 — Simulated delivery on a map (Priority: P4)

**Goal**: Stage derivation and on-device parcel interpolation, rendered on a map.

**Independent Test**: Create an order, query it at several controlled times, assert the stage
and interpolated position match the stored timestamps.

### Tests for User Story 4 ⚠️

- [X] T090 [P] [US4] Unit test — stage derivation at every boundary: before processing, on each timestamp exactly, between each pair, after delivered (FR-035)
- [X] T091 [P] [US4] Unit test — elapsed fraction clamps to 0 and to 1 for clocks set before the window and after it (FR-038)
- [X] T092 [P] [US4] Unit test — warehouse assignment picks the nearest fixed warehouse and is stable for a given destination; the four stage timestamps are non-decreasing and the creation-to-delivery window falls between 24 and 96 hours for every destination in the warehouse table (FR-033, research D5)
- [X] T093 [P] [US4] Unit test — stage timestamps for a given order id are identical across repeated generation (Principle III, SC-008)
- [X] T094 [P] [US4] Contract test for `GET /orders/{id}` in `backend/tests/contract/test_orders_get.py` — includes the tracking payload; another user's order returns `404` (FR-032, FR-036)
- [X] T095 [P] [US4] Widget test — the map renders origin, destination, polyline, and a marker at the expected fraction for a frozen clock (FR-039)

### Implementation for User Story 4

- [X] T096 [US4] `backend/src/dupermarket_api/services/delivery.py` — warehouse table, nearest selection, deterministic jittered window, stage derivation (FR-033, FR-035)
- [X] T097 [US4] Wire stage assignment into order creation in the same transaction (FR-033)
- [X] T098 [US4] `GET /orders/{id}` returning `DeliveryTracking` in `backend/src/dupermarket_api/api/orders.py` (FR-036)
- [X] T099 [P] [US4] `mobile/lib/features/orders/domain/parcel_position.dart` — clamped interpolation, injected clock (FR-037, FR-038)
- [X] T100 [P] [US4] `mobile/lib/features/orders/presentation/delivery_map.dart` — Google Maps widget, polyline, animated marker, behind a `RouteProvider` interface so road routing can replace the straight line later (Principle V)
- [X] T101 [US4] Stage timeline widget above the map showing all four stages and their timestamps

**Checkpoint**: Delivery tracking is demoable and deterministic.

**Deviations recorded at implementation**:

- **T096 / T097** — the warehouse table, window generation and stage derivation were written in
  Phase 5, inside `services/orders.py`, because order creation could not assign a timeline
  without them. T096 moved them to `services/delivery.py` as the task names; `orders.py` now
  calls that one rule rather than holding a second copy. T097 was therefore already satisfied —
  stage assignment has been inside the order-creation transaction since T082.
- **T091** — implemented and tested client-side (`parcel_position.dart`), not on the backend.
  FR-038 clamps the fraction *on the device*, and the contract deliberately returns no parcel
  position, so a server-side elapsed fraction would be a second implementation of a rule that
  has one home.
- **T095** — a `GoogleMap` is a platform view and renders nothing in a widget test. The test
  asserts the geometry the map is *handed* — marker positions, the polyline, the framing camera
  — which is the whole of what FR-039 specifies. The map surface itself is left to integration
  and manual testing, where a platform view can actually be exercised.
- **T100** — `google_maps_flutter` is wired in, but no Maps API key is configured in this
  checkout, so the map has not been rendered against live Google Maps. Same shape as T066:
  the logic is tested behind its seam; the platform integration awaits credentials.

---

## Phase 7: User Story 5 — Order history (Priority: P5)

- [ ] T102 [P] [US5] Contract test for `GET /orders` in `backend/tests/contract/test_orders_list.py` — paging, ownership scoping, `401` anonymous (FR-031, FR-032)
- [ ] T103 [P] [US5] Integration test — orders return newest first and page without duplication (FR-031)
- [ ] T104 [P] [US5] Widget test — order history renders from cache with the network disabled, and says the data may be stale (FR-057, VI)
- [ ] T105 [P] [US5] Widget test — the no-orders empty state offers a route to the catalogue (FR-063)
- [ ] T106 [US5] `GET /orders` in `backend/src/dupermarket_api/api/orders.py` with keyset paging
- [ ] T107 [P] [US5] `mobile/lib/features/orders/presentation/order_history_screen.dart` and `order_detail_screen.dart`
- [ ] T108 [US5] Drift caching of order history with the sign-out purge hooked in (FR-016, FR-057)

**Checkpoint**: History is readable online and offline.

---

## Phase 8: User Story 6 — Profile, addresses, wishlist, preferences (Priority: P6)

- [ ] T109 [P] [US6] Contract tests for the four `/me/addresses` operations in `backend/tests/contract/test_addresses.py` — including `422` for an unresolvable address (FR-043)
- [ ] T110 [P] [US6] Contract tests for the three `/me/wishlist` operations in `backend/tests/contract/test_wishlist.py`
- [ ] T111 [P] [US6] Integration test — the partial unique index makes two default addresses impossible; setting a new default clears the old one atomically (FR-041)
- [ ] T112 [P] [US6] Integration test — deleting an address leaves an existing order's address unchanged (FR-044)
- [ ] T113 [P] [US6] Integration test — geocoding is called exactly once on create and not at all on read (FR-042); assert on a counting fake
- [ ] T114 [P] [US6] Widget test — a currency override changes every displayed price and survives relaunch (FR-049)
- [ ] T115 [P] [US6] Widget test — an untranslated string falls back to English rather than showing a key (FR-047)
- [ ] T116 [P] [US6] Widget test — the empty-wishlist and no-addresses states show copy and an action (FR-063)
- [ ] T117 [US6] `backend/src/dupermarket_api/services/geocoding.py` — the single geocoding seam, write path only (FR-042, FR-043)
- [ ] T118 [US6] Router `backend/src/dupermarket_api/api/addresses.py` — list, create, update, soft delete with default promotion; multiple addresses per user (FR-040)
- [ ] T119 [P] [US6] Router `backend/src/dupermarket_api/api/wishlist.py` — list, add (idempotent), remove (FR-045)
- [ ] T120 [P] [US6] `mobile/lib/features/profile/` — address management, wishlist, language override persisted to the profile (FR-048), currency override, notification preferences (FR-046)
- [ ] T121 [P] [US6] `mobile/lib/features/profile/presentation/photo_credits_screen.dart` — attribution from `ProductImage.attribution` (FR-075)

**Checkpoint**: Full profile surface complete.

---

## Phase 9: User Story 7 — Delivery notifications (Priority: P7)

> Mechanism per [research D6](./research.md#d6-delivery-stage-notifications-without-a-scheduler):
> local notifications scheduled on-device at order creation from the immutable timestamps. No
> server-side scheduler, which is what keeps this consistent with FR-035.

- [ ] T122 [P] [US7] Unit test — `(order, now) -> List<ScheduledNotification>` produces exactly three notifications with stable ids derived from `order_id + stage` (FR-054)
- [ ] T123 [P] [US7] Unit test — scheduling the same order twice deduplicates rather than double-notifying (FR-054)
- [ ] T124 [P] [US7] Contract test for `POST /me/devices` in `backend/tests/contract/test_devices.py` — including that re-registering a token owned by another user reassigns it
- [ ] T125 [P] [US7] Widget test — permission is not requested on first launch, and is requested after the first order with an explanation (FR-053)
- [ ] T126 [P] [US7] Integration test — with permission denied, every other function still works (FR-056)
- [ ] T127 [US7] Router `backend/src/dupermarket_api/api/devices.py` — upsert with cross-user reassignment
- [ ] T128 [US7] `mobile/lib/features/notifications/scheduler.dart` — schedule the three local notifications at order creation
- [ ] T129 [US7] Contextual permission prompt on the order confirmation screen (FR-053)
- [ ] T130 [US7] Deep links from notification tap to order detail, cold and warm start (FR-055)

**Checkpoint**: Notifications work without any server-side scheduler.

---

## Phase 10: User Story 8 — Offline and degraded connectivity (Priority: P8)

- [ ] T131 [P] [US8] Widget test — cached content renders before any network response, then updates in place without a flash or a lost scroll position (FR-057)
- [ ] T132 [P] [US8] Widget test — content older than the TTL is refetched; pull-to-refresh forces a fetch regardless (FR-058)
- [ ] T133 [P] [US8] Widget test — each of the four `AppFailure` variants renders its own message and a retry (FR-059, FR-060)
- [ ] T134 [P] [US8] Widget test — the offline banner appears on connectivity loss and clears on restore (FR-062)
- [ ] T135 [P] [US8] Widget test — a cache written by an older schema version is rebuilt rather than deserialised (edge case)
- [ ] T136 [US8] TTL policy and background refresh in `mobile/lib/core/cache/`
- [ ] T137 [US8] Connectivity listener and offline banner in `mobile/lib/core/network/`
- [ ] T138 [US8] Pull-to-refresh on every list screen

**Checkpoint**: The full offline walk from [quickstart.md](./quickstart.md#manual-smoke-walk) passes.

---

## Phase 11: Seed Pipeline

Independent of the client; can proceed in parallel with any user story once Phase 2 is done.

- [ ] T139 [P] Unit test — price synthesis is identical across runs for the same product id (FR-073)
- [ ] T140 [P] Unit test — excluded source categories (`groceries`, `vehicle`, `motorcycle`) never survive normalisation (FR-071)
- [ ] T141 [P] Integration test — a second seed run changes zero rows and uploads zero images (FR-072, SC-012)
- [ ] T142 [P] Integration test — `verify.py` fails loudly when a product has no image or a CDN path does not resolve (FR-074)
- [ ] T143 [P] Integration test — an `overrides.csv` entry wins over automatic image resolution (FR-076)
- [ ] T144 [P] `seed/src/dupermarket_seed/ingest/dummyjson.py` — fetch and stage
- [ ] T145 [P] `seed/src/dupermarket_seed/ingest/kaggle.py` — CSV reader for the fashion dataset
- [ ] T146 `seed/src/dupermarket_seed/normalise.py` — source taxonomy to app taxonomy, exclusions
- [ ] T147 `seed/src/dupermarket_seed/prices.py` — per-category bands, low-end bias, charm endings, RNG seeded on product id (FR-073)
- [ ] T148 [P] `seed/src/dupermarket_seed/images/pexels.py` — category-keyed pools of 20–40, throttled under 200 req/hour, cached to disk
- [ ] T149 `seed/src/dupermarket_seed/images/process.py` — resize to 300 px and 1200 px, WebP, strip EXIF, SHA-256
- [ ] T150 `seed/src/dupermarket_seed/images/r2.py` — upload to `products/{product_id}/{index}.webp`, skip when the hash matches (FR-072)
- [ ] T151 `seed/src/dupermarket_seed/verify.py` — the post-run assertions, non-zero exit on failure (FR-074)
- [ ] T152 [P] Capture attribution per image at ingest (FR-075)

---

## Phase 12: Polish & Cross-Cutting

- [ ] T153 [P] Accessibility sweep — semantic labels on every interactive element and meaningful image, verified by an automated scan (FR-068, SC-010)
- [ ] T154 [P] Contrast audit against WCAG AA; confirm no information is carried by colour alone (FR-069)
- [ ] T155 [P] Safe-area, notch, and cutout handling on every screen (FR-070)
- [ ] T156 [P] Tablet master–detail layout for the catalogue (FR-066)
- [ ] T157 [P] Skeleton loaders on every screen with a predictable layout (FR-064)
- [ ] T158 [P] Search latency benchmark in `backend/tests/performance/test_search_latency.py` — against a full-size seeded catalogue, issue a representative mix of search terms and assert p95 under 1 s, failing with the measured figure (SC-002)
- [ ] T159 [P] Cached-paint benchmark in `mobile/integration_test/perf/cached_paint_test.dart` — with warm caches and the network stubbed to never respond, assert time-to-first-content under 500 ms on the category and product-list screens (SC-003)
- [ ] T160 Structured logging with a formatter that cannot emit a card-shaped string (Principle I)
- [ ] T161 [P] `README.md` — replace the stub; document the layout and link the spec artifacts (constitution sync report flagged this)
- [ ] T162 Run `/speckit-verify` end to end and clear every finding
- [ ] T163 Full manual smoke walk from [quickstart.md](./quickstart.md#manual-smoke-walk), including the 200% font-size and screen-reader passes. This walk is where SC-001 and SC-004 are judged: time a first-time participant from app open to completed order with a stopwatch, record the figure in the release notes, and confirm no screen is a dead end

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (1)** — no dependencies
- **Foundational (2)** — depends on Setup; BLOCKS every user story. Note that T011–T015, the
  verification infrastructure, come first within this phase by design
- **US1 (3)** — depends on Phase 2. No dependency on any other story
- **US2 (4)** — depends on Phase 2
- **US3 (5)** — depends on Phase 2; needs US2 for identity and either US6 or an inline address
  capture for a delivery destination
- **US4 (6)** — depends on US3, since it tracks an order
- **US5 (7)** — depends on US3
- **US6 (8)** — depends on US2
- **US7 (9)** — depends on US3 and US4 for the timestamps it schedules from
- **US8 (10)** — depends on Phase 2; richer once US1 and US5 exist, but independently testable
- **Seed (11)** — depends on Phase 2 migrations only; parallel with everything else
- **Polish (12)** — depends on all desired stories

### Within each story

Tests first, then models, then services, then routers, then client. A story is not complete
while any of its tests fail.

### Parallel opportunities

- All `[P]` tasks within a phase touch different files and can run concurrently
- Phase 11 (seed) runs alongside Phases 3–10 entirely
- After Phase 2, US1, US2, and US8 can start simultaneously
- Every test task marked `[P]` within a story can be written at the same time

---

## Implementation Strategy

**MVP** = Phase 1 + Phase 2 + Phase 3 (US1) + enough of Phase 11 to have a catalogue. That is a
browsable shop, demoable, with no account required.

**Then**, in order: US2 (identity) → US3 (the transaction) → US4 (the payoff) → US5 → US6 → US7
→ US8. Stop and validate at each checkpoint.

**Never**: mark a phase complete with failing, skipped, or absent tests, or with
`scripts/check_traceability.py` reporting an unmapped requirement. That script is the gate, and
`/speckit-verify` runs it first.

---

## Traceability

163 tasks. Every `FR-xxx` in `spec.md` is referenced by at least one task above. The mapping is
machine-checked rather than trusted — run:

```bash
python3 scripts/check_traceability.py
```

The first run of that script against the first draft of this file found six requirements with
no task at all (FR-006, FR-009, FR-040, FR-045, FR-046, FR-048), including a missing
review-creation task for an endpoint that was already in the contract. That is the argument for
the check existing rather than the claim being asserted in prose.

Requirements with the heaviest test coverage, deliberately: FR-002 (paging stability), FR-013
(authorisation leakage), FR-027 (snapshot immutability), FR-034 (timestamp immutability),
FR-038 (clock skew), FR-072 (seed idempotency). These are the ones where a bug is silent —
nothing crashes, the data is just quietly wrong.
