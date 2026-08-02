# Feature Specification: Shopping App Simulator

**Feature Branch**: `001-shopping-app-simulator`

**Created**: 2026-08-02

**Status**: Draft

**Input**: User description: "Analyse `claude/01_INITIAL_SPECS.md` — a Temu-style mobile shopping application that simulates the full e-commerce experience without processing real transactions — and produce the spec-driven artifacts for it."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse and discover the catalogue (Priority: P1)

A visitor opens the app and immediately sees a grid of product categories. They drill into a
category, scroll a long list of products that keeps loading as they go, narrow it down with a
price range and a minimum rating, sort by cheapest first, and open a product to see its photo
carousel, price, description, rating summary, and what other people said about it. They can
also type a few words into search and find products by title or description text. None of this
requires an account.

**Why this priority**: This is the largest surface of the app and the only part that works
with no account, no cart, and no network writes. It is the thinnest slice that is still
recognisably the product, and every later story depends on a browsable catalogue existing.

**Independent Test**: Seed the catalogue, launch the app signed out, and complete
category → list → filter → sort → search → product detail without ever authenticating.
Delivers value on its own as a browsable product catalogue.

**Acceptance Scenarios**:

1. **Given** a seeded catalogue and a signed-out user, **When** they open the app, **Then**
   the home screen shows the top-level category grid with a name and image per category.
2. **Given** a category with more products than one page, **When** the user scrolls to the
   bottom of the list, **Then** the next page loads and appends without losing scroll position.
3. **Given** a product list, **When** the user sets a minimum rating of 4 and a maximum price,
   **Then** every product shown satisfies both constraints and the applied filters remain
   visible and individually removable.
4. **Given** a product list, **When** the user sorts by price ascending, **Then** results are
   ordered non-decreasing by the price displayed in the user's active currency.
5. **Given** a search term matching words in a product description but not its title,
   **When** the user searches, **Then** that product appears in the results.
6. **Given** a product with several images, **When** the user opens its detail screen,
   **Then** they can swipe through every image and see title, price, description, average
   rating, rating count, and a paginated review list.
7. **Given** a search that matches nothing, **When** results return, **Then** the empty state
   explains that nothing matched and offers to clear the filters.

---

### User Story 2 - Sign up or sign in and be recognised (Priority: P2)

A new user taps sign up, chooses Google, Facebook, or Apple, and lands back in the app with an
account that already exists — no form, no password, no verification email. A returning user
taps sign in and is simply recognised. Either way their display name and avatar are shown, and
anything they saved previously — addresses, wishlist, past orders — is theirs again. Signing
out removes their personal data from the device.

**Why this priority**: Everything user-scoped (cart sync, orders, addresses, wishlist,
notifications) is gated on a stable identity. It is small, self-contained, and blocks stories
3 onward.

**Note on sign-up versus sign-in**: with social providers these are the *same* authorization
call; what differs is whether the account already existed. The distinction is real at the
product level (first-run welcome, terms acceptance) and, for Apple, at the technical level:
Apple returns the user's name **only on the very first authorization**, so an app that treats
sign-up as "just sign-in" loses that name permanently. See FR-081 and research decision D13.

**Independent Test**: Sign up with each provider from a clean install and confirm an account is
created and named correctly. Then sign out, sign back in, and confirm the same account is
returned rather than a second one created. Kill and relaunch to confirm the session persists,
then sign out and confirm user-scoped screens return to their signed-out state.

**Acceptance Scenarios**:

1. **Given** a signed-out user, **When** they complete sign-in with any supported provider,
   **Then** they land back where they started, now signed in, with name and avatar populated.
2. **Given** a first-time user, **When** their first authenticated request reaches the system,
   **Then** a profile is created for them automatically with no extra registration step.
3. **Given** a user signing up with Apple for the first time, **When** the provider returns
   their name, **Then** that name is stored immediately, because Apple will not return it on
   any later authorization.
4. **Given** a user who already has an account, **When** they authorize with the same provider
   again, **Then** they are signed in to the existing account and no second account is created.
5. **Given** a user who has just signed up, **When** they arrive back in the app, **Then** they
   are shown a first-run welcome; a returning user is not.
6. **Given** a returning user, **When** they relaunch the app, **Then** they are still signed
   in without re-entering credentials.
7. **Given** an expired credential, **When** the user performs any action, **Then** the
   session is renewed transparently and the action succeeds without a visible interruption.
