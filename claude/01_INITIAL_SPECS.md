# Shopping App Simulator — Specification
## app name: DuperMarket

**Version:** 0.1 (draft)
**Date:** 1 August 2026
**Status:** Feature exploration complete, ready for technical design

---

## 1. Overview

A Temu-style mobile shopping application that **simulates** the full e-commerce experience without processing real transactions. Users browse a large product catalogue organised by category, add items to a basket, "pay" at checkout using pre-filled demo cards, and track a simulated delivery to their address.

No real money moves. No real cards are stored. No goods are shipped.

### 1.1 Goals

- Provide a realistic, polished end-to-end shopping UX for demo/testing purposes
- Exercise a complete mobile stack: auth, catalogue, cart, checkout, order history, delivery tracking, push notifications
- Avoid regulatory scope (PCI-DSS, GDPR obligations around payment data) by never handling real payment instruments

### 1.2 Explicit non-goals

- Real payment processing
- Real fulfilment or logistics integration
- Storing user-entered credit card data (deliberately excluded — see §6.3)

---

## 2. Technology Stack

| Layer | Choice | Notes |
|---|---|---|
| Mobile client | Flutter (latest stable) | iOS + Android flavors |
| Authentication | Firebase Authentication | Google, Facebook, Apple sign-in |
| Push notifications | Firebase Cloud Messaging | APNs key configured for iOS |
| Backend | Python + FastAPI | REST API, acts as OAuth2 resource server |
| Database | PostgreSQL | Catalogue, users, orders, addresses |
| Image CDN | Cloudflare R2 | Public URLs, no backend proxying |
| Maps | Google Maps (Flutter SDK) | Mobile map SDK is free; geocoding metered |
| Backend hosting | Azure | Keep image traffic off the backend |

### 2.1 Build flavors

Two flavors, `ios` and `android`, plus environment configuration (`dev`, `staging`, `prod`) for API base URL, Firebase project, and Maps API key.

---

## 3. Authentication

### 3.1 Providers

- Google Sign-In
- Facebook Login
- Sign in AND Sign up with Apple (mandatory on iOS if other social logins are present — App Store requirement)

### 3.2 Flow

1. Client authenticates via Firebase SDK
2. Client obtains a Firebase ID token
3. Client sends the token as `Authorization: Bearer <token>` on every backend call
4. FastAPI validates the token against Firebase public keys (JWKS), verifies issuer/audience/expiry, and extracts the Firebase UID
5. On first successful call, the backend lazily provisions a user row keyed by Firebase UID

### 3.3 Notes

- The backend never issues its own session tokens; Firebase UID is the canonical user identity
- Token refresh is handled by the Firebase SDK on-device
- Sign-out clears local caches of user-scoped data (orders, addresses, wishlist), but may retain the public catalogue cache

---

## 4. Product Catalogue

### 4.1 Data model (conceptual)

**Category**
- `id`, `slug`, `name` (localised), `parent_id` (nullable, supports nesting), `sort_order`, `image_url`

**Product**
- `id`, `sku`, `title` (localised), `description` (localised), `category_id`
- `base_price` (stored in a single base currency — see §8.2)
- `rating_average`, `rating_count`, `stock_status`
- `created_at`, `updated_at`

**ProductImage**
- `id`, `product_id`, `cdn_path`, `sort_order`, `alt_text`
- Multiple images per product; first is the primary/thumbnail

**Review**
- `id`, `product_id`, `user_id`, `rating` (1–5), `comment`, `created_at`
- Seeded reviews for demo realism; users may add their own

### 4.2 Browsing features

- Category grid on home, drill-down into subcategories
- Product listing with pagination / infinite scroll
- Product detail page: image carousel, title, price, description, rating summary, review list
- **Search** — full-text across title and description (Postgres `tsvector` is sufficient at this scale)
- **Filters** — category, price range, minimum rating
- **Sorting** — price ascending/descending, rating, newest

---

## 5. Images and CDN

### 5.1 Approach

Images live in **Cloudflare R2** and are served over **public URLs**. The Flutter client fetches them directly. The backend stores only the path/URL reference and never proxies image bytes — this keeps bandwidth off the Azure-hosted API.

### 5.2 Access control — accepted trade-off

Public URLs are, by definition, accessible outside the app. This is **accepted** for a simulation app with non-sensitive stock imagery.

