"""US3 — cart and simulated checkout, against a real PostgreSQL.

The executable form of User Story 3's Independent Test. Covers T072 (a decline leaves nothing
behind), T073 (line snapshots survive a catalogue change) and T074 (a repeated create with the
same key returns the original order).

T073 is the one that needs a real database rather than a mocked repository: the assertion is
that a later `UPDATE product` does not reach through into `order_item`, and only actual columns
can demonstrate that.
"""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from dupermarket_api.models import Order, OrderItem
from tests.factories import add_address, add_product, order_payload, user_for

pytestmark = pytest.mark.integration

ORDERS = "/v1/orders"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}


def order_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(Order)) or 0


@pytest.fixture
def checkout(client: Any, db_session: Session) -> Any:
    client.get(ME, headers=AUTH_A)
    user = user_for(db_session)
    return {
        "user": user,
        "product": add_product(db_session, title="Running Shoe", price_minor=4999),
        "address": add_address(db_session, user),
    }


class TestWhatAConfirmedCheckoutRecords:
    """FR-026 — the order records the buyer, the lines, the totals, the currency, the address
    and the creation time.

    Asserted field by field rather than by "a row exists": every one of these is something a
    later screen reads back, and a missing one only shows up in order history weeks later.
    """

    def test_the_buyer_is_recorded(self, client: Any, checkout: Any, db_session: Session) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert order.user_id == checkout["user"].id

    def test_the_line_items_are_recorded(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                quantities=[2],
            ),
        ).json()

        items = db_session.scalars(
            select(OrderItem).where(OrderItem.order_id == created["id"])
        ).all()
        assert len(items) == 1
        assert items[0].product_id == checkout["product"].id
        assert items[0].quantity == 2

    def test_the_totals_and_currency_are_recorded(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                quantities=[2],
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert order.total_minor == 2 * 4999
        assert order.currency == "EUR"
        # The base-currency total and the rate used are kept so a historical total stays
        # reproducible when rates move (research D4).
        assert order.base_total_minor == 2 * 4999
        assert order.fx_rate is not None

    def test_the_delivery_address_is_recorded(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert order.address_id == checkout["address"].id
        assert order.address_snapshot

    def test_the_creation_time_is_recorded(
        self, client: Any, checkout: Any, db_session: Session, frozen_clock: Any
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert order.created_at == frozen_clock.now()

    def test_no_payment_detail_is_recorded_anywhere_on_the_order(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """Principle I: `demo_card_id` decides the outcome and is then forgotten.

        Storing it would create the first payment-shaped column in the schema, and the second
        one is always easier than the first.
        """
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        columns = {column.name for column in order.__table__.columns}
        assert not {"demo_card_id", "card_number", "payment_method"} & columns


class TestDeclinedCheckout:
    """T072 / FR-024, FR-025."""

    def test_the_decline_card_creates_no_order(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        before = order_count(db_session)

        client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="decline",
            ),
        )

        assert order_count(db_session) == before

    def test_the_decline_is_deterministic(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """FR-024: the same card declines every time, which is what makes it demonstrable."""
        for _ in range(3):
            response = client.post(
                ORDERS,
                headers=AUTH_A,
                json=order_payload(
                    product_ids=[checkout["product"].id],
                    address_id=checkout["address"].id,
                    demo_card_id="decline",
                ),
            )
            assert response.status_code == 402

        assert order_count(db_session) == 0

    def test_the_problem_offers_a_retry(self, client: Any, checkout: Any) -> None:
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="decline",
            ),
        ).json()

        assert body["retryable"] is True

    def test_a_success_card_still_works_afterwards(self, client: Any, checkout: Any) -> None:
        """FR-025: recoverable means the next attempt goes through."""
        client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="decline",
            ),
        )

        retry = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="visa_success",
            ),
        )

        assert retry.status_code == 201