8. **Given** a signed-in user, **When** they sign out, **Then** their orders, addresses, and
   wishlist are cleared from the device while the browsable catalogue remains available.
9. **Given** an iOS device, **When** the sign-up and sign-in options are shown, **Then** Apple
   is offered for both, alongside the other providers.

---

### User Story 3 - Build a cart and complete a simulated checkout (Priority: P3)

A user adds several products to their cart, changes a quantity, removes one, watches the
subtotal update in their currency, then checks out: pick a delivery address, pick one of the
built-in demo cards, confirm, and land on a confirmation screen with an order number and an
estimated delivery window. No real payment happens and no card details are ever typed.

**Why this priority**: This is the core simulated transaction — the reason the app exists —
but it depends on both a catalogue and an identity.

**Independent Test**: Signed in with at least one saved address, add items, adjust
quantities, check out with the success demo card, and confirm an order is created with the
correct totals and a delivery window. Repeat with the decline card and confirm no order is
created and the user is told why.

**Acceptance Scenarios**:

1. **Given** a product detail screen, **When** the user adds the product to their cart,
   **Then** the cart badge count increases and the item appears in the cart with quantity 1.
2. **Given** a cart with items, **When** the user changes a quantity or removes a line,
   **Then** the subtotal recalculates immediately in the user's active currency.
3. **Given** a cart and no saved address, **When** the user starts checkout, **Then** they are
   prompted to add a delivery address before they can continue.
4. **Given** checkout, **When** the user reaches payment, **Then** only built-in demo cards are
   selectable and there is no field anywhere that accepts card details.
5. **Given** a valid checkout, **When** the user confirms with the success demo card,
   **Then** an order is created and the confirmation screen shows an order number and an
   estimated delivery window.
6. **Given** a valid checkout, **When** the user confirms with the decline demo card,
   **Then** no order is created, the cart is preserved intact, and the user is told the
   payment was declined and offered another card.
7. **Given** the device is offline, **When** the user attempts to confirm checkout,
   **Then** they are told explicitly that checkout needs a connection, and the attempt is not
   silently queued for later.
8. **Given** a completed order, **When** the catalogue price or title of a purchased product
   later changes, **Then** the order still shows the title, price, and image as they were at
   purchase time.

---

### User Story 4 - Watch a simulated delivery move on a map (Priority: P4)

After ordering, the user opens the order and sees where their parcel is: a map with the
warehouse it left, their address, the line between them, and a marker that has moved a
believable distance along it. Above the map, the current stage — processing, shipped, out for
delivery, delivered — is shown with its timestamps.

**Why this priority**: The most visible payoff of the simulation, and the feature most likely
to be demoed, but it is meaningless without an order to track.

**Independent Test**: Create an order, then query it at several controlled points in time and
assert the reported stage and the interpolated marker position match the stored timestamps.

**Acceptance Scenarios**:

1. **Given** an order is created, **When** it is stored, **Then** all four stage timestamps
   are already assigned, spread across a plausible window, and never change afterwards.
2. **Given** the current time is between the shipped and out-for-delivery timestamps,
   **When** the user opens the order, **Then** the stage shown is "shipped".
3. **Given** an order in transit, **When** the map renders, **Then** it shows the origin, the
   destination, the line between them, and a marker positioned at the elapsed fraction of the
   delivery window.
4. **Given** the current time is past the delivered timestamp, **When** the user opens the
   order, **Then** the stage is "delivered" and the marker sits at the destination.
5. **Given** two users open the same order at the same moment on different devices,
   **When** the marker is drawn, **Then** both see it in the same place.

---

### User Story 5 - Review past orders (Priority: P5)

The user opens their order history, sees past orders newest first, and taps one to see what
they bought, what it cost, where it went, and where the delivery has got to. This works with
no connection, showing the last known state.

**Why this priority**: Expected of any shopping app and cheap once orders exist, but it adds
no new capability beyond viewing what stories 3 and 4 already produced.

**Independent Test**: Place several orders, open history, confirm ordering and totals, then
disable the network and confirm the list and details still render from the last known state.

**Acceptance Scenarios**:

1. **Given** a user with orders, **When** they open order history, **Then** orders are listed
   newest first with date, total in the active currency, and current stage.
2. **Given** an order in the list, **When** the user taps it, **Then** they see line items with
   purchase-time titles, prices, and images, plus totals, delivery address, and stage.