Options deliberately **not** taken (documented for future reference):
- Signed URLs with expiry — reintroduces a token round-trip per image
- Referer/hotlink protection — trivially spoofed, and awkward for native mobile clients

If protection becomes necessary later, Cloudflare signed URLs are the upgrade path.

### 5.3 Client-side handling

- Images cached on disk (`cached_network_image` or equivalent)
- Per-image placeholder and error fallback — a single failed image must never break a grid
- Appropriately sized variants if bandwidth becomes a concern (R2 + Cloudflare Images transforms)

---

## 6. Cart and Simulated Checkout

### 6.1 Cart

- Add / remove / change quantity
- Cart persisted locally and (optionally) synced server-side per user
- Running subtotal in the user's active currency

### 6.2 Checkout flow

1. Review basket
2. Select delivery address (from saved addresses, or add new)
3. Select a demo payment card
4. Confirm → backend creates an `Order`
5. Confirmation screen with order number and estimated delivery window

Checkout **requires connectivity** — it is not queued offline. The user is told so explicitly if offline.

### 6.3 Demo payment cards

**No user-entered card data is ever collected or stored.** The app ships with a small set of hardcoded demo cards, purely cosmetic:

- e.g. `4242 4242 4242 4242`, any name, any future expiry
- Optionally a "declined" test card to exercise the failure path

Rationale: avoids PCI-DSS scope and GDPR obligations around payment data entirely.

---

## 7. Orders and Delivery Tracking

### 7.1 Order model

**Order**
- `id`, `user_id`, `created_at`, `total`, `currency`
- `delivery_address_id`
- `origin_lat`, `origin_lng` (fake warehouse assigned at checkout)
- `destination_lat`, `destination_lng` (geocoded delivery address)
- Status stage timestamps: `processing_at`, `shipped_at`, `out_for_delivery_at`, `delivered_at`

**OrderItem**
- `id`, `order_id`, `product_id`, `quantity`, `unit_price_at_purchase`, `title_snapshot`, `image_snapshot`

> Line items snapshot title/price/image so historical orders stay correct even if the catalogue changes.

### 7.2 Simulated delivery progression

At checkout the backend assigns **timestamps to all four stages up front**, spread across a plausible window. No background jobs, no cron, no live courier feed.

The client simply compares the current time against the stored timestamps to determine the present stage. This is deterministic, trivially testable, and looks entirely convincing.

### 7.3 Map tracking

- Backend returns `origin`, `destination`, and the delivery time window
- Client interpolates the parcel's position **along a straight line** between the two points based on elapsed fraction of the window
- Google Maps widget renders the route polyline plus an animated marker
- All motion is computed **on-device** — the server stays stateless with respect to parcel position

**Future enhancement:** swap the straight line for a real road route (Directions API) without changing the data model.

### 7.4 Order history

- List of past orders, newest first
- Tap through to order detail: line items, totals, address, current delivery status, map
- Cached locally for offline viewing

---

## 8. Localisation, Currency, and Language

### 8.1 Language

- Detected automatically from the **device locale** via Flutter's built-in localisation
- Falls back to English if no translation exists
- User can override language in settings

### 8.2 Currency

- **Default** derived from the device locale (Spain → EUR, US → USD)
- **Overridable** and stored on the user's profile — locale and actual currency preference are not always the same (e.g. an American living in Madrid)
- Prices stored **once** in a base currency in Postgres; conversion applied at display time

### 8.3 Exchange rates

- **Phase 1:** hardcoded fixed conversion rates
- **Phase 2:** live rates from an exchange-rate API

Implementation requirement: all conversion goes through a **single currency service** with a stable interface. The rest of the app is blind to whether the rate is hardcoded or fetched, so the upgrade is a one-file change.

---

## 9. User Profile

- Display name and avatar (from the auth provider)
- **Multiple saved delivery addresses**, with one marked default
- Address fields geocoded to lat/lng **once at save time** and stored — avoids repeat Geocoding API calls
- Wishlist / favourites — save products for later, accessible from profile
- Notification preferences
- Language and currency overrides
- Sign out; account deletion request

---

## 10. Push Notifications

