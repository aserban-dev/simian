"""`GET /orders` against the published contract (T102).

The order history is the one list in this API that is *per user*, so the assertion that matters
is not the paging — it is that a page can never contain somebody else's order (FR-032). Paging
is asserted alongside it because a keyset cursor scoped to the wrong user would leak exactly
one row at a time, which is the kind of bug a single-user test never sees.
"""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy.orm import Session

from tests.factories import add_address, add_product, order_payload, user_for

pytestmark = [pytest.mark.contract, pytest.mark.integration]

ORDERS = "/v1/orders"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


def place_orders(client: Any, session: Session, headers: dict[str, str], count: int) -> list[str]:
    """`count` orders for the caller, oldest first. Returns their ids in creation order."""
    token = headers["Authorization"].removeprefix("Bearer ")
    client.get(ME, headers=headers)
    user = user_for(session, token)
    product = add_product(session, title="Running Shoe", price_minor=4999)
    # One default per user is what the partial unique index allows, so each caller gets one.
    address = add_address(session, user, is_default=True)

    ids: list[str] = []
    for index in range(count):
        response = client.post(
            ORDERS,
            headers=headers,
            json=order_payload(
                product_ids=[product.id],
                address_id=address.id,
                idempotency_key=f"{token}-{index}",
            ),
        )
        assert response.status_code == 201, response.text
        ids.append(response.json()["id"])
    return ids


class TestTheShape:
    def test_returns_200(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 1)

        assert client.get(ORDERS, headers=AUTH_A).status_code == 200

    def test_the_body_has_items_and_next_cursor(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 1)

        body = client.get(ORDERS, headers=AUTH_A).json()

        assert "items" in body
        assert "next_cursor" in body

    def test_each_item_matches_the_contracted_OrderSummary(
        self, client: Any, db_session: Session, contract: dict[str, Any]
    ) -> None:
        place_orders(client, db_session, AUTH_A, 1)

        item = client.get(ORDERS, headers=AUTH_A).json()["items"][0]

        for field in contract["components"]["schemas"]["OrderSummary"]["required"]:
            assert field in item, f"contract requires `{field}` on OrderSummary"

    def test_a_summary_carries_no_line_items(self, client: Any, db_session: Session) -> None:
        """OrderSummary is a summary: the detail endpoint is where the lines live."""
        place_orders(client, db_session, AUTH_A, 1)

        item = client.get(ORDERS, headers=AUTH_A).json()["items"][0]

        assert "items" not in item
        assert "tracking" not in item

    def test_an_empty_history_is_an_empty_list_not_a_404(
        self, client: Any, db_session: Session
    ) -> None:
        """FR-063: the client renders an empty state; it should not have to catch an error."""
        client.get(ME, headers=AUTH_A)

        body = client.get(ORDERS, headers=AUTH_A).json()

        assert body["items"] == []
        assert body["next_cursor"] is None


class TestOwnershipScoping:
    """FR-032 — a page must never contain another user's order."""

    def test_only_the_callers_orders_are_listed(self, client: Any, db_session: Session) -> None:
        mine = place_orders(client, db_session, AUTH_A, 2)
        theirs = place_orders(client, db_session, AUTH_B, 2)

        listed = {item["id"] for item in client.get(ORDERS, headers=AUTH_A).json()["items"]}

        assert listed == set(mine)
        assert listed.isdisjoint(theirs)

    def test_each_user_sees_their_own_count(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 3)
        place_orders(client, db_session, AUTH_B, 1)

        assert len(client.get(ORDERS, headers=AUTH_A).json()["items"]) == 3
        assert len(client.get(ORDERS, headers=AUTH_B).json()["items"]) == 1

    def test_another_users_cursor_does_not_expose_their_orders(
        self, client: Any, db_session: Session
    ) -> None:
        """A cursor is a position, not a capability — paging with one must stay user-scoped."""
        theirs = place_orders(client, db_session, AUTH_B, 3)
        place_orders(client, db_session, AUTH_A, 3)

        their_page = client.get(ORDERS, headers=AUTH_B, params={"limit": 1}).json()
        borrowed = their_page["next_cursor"]
        assert borrowed

        mine = client.get(ORDERS, headers=AUTH_A, params={"cursor": borrowed}).json()

        assert {item["id"] for item in mine["items"]}.isdisjoint(theirs)


class TestPaging:
    def test_the_limit_is_respected(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 5)

        body = client.get(ORDERS, headers=AUTH_A, params={"limit": 2}).json()

        assert len(body["items"]) == 2

    def test_a_next_cursor_is_returned_when_more_remain(
        self, client: Any, db_session: Session
    ) -> None:
        place_orders(client, db_session, AUTH_A, 5)

        body = client.get(ORDERS, headers=AUTH_A, params={"limit": 2}).json()

        assert body["next_cursor"]

    def test_no_cursor_is_returned_on_the_last_page(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 2)

        body = client.get(ORDERS, headers=AUTH_A, params={"limit": 20}).json()

        assert body["next_cursor"] is None

    def test_a_malformed_cursor_is_a_handled_400(self, client: Any, db_session: Session) -> None:
        """FR-060: recoverable — the client restarts paging rather than showing an error."""
        place_orders(client, db_session, AUTH_A, 1)

        response = client.get(ORDERS, headers=AUTH_A, params={"cursor": "not-a-cursor"})

        assert response.status_code == 400
        assert response.headers["content-type"].startswith("application/problem+json")

    def test_an_out_of_range_limit_is_400(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 1)

        assert client.get(ORDERS, headers=AUTH_A, params={"limit": 0}).status_code == 400
        assert client.get(ORDERS, headers=AUTH_A, params={"limit": 500}).status_code == 400


class TestRejectedRequests:
    def test_an_anonymous_request_is_401(self, client: Any, db_session: Session) -> None:
        place_orders(client, db_session, AUTH_A, 1)

        assert client.get(ORDERS).status_code == 401

    def test_a_rejected_token_is_401(self, client: Any) -> None:
        assert client.get(ORDERS, headers={"Authorization": "Bearer nonsense"}).status_code == 401
