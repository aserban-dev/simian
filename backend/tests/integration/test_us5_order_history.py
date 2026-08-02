"""US5 — order history, against a real PostgreSQL (T103).

FR-031: newest first, and pageable without duplication.

The second half is the reason this is an integration test rather than a unit one. Offset paging
would pass every assertion here *until* a row is inserted between two page fetches — so the
interesting cases place an order mid-pagination and check the page boundary held. Only a real
database ordering real rows can demonstrate that.

Orders are created with the clock advanced between them, because a frozen clock would give every
order the same `created_at` and "newest first" would be untestable.
"""

from __future__ import annotations

import datetime as dt
from typing import Any

import pytest
from sqlalchemy.orm import Session

from tests.factories import add_address, add_product, order_payload, user_for

pytestmark = pytest.mark.integration

ORDERS = "/v1/orders"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}


@pytest.fixture
def shop(client: Any, db_session: Session) -> Any:
    client.get(ME, headers=AUTH_A)
    user = user_for(db_session)
    return {
        "user": user,
        "product": add_product(db_session, title="Running Shoe", price_minor=4999),
        "address": add_address(db_session, user),
    }


def place(client: Any, shop: Any, clock: Any, key: str) -> dict[str, Any]:
    """Place one order, then advance the clock so the next one is strictly newer."""
    response = client.post(
        ORDERS,
        headers=AUTH_A,
        json=order_payload(
            product_ids=[shop["product"].id],
            address_id=shop["address"].id,
            idempotency_key=key,
        ),
    )
    assert response.status_code == 201, response.text
    clock.advance(dt.timedelta(minutes=1))
    return response.json()


def page_through(client: Any, limit: int) -> list[str]:
    """Every order id, walked page by page the way a client would."""
    ids: list[str] = []
    cursor: str | None = None
    for _ in range(50):  # a bound, so a paging bug fails rather than hangs
        params: dict[str, Any] = {"limit": limit}
        if cursor:
            params["cursor"] = cursor
        body = client.get(ORDERS, headers=AUTH_A, params=params).json()
        ids.extend(item["id"] for item in body["items"])
        cursor = body["next_cursor"]
        if not cursor:
            return ids
    raise AssertionError("paging did not terminate")


class TestNewestFirst:
    """FR-031."""

    def test_the_most_recent_order_is_first(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        place(client, shop, frozen_clock, "first")
        newest = place(client, shop, frozen_clock, "second")

        body = client.get(ORDERS, headers=AUTH_A).json()

        assert body["items"][0]["id"] == newest["id"]

    def test_the_whole_list_is_in_descending_order(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        for index in range(5):
            place(client, shop, frozen_clock, f"key-{index}")

        items = client.get(ORDERS, headers=AUTH_A).json()["items"]

        stamps = [item["created_at"] for item in items]
        assert stamps == sorted(stamps, reverse=True)

    def test_ordering_survives_paging(self, client: Any, shop: Any, frozen_clock: Any) -> None:
        for index in range(6):
            place(client, shop, frozen_clock, f"key-{index}")

        paged = page_through(client, limit=2)
        single = [item["id"] for item in client.get(ORDERS, headers=AUTH_A).json()["items"]]

        assert paged == single


class TestPagingWithoutDuplication:
    """FR-031, research D3 — the failure keyset paging exists to prevent."""

    def test_every_order_appears_exactly_once(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        for index in range(7):
            place(client, shop, frozen_clock, f"key-{index}")

        ids = page_through(client, limit=2)

        assert len(ids) == 7
        assert len(set(ids)) == 7

    def test_a_page_size_of_one_still_returns_everything(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        for index in range(5):
            place(client, shop, frozen_clock, f"key-{index}")

        assert len(set(page_through(client, limit=1))) == 5

    def test_an_order_placed_mid_pagination_does_not_shift_the_window(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        """The exact case offset paging gets wrong: a new newest row while paging is in flight.

        With `OFFSET`, inserting at the head pushes everything down and the second page repeats
        a row from the first. A keyset cursor is anchored to a row, so the boundary holds.
        """
        for index in range(4):
            place(client, shop, frozen_clock, f"key-{index}")

        first = client.get(ORDERS, headers=AUTH_A, params={"limit": 2}).json()
        place(client, shop, frozen_clock, "inserted-mid-pagination")
        second = client.get(
            ORDERS, headers=AUTH_A, params={"limit": 2, "cursor": first["next_cursor"]}
        ).json()

        first_ids = {item["id"] for item in first["items"]}
        second_ids = {item["id"] for item in second["items"]}
        assert first_ids.isdisjoint(second_ids), "a row was served on two consecutive pages"

    def test_orders_sharing_a_timestamp_still_page_without_duplication(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        """Two orders in the same second are ordinary; the cursor breaks the tie on id."""
        for index in range(4):
            client.post(
                ORDERS,
                headers=AUTH_A,
                json=order_payload(
                    product_ids=[shop["product"].id],
                    address_id=shop["address"].id,
                    idempotency_key=f"same-instant-{index}",
                ),
            )

        ids = page_through(client, limit=1)

        assert len(ids) == 4
        assert len(set(ids)) == 4


class TestWhatASummaryShows:
    def test_the_total_and_item_count_are_reported(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[shop["product"].id],
                address_id=shop["address"].id,
                quantities=[3],
            ),
        )

        item = client.get(ORDERS, headers=AUTH_A).json()["items"][0]

        assert item["total"]["amount_minor"] == 3 * 4999
        assert item["item_count"] == 3

    def test_the_current_stage_is_derived_at_read_time(
        self, client: Any, shop: Any, frozen_clock: Any
    ) -> None:
        """FR-035: the same stored order reads differently later, with nothing written between."""
        place(client, shop, frozen_clock, "aging")
        assert client.get(ORDERS, headers=AUTH_A).json()["items"][0]["current_stage"] == (
            "processing"
        )

        frozen_clock.advance(dt.timedelta(days=4))

        assert client.get(ORDERS, headers=AUTH_A).json()["items"][0]["current_stage"] == (
            "delivered"
        )
