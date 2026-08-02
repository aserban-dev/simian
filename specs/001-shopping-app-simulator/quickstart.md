# Quickstart: Shopping App Simulator

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-08-02

How to bring the stack up, seed it, and run every layer of verification. Written to be
followed top to bottom on a clean machine.

> **Status**: the harness in `backend/tests/`, `scripts/`, and `.github/workflows/` exists and
> runs today. Application code under `backend/src/`, `mobile/`, and `seed/` is produced by
> `/speckit-implement` — until then the contract and traceability checks run and report
> honestly on what is missing rather than pretending to pass.

---

## Prerequisites

| Tool | Version | Check |
|---|---|---|
| Python | 3.12+ | `python3 --version` |
| uv | 0.5+ | `uv --version` |
| Docker | 24+ | `docker compose version` |
| Flutter | latest stable | `flutter --version` |
| Firebase project | — | Auth + Cloud Messaging enabled |
| Cloudflare R2 bucket | — | Public access enabled |
| Google Maps API key | — | Maps SDK for iOS/Android + Geocoding API |
| Pexels API key | — | Free, issued instantly, seed only |

Secrets go in `.env` (git-ignored). `.env.example` lists every variable with a safe default or a
placeholder; the API refuses to start with an unset required variable rather than failing later
at first use.

---

## 1. Bring up the datastore

```bash
docker compose up -d postgres
docker compose ps          # expect postgres healthy
```

## 2. Backend

```bash
cd backend
uv sync                                   # installs runtime + dev dependencies
uv run alembic upgrade head               # apply migrations
uv run uvicorn dupermarket_api.main:app --reload --port 8000
```

Sanity check, no auth required:

```bash
curl -s localhost:8000/v1/categories | head
```

## 3. Seed the catalogue

```bash
cd seed
uv sync
uv run python -m dupermarket_seed --source dummyjson --limit 200      # fast smoke seed
uv run python -m dupermarket_seed --source dummyjson --source kaggle  # full run
```

The run ends with its own verification pass (FR-074): every product has at least one image and
every stored CDN path returns 200. It exits non-zero and prints the offending product IDs if
either fails — a partially seeded catalogue is a failed seed, not a warning.

Re-run it. The second run must report zero rows changed and zero images uploaded (SC-012). That
is the idempotency assertion, and it is worth running by hand once before trusting CI to do it.

## 4. Mobile client

```bash
cd mobile
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

On a simulator, `localhost` is not the host machine. Set `API_BASE_URL` in
`mobile/.env.dev` to `http://10.0.2.2:8000/v1` for the Android emulator, or your machine's LAN
address for a physical device.

---

## Verification

