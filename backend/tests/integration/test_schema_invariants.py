"""Database invariants, executed against a real PostgreSQL.

The unit suite asserts these constraints *ship* by compiling the DDL. These assert PostgreSQL
actually **enforces** them — the difference between "the trigger text mentions shipped_at" and
"an UPDATE to shipped_at is rejected".

Covers T029 (write-once delivery timeline) and T111 (exactly one default address).
"""

from __future__ import annotations

import datetime as dt
import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, IntegrityError
from sqlalchemy.orm import Session

from dupermarket_api.models import Address, AppUser, Category, Order, Product, Review

pytestmark = pytest.mark.integration

NOW = dt.datetime(2026, 8, 2, 12, tzinfo=dt.UTC)


def make_user(session: Session, uid: str = "uid-1") -> AppUser:
    user = AppUser(firebase_uid=uid, notification_prefs={})
    session.add(user)
    session.flush()
    return user


def make_category(session: Session, slug: str = "shoes") -> Category:
    category = Category(slug=slug, name={"en": slug.title()}, sort_order=0)
    session.add(category)
    session.flush()
    return category


def make_product(session: Session, category: Category, sku: str = "SKU-1") -> Product:
    product = Product(
        sku=sku,
        category_id=category.id,
        title={"en": f"Product {sku}"},
        description={"en": "A product"},
        base_price_minor=1999,
        base_currency="EUR",
        stock_status="in_stock",
    )
    session.add(product)
    session.flush()
    return product


def make_address(session: Session, user: AppUser, *, default: bool) -> Address:
    address = Address(
        user_id=user.id,
        line1="1 Test Street",
        city="Madrid",
        country_code="ES",
        lat=40.4168,
        lng=-3.7038,
        is_default=default,
    )
    session.add(address)
    session.flush()
    return address


def make_order(session: Session, user: AppUser, address: Address) -> Order:
    order = Order(
        order_number=f"DP-{uuid.uuid4().hex[:10]}",
        user_id=user.id,
        address_id=address.id,
        address_snapshot={"formatted": "1 Test Street, Madrid"},
        total_minor=1999,
        currency="EUR",
        base_total_minor=1999,
        fx_rate=1,
        origin_lat=41.0,
        origin_lng=-3.0,
        destination_lat=40.4168,
        destination_lng=-3.7038,
        processing_at=NOW,
        shipped_at=NOW + dt.timedelta(hours=6),
        out_for_delivery_at=NOW + dt.timedelta(hours=54),
        delivered_at=NOW + dt.timedelta(hours=60),
    )
    session.add(order)
    session.flush()
    return order


class TestDeliveryTimelineIsWriteOnce:
    """FR-034 — T029."""

    @pytest.mark.parametrize(
        "column",
        ["processing_at", "shipped_at", "out_for_delivery_at", "delivered_at"],
    )
    def test_updating_a_stage_timestamp_is_rejected(self, db_session: Session, column: str) -> None:
        user = make_user(db_session)
        address = make_address(db_session, user, default=True)
        order = make_order(db_session, user, address)

        with pytest.raises(DBAPIError, match="immutable"):
            db_session.execute(
                text(f'UPDATE "order" SET {column} = :v WHERE id = :id'),
                {"v": NOW + dt.timedelta(days=1), "id": order.id},
            )

    @pytest.mark.parametrize(
        "column", ["origin_lat", "origin_lng", "destination_lat", "destination_lng"]
    )
    def test_moving_the_route_endpoints_is_rejected(self, db_session: Session, column: str) -> None:
        # The parcel is interpolated between these two points on-device; moving one after the
        # fact would rewrite where a delivered order went.
        user = make_user(db_session)
        address = make_address(db_session, user, default=True)
        order = make_order(db_session, user, address)

        with pytest.raises(DBAPIError, match="immutable"):
            db_session.execute(
                text(f'UPDATE "order" SET {column} = :v WHERE id = :id'),
                {"v": 1.234, "id": order.id},
            )

    def test_an_unrelated_column_can_still_be_updated(self, db_session: Session) -> None:
        # The trigger must not freeze the whole row — only the timeline and the endpoints.
        user = make_user(db_session)
        address = make_address(db_session, user, default=True)
        order = make_order(db_session, user, address)

        db_session.execute(
            text('UPDATE "order" SET total_minor = :v WHERE id = :id'),
            {"v": 2999, "id": order.id},
        )
        db_session.flush()
        assert db_session.get(Order, order.id) is not None

    def test_the_monotonic_timeline_check_rejects_a_backwards_order(
        self, db_session: Session
    ) -> None:
        """FR-035: stage derivation is only total if the timeline cannot go backwards."""
        user = make_user(db_session)
        address = make_address(db_session, user, default=True)

        # Insert a bad row rather than mutating a good one: mutating would trip the write-once
        # trigger first (correctly), and the CHECK under test would never be reached.
        with pytest.raises(IntegrityError, match="timeline_monotonic"):
            db_session.add(
                Order(
                    order_number=f"DP-{uuid.uuid4().hex[:10]}",
                    user_id=user.id,
                    address_id=address.id,
                    address_snapshot={},
                    total_minor=1,
                    currency="EUR",
                    base_total_minor=1,
                    fx_rate=1,
                    origin_lat=0,
                    origin_lng=0,
                    destination_lat=0,
                    destination_lng=0,
                    # Window stays a valid 60h so only the ordering is wrong. A row that
                    # breaks both constraints reports whichever Postgres checks first, and
                    # the test would pass for the wrong reason.
                    processing_at=NOW,
                    shipped_at=NOW - dt.timedelta(hours=1),
                    out_for_delivery_at=NOW + dt.timedelta(hours=54),
                    delivered_at=NOW + dt.timedelta(hours=60),
                )
            )
            db_session.flush()

    def test_a_window_outside_24_to_96_hours_is_rejected(self, db_session: Session) -> None:
        """FR-033 (finding A1): the window bound is enforced, not merely documented."""
        user = make_user(db_session)
        address = make_address(db_session, user, default=True)

        with pytest.raises(IntegrityError, match="delivery_window_bounds"):
            db_session.add(
                Order(
                    order_number=f"DP-{uuid.uuid4().hex[:10]}",
                    user_id=user.id,
                    address_id=address.id,
                    address_snapshot={},
                    total_minor=1,
                    currency="EUR",
                    base_total_minor=1,
                    fx_rate=1,
                    origin_lat=0,
                    origin_lng=0,
                    destination_lat=0,
                    destination_lng=0,
                    processing_at=NOW,
                    shipped_at=NOW,
                    out_for_delivery_at=NOW,
                    delivered_at=NOW + dt.timedelta(hours=2),  # far too fast
                )
            )
            db_session.flush()


