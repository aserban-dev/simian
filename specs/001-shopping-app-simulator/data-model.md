# Phase 1 Data Model: Shopping App Simulator

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-08-02

PostgreSQL 16. All primary keys are `UUID` (`gen_random_uuid()`) except where a natural key is
better. All timestamps are `TIMESTAMPTZ` stored in UTC. All money is `BIGINT` in minor units of
the base currency, per [research D4](./research.md#d4-money-representation).

Conventions: `FK` = foreign key, `UQ` = unique, `IX` = index. Every table has `created_at`;
mutable tables also have `updated_at`.

---

## category

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `slug` | TEXT | UQ, NOT NULL | Stable identifier used in URLs and the seed override CSV |
| `name` | JSONB | NOT NULL | Locale map, e.g. `{"en": "Shoes", "es": "Zapatos"}` |
| `parent_id` | UUID | FK → `category.id`, NULL | NULL = top level. Self-referential, arbitrary depth (FR-001) |
| `sort_order` | INT | NOT NULL, DEFAULT 0 | |
| `image_url` | TEXT | NULL | Full public CDN URL |
| `source_key` | TEXT | UQ, NULL | Source taxonomy key, for seed idempotency (FR-072) |

- `IX category_parent_sort` on `(parent_id, sort_order)` — serves the category grid and every
  drill-down in one index.
- **Cycle guard**: a `BEFORE INSERT OR UPDATE` trigger walks `parent_id` and rejects a cycle.
  Without it, a single bad seed row makes the category tree traversal non-terminating.

## product

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | Also the RNG seed for all synthesised values (FR-073) |
| `sku` | TEXT | UQ, NOT NULL | |
| `category_id` | UUID | FK → `category.id`, NOT NULL, ON DELETE RESTRICT | Restrict, not cascade — see note |
| `title` | JSONB | NOT NULL | Locale map |
| `description` | JSONB | NOT NULL | Locale map |
| `base_price_minor` | BIGINT | NOT NULL, CHECK ≥ 0 | In `base_currency` |
| `base_currency` | CHAR(3) | NOT NULL, DEFAULT `'EUR'` | Single base currency (FR-050) |
| `discount_percentage` | NUMERIC(5,2) | NULL, CHECK 0–100 | Drives the struck-through original price |
| `rating_average` | NUMERIC(3,2) | NOT NULL, DEFAULT 0, CHECK 0–5 | Denormalised, recomputed on review write (FR-009) |
| `rating_count` | INT | NOT NULL, DEFAULT 0, CHECK ≥ 0 | |
| `stock_status` | TEXT | NOT NULL, CHECK IN (`in_stock`, `low_stock`, `out_of_stock`) | |
| `withdrawn_at` | TIMESTAMPTZ | NULL | Soft withdrawal — see note |
| `search_vector` | TSVECTOR | GENERATED, STORED | `setweight(title,'A') \|\| setweight(description,'B')` |
| `source_id` | TEXT | UQ, NULL | e.g. `dummyjson:42`. Seed idempotency key |
| `created_at` / `updated_at` | TIMESTAMPTZ | NOT NULL | |

- `IX product_search` — GIN on `search_vector` (FR-003, SC-002).
- `IX product_category_price` on `(category_id, base_price_minor, id)` — the keyset cursor for
  price-sorted browsing ([research D3](./research.md#d3-pagination-strategy)).
- `IX product_category_rating` on `(category_id, rating_average DESC, id)`.
- `IX product_created` on `(created_at DESC, id)` — "newest" sort.

**Why `ON DELETE RESTRICT` and `withdrawn_at` rather than deletion**: FR-021 requires a cart
line whose product is gone to be flagged, not to break checkout, and FR-027 requires historical
orders to stay correct. Hard-deleting a product with `order_item` rows pointing at it would
either cascade away order history or fail the delete at an arbitrary later moment. Withdrawal
is a nullable timestamp; catalogue queries filter `withdrawn_at IS NULL`, while order history
and the cart still resolve the row.

## product_image

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `product_id` | UUID | FK → `product.id`, ON DELETE CASCADE, NOT NULL | |
| `cdn_path` | TEXT | NOT NULL | Key within the R2 bucket, e.g. `products/{id}/0.webp` |
| `sort_order` | INT | NOT NULL | `0` is the thumbnail |
| `alt_text` | TEXT | NOT NULL | Generated from category + title for screen readers (FR-068) |
| `source_name` | TEXT | NOT NULL | e.g. `pexels`, `dummyjson` |
| `source_url` | TEXT | NULL | Original asset URL |
| `photographer` | TEXT | NULL | Populated when the source's terms request attribution (FR-075) |
| `content_sha256` | CHAR(64) | NOT NULL | Hash of processed bytes; drives upload skip (FR-072) |

- `UQ product_image_position` on `(product_id, sort_order)`.
- **FR-074 is enforced at the end of the seed run**, not as a table constraint: a product row
  must exist before its images can, so a NOT NULL requirement is not expressible in DDL. The
  seed's `verify.py` asserts every product has ≥ 1 image and every `cdn_path` returns 200, and
  fails the run otherwise.

## review

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `product_id` | UUID | FK → `product.id`, ON DELETE CASCADE, NOT NULL | |
| `user_id` | UUID | FK → `app_user.id`, NULL | NULL = seeded demo review |
| `rating` | SMALLINT | NOT NULL, CHECK 1–5 | |
| `comment` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

- `UQ review_one_per_user_product` on `(product_id, user_id)` WHERE `user_id IS NOT NULL` —
  enforces FR-008's one review per product, while leaving seeded reviews unconstrained.
- `IX review_product_created` on `(product_id, created_at DESC, id)` — FR-007 paging.

## app_user

Named `app_user` because `user` is reserved in Postgres.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `firebase_uid` | TEXT | UQ, NOT NULL | The `sub` claim. Canonical identity (constitution) |
| `display_name` | TEXT | NULL | From the auth provider |
| `avatar_url` | TEXT | NULL | From the auth provider |
| `language_override` | TEXT | NULL | BCP-47. NULL = follow device locale (FR-048) |
| `currency_override` | CHAR(3) | NULL | NULL = derive from device locale (FR-049) |
| `notification_prefs` | JSONB | NOT NULL, DEFAULT `'{}'` | FR-046 |
| `deletion_requested_at` | TIMESTAMPTZ | NULL | FR-017 |

**Deletion semantics (FR-017)**: setting `deletion_requested_at` does not remove anything except
the user's `device` rows, which are deleted in the same transaction so no further push can
reach them. The account stays usable and in-flight orders complete. When the request is
processed manually, `review.user_id` is set to NULL rather than the rows being deleted — the
partial unique index on `(product_id, user_id)` excludes NULLs, and keeping the rows means a
product's `rating_average` and `rating_count` stay reproducible (Principle III). Order history
survives, because `order` snapshots the address and every `order_item` snapshots its product.

There is **no** payment-related column on this table or any other. That absence is asserted by
an automated check (SC-013), because "we did not add one" is not a durable guarantee.

## address

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → `app_user.id`, ON DELETE CASCADE, NOT NULL | |
| `label` | TEXT | NULL | "Home", "Work" |
| `recipient_name`, `line1`, `line2`, `city`, `postal_code`, `country_code` | TEXT | `line1`, `city`, `country_code` NOT NULL | |
| `lat`, `lng` | DOUBLE PRECISION | NOT NULL | Resolved once at write (FR-042). NOT NULL is what makes FR-043 unavoidable |
| `is_default` | BOOLEAN | NOT NULL, DEFAULT false | |
| `deleted_at` | TIMESTAMPTZ | NULL | Soft delete, see note |

- `UQ address_one_default` on `(user_id)` WHERE `is_default AND deleted_at IS NULL` — makes
  FR-041's "exactly one default" a database invariant rather than application etiquette.
- **Soft delete because of FR-044**: an order references the address it shipped to. Deleting the
  row would either orphan or cascade the order. `order` additionally snapshots the formatted
  address text, so even a purged address leaves order history correct.

## wishlist_item

| Column | Type | Constraints |
|---|---|---|
| `user_id` | UUID | FK → `app_user.id`, ON DELETE CASCADE |
| `product_id` | UUID | FK → `product.id`, ON DELETE CASCADE |
| `created_at` | TIMESTAMPTZ | NOT NULL |

- PK is the composite `(user_id, product_id)`, which makes the add operation idempotent by
  construction (FR-045).

## order

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `order_number` | TEXT | UQ, NOT NULL | Human-facing, e.g. `DP-2026-0007413` (FR-030) |
| `user_id` | UUID | FK → `app_user.id`, NOT NULL | |
| `address_id` | UUID | FK → `address.id`, NOT NULL | |
| `address_snapshot` | JSONB | NOT NULL | Formatted address at purchase time (FR-044) |
| `total_minor` | BIGINT | NOT NULL, CHECK ≥ 0 | In `currency` |
| `currency` | CHAR(3) | NOT NULL | The user's active currency at checkout |
| `base_total_minor` | BIGINT | NOT NULL | Same total in the base currency |
| `fx_rate` | NUMERIC(18,8) | NOT NULL | The rate actually used, recorded so a historical total is reproducible |
| `origin_lat`, `origin_lng` | DOUBLE PRECISION | NOT NULL | Assigned warehouse (FR-033) |
| `destination_lat`, `destination_lng` | DOUBLE PRECISION | NOT NULL | Copied from the address at creation |
| `processing_at`, `shipped_at`, `out_for_delivery_at`, `delivered_at` | TIMESTAMPTZ | NOT NULL | All four written at creation (FR-033) |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

- `CHECK processing_at <= shipped_at <= out_for_delivery_at <= delivered_at` — a monotonic
  timeline is what makes stage derivation total.
- **Write-once trigger**: `BEFORE UPDATE` raises if any of the four stage columns, the origin,
  or the destination changes. FR-034 says the timestamps are immutable; a trigger is the only
  place that survives a future developer who has not read the spec.
- `IX order_user_created` on `(user_id, created_at DESC, id)` — FR-031 history paging.
- **No payment columns**, deliberately. `demo_card_id` is not persisted: it has no effect on a
  successful order and recording it would create the first payment-shaped column in the schema.

## order_item

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `order_id` | UUID | FK → `order.id`, ON DELETE CASCADE, NOT NULL | |
| `product_id` | UUID | FK → `product.id`, ON DELETE RESTRICT, NOT NULL | Restrict — order history outlives the catalogue entry |
| `quantity` | INT | NOT NULL, CHECK > 0 | |
| `unit_price_minor` | BIGINT | NOT NULL | Snapshot, in the order's currency |
| `title_snapshot` | TEXT | NOT NULL | Snapshot (FR-027) |
| `image_snapshot` | TEXT | NOT NULL | Full CDN URL snapshot |

The three snapshot columns are the whole point of this table. They exist so a price change or a
retitle in the catalogue cannot rewrite what a user sees they paid — which is FR-027, and which
an integration test asserts by mutating the product after the order and re-reading the order.

## device

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → `app_user.id`, ON DELETE CASCADE, NOT NULL | |
| `fcm_token` | TEXT | UQ, NOT NULL | UQ across all users, not per user — see note |
| `platform` | TEXT | NOT NULL, CHECK IN (`ios`, `android`) | |
| `last_seen_at` | TIMESTAMPTZ | NOT NULL | |

**Why the token is globally unique**: the edge case "a device registers, is signed out, and
another user signs in" is real. A token unique only per user would leave the first user's row in
place and push their order updates to the second user's device. A global unique constraint with
an upsert that reassigns `user_id` makes the second registration take ownership.

---

## Not in the database

- **Cart** — locally authoritative on the device (FR-019), stored in Drift. No server table in
  v1. Server-side sync is deferred (spec Assumptions), and adding it later is additive.
- **Demo cards** — a client-side constant list. Putting them in the database would create a
  payment-instrument table, which Principle I forbids on principle even when the contents are
  fake.
- **Parcel position** — computed on-device from `origin`, `destination`, and the window
  (FR-037). Never stored, never returned.
- **Exchange rates in v1** — a constant map inside `CurrencyService`. Phase 2 replaces the
  implementation behind the same interface (FR-051); a rates table is that change's concern.

## Entity relationship summary

```text
category ──< category (self, nullable parent)
category ──< product ──< product_image
                  └────< review >──── app_user
app_user ──< address
app_user ──< wishlist_item >──── product
app_user ──< device
app_user ──< order ──< order_item >──── product
                └──── address (+ address_snapshot)
```