3. **Given** the device is offline, **When** the user opens order history, **Then** the last
   known list and details render, with a clear indication that the data may be out of date.
4. **Given** a user with no orders, **When** they open order history, **Then** the empty state
   invites them to start shopping and links to the catalogue.

---

### User Story 6 - Manage profile, addresses, wishlist, and preferences (Priority: P6)

The user saves several delivery addresses and marks one as default, saves products to a
wishlist for later, and overrides the app's language and currency when the automatic choice
is not what they want.

**Why this priority**: Addresses are a hard prerequisite for checkout, but a single address
captured inline during checkout satisfies story 3. The full management surface is a
refinement.

**Independent Test**: Add, edit, delete, and re-default addresses; add and remove wishlist
items; change language and currency and confirm both persist across a relaunch and across
devices.

**Acceptance Scenarios**:

1. **Given** the profile screen, **When** the user adds an address, **Then** it is saved with
   map coordinates resolved at save time and is available for checkout.
2. **Given** several saved addresses, **When** the user marks one as default, **Then** exactly
   one address is default and it is preselected at checkout.
3. **Given** the user deletes the address used by a past order, **When** they view that order,
   **Then** the order still shows the address it was delivered to.
4. **Given** a product, **When** the user saves it to their wishlist, **Then** it appears in
   the wishlist and the save state is reflected on the product detail screen.
5. **Given** a user whose device locale implies one currency, **When** they override the
   currency in settings, **Then** every price in the app is shown in the chosen currency and
   the override survives a relaunch and a reinstall.
6. **Given** a user changes language, **When** the app reloads, **Then** all translated copy
   follows the choice, and untranslated strings fall back to English rather than showing a
   key or an empty string.

---

### User Story 7 - Be notified as the delivery progresses (Priority: P7)

The user is asked for notification permission after their first order — not on first launch —
and from then on gets a notification when their order ships, goes out for delivery, and
arrives. Tapping one opens that order.

**Why this priority**: Genuinely valuable for the demo but the most platform-dependent and
least testable slice, and everything it references already works without it.

**Independent Test**: Place an order, grant permission when prompted, dispatch each stage
notification, and confirm the tap target opens the correct order detail screen from both a
cold and a warm start.

**Acceptance Scenarios**:

1. **Given** a user who has never ordered, **When** they launch the app for the first time,
   **Then** they are not asked for notification permission.
2. **Given** a user who has just placed their first order, **When** the confirmation screen
   appears, **Then** they are asked for notification permission with an explanation of what
   they will receive.
3. **Given** permission granted, **When** an order reaches a new delivery stage, **Then** a
   notification for that stage is delivered once and only once.
4. **Given** a delivered notification, **When** the user taps it with the app closed,
   **Then** the app opens directly on that order's detail screen.
5. **Given** permission denied, **When** delivery stages change, **Then** the app continues to
   work normally and the stage is still visible in the app.

---

### User Story 8 - Keep working when the network does not (Priority: P8)

The user goes into a lift. The catalogue they already browsed still renders, images they have
seen still appear, their cart is intact, and their past orders are readable. An unobtrusive
banner tells them they are offline. When the connection returns, content refreshes without
them doing anything.

**Why this priority**: Cross-cutting quality rather than new capability. Called out as its own
story because it is the single most common source of demo failure and needs explicit tests.

**Independent Test**: Warm the caches by browsing, disable the network, and walk the whole app
asserting each screen degrades as specified rather than erroring.

**Acceptance Scenarios**:

1. **Given** previously browsed content, **When** the user opens a screen offline, **Then**
   cached content renders immediately and an offline banner is shown.
2. **Given** cached content is displayed, **When** the network is available, **Then** fresh
   content is fetched in the background and replaces it without a visible flash or a lost
   scroll position.
3. **Given** the app is offline, **When** the user adds and removes cart items, **Then** the
   cart behaves normally and survives a relaunch.
4. **Given** a single product image fails to load, **When** the grid renders, **Then** that one
   tile shows a placeholder and every other tile renders normally.
5. **Given** any failed request, **When** the failure is shown, **Then** the message
   distinguishes no-connection from service-unavailable and offers a retry.
6. **Given** cached catalogue data older than its freshness window, **When** the user opens the
   screen with a connection, **Then** the data is refetched rather than served from cache.

