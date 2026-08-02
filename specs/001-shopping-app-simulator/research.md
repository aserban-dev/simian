# Phase 0 Research: Shopping App Simulator

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-08-02

Every decision below was a `NEEDS CLARIFICATION` in the Technical Context before this phase.
None remain open. Each entry states the decision, why, and what was rejected.

---

## D1. How the backend verifies Firebase ID tokens

**Decision**: Verify tokens in-process with `PyJWT`, against Google's public keys fetched from
the JWKS endpoint and cached in memory until their `Cache-Control` max-age expires. Assert
`iss == https://securetoken.google.com/<project-id>`, `aud == <project-id>`, `exp` in the
future, and a non-empty `sub`. The `sub` claim is the Firebase UID and is the primary key
relationship for every user-scoped row.

**Why**: Constitution says the backend is a resource server that mints nothing. Local JWKS
verification is a signature check plus three string comparisons — no network call on the hot
path once the key set is cached, and no dependency on Firebase being reachable per request.

**Rejected**:

- *`firebase-admin` SDK `verify_id_token()`* — works, but pulls in a large transitive
  dependency tree for one function, and its optional revocation check makes a network call per
  request. Revocation is not a requirement here.
- *Calling Google's tokeninfo endpoint per request* — a network round trip on every API call.
  Unacceptable against the p95 target.

**Testing consequence**: the verification function is injected via `deps.py`, so tests
substitute a fake that maps a header value straight to a UID. No test needs a real Firebase
project. One unit test suite covers the real verifier against locally generated keys, including
expired, wrong-audience, wrong-issuer, and tampered-signature cases.

---

## D2. Search implementation

**Decision**: PostgreSQL full-text search. A generated `tsvector` column over
`setweight(to_tsvector(title), 'A') || setweight(to_tsvector(description), 'B')`, with a GIN
index, ranked by `ts_rank_cd`. Language configuration selected per row from the product's
locale, defaulting to `simple` for mixed content.

User input is parsed with **`websearch_to_tsquery`**, never `to_tsquery` or `plainto_tsquery`.

**Why**: The source specification says explicitly that this is sufficient at this scale, and
the assumed catalogue ceiling is tens of thousands of rows. Title weighting above description
gives the ordering users expect while still satisfying FR-003's requirement that
description-only matches appear.

**Why `websearch_to_tsquery` specifically**: `to_tsquery` raises a syntax error on unbalanced
parentheses, bare operators, and punctuation-only input — a 500 for anyone who types `(` or
`C++`, which is a raw error reaching the user and a Principle IV violation.
`websearch_to_tsquery` never raises: it accepts the Google-ish syntax users already expect
(quoted phrases, `OR`, leading `-`) and treats everything else as literal text. This is the
parser-level half of FR-003; T041 asserts it with hostile input.

**Rejected**:

- *Elasticsearch / OpenSearch / Meilisearch* — a second datastore to run, seed, keep in sync,
  and back up, for a catalogue that fits comfortably in one Postgres index. Violates the
  complexity-must-be-justified rule.
- *`ILIKE '%term%'`* — cannot rank, cannot stem, and forces a sequential scan. Fails SC-002 at
  catalogue scale.

---

## D3. Pagination strategy

**Decision**: Keyset (cursor) pagination. The cursor encodes the active sort key plus the
product ID as a tiebreaker, base64-encoded and opaque to clients. Offset pagination is not
offered.

**Why**: FR-002 requires a stable order across pages with nothing duplicated or skipped. With
offset pagination, a row inserted or a rating updated between page fetches shifts the window
and silently drops a product — precisely the failure FR-002 forbids. Keyset pagination is also
what makes infinite scroll cheap at depth, since it never scans skipped rows.

**Rejected**:

- *`LIMIT`/`OFFSET`* — simpler to write, but breaks FR-002 and degrades at deep offsets.
- *Snapshot/point-in-time tokens* — solves stability but requires server-side state per
  scroll session. Not warranted.

**Testing consequence**: an integration test pages through a category while concurrently
inserting a product that sorts into an already-served page, and asserts no duplicate or missing
ID across the full traversal.

---

## D4. Money representation

**Decision**: Store money as an integer count of minor units (`BIGINT`) in a single base
currency, alongside a three-letter currency code column. Never `FLOAT`, never `DOUBLE`. In
Python, convert to `Decimal` only at the presentation boundary. In Dart, keep integers and
format with `intl`'s `NumberFormat.currency`.

**Why**: Binary floating point cannot represent `0.10`, and charm pricing (§17.5 of the source
spec) makes `.99` and `.49` endings ubiquitous — exactly the values that accumulate error. An
integer subtotal is exact and comparable, which SC-008's determinism requirement depends on.

**Rejected**:

- *`NUMERIC(10,2)`* — exact in the database, but drivers hand it back as a float in several
  client paths, and it invites arithmetic in SQL that the currency seam is supposed to own.
- *Floats* — never correct for money.

**Rounding rule**: conversion multiplies the base minor-unit integer by a rate expressed as a
`Decimal`, then rounds half-up to the target currency's minor unit. The rule lives in
`CurrencyService` and nowhere else (Principle V).