- Firebase Cloud Messaging for both platforms
- **iOS setup:** create an APNs authentication key in the Apple Developer account, upload it to the Firebase project; Firebase then talks to APNs on your behalf
- Triggers: delivery stage changes (shipped, out for delivery, delivered), plus optional promotional messages
- Tapping a notification deep-links to the relevant order detail screen
- Permission requested contextually (after first order), not on first launch

---

## 11. Offline Behaviour and Caching

### 11.1 Strategy — cache-then-network

Show cached content **immediately**, then refresh from the backend in the background and update the UI.

### 11.2 What is cached

| Data | Store | Behaviour |
|---|---|---|
| Catalogue (categories, products) | Drift or Hive | Cache-first, background refresh |
| Product images | Disk cache | Previously viewed images load offline |
| Order history | Drift or Hive | Last known state viewable offline |
| Cart | Local, authoritative | Fully usable offline |
| Checkout | Not cached | Requires connectivity; user told explicitly |

### 11.3 Cache invalidation

- Time-based TTL on catalogue data
- Pull-to-refresh forces a fetch
- Cleared user-scoped caches on sign-out

---

## 12. Error States

**Principle:** never surface a raw error; always explain what happened and offer a next step.

- **Distinguish** failure types: no internet connection, backend unreachable, backend error response, single image failed to load
- **Always offer retry** — never a dead end
- **Degrade gracefully** — one broken image shows a placeholder, it does not break the grid
- **Prefer inline, gentle messaging** over modal alert dialogs
- Show a persistent but unobtrusive offline banner when connectivity is lost
- Loading states use skeletons/shimmer rather than bare spinners where a layout is predictable

---

## 13. Empty States

Every empty state is **helpful, not blank** — an illustration, a friendly line of copy, and a clear action out.

| Screen | Message | Action |
|---|---|---|
| Empty cart | "Your cart's feeling lonely" | Browse products |
| No orders yet | "No orders yet" | Start shopping |
| Empty wishlist | "Nothing saved yet" | Browse products |
| No search results | "Nothing matched that search" | Clear filters / suggestions |
| No addresses | "Add a delivery address" | Add address |

---

## 14. Responsive and Adaptive Layout

The same app reflows by screen size rather than stretching a fixed phone design.

- **Breakpoints** drive layout switching, not just scaling
- Product grid: ~2 columns on phone, 4–5 on tablet
- Tablet may use **master–detail** (list left, product right); phone navigates between separate screens
- Both portrait and landscape supported on tablets
- Respect safe areas, notches, and dynamic island

### 14.1 Accessibility

- Scalable text honouring the OS font-size setting (no hardcoded font sizes that break at 200%)
- Sufficient colour contrast; do not rely on colour alone
- Semantic labels on interactive elements and images for screen readers
- Minimum touch target sizes

---

## 15. Backend API (indicative)

All endpoints require a valid Firebase ID token unless marked public.

| Method | Path | Purpose |
|---|---|---|
| GET | `/categories` | Category tree |
| GET | `/products` | List; supports `category`, `q`, `min_price`, `max_price`, `min_rating`, `sort`, pagination |
| GET | `/products/{id}` | Product detail incl. images |
| GET | `/products/{id}/reviews` | Reviews, paginated |
| POST | `/products/{id}/reviews` | Add a review |
| GET | `/me` | Profile |
| PATCH | `/me` | Update preferences (language, currency) |
| GET/POST/PATCH/DELETE | `/me/addresses` | Saved addresses (geocoded on write) |
| GET/POST/DELETE | `/me/wishlist` | Wishlist |
| POST | `/orders` | Create order — assigns stage timestamps and origin warehouse |
| GET | `/orders` | Order history |
| GET | `/orders/{id}` | Order detail incl. tracking payload |
| POST | `/me/devices` | Register FCM token |

---

## 16. Admin and Data Seeding

### 16.1 Phase 1 — seed script

A Python script that:
- Populates categories and products into Postgres
- Uploads product images to Cloudflare R2 and writes back the public paths
- Generates plausible seeded reviews and ratings

Data sources are specified in §17, image sourcing in §18, and the image-to-product mapping pipeline in §19.

### 16.2 Phase 2 — admin web interface

Deferred. A simple web UI for CRUD on categories, products, and images, sharing the same FastAPI backend with a separate admin auth path.

---

## 17. Sample Product Data Sources

Target catalogue shape, using Temu as the reference: broad, cheap, non-perishable consumer goods. **No food or beverages.**

### 17.1 Primary source — DummyJSON