### Edge Cases

- A product's category is deleted while a user has that category's list open.
- A product goes out of stock between being added to the cart and checkout being confirmed.
- The cart contains a product that has since been removed from the catalogue entirely.
- Two devices signed into the same account modify the cart at the same time.
- An address fails to resolve to coordinates at save time (ambiguous or nonsense input).
- An order's destination is on the other side of the world from its assigned warehouse,
  producing a delivery window that looks implausible.
- The device clock is wrong or is changed by the user mid-delivery, so the elapsed fraction
  goes negative or exceeds one.
- A product has zero reviews, so there is no average rating to display.
- The user's chosen currency has no configured conversion rate.
- Search terms contain characters that are meaningful to the search engine — quotes, boolean
  operators, prefix wildcards, an unbalanced parenthesis, or a term consisting only of
  punctuation.
- A user requests account deletion while an order is still mid-delivery.
- The catalogue cache exists but is from an older, incompatible app version.
- A device registers for notifications, is signed out, and another user signs in on it.
- A user scrolls to the very end of a category list and then applies a filter.

## Requirements *(mandatory)*

### Functional Requirements

> Requirement identifiers are **append-only and never reused**. A requirement added later to an
> earlier topic keeps the next free number and sits with its topic, so `FR-077` appearing among
> the catalogue requirements is intentional — renumbering would break every existing reference
> in `tasks.md`, the tests, and the traceability gate.

#### Catalogue and discovery

- **FR-001**: System MUST present top-level categories with a localised name and an image, and
  MUST support nested subcategories to arbitrary depth.
- **FR-002**: System MUST return products for a category in pages, with a stable order across
  pages so no product is duplicated or skipped while paging.
- **FR-003**: Users MUST be able to search products by free text matched against both title and
  description. Search input MUST be treated as literal user text: characters that carry meaning
  to the underlying search engine MUST NOT produce an error, MUST NOT alter query semantics, and
  MUST NOT reach the user as a failure. A search that matches nothing returns the empty state of
  FR-063, never an error state.
- **FR-004**: System MUST support filtering by category, minimum price, maximum price, and
  minimum average rating, in any combination.
- **FR-005**: System MUST support sorting by price ascending, price descending, rating, and
  newest first.
- **FR-006**: System MUST expose, for each product, its title, description, price, average
  rating, rating count, stock status, and ordered image list.
- **FR-007**: System MUST return a product's reviews in pages, newest first.
- **FR-008**: Authenticated users MUST be able to submit one review per product, with a rating
  from 1 to 5 and an optional comment.
- **FR-009**: System MUST recompute a product's average rating and rating count when a review
  is added.
- **FR-010**: Catalogue browsing, search, product detail, and review reading MUST be available
  without authentication.
- **FR-077**: When a product carries a discount, the system MUST expose both the discounted
  price and the original price, and the app MUST show the discounted price as primary with the
  original struck through. Both prices MUST be converted through the same currency service, so
  a discount can never appear in one currency and its original in another.
- **FR-078**: Out-of-stock products MUST remain browsable and searchable, MUST be clearly
  labelled as out of stock, and MUST NOT be addable to the cart. A product that goes out of
  stock while already in a cart MUST be flagged there and excluded from the total, as in FR-021.
- **FR-079**: A review MUST expose only its rating, comment, creation time, and the author's
  display name and avatar as supplied by their authentication provider. No other user attribute
  may be exposed to another user, authenticated or not.

#### Identity

- **FR-011**: Users MUST be able to **create an account (sign up) and sign in** with Google,
  Facebook, or Apple. Account creation MUST require no password, no separate registration form,
  and no email verification step.
- **FR-012**: System MUST offer Apple for **both sign-up and sign-in** on iOS whenever any other
  social provider is offered, as the App Store requires.
- **FR-080**: System MUST distinguish a first-time sign-up from a returning sign-in and MUST
  show a first-run welcome only to the former. Authorising again with a provider already linked
  to an account MUST sign the user in to that existing account and MUST NOT create a second one.
- **FR-081**: When a provider supplies the user's name only at first authorisation — as Apple
  does — the system MUST persist it at sign-up. It MUST NOT rely on being able to read the name
  again later, and a returning sign-in that carries no name MUST NOT overwrite the stored one
  with an empty value.
- **FR-013**: System MUST reject any request to a user-scoped resource that does not carry a
  valid, unexpired credential, and MUST NOT leak whether the resource exists.