---

## D5. Delivery window generation and warehouse assignment

**Decision**: At order creation, pick the nearest warehouse from a fixed table of fictional
warehouse coordinates by great-circle distance to the destination. Then assign:
`processing_at = now`, `shipped_at = now + 6h`, `out_for_delivery_at = now + 54h`,
`delivered_at = now + 60h`, jittered deterministically by hashing the order ID so two orders
placed in the same second do not look cloned. All four are written in the same transaction as
the order and the columns are never updated afterwards.

**Why**: FR-033 through FR-035 require the whole timeline up front with no background job. A
fixed base window with ID-derived jitter is deterministic (Principle III) yet not obviously
synthetic. Nearest-warehouse selection keeps the map line short enough to look real.

**Rejected**:

- *Distance-proportional windows* — more realistic, but makes the expected timeline a function
  of geocoding output, so tests would have to recompute distances to assert stages. The
  realism gain does not pay for the test complexity.
- *Random jitter from an unseeded RNG* — breaks Principle III outright.

**Enforcement**: a database-level rule (trigger or check on an `UPDATE` guard) rejects changes
to the four stage columns after insert, so FR-034 cannot be violated by application code that
forgets.

---

## D6. Delivery-stage notifications without a scheduler

**Decision**: Schedule **local** notifications on-device at order creation, computed from the
four stage timestamps returned by `POST /orders`. Firebase Cloud Messaging is retained for
promotional pushes and for a "your order shipped" nudge to devices that were offline when the
local notification would have fired. The server dispatches no per-stage push.

**Why**: This was the one real tension between the source specification and its own
constraints. §10 requires a notification at each stage change; §7.2 forbids background jobs,
cron, and any server-side progression. A server cannot push on a transition it never observes.
Because the client already knows all four timestamps the moment the order is created, and
because those timestamps are immutable (FR-034), the device can schedule all three
notifications immediately with no server involvement. This is more robust than a scheduler — it
survives backend downtime entirely — and it keeps the server stateless with respect to delivery,
which is what §7.3 asks for.

**Rejected**:

- *A cron job or Azure timer function scanning for due transitions* — directly contradicts
  §7.2, adds a stateful component, and needs its own idempotency ledger to satisfy FR-054's
  "at most once per stage per order".
- *Push on next API read* — only fires if the user opens the app, which defeats the purpose.

**Consequence for the spec**: FR-054 is satisfied, but the mechanism differs from the "Firebase
Cloud Messaging for both platforms" reading of §10. Recorded here rather than silently
implemented, and raised as a finding in [analysis-report.md](./analysis-report.md) so the
divergence is a decision rather than a surprise.

**Testing consequence**: the scheduling function is pure — `(order, now) -> List<ScheduledNotification>` —
and unit-testable without a device. FR-054's once-per-stage guarantee is asserted by scheduling
twice with the same order and expecting deduplication by a stable notification ID derived from
`order_id + stage`.

---

## D7. On-device cache store

**Decision**: Drift (SQLite).

**Why**: The cache has to answer queries, not just fetch by key — "products in category X,
sorted by price, page 2" must be servable from cache to satisfy FR-057 for the offline case.
That is a relational query. Drift also gives typed schema migrations, which matters for the
"cache from an older app version" edge case: a schema version bump drops and rebuilds rather
than deserialising garbage.

**Rejected**:

- *Hive* — faster for pure key-value access and simpler to set up, but filtering and sorting a
  cached category would mean loading every product into memory and sorting in Dart.
- *`shared_preferences`* — not a database; unsuitable for anything beyond the currency and
  language overrides, which is in fact what it will be used for.

---

## D8. Client state management

**Decision**: Riverpod, with repositories exposed as providers returning a
cached-then-fresh stream.

**Why**: The cache-then-network requirement (FR-057) is naturally expressed as a stream that
emits twice — once from cache, once from network. Riverpod's `StreamProvider` plus
`AsyncValue` models loading, data, and typed error states directly, which maps onto the
`AppFailure` taxonomy FR-059 requires without a hand-rolled state enum per screen.

**Rejected**:

- *BLoC* — equally capable; more boilerplate per feature for the same result on a project with
  roughly twenty screens.
- *`setState` / `InheritedWidget` alone* — no answer for cross-screen cache invalidation on
  sign-out (FR-016).

---

## D9. Image pipeline: sourcing, processing, and idempotency

**Decision**: Prefer the image the source data already provides (DummyJSON, Kaggle) since it
genuinely matches the product. Fall back to a per-category Pexels pool of 20–40 images dealt
round-robin, keyed by an RNG seeded on product ID. Process every image to WebP at two sizes —
300 px thumbnail, 1200 px detail — strip EXIF, and upload to
`products/{product_id}/{index}.webp`. Idempotency is by content hash: store the source URL and
the SHA-256 of the processed bytes on `product_image`, and skip the upload when both match.
`seed/src/dupermarket_seed/overrides.csv` is applied last and wins over everything.

