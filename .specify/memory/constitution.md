<!--
SYNC IMPACT REPORT
==================
Version change: 1.1.0 → 1.1.1 (2026-08-02)
Rationale: PATCH. The application was named **DuperMarket** in the source brief
(`claude/01_INITIAL_SPECS.md` §"app name"), and every artifact was renamed from the earlier
working placeholder to match. Naming only — no principle, obligation, or gate changed, so
this is neither MAJOR nor MINOR.

Scope of the rename: 151 occurrences across 47 files — all spec-kit artifacts, the
constitution, the API contract, the Python package (now `dupermarket_api`), the
Flutter package (now `package:dupermarket`), the container and database names,
and CI. `claude/01_INITIAL_SPECS.md` was deliberately left untouched: it is the author's brief,
not a generated artifact. The checkout directory is now `dupermarket/`, and the leftover
pre-rename checkout that sat inside it has been deleted.

---
Version change (previous): 1.0.0 → 1.1.0 (2026-08-02)
Rationale: MINOR. Materially expanded guidance in "Technology and Architecture Constraints":
the push row now states that delivery-stage notifications are scheduled on-device and that a
server-side scheduler for stage transitions is forbidden. No principle was removed or
redefined, so this is not MAJOR; it adds an obligation, so it is not PATCH.

Trigger: /speckit-analyze finding D1. FR-054 required the *system* to send a notification on
each stage change, while FR-035 and Principle III forbid any background progression — so no
component would ever observe the transition to send on. Resolved per research decision D6:
the client schedules all three notifications at order creation from the immutable timestamps.
FR-054 was reworded to state the outcome rather than the mechanism; this row records the
prohibition so nobody rebuilds the scheduler later.

Templates requiring updates for 1.1.0:
  - ✅ specs/001-shopping-app-simulator/spec.md — FR-054 reworded
  - ✅ specs/001-shopping-app-simulator/tasks.md — Phase 9 already implements the on-device
       mechanism (T122, T123, T128); no task change needed
  - ✅ specs/001-shopping-app-simulator/research.md — D6 already records the decision

---
Version change (initial): (unversioned template) → 1.0.0
Rationale: Initial ratification. All placeholder tokens replaced with concrete
principles derived from `claude/01_INITIAL_SPECS.md` (Shopping App Simulator v0.1).

Principles defined (7, template shipped 5 slots — expanded):
  - I.   Simulation Boundary (NON-NEGOTIABLE)      [new] ← specs §1.2, §6.3
  - II.  Test-First (NON-NEGOTIABLE)               [new] ← user requirement: strong verification
  - III. Determinism & Reproducibility             [new] ← specs §7.2, §17.5, §19.4
  - IV.  Never a Dead End                          [new] ← specs §12, §13
  - V.   Single Seam per Cross-Cutting Concern     [new] ← specs §8.3, §9, §5.1
  - VI.  Offline-First, Cache-Then-Network         [new] ← specs §11
  - VII. Accessible and Adaptive by Default        [new] ← specs §14, §14.1

Sections added:
  - Technology and Architecture Constraints (was [SECTION_2_NAME])
  - Development Workflow and Quality Gates (was [SECTION_3_NAME])
  - Governance

Sections removed: none.

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md — "Constitution Check" gate satisfied by the
       Constitution Check table this document mandates; no template edit required.
  - ✅ .specify/templates/spec-template.md — mandatory sections (User Scenarios & Testing,
       Requirements, Success Criteria, Assumptions) already align with Principles II and IV.
  - ✅ .specify/templates/tasks-template.md — tests-before-implementation ordering already
       present; Principle II promotes it from OPTIONAL to MANDATORY for this project. Tasks
       generated for this project MUST NOT treat test tasks as optional.
  - ✅ .claude/skills/speckit-*/SKILL.md — reviewed; agent-generic wording, no stale
       agent-specific references found. Note: this integration invokes skills with a hyphen
       separator (`/speckit-plan`), not a dot (`/speckit.plan`).
  - ✅ README.md — rewritten from the repo-init stub; documents the workflow, the gates, and
       the two non-negotiable principles.

Deferred TODOs: none. RATIFICATION_DATE set to the date of this initial adoption.
-->

# DuperMarket Shopping App Simulator Constitution

## Core Principles

### I. Simulation Boundary (NON-NEGOTIABLE)

No real money moves, no real payment instrument is ever accepted, and no real goods are
shipped. Concretely:

- The system MUST NOT collect, transmit, log, or persist user-entered card data. Payment
  selection is limited to a hardcoded, cosmetic demo card set (including at least one
  card that deterministically exercises the decline path).
- The system MUST NOT integrate a payment processor, acquirer, or fulfilment provider.
- Delivery progression MUST be simulated from timestamps assigned at order creation; no
  courier feed, no logistics integration.