- **FR-014**: System MUST create a user profile automatically on a user's first authenticated
  request, with no separate registration step.
- **FR-015**: System MUST renew expired credentials without user-visible interruption.
- **FR-016**: On sign-out, the app MUST clear all user-scoped local data (orders, addresses,
  wishlist, cart) and MAY retain the public catalogue cache.
- **FR-017**: Users MUST be able to request account deletion from within the app. The request
  MUST be recorded with its timestamp and MUST tell the user what happens next. On request the
  system MUST immediately deregister the user's notification devices, so no further push can
  reach them. Orders already in progress MUST complete and remain readable until the request is
  processed; the account MUST stay usable in the meantime. A user MUST be able to make the
  request while an order is mid-delivery — that case MUST NOT be rejected.

#### Cart

- **FR-018**: Users MUST be able to add a product to the cart, change its quantity, and remove
  it.
- **FR-019**: The cart MUST persist locally across app restarts and MUST be fully usable with
  no network connection.
- **FR-020**: The cart MUST display a running subtotal in the user's active currency, updated
  immediately on any change.
- **FR-021**: System MUST handle a cart line whose product has been withdrawn from the
  catalogue by flagging that line and excluding it from the total rather than failing checkout.
  An excluded line MUST NOT be submitted at checkout. If a product is withdrawn in the window
  between submission and the order being recorded, the whole order MUST be rejected with a
  message naming the product, and the cart left intact — a line MUST NOT be silently dropped
  from an order the user has already confirmed.

#### Checkout and orders

- **FR-022**: System MUST require a selected delivery address before checkout can be confirmed.
- **FR-023**: System MUST offer only built-in demo payment cards, and MUST NOT provide any
  input that accepts payment card details.
- **FR-024**: System MUST include at least one demo card that deterministically produces a
  declined outcome.
- **FR-025**: A declined checkout MUST leave the cart unchanged, create no order, and present a
  recoverable message offering another card.
- **FR-026**: A confirmed checkout MUST create an order recording the buyer, line items,
  totals, currency, delivery address, and creation time.
- **FR-027**: Each order line MUST snapshot the product's title, unit price, and primary image
  at purchase time, and those values MUST NOT change when the catalogue changes.
- **FR-028**: A successful checkout MUST empty the cart.
- **FR-029**: Checkout MUST require connectivity, MUST NOT be queued for later, and MUST tell
  the user explicitly when it cannot proceed for that reason.
- **FR-030**: System MUST show an order number and an estimated delivery window on confirmation.
- **FR-031**: Users MUST be able to list their own orders, newest first, and open any of them.
- **FR-032**: System MUST NOT allow a user to read an order belonging to another user.

#### Simulated delivery

- **FR-033**: At order creation, the system MUST assign an origin warehouse location and
  timestamps for all four delivery stages — processing, shipped, out for delivery, delivered.
  The four MUST be in non-decreasing order, and the window from order creation to delivery MUST
  fall between 24 and 96 hours. ("Plausible" is not testable; this range is.)
- **FR-034**: Assigned stage timestamps MUST be immutable after creation.
- **FR-035**: The current delivery stage MUST be derived solely from the stored timestamps and
  the current time, with no background job or external feed.
- **FR-036**: System MUST expose an order's origin coordinates, destination coordinates, and
  delivery window so a client can compute parcel position without further calls.
- **FR-037**: Parcel position MUST be computed on the device by interpolating along the path
  between origin and destination using the elapsed fraction of the delivery window.
- **FR-038**: Elapsed fraction MUST be clamped to the range 0 to 1 so that a wrong device clock
  cannot place the parcel outside the route.
- **FR-039**: The delivery map MUST render the origin, the destination, the route between them,
  and the current parcel position.

#### Profile, addresses, wishlist

- **FR-040**: Users MUST be able to save multiple delivery addresses and to create, update, and
  delete them.
- **FR-041**: Exactly one saved address MUST be marked default at any time; the default MUST be
  preselected at checkout.
- **FR-042**: Addresses MUST be resolved to coordinates once, when saved, and the coordinates
  stored. Coordinates MUST NOT be re-resolved on read.
- **FR-043**: When an address cannot be resolved to coordinates, the system MUST tell the user
  and MUST NOT save a partial address.