`https://dummyjson.com/products` — the best single starting point. Free, no API key, and the record shape maps almost one-to-one onto the `Product` model in §4.1: title, description, category, price, discount percentage, rating, stock, tags, brand, SKU, dimensions, warranty and shipping info, plus nested reviews and multiple image URLs per product.

Its 24 categories align well with the target mix:

| Target category | DummyJSON categories |
|---|---|
| Clothing | `mens-shirts`, `womens-dresses`, `tops` |
| Shoes | `mens-shoes`, `womens-shoes` |
| Phones & accessories | `smartphones`, `mobile-accessories` |
| Computers | `laptops`, `tablets` |
| Sportswear | `sports-accessories` |
| Bags & accessories | `womens-bags`, `sunglasses`, `mens-watches`, `womens-watches`, `womens-jewellery` |
| Beauty | `beauty`, `fragrances`, `skin-care` |
| Home | `furniture`, `home-decoration`, `kitchen-accessories` |

**Excluded on ingest:** `groceries` (food), `vehicle`, `motorcycle`.

**Gaps:** DummyJSON has no underwear category and only accessories under sportswear (no sports apparel). It is also small — roughly 200 products total, which is thin for testing infinite scroll and search.

### 17.2 Supplementary source — Kaggle Fashion Product Images Dataset

`kaggle.com/datasets/paramaggarwal/fashion-product-images-dataset` — around 44,000 apparel and footwear products with multi-level category labels, descriptive metadata, and high-resolution images. Its taxonomy includes **innerwear**, **sportswear/activewear**, **loungewear**, and **socks**, filling exactly the gaps DummyJSON leaves.

Caveats: the metadata has **no prices** (synthesise them, see §17.5) and product titles are terse. There is also a smaller variant, "E-commerce Product Images", with ~2,900 apparel and footwear items and metadata, if 44k is more than needed.

### 17.3 Alternative fake-store APIs

| Source | Fit |
|---|---|
| **FakeStoreAPI** (`fakestoreapi.com`) | Only ~20 products; useful as a smoke-test fixture, too small for the real catalogue |
| **Platzi Fake Store API** (`fakeapi.platzi.com`) | REST + GraphQL, filtering, AI-generated product images, file upload support |

### 17.4 Electronics depth

For a larger electronics catalogue with real pricing, the **Electronic Products and Pricing Data** dataset (Datafiniti, ~7,000 products across 10 pricing fields) provides realistic price distributions for phones, laptops, and accessories.

### 17.5 Price synthesis rules

Where a source has no price, generate one deterministically so seeds are reproducible:

- Assign a plausible band per category (e.g. underwear €4–15, t-shirts €6–25, trainers €15–60, smartphones €90–900, laptops €250–1,500)
- Bias toward the low end of each band to match the Temu feel
- Use "charm pricing" endings (`.99`, `.49`)
- Give a subset a `discount_percentage` and a struck-through original price
- Seed the RNG with the product ID so repeated runs produce identical data

### 17.6 Licensing note

Kaggle and Datafiniti datasets are for **development and demo use** under their respective terms. Since this app is a simulation and never sells anything, that is fine — but do not carry scraped brand names and copyrighted product photography into anything public-facing without re-checking the licence. For a public demo, prefer generated titles over real brand names.

---

## 18. Free Stock Image Sources

### 18.1 Recommendation — Pexels

**Pexels** (`pexels.com/api`) is the recommended source, chiefly because its terms permit **downloading and re-hosting** images on your own CDN — which is exactly what §5 requires.

- Free API, key issued instantly on signup
- Default limits: 200 requests/hour and 20,000 requests/month, which is far more than a one-off seed run needs
- Limits can be lifted free of charge for eligible applications that display proper attribution
- Includes video as well as photos
- Attribution requested: credit the photographer where possible, e.g. "Photo by [name] on Pexels" with a link, or a general "Photos provided by Pexels" text link

**Restriction to respect:** Pexels does not permit apps that replicate Pexels' core functionality or resell unaltered copies. A shopping simulator does neither.

### 18.2 Unsplash — important caveat

Unsplash has arguably the highest-quality library and permits commercial use, but its **API guidelines require hotlinking**: image URLs returned by the API must be embedded directly from the Unsplash CDN so photo views can be tracked and reported to the photographer.

