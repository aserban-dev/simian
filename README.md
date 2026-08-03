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
| `backend/` | FastAPI resource server — all 19 contract operations |
| `mobile/` | Flutter client — catalogue, auth, cart, checkout, delivery map, history, profile |
| `seed/` | Catalogue seed pipeline — ingest, normalise, price, images, verify |

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

Status: phases 1–12 implemented. The API contract is fully covered (19/19 operations) and the
traceability gate passes. What remains needs credentials or a device — see
**[What is not done](#what-is-not-done)**.

## Running it

```bash
docker compose up -d postgres          # the database the integration tests need

cd backend && uv sync --extra dev
uv run alembic upgrade head
uv run uvicorn dupermarket_api.main:create_app --factory --reload

cd ../mobile && flutter pub get && flutter run
```

`.env.example` lists every variable. The API refuses to start with a required one missing.

## Verification

```bash
python3 scripts/check_traceability.py     # requirement coverage + the simulation boundary
cd backend && uv run pytest tests -q      # unit, contract and integration
cd backend && uv run pytest -m performance -q   # search-latency benchmark (SC-002)
cd seed    && uv run --extra dev pytest -q
cd mobile  && flutter test && flutter analyze
```

Benchmarks are excluded from the default backend run: they seed thousands of rows, and a suite
people skip because it is slow protects nothing.

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

## What is not done

Everything below needs a credential or a physical device, and none of it is stubbed out
pretending otherwise. Each is recorded against its task in
[tasks.md](specs/001-shopping-app-simulator/tasks.md).

| Area | Why it is outstanding |
|---|---|
| Firebase sign-in | No Firebase project. `AuthGateway` is implemented and tested behind a fake; `Firebase.initializeApp()` is deliberately not called, since it crashes without config |
| Google Maps rendering | No Maps API key. The map's geometry — markers, polyline, parcel position — is asserted; the platform view cannot render in a test |
| Local notifications | No plugin wired. The scheduling rules are pure functions behind `NotificationPlatform` and fully tested |
| Live geocoding | No API key. `FixedTableGeocoder` resolves the cities this demo ships to and declines the rest, which keeps FR-043's rejection path reachable |
| Pexels image pools | `PEXELS_API_KEY` is unset. `images/openverse.py` is a keyless alternative that carries a per-image licence |
| R2 upload | No bucket credentials. The uploader is exercised against a recording stand-in, including the zero-upload re-run |
| Cached-paint benchmark, manual smoke walk | Need a running app on a device |

The seed pipeline's image stages *have* been run on real bytes: images downloaded, processed to
WebP with EXIF stripped, hashed, and re-run to confirm the second pass uploads nothing.