- **FR-044**: Deleting an address MUST NOT alter the address recorded on any existing order.
- **FR-045**: Users MUST be able to add and remove products from a wishlist and view it from
  their profile.
- **FR-046**: Users MUST be able to set notification preferences.

#### Localisation and currency

- **FR-047**: The app's language MUST default to the device locale and MUST fall back to
  English when no translation exists for a string.
- **FR-048**: Users MUST be able to override the language, and the override MUST persist on
  their profile across devices.
- **FR-049**: The active currency MUST default from the device locale and MUST be overridable
  independently of language.
- **FR-050**: Prices MUST be stored once in a single base currency and converted only at display
  time.
- **FR-051**: All currency conversion MUST pass through one interface, so that replacing fixed
  rates with live rates requires no change to calling code.
- **FR-052**: When no conversion rate exists for the active currency, the system MUST display
  the base currency price rather than an incorrect converted price or an error.

#### Notifications

- **FR-053**: System MUST request notification permission only after a user's first order, not
  on first launch.
- **FR-054**: The app MUST deliver a notification when an order reaches the shipped, out for
  delivery, and delivered stages, at most once per stage per order. Because FR-035 forbids any
  background progression, no component ever observes a stage transition; the notification MUST
  therefore be derivable from the stage timestamps assigned at order creation, and MUST NOT
  depend on a scheduler that watches for the transition.
- **FR-055**: Tapping a delivery notification MUST open the corresponding order's detail screen
  from both a cold and a warm start.
- **FR-056**: Denied or revoked notification permission MUST NOT degrade any other function.

#### Resilience, errors, and empty states

- **FR-057**: The app MUST render previously fetched catalogue content and order history from
  cache before any network request completes, then refresh in the background.
- **FR-058**: Cached catalogue content MUST expire after a defined freshness window, and
  pull-to-refresh MUST force a fetch regardless of that window.
- **FR-059**: The app MUST distinguish and separately handle: no connectivity, service
  unreachable, service error response, and single asset load failure.
- **FR-060**: Every error state MUST offer a retry or an alternative action; no error state may
  be a dead end.
- **FR-061**: A failed image MUST show a placeholder in its own tile and MUST NOT prevent
  sibling content from rendering.
- **FR-062**: The app MUST show a persistent, unobtrusive banner while offline, and remove it
  when connectivity returns.
- **FR-063**: Every empty state — cart, orders, wishlist, search results, addresses — MUST show
  explanatory copy and a primary action out.
- **FR-064**: Loading states MUST use skeleton placeholders wherever the resulting layout is
  predictable.

#### Presentation and accessibility

- **FR-065**: Layout MUST switch at breakpoints rather than scale, showing approximately two
  product columns on phones and four to five on tablets.
- **FR-066**: Tablets MUST support a master–detail layout and both portrait and landscape.
- **FR-067**: All text MUST honour the operating system font-size setting and remain legible and
  unclipped at 200%.
- **FR-068**: All interactive elements and meaningful images MUST expose screen-reader labels.
- **FR-069**: Colour MUST NOT be the only means of conveying information, and text contrast MUST
  meet WCAG AA.
- **FR-070**: Layout MUST respect device safe areas, notches, and cutouts.

#### Catalogue seeding and image attribution

- **FR-071**: A seed process MUST populate categories, products, images, and reviews from
  external data sources, excluding food, vehicle, and motorcycle categories.
- **FR-072**: The seed process MUST be idempotent: re-running MUST NOT duplicate records or
  re-upload unchanged images.
- **FR-073**: Synthesised values (prices where the source has none, image assignment) MUST be
  deterministic for a given product identifier.
- **FR-074**: Every product MUST end the seed run with at least one image, and every stored
  image reference MUST resolve successfully. A seed run that violates either MUST fail loudly.
- **FR-075**: Each image MUST store its source and, where required by the source's terms, its
  photographer, and the app MUST surface these credits on a dedicated screen.
- **FR-076**: An operator-supplied override mapping of product to image MUST take precedence
  over automatic image resolution.

### Key Entities

- **Category**: A node in the browsable taxonomy. Has a localised name, a slug, an image, an
  optional parent, and a sort position. Categories nest.
- **Product**: A sellable item. Has a stock-keeping identifier, localised title and
  description, a category, a price in the base currency, an average rating, a rating count,
  stock status, and creation and update times.
