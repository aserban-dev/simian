"""`GET /orders/{orderId}` against the published contract (T094).

Two things are being checked, and the second matters more:

* the tracking payload carries everything a client needs to place the parcel itself (FR-036) —
  origin, destination, the window, and all four stage timestamps;
* another user's order is reported as **404, never 403** (FR-013, FR-032). A 403 would confirm
  the order id is real, which is exactly the leak the requirement exists to prevent.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Any

import pytest
from sqlalchemy.orm import Session

from tests.factories import add_address, add_product, order_payload, user_for

pytestmark = [pytest.mark.contract, pytest.mark.integration]

ORDERS = "/v1/orders"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


@pytest.fixture
def placed_order(client: Any, db_session: Session) -> Any:
    """An order belonging to user A."""
    client.get(ME, headers=AUTH_A)
    user = user_for(db_session)
    product = add_product(db_session, title="Running Shoe", price_minor=4999)
    address = add_address(db_session, user)
    created = client.post(
        ORDERS,
        headers=AUTH_A,
        json=order_payload(product_ids=[product.id], address_id=address.id),
    )
    assert created.status_code == 201, created.text
    return created.json()


class TestReadingYourOwnOrder:
    def test_returns_200(self, client: Any, placed_order: Any) -> None:
        assert client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).status_code == 200

    def test_the_body_matches_the_contracted_OrderDetail(
        self, client: Any, placed_order: Any, contract: dict[str, Any]
    ) -> None:
        body = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()

        summary_required = contract["components"]["schemas"]["OrderSummary"]["required"]
        detail_required = contract["components"]["schemas"]["OrderDetail"]["allOf"][1]["required"]
        for field in [*summary_required, *detail_required]:
            assert field in body, f"contract requires `{field}` on OrderDetail"

    def test_the_tracking_payload_is_complete(
        self, client: Any, placed_order: Any, contract: dict[str, Any]
    ) -> None:
        """FR-036: enough to compute the position with no further calls."""
        tracking = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()["tracking"]

        for field in contract["components"]["schemas"]["DeliveryTracking"]["required"]:
            assert field in tracking, f"contract requires `{field}` on DeliveryTracking"

    def test_origin_and_destination_are_coordinates(self, client: Any, placed_order: Any) -> None:
        tracking = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()["tracking"]

        for endpoint in ("origin", "destination"):
            assert -90 <= tracking[endpoint]["lat"] <= 90
            assert -180 <= tracking[endpoint]["lng"] <= 180

    def test_all_four_stage_timestamps_are_present(self, client: Any, placed_order: Any) -> None:
        stages = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()["tracking"][
            "stages"
        ]

        assert set(stages) == {
            "processing_at",
            "shipped_at",
            "out_for_delivery_at",
            "delivered_at",
        }

    def test_the_window_spans_the_whole_timeline(self, client: Any, placed_order: Any) -> None:
        tracking = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()["tracking"]

        start = dt.datetime.fromisoformat(tracking["window_start"])
        end = dt.datetime.fromisoformat(tracking["window_end"])
        assert start == dt.datetime.fromisoformat(tracking["stages"]["processing_at"])
        assert end == dt.datetime.fromisoformat(tracking["stages"]["delivered_at"])

    def test_the_current_stage_is_reported(self, client: Any, placed_order: Any) -> None:
        """Frozen at creation time, so the order is still processing."""
        body = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()

        assert body["current_stage"] == "processing"
        assert body["tracking"]["current_stage"] == "processing"

    def test_no_parcel_position_is_returned(self, client: Any, placed_order: Any) -> None:
        """FR-037: the device interpolates. A server-held position would be a value to refresh."""
        tracking = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()["tracking"]

        assert "position" not in tracking
        assert "parcel" not in tracking

    def test_the_line_items_come_back_too(self, client: Any, placed_order: Any) -> None:
        body = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()

        assert body["items"][0]["title"] == "Running Shoe"

    def test_reading_twice_returns_the_same_timeline(self, client: Any, placed_order: Any) -> None:
        """FR-034: assigned once. Re-reading must not regenerate anything."""
        first = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()
        second = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_A).json()

        assert first["tracking"]["stages"] == second["tracking"]["stages"]


class TestAnotherUsersOrder:
    """FR-032 and FR-013 — indistinguishable from one that does not exist."""

    def test_it_is_404(self, client: Any, placed_order: Any) -> None:
        client.get(ME, headers=AUTH_B)

        response = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_B)

        assert response.status_code == 404

    def test_it_is_never_403(self, client: Any, placed_order: Any) -> None:
        client.get(ME, headers=AUTH_B)

        response = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_B)

        assert response.status_code != 403, "403 confirms the order id is real"

    def test_it_is_indistinguishable_from_a_missing_order(
        self, client: Any, placed_order: Any
    ) -> None:
        """The strongest form of the requirement: the two responses are the same document."""
        client.get(ME, headers=AUTH_B)

        foreign = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_B)
        missing = client.get(f"{ORDERS}/{uuid.uuid4()}", headers=AUTH_B)

        assert foreign.status_code == missing.status_code
        assert foreign.json()["title"] == missing.json()["title"]
        assert foreign.json()["detail"] == missing.json()["detail"]

    def test_no_order_content_leaks_into_the_404_body(self, client: Any, placed_order: Any) -> None:
        client.get(ME, headers=AUTH_B)

        body = client.get(f"{ORDERS}/{placed_order['id']}", headers=AUTH_B).text

        assert placed_order["order_number"] not in body
        assert "Running Shoe" not in body


class TestRejectedRequests:
    def test_an_anonymous_request_is_401(self, client: Any, placed_order: Any) -> None:
        assert client.get(f"{ORDERS}/{placed_order['id']}").status_code == 401

    def test_an_unknown_order_is_404(self, client: Any, placed_order: Any) -> None:
        assert client.get(f"{ORDERS}/{uuid.uuid4()}", headers=AUTH_A).status_code == 404

    def test_a_malformed_id_is_a_handled_400_not_a_crash(
        self, client: Any, placed_order: Any
    ) -> None:
        response = client.get(f"{ORDERS}/not-a-uuid", headers=AUTH_A)

        assert response.status_code == 400
        assert response.headers["content-type"].startswith("application/problem+json")