class TestExactlyOneDefaultAddress:
    """FR-041 — T111."""

    def test_a_second_default_address_is_rejected(self, db_session: Session) -> None:
        user = make_user(db_session)
        make_address(db_session, user, default=True)

        with pytest.raises(IntegrityError, match="uq_address_one_default"):
            make_address(db_session, user, default=True)

    def test_two_users_may_each_have_their_own_default(self, db_session: Session) -> None:
        # The index is partial *per user*; a global one would let the first user's default
        # block everybody else's.
        a = make_user(db_session, "uid-a")
        b = make_user(db_session, "uid-b")

        make_address(db_session, a, default=True)
        make_address(db_session, b, default=True)
        db_session.flush()

    def test_a_soft_deleted_default_frees_the_slot(self, db_session: Session) -> None:
        """FR-044: an address is soft-deleted, and must not keep occupying the default slot."""
        user = make_user(db_session)
        first = make_address(db_session, user, default=True)

        first.deleted_at = NOW
        db_session.flush()

        make_address(db_session, user, default=True)
        db_session.flush()

    def test_any_number_of_non_default_addresses_are_allowed(self, db_session: Session) -> None:
        user = make_user(db_session)
        for _ in range(3):
            make_address(db_session, user, default=False)
        db_session.flush()


class TestOneReviewPerUserPerProduct:
    """FR-008."""

    def test_a_second_review_by_the_same_user_is_rejected(self, db_session: Session) -> None:
        user = make_user(db_session)
        product = make_product(db_session, make_category(db_session))

        db_session.add(Review(product_id=product.id, user_id=user.id, rating=5))
        db_session.flush()

        with pytest.raises(IntegrityError, match="uq_review_one_per_user_product"):
            db_session.add(Review(product_id=product.id, user_id=user.id, rating=1))
            db_session.flush()

    def test_seeded_reviews_are_unconstrained(self, db_session: Session) -> None:
        # user_id NULL means a seeded demo review, or one anonymised on account deletion
        # (FR-017). Many may exist per product, and they must not collide with each other.
        product = make_product(db_session, make_category(db_session))
        for rating in (1, 3, 5):
            db_session.add(Review(product_id=product.id, user_id=None, rating=rating))
        db_session.flush()

    def test_different_users_may_review_the_same_product(self, db_session: Session) -> None:
        product = make_product(db_session, make_category(db_session))
        for uid in ("uid-a", "uid-b"):
            db_session.add(
                Review(product_id=product.id, user_id=make_user(db_session, uid).id, rating=4)
            )
        db_session.flush()


class TestCategoryCycleGuard:
    """Without this, one bad seed row makes tree traversal non-terminating."""

    def test_a_category_cannot_be_its_own_parent(self, db_session: Session) -> None:
        category = make_category(db_session)
        with pytest.raises(DBAPIError, match="cycle"):
            db_session.execute(
                text("UPDATE category SET parent_id = id WHERE id = :id"), {"id": category.id}
            )

    def test_a_longer_cycle_is_also_rejected(self, db_session: Session) -> None:
        a = make_category(db_session, "a")
        b = make_category(db_session, "b")
        b.parent_id = a.id
        db_session.flush()

        with pytest.raises(DBAPIError, match="cycle"):
            db_session.execute(
                text("UPDATE category SET parent_id = :p WHERE id = :id"),
                {"p": b.id, "id": a.id},
            )

    def test_normal_nesting_is_unaffected(self, db_session: Session) -> None:
        parent = make_category(db_session, "clothing")
        child = make_category(db_session, "shirts")
        child.parent_id = parent.id
        db_session.flush()
        assert child.parent_id == parent.id


class TestSimulationBoundary:
    def test_no_column_in_the_live_schema_looks_like_a_payment_field(
        self, db_session: Session
    ) -> None:
        """SC-013 / Principle I, asserted against the deployed schema rather than the models."""
        rows = db_session.execute(
            text(
                """
                SELECT table_name, column_name
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND (column_name ~* 'card|cvv|cvc|pan$|expiry|cardholder')
                """
            )
        ).all()
        assert not rows, f"payment-shaped columns in the live schema: {rows}"