- **ProductImage**: One image belonging to a product, with its position in the carousel,
  alternative text for screen readers, and the attribution required by its source. The first
  by position is the thumbnail.
- **Review**: A rating from 1 to 5 with an optional comment, written by a user about a product
  at a point in time.
- **User**: A person identified by their authentication provider. Holds display name, avatar,
  language override, currency override, and notification preferences.
- **Address**: A delivery destination belonging to a user, with its resolved coordinates and a
  flag marking the user's default.
- **Cart**: The set of products and quantities a user intends to buy. Locally authoritative.
- **Order**: A completed simulated purchase. Holds buyer, totals, currency, delivery address,
  origin and destination coordinates, and the four immutable delivery stage timestamps.
- **OrderItem**: One line of an order, holding quantity plus a snapshot of the product's title,
  unit price, and image as they were at purchase.
- **DemoCard**: A built-in, cosmetic payment card with a fixed outcome (approve or decline).
  Never user-supplied.
- **Device**: A registered notification target belonging to a user.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from opening the app to a completed simulated order in under three
  minutes without assistance. **Measured by a human**, stopwatch in hand, with a participant who
  has not used the app before, as part of the release smoke walk — not by an automated test.
  Recorded as a number in the release notes so a regression is visible.
- **SC-002**: 95% of catalogue searches return results within one second on a normal
  connection.
- **SC-003**: Previously browsed screens render cached content within 500 ms of opening, before
  any network response arrives.
- **SC-004**: With the network disabled, the catalogue, cart, and order history remain usable;
  zero screens show a raw error or an unrecoverable dead end.
- **SC-005**: 100% of functional requirements are traceable to at least one automated test that
  passes.
- **SC-006**: 100% of published API operations have a contract test covering success, failure,
  and unauthenticated access.
- **SC-007**: Every seeded product has at least one image that resolves, verified as part of
  the seed run.
- **SC-008**: The delivery stage and parcel position reported for a given order and a given
  point in time are identical across repeated runs and across devices.
- **SC-009**: Every screen remains usable with the operating system font size at 200%, with no
  clipped or overlapping text.
- **SC-010**: Every interactive element exposes a screen-reader label, verified by an automated
  accessibility scan.
- **SC-011**: Product grids show approximately two columns on phones and four to five on
  tablets, in both orientations.
- **SC-012**: Re-running the seed process against an already-seeded database changes no rows and
  uploads no images.
- **SC-013**: Zero user-entered payment card data exists anywhere in the codebase, the database
  schema, or the logs, verified by an automated check.

## Assumptions

- **Simulation only.** No real payments, no fulfilment, no shipping. This is a fixed constraint
  from the source specification, not a v1 simplification.
- **Fixed technology constraints.** The source specification fixes the client, authentication,
  push, backend, database, image CDN, maps, and hosting choices. They are recorded in the
  constitution and elaborated in `plan.md`; this specification deliberately describes behaviour
  rather than those choices.
- **Catalogue scale.** Tens of thousands of products at most. Search and filtering are assumed
  to be satisfiable by the primary datastore without a separate search service.
- **Single-region deployment.** No multi-region replication or data residency requirements.
- **Demo data licensing.** Seed data and imagery come from sources licensed for development and
  demo use. Publishing the app publicly would require re-checking those licences, and generated
  titles would be preferred over real brand names.
- **Exchange rates are fixed in v1.** Live rate fetching is a planned later change behind the
  same interface, per FR-051.
- **Delivery routes are straight lines in v1.** Real road routing is a planned later change that
  must not require a data model change.
- **Server-side cart sync is optional.** The cart is locally authoritative; cross-device sync is
  explicitly deferred, so the concurrent-edit edge case above resolves as last-write-wins on a
  single device rather than a merge.
- **Admin tooling is deferred.** Catalogue management in v1 is the seed script; a web admin
  interface is future work.
- **Account deletion is a request, not an immediate erasure.** In v1 the request is recorded and
  handled manually; there is no automated purge pipeline, and no admin interface to run one
  from. FR-017 specifies the parts that must be immediate — the acknowledgement and device
  deregistration — because those are the parts a user would otherwise notice going wrong.
- **Reviews are anonymised, not deleted, when an account is removed.** Deleting them would
  change every affected product's rating average and count retroactively, which would make
  historical catalogue data irreproducible and contradict Principle III.
- **Photo credits.** A static credits screen satisfies the attribution requested by the chosen
  image sources.