- Any change that would move the project across this boundary is a MAJOR constitutional
  amendment, not a feature.

**Rationale**: Staying outside PCI-DSS scope and outside GDPR obligations for payment data
is the single largest risk reduction available to this project, and it is free as long as
the boundary is never crossed. It is cheap to hold and expensive to reinstate.

### II. Test-First (NON-NEGOTIABLE)

Tests are written before the implementation they cover, are observed to fail, and only then
is production code written. Specifically:

- Every functional requirement (`FR-xxx`) MUST be traceable to at least one automated test.
  Traceability is machine-checked, not asserted in prose.
- Every API endpoint in the published contract MUST have a contract test asserting status
  codes, response shape, and auth enforcement.
- Every user story MUST have an integration test that exercises it end-to-end and can be run
  in isolation from the other stories.
- A task is not "done" while its tests are failing, skipped, or absent.
- Task ordering in `tasks.md` MUST place test tasks before the implementation tasks they
  cover. The upstream tasks template marks test tasks OPTIONAL; for this project they are
  MANDATORY and that default is overridden.

**Rationale**: The requested outcome for this project is strong verification. Verification
bolted on afterwards measures what was built; verification written first measures what was
specified.

### III. Determinism and Reproducibility

Identical inputs MUST produce identical outputs across runs, machines, and clock time where
the domain permits it.

- Seed pipelines MUST be idempotent: re-running MUST NOT duplicate rows or re-upload
  unchanged assets. Keying is on stable source IDs.
- Synthesised data (prices, review text, image assignment) MUST derive from an RNG seeded
  with the product ID, so a given product always yields the same values.
- Delivery stage timestamps MUST be assigned once, at order creation, and stored. Present
  stage is a pure function of stored timestamps and current time. No background jobs, no
  cron, no server-held parcel position.
- Tests MUST NOT depend on wall-clock time; time MUST be injectable.

**Rationale**: Determinism is what makes a simulation testable at all. It converts "looks
plausible" into "asserts equal".

### IV. Never a Dead End

Every failure state and every empty state MUST tell the user what happened and offer a way
forward.

- Raw errors, stack traces, and bare status codes MUST NOT reach the UI.
- Failure types MUST be distinguished and handled separately: no connectivity, backend
  unreachable, backend error response, single asset failed.
- Every error state MUST offer a retry or an alternative action.
- Degradation MUST be local: one broken image shows a placeholder and MUST NOT break the
  grid around it.
- Every empty state MUST carry an illustration, a line of human copy, and a primary action.
- Messaging is inline and unobtrusive by default; modal dialogs require justification.

**Rationale**: This is a demo app whose entire value is perceived polish. Error and empty
states are where unpolished apps reveal themselves, and they are cheap to get right if
treated as requirements rather than afterthoughts.

### V. Single Seam per Cross-Cutting Concern

Each cross-cutting concern MUST be reachable through exactly one interface, so that swapping
its implementation is a one-file change.

- Currency conversion MUST go through one currency service. Callers MUST NOT know whether
  rates are hardcoded or fetched live. Prices are stored once in a single base currency and
  converted at display time only.
- Geocoding MUST happen once, at address save time, and the coordinates are stored. No
  read-path geocoding.
- Image bytes MUST be served to clients directly from the CDN. The backend stores paths and
  MUST NOT proxy image bytes.
- Route rendering MUST go through one interface so a straight-line interpolation can later be
  replaced by a real road route without a data-model change.

**Rationale**: Each of these has a known, planned future upgrade. Naming the seam now is the
difference between a one-file change and a migration.

### VI. Offline-First, Cache-Then-Network

The UI renders from cache immediately, then refreshes in the background and updates.

- Catalogue, product images, and order history MUST be viewable offline from last known
  state. The cart MUST be fully usable offline and is locally authoritative.
- Checkout is the sole exception: it requires connectivity, MUST NOT be queued offline, and
  the user MUST be told so explicitly rather than failing silently.
- Cached catalogue data MUST carry a TTL; pull-to-refresh MUST force a fetch.
- Sign-out MUST clear all user-scoped caches (orders, addresses, wishlist). The public
  catalogue cache MAY be retained.

**Rationale**: Perceived speed comes from never showing a spinner where cached content
exists. Naming the one exception prevents "offline-capable" from being quietly interpreted
as "offline checkout".

### VII. Accessible and Adaptive by Default

Accessibility and responsiveness are acceptance criteria, not polish tasks.

- Text MUST scale with the OS font-size setting and remain usable at 200%. Hardcoded font
  sizes that clip or overflow at that scale are defects.
- Interactive elements and meaningful images MUST carry semantic labels for screen readers.
- Colour MUST NOT be the sole carrier of meaning, and contrast MUST meet WCAG AA.
- Minimum touch target sizes MUST be respected.
- Layout MUST switch at breakpoints (phone grid ≈2 columns, tablet 4–5, tablet master–detail)
  rather than scaling a fixed phone design. Portrait and landscape are both supported on
  tablet. Safe areas, notches, and dynamic island MUST be respected.