**This conflicts with re-hosting on Cloudflare R2.** Unsplash is therefore unsuitable as the R2 seed source under its API terms. Its demo tier is also rate-limited to 50 requests/hour (5,000/hour once approved for production), which is slow for bulk seeding.

### 18.3 Other options

| Source | Notes |
|---|---|
| **Burst by Shopify** | Purpose-built e-commerce product shots — the most convincing look for a shop |
| **Pixabay** | Free API, permissive licence, large library |
| **Lorem Picsum** (`picsum.photos/400/400`) | No key, no signup. Not real products, but ideal for early layout, loading-state, and skeleton testing |

### 18.4 Attribution in-app

Add a **"Photo credits"** entry under Settings listing the image sources and, where practical, per-photographer credits. This satisfies Pexels' attribution request and costs one static screen.

---

## 19. Image-to-Product Mapping Pipeline

Products and images come from different places, so the seed script must bind them together deterministically and store the result as the `ProductImage` rows described in §4.1.

### 19.1 Strategy by source

**A. Source already has images** (DummyJSON, Kaggle) — the mapping is inherent. Download the referenced image, upload to R2, and write back the new public path. This is preferred: the picture genuinely matches the product.

**B. Source has no images** (a price-only dataset) — resolve an image by **category-keyed search** against Pexels, never by raw product title. Searching "Essence Mascara Lash Princess" returns nothing useful; searching "mascara product white background" returns a usable shot.

### 19.2 Category → search-query map

Maintain an explicit lookup so results stay on-brief and repeatable:

| Category | Pexels query |
|---|---|
| `mens-shirts` | `mens shirt flat lay white background` |
| `underwear` | `folded underwear product photography` |
| `womens-shoes` | `womens shoes product white background` |
| `sportswear` | `activewear clothing flat lay` |
| `smartphones` | `smartphone product shot white background` |
| `laptops` | `laptop product photography white background` |

Fetch a **pool** of 20–40 images per category, then deal them out to products in that category round-robin. This avoids every t-shirt sharing one photo while keeping API calls low.

### 19.3 Pipeline steps

1. **Ingest** product records from the sources in §17 into a staging table
2. **Normalise** into the schema in §4.1 — map source categories onto the app's taxonomy, drop excluded categories, synthesise prices where missing
3. **Resolve images** — strategy A or B per §19.1; target 3–5 images per product
4. **Process** — resize to a standard set (thumbnail 300px, detail 1200px), convert to WebP, strip EXIF
5. **Upload** to R2 under a deterministic key: `products/{product_id}/{index}.webp`
6. **Persist** `ProductImage` rows with `cdn_path`, `sort_order`, and `alt_text` (generated from category and title for screen readers, per §14.1)
7. **Verify** — assert every product has at least one image and every `cdn_path` returns HTTP 200; fail the seed run loudly if not

### 19.4 Implementation requirements

- **Idempotent** — re-running must not duplicate rows or re-upload unchanged images; key on source ID
- **Cached downloads** — keep a local copy of fetched images so re-runs do not hammer the image API
- **Deterministic** — seed the RNG with the product ID so the same product always gets the same photos
- **Attribution captured** — store photographer name and source URL alongside each `ProductImage` to populate the credits screen in §18.4
- **Rate-limit aware** — throttle to stay inside 200 requests/hour on Pexels; the pool-per-category approach in §19.2 keeps total calls in the low hundreds
- **Manual override** — a simple CSV of `product_id, image_url` that wins over automatic resolution, for fixing the handful of comically wrong matches that always appear

---

## 20. Cost Notes

- **Google Maps mobile SDK** — free, unmetered, for rendering maps in the app
- **Geocoding API** — metered (~$5 per 1,000 requests) with a monthly free tier; new accounts receive a trial credit. Mitigated by geocoding each address **once** on save and storing coordinates
- **Cloudflare R2** — no egress fees, which is why images bypass the backend
- **Firebase Auth / FCM** — free at demo scale

Verify current pricing before launch; Google's Maps Platform pricing model changed in 2025 to per-SKU free caps.

---

## 21. Open Questions / Future Work

- Real road-following delivery routes via Directions API
- Live exchange-rate API integration
- Admin web interface
- Signed CDN URLs if image protection becomes a requirement
- Server-side cart sync across devices
- Analytics / crash reporting (Firebase Crashlytics)