**Why**: This is FR-072 through FR-076 read literally. Content hashing rather than
"does the key exist" means a changed source image is re-uploaded while an unchanged one is not,
which is what SC-012 measures. Pexels is the fallback source because its terms permit
re-hosting, which §5.1 requires; Unsplash is excluded because its API terms require hotlinking.

**Rejected**:

- *Resolving images by product title search* — "Essence Mascara Lash Princess" returns nothing
  usable. Category-keyed queries return usable stock shots. This is the source spec's own
  finding (§19.1) and it holds.
- *Skipping upload when the R2 key exists* — cheaper, but never picks up a corrected source
  image, and cannot distinguish "already correct" from "uploaded broken last time".

---

## D10. Contract testing approach

**Decision**: Two complementary suites, both driven from `contracts/openapi.yaml`. Schemathesis
generates property-based cases per operation and asserts responses validate against the declared
schemas. Alongside it, explicit hand-written tests cover the authorisation matrix: for every
non-public operation, an anonymous request expecting 401, and a request from user B for user A's
resource expecting 404 rather than 403.

**Why**: Property-based testing is excellent at finding shapes the schema does not describe and
useless at finding authorisation holes, because it has no notion of two users. The two together
satisfy SC-006's "success, failure, and unauthenticated access" for every operation.

**404-not-403 note**: FR-013 requires not leaking whether a resource exists. Returning 403 for
someone else's order confirms the order ID is real. 404 does not.

**Rejected**:

- *Hand-written contract tests only* — will drift from the OpenAPI document, and the document
  is the thing `/speckit-verify` checks against.
- *Schemathesis only* — no cross-user coverage; would pass with a completely broken
  authorisation layer.

---

## D11. Test database strategy

**Decision**: A real PostgreSQL instance for integration and contract tests, one transactional
schema per test, rolled back after each. Locally it comes from `docker-compose.yml`; in CI it is
a service container.

**Why**: The design leans on Postgres-specific behaviour — `tsvector` ranking, GIN indexes,
keyset pagination ordering semantics, and the write-once trigger on delivery timestamps. None
of it exists in SQLite, so an SQLite test suite would pass while the production query path was
broken.

**Rejected**:

- *SQLite in-memory* — fast, but tests the wrong database.
- *Mocking the repository layer* — leaves every query in the system untested.

---

## D12. Time injection

**Decision**: A `Clock` protocol resolved through FastAPI dependency injection, with a
`FrozenClock` used in tests. No production code calls `datetime.now()` directly; a lint rule
forbids it outside `deps.py`. On the client, the same shape via an injected `DateTime Function()`.

**Why**: Principle III requires tests not to depend on wall-clock time, and the delivery
simulation is entirely a function of time. Without injection, "assert stage is `shipped` six
hours after creation" becomes an untestable sleep.

**Rejected**:

- *`freezegun` and equivalents* — patches globals, works, but hides the dependency and does not
  extend to the Dart client. Explicit injection makes the same idea work on both sides.

---

## D13. Sign-up as a distinct flow from sign-in

**Decision**: Present sign-up and sign-in as two entry points over the *same* provider
authorisation call. Firebase's `additionalUserInfo.isNewUser` flag decides which happened, and
drives the first-run welcome. Critically, on the sign-up path the client **captures the display
name from the provider response and writes it to the profile immediately**, via `PATCH /me`.

**Why**: With social providers there is no separate registration to implement — the same OAuth
round trip both creates and returns an account. Treating them as identical is tempting, and it
is wrong for one concrete reason:

> **Apple returns the user's full name only on the very first authorisation.** Every subsequent
> sign-in returns the identity token with no name at all. An app that reads the name lazily
> "next time" never gets one, and the user is stuck as an unnamed account forever unless they
> revoke the app in iOS Settings and re-authorise.

Facebook and Google return the profile on every sign-in, so they forgive the mistake. Apple does
not, and Apple is mandatory on iOS whenever another social provider is offered. That single
asymmetry is what makes sign-up a real flow rather than a label on a button.

**Consequences**:

- `PATCH /me` accepts `display_name` (contract change). Without it there is no way to record a
  name the client learned but the backend never saw — the ID token does not carry it.
- Lazy provisioning (FR-014) is unchanged and still the mechanism that creates the row. Sign-up
  is a *client-side* distinction plus one write; the backend does not need a separate endpoint.
- A returning sign-in that carries no name must not clobber the stored one (FR-081). The
  provisioning code already guards this — it only overwrites when the incoming value is
  non-empty — and a test asserts it.
- Apple's "Hide My Email" means the email may be a private relay address. Nothing in this system
  keys on email (the Firebase UID is canonical), so no further handling is needed. Recorded so
  nobody later adds an email-keyed lookup and is surprised.

**Rejected**:

- *A dedicated `POST /users` sign-up endpoint* — duplicates what lazy provisioning already does,
  and creates a second code path that can disagree with the first about how an account comes
  into existence.
- *Reading the Apple name from the ID token on every sign-in* — it simply is not there after the
  first authorisation. This is the failure mode the decision exists to prevent.

**Testing consequence**: the name-capture rule is unit-testable without Apple — provision a user
with a name, then provision again with the same UID and no name, and assert the stored name
survives. That is task T164.