**Rationale**: Retrofitting accessibility means rewriting layout code. Declaring it as an
acceptance criterion costs nothing at design time.

## Technology and Architecture Constraints

The stack below is fixed for v1. Substitutions require a constitutional amendment.

| Layer | Choice |
|---|---|
| Mobile client | Flutter (latest stable), `ios` + `android` flavors, `dev`/`staging`/`prod` envs |
| Authentication | Firebase Authentication (Google, Facebook, Apple) |
| Push | Firebase Cloud Messaging (APNs auth key uploaded to Firebase for iOS). Delivery-stage notifications are scheduled **on-device** from the immutable stage timestamps; FCM carries promotional sends and offline catch-up only. A server-side scheduler for stage transitions is forbidden — it would contradict Principle III |
| Backend | Python + FastAPI, acting as an OAuth2 resource server |
| Database | PostgreSQL |
| Image CDN | Cloudflare R2, public URLs |
| Maps | Google Maps Flutter SDK |
| Hosting | Azure |

Additional binding constraints:

- **Identity**: The Firebase UID is the canonical user identity. The backend MUST NOT issue
  its own session tokens. Every non-public request carries `Authorization: Bearer <Firebase
  ID token>`, validated against Firebase JWKS with issuer, audience, and expiry checks. User
  rows are lazily provisioned on first authenticated call.
- **Order line items** MUST snapshot `title`, `unit_price_at_purchase`, and `image` so
  historical orders stay correct when the catalogue changes.
- **Public catalogue reads** are the only unauthenticated endpoints; everything else requires
  a valid token, and that MUST be asserted by a contract test per endpoint.
- **Image licensing**: Assets re-hosted on R2 MUST come from a source whose terms permit
  re-hosting (Pexels, Pixabay, Burst). Unsplash is excluded because its API terms require
  hotlinking. Photographer attribution MUST be captured per image at ingest and surfaced in
  an in-app credits screen.
- **Cost discipline**: Geocoding is metered, so addresses are geocoded once on write. R2 has
  no egress fees, which is why images bypass the backend. These two facts are the reason for
  the corresponding rules in Principle V and MUST NOT be optimised away.

## Development Workflow and Quality Gates

The Spec Kit workflow is the development process for this repository:

`/speckit-constitution` → `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` →
`/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → `/speckit-verify`

Gates, in order, each blocking the next:

1. **Spec gate** — `spec.md` passes its requirements checklist; no unresolved
   `[NEEDS CLARIFICATION]` markers remain.
2. **Plan gate** — `plan.md` includes a Constitution Check table with an explicit pass/fail
   line per principle. Any failure is recorded in Complexity Tracking with the simpler
   alternative that was rejected and why. An unjustified failure blocks the plan.
3. **Task gate** — every task names concrete file paths; test tasks precede the
   implementation they cover.
4. **Analysis gate** — `/speckit-analyze` reports zero CRITICAL findings before
   implementation begins.
5. **Verification gate** — `/speckit-verify` passes: full test suite green, every `FR-xxx`
   mapped to at least one passing test, every contract endpoint covered, seed-pipeline
   assertions satisfied.

Additional rules:

- Changes to the published API contract MUST update `contracts/` in the same change as the
  implementation, and the contract test MUST be updated first.
- Complexity MUST be justified in writing. "We might need it later" is not a justification;
  a named, dated requirement is.
- Any deviation discovered during implementation MUST be reflected back into `spec.md` or
  `plan.md` rather than left as an undocumented divergence.

## Governance

This constitution supersedes all other development practices in this repository. Where a
skill, template, or convention conflicts with it, the constitution wins and the conflicting
artifact MUST be updated.

**Amendment procedure**: Amendments are proposed as a diff to this file accompanied by a
rationale and, where the change invalidates existing artifacts, a migration note. An
amendment is adopted when merged. Every amendment MUST update the Sync Impact Report at the
top of this file and the version line at the bottom.

**Versioning policy** (semantic):

- **MAJOR** — a principle is removed or redefined in a backward-incompatible way, or the
  Simulation Boundary is altered.
- **MINOR** — a principle or section is added, or existing guidance is materially expanded.
- **PATCH** — clarifications, wording, and typo fixes that do not change obligations.

**Compliance review**: Every plan MUST carry a Constitution Check table. Every review MUST
verify compliance against it. `/speckit-analyze` MUST flag any requirement, task, or design
decision that contradicts a principle as a CRITICAL finding. Runtime development guidance for
agents lives in `CLAUDE.md`; it MUST NOT contradict this document.

**Version**: 1.1.1 | **Ratified**: 2026-08-02 | **Last Amended**: 2026-08-02