Six layers, matching the Verification Strategy in [plan.md](./plan.md#verification-strategy).
`/speckit-verify` runs all of them in order and stops at the first failing layer.

### Layer 1 — Unit (backend)

```bash
cd backend && uv run pytest tests/unit -v
```

No database, no network, clock injected. Covers currency conversion and its fallback,
stage derivation, elapsed-fraction clamping, and price-synthesis determinism.

### Layer 2 — Contract

```bash
cd backend
uv run pytest tests/contract -v                      # explicit auth-matrix tests
uv run schemathesis run ../specs/001-shopping-app-simulator/contracts/openapi.yaml \
    --url http://localhost:8000/v1 --checks all      # property-based
```

The explicit suite is the one that matters most: for each of the 19 operations it asserts the
declared status codes, and for each non-public operation it asserts `401` anonymously and `404`
— not `403` — for another user's resource.

Validate the contract document itself:

```bash
uvx --from openapi-spec-validator openapi-spec-validator \
    specs/001-shopping-app-simulator/contracts/openapi.yaml
```

### Layer 3 — Integration (one module per user story)

```bash
cd backend && uv run pytest tests/integration -v
uv run pytest tests/integration/test_us3_checkout.py -v    # a single story in isolation
```

Each module is the executable form of one story's "Independent Test" from `spec.md`. They run
against a disposable Postgres, one transactional schema per test, rolled back afterwards.

### Layer 4 — Client

```bash
cd mobile
flutter analyze
flutter test                                  # everything host-side: unit, widget, goldens
flutter test --update-goldens                 # only when a layout change is intended
flutter test integration_test/ -d <device>    # P1–P4 journeys against a running backend
```

**Layout convention.** `mobile/test/` mirrors `mobile/lib/`, one directory per area
(`test/core/`, `test/catalogue/`, …), plus `test/goldens/`. `mobile/integration_test/` holds
only what needs a device: one driver per user story, plus `integration_test/perf/` for
benchmarks. So `flutter test` with no arguments is always the whole host-side suite — never
pass it a path list, because a mistyped path reports "no tests ran" as success.

Goldens cover a matrix of three layouts (phone portrait, tablet portrait, tablet landscape) at
two text scales (1.0×, 2.0×). The 2.0× goldens are the ones that catch FR-067 regressions;
review them by eye when they change, since a golden that updates silently proves nothing.

### Layer 5 — Seed verification

```bash
cd seed && uv run python -m dupermarket_seed.verify        # assert-only, no writes
uv run pytest tests -v
```

### Layer 6 — Traceability and simulation boundary

```bash
uv run python scripts/check_traceability.py
```

Two checks, both blocking:

1. **Traceability** — parses every `FR-xxx` from `spec.md`, scans the test tree for `FR-xxx`
   markers in test names and docstrings, and fails listing any requirement with no test
   (SC-005). Tests reference requirements like this:

   ```python
   def test_declined_card_leaves_cart_intact():
       """FR-025: a declined checkout creates no order and preserves the cart."""
   ```

2. **Simulation boundary** — greps the schema, source, and log formatters for card-number-shaped
   literals, PAN-like field names (`card_number`, `cvv`, `cvc`, `expiry`), and payment-processor
   imports (`stripe`, `braintree`, `adyen`, `paypal`, `square`). Any hit fails the build
   (SC-013). Principle I is the project's cheapest guarantee and the easiest to erode by
   accident; this is what keeps it true.

### Everything at once

```bash
uv run python scripts/check_traceability.py \
  && (cd backend && uv run pytest) \
  && (cd seed && uv run pytest) \
  && (cd mobile && flutter test)
```

CI runs exactly this on every push — see `.github/workflows/ci.yml`.

---

## Manual smoke walk

Automated tests do not judge whether the simulation *looks* convincing. Once per release, walk
this by hand:

1. Open the app signed out. Browse a category, filter, sort, search, open a product. Every tile
   has an image; nothing shows a raw error.
2. Sign in with each provider. Confirm name and avatar.
3. Add three items, change a quantity, remove one. Watch the subtotal.
4. Check out with `decline`. Confirm the cart survives intact and the message offers another
   card.
5. Check out with `visa_success`. Note the order number and window.
6. Open the order. The map shows origin, destination, route, and a marker part-way along.
7. Turn off the network. Walk the whole app again. Cached content renders; the offline banner
   appears; checkout refuses with an explanation rather than hanging.
8. Set the OS font size to maximum. Walk the app again. Nothing clips or overlaps.
9. Turn on the screen reader. Confirm every control announces something meaningful.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Every authenticated call returns 401 | Firebase project ID mismatch between client and API | `FIREBASE_PROJECT_ID` in `.env` must equal the client's project |
| 401 only after ~an hour | Client is not refreshing the ID token | Fetch the token per request through the SDK; do not cache it yourself |
| Images 404 from the app but the seed passed | R2 bucket is not public | Enable public access, or check the custom domain binding |
| Seed run exits non-zero at the verify step | A product got no image | Add a row to `seed/src/dupermarket_seed/overrides.csv` and re-run; it is idempotent |
| Integration tests hang | Postgres container not up | `docker compose up -d postgres` |
| Golden tests fail on CI but pass locally | Font rendering differs across platforms | Run goldens only on the CI platform, or check in platform-specific goldens |
| `check_traceability.py` fails on a new FR | The requirement has no test yet | Write the test first — that is the point (Principle II) |