class TestSnapshotsSurviveCatalogueChanges:
    """T073 / FR-027 — the reason `order_item` duplicates three columns instead of joining."""

    def test_the_title_recorded_is_the_title_at_purchase(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        checkout["product"].title = {"en": "Renamed Shoe"}
        db_session.flush()

        item = db_session.scalar(select(OrderItem).where(OrderItem.order_id == created["id"]))
        assert item is not None
        assert item.title_snapshot == "Running Shoe"

    def test_the_price_recorded_is_the_price_at_purchase(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        checkout["product"].base_price_minor = 9999
        db_session.flush()

        item = db_session.scalar(select(OrderItem).where(OrderItem.order_id == created["id"]))
        assert item is not None
        assert item.unit_price_minor == 4999

    def test_the_order_total_does_not_move_with_the_catalogue(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                quantities=[2],
            ),
        ).json()

        checkout["product"].base_price_minor = 1
        db_session.flush()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert order.total_minor == 2 * 4999

    def test_a_withdrawn_product_does_not_erase_the_order_line(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """Order history outlives the catalogue entry — hence `ondelete=RESTRICT`."""
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        checkout["product"].withdrawn_at = checkout["product"].created_at
        db_session.flush()

        item = db_session.scalar(select(OrderItem).where(OrderItem.order_id == created["id"]))
        assert item is not None
        assert item.title_snapshot == "Running Shoe"

    def test_the_address_is_snapshotted_too(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """FR-044: the order shows where it shipped, not where the user lives now."""
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        checkout["address"].line1 = "99 Moved Away Road"
        db_session.flush()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert "1 Test Street" in str(order.address_snapshot)


class TestIdempotency:
    """T074 — a retried submission must not become a second order.

    The realistic trigger is a client that loses the response rather than the request: the order
    was created, the reply never arrived, and the user taps Confirm again.
    """

    def test_repeating_with_the_same_key_returns_the_original_order(
        self, client: Any, checkout: Any
    ) -> None:
        payload = order_payload(
            product_ids=[checkout["product"].id],
            address_id=checkout["address"].id,
            idempotency_key="key-1",
        )

        first = client.post(ORDERS, headers=AUTH_A, json=payload).json()
        second = client.post(ORDERS, headers=AUTH_A, json=payload).json()

        assert first["id"] == second["id"]
        assert first["order_number"] == second["order_number"]

    def test_repeating_with_the_same_key_creates_no_duplicate(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        payload = order_payload(
            product_ids=[checkout["product"].id],
            address_id=checkout["address"].id,
            idempotency_key="key-1",
        )

        client.post(ORDERS, headers=AUTH_A, json=payload)
        client.post(ORDERS, headers=AUTH_A, json=payload)

        assert order_count(db_session) == 1

    def test_the_replay_is_still_a_201(self, client: Any, checkout: Any) -> None:
        payload = order_payload(
            product_ids=[checkout["product"].id],
            address_id=checkout["address"].id,
            idempotency_key="key-1",
        )
        client.post(ORDERS, headers=AUTH_A, json=payload)

        assert client.post(ORDERS, headers=AUTH_A, json=payload).status_code == 201

    def test_a_different_key_creates_a_second_order(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        for key in ("key-1", "key-2"):
            client.post(
                ORDERS,
                headers=AUTH_A,
                json=order_payload(
                    product_ids=[checkout["product"].id],
                    address_id=checkout["address"].id,
                    idempotency_key=key,
                ),
            )

        assert order_count(db_session) == 2

    def test_omitting_the_key_does_not_deduplicate(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """Two deliberate identical orders are a real thing a shopper can do."""
        payload = order_payload(
            product_ids=[checkout["product"].id],
            address_id=checkout["address"].id,
        )

        client.post(ORDERS, headers=AUTH_A, json=payload)
        client.post(ORDERS, headers=AUTH_A, json=payload)

        assert order_count(db_session) == 2

    def test_a_key_is_scoped_to_its_user(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """Otherwise one user's key could return another user's order — a data leak, not a race."""
        client.get(ME, headers={"Authorization": "Bearer user-b"})
        other = user_for(db_session, "user-b")
        other_address = add_address(db_session, other, is_default=False)

        first = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                idempotency_key="shared-key",
            ),
        ).json()
        second = client.post(
            ORDERS,
            headers={"Authorization": "Bearer user-b"},
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=other_address.id,
                idempotency_key="shared-key",
            ),
        ).json()

        assert first["id"] != second["id"]
        assert order_count(db_session) == 2


class TestDeliveryTimeline:
    """FR-033 through FR-035, research D5 — assigned once, at creation."""

    def test_the_timeline_is_stored_not_derived_at_read_time(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        assert order.processing_at < order.shipped_at < order.delivered_at

    def test_the_window_stays_inside_the_contracted_bounds(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """A1/FR-033: 24 to 96 hours. The database enforces it; this proves we stay inside."""
        created = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        order = db_session.get(Order, created["id"])
        assert order is not None
        window = order.delivered_at - order.processing_at
        assert 24 <= window.total_seconds() / 3600 <= 96

    def test_two_orders_placed_at_the_same_instant_are_not_identical(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """Research D5: deterministic jitter, so simultaneous orders do not look cloned.

        The clock is frozen, so any difference here comes from the per-order derivation rather
        than from elapsed time.
        """
        stamps = set()
        for key in ("a", "b", "c", "d"):
            created = client.post(
                ORDERS,
                headers=AUTH_A,
                json=order_payload(
                    product_ids=[checkout["product"].id],
                    address_id=checkout["address"].id,
                    idempotency_key=key,
                ),
            ).json()
            order = db_session.get(Order, created["id"])
            assert order is not None
            stamps.add(order.delivered_at)

        assert len(stamps) > 1, "every order got the same delivery time; jitter is not applied"
