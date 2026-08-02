"""`POST /orders` against the published contract (T070).

Every declared response is exercised: 201, 400, 401, 402, 404 and 409. The two that matter most
are the ones that must leave *nothing* behind — a decline and a mid-flight withdrawal both have
to be all-or-nothing, and "no row was written" is the assertion, not "the status code was right".
"""

from __future__ import annotations

import uuid
from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from dupermarket_api.models import Order, OrderItem
from tests.factories import add_address, add_product, order_payload, user_for

pytestmark = [pytest.mark.contract, pytest.mark.integration]

ORDERS = "/v1/orders"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


def order_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(Order)) or 0


def item_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(OrderItem)) or 0


@pytest.fixture
def checkout(client: Any, db_session: Session) -> Any:
    """A signed-in user with an address and one in-stock product."""
    client.get(ME, headers=AUTH_A)
    user = user_for(db_session)
    product = add_product(db_session, price_minor=4999)
    address = add_address(db_session, user)
    return {"user": user, "product": product, "address": address}


class TestCreated:
    def test_a_confirmed_checkout_returns_201(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        )

        assert response.status_code == 201, response.text

    def test_the_body_matches_the_contracted_OrderDetail(
        self, client: Any, checkout: Any, contract: dict[str, Any]
    ) -> None:
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        # OrderDetail is OrderSummary plus three fields; both halves are required.
        summary_required = contract["components"]["schemas"]["OrderSummary"]["required"]
        detail_required = contract["components"]["schemas"]["OrderDetail"]["allOf"][1]["required"]
        for field in [*summary_required, *detail_required]:
            assert field in body, f"contract requires `{field}` on OrderDetail"

    def test_the_line_items_are_snapshots_not_references(self, client: Any, checkout: Any) -> None:
        """FR-027: the response carries the values recorded, not a lookup of today's catalogue."""
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        item = body["items"][0]
        assert item["title"] == "Running Shoe"
        assert item["unit_price"]["amount_minor"] == 4999
        assert item["quantity"] == 1

    def test_the_whole_delivery_timeline_is_returned(self, client: Any, checkout: Any) -> None:
        """FR-033: all four stages are assigned at creation, so all four are readable now."""
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        stages = body["tracking"]["stages"]
        assert set(stages) == {
            "processing_at",
            "shipped_at",
            "out_for_delivery_at",
            "delivered_at",
        }

    def test_the_timeline_is_monotonic(self, client: Any, checkout: Any) -> None:
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        stages = body["tracking"]["stages"]
        ordered = [
            stages["processing_at"],
            stages["shipped_at"],
            stages["out_for_delivery_at"],
            stages["delivered_at"],
        ]
        assert ordered == sorted(ordered)

    def test_an_order_number_is_issued(self, client: Any, checkout: Any) -> None:
        """FR-030: the confirmation screen needs something to show."""
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        ).json()

        assert body["order_number"]

    def test_quantities_multiply_into_the_total(self, client: Any, checkout: Any) -> None:
        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                quantities=[3],
            ),
        ).json()

        assert body["total"]["amount_minor"] == 3 * 4999

    def test_the_second_demo_card_also_succeeds(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="mastercard_success",
            ),
        )

        assert response.status_code == 201


class TestDeclined:
    """FR-024, FR-025 — deterministic, and it must not leave a trace."""

    def test_the_decline_card_returns_402(self, client: Any, checkout: Any) -> None:
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

    def test_no_order_row_is_written(self, client: Any, checkout: Any, db_session: Session) -> None:
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

    def test_no_order_item_row_is_written(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        before = item_count(db_session)

        client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="decline",
            ),
        )

        assert item_count(db_session) == before

    def test_the_problem_is_retryable_and_offers_another_card(
        self, client: Any, checkout: Any
    ) -> None:
        """FR-025: recoverable, with a message that suggests what to do."""
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
        assert body["detail"]

    def test_the_decline_is_a_problem_document(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="decline",
            ),
        )

        assert response.headers["content-type"].startswith("application/problem+json")


class TestNotFound:
    """FR-013 and FR-032: someone else's address is indistinguishable from a missing one."""

    def test_another_users_address_is_404(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        client.get(ME, headers=AUTH_B)
        other_address = add_address(db_session, user_for(db_session, "user-b"), is_default=False)

        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=other_address.id,
            ),
        )

        assert response.status_code == 404

    def test_never_403_for_a_foreign_address(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        client.get(ME, headers=AUTH_B)
        other_address = add_address(db_session, user_for(db_session, "user-b"), is_default=False)

        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=other_address.id,
            ),
        )

        assert response.status_code != 403, "403 confirms the address exists (FR-013)"

    def test_an_unknown_address_is_404(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=uuid.uuid4(),
            ),
        )

        assert response.status_code == 404

    def test_an_unknown_product_is_404(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[uuid.uuid4()],
                address_id=checkout["address"].id,
            ),
        )

        assert response.status_code == 404


class TestWithdrawnBetweenSubmissionAndCommit:
    """FR-021's race half, and the contract's 409.

    The client already excludes a withdrawn line before submitting, so arriving here means the
    product was withdrawn in the window between submission and commit. The order is rejected
    whole: silently dropping the line would mean recording an order the user never confirmed.
    """

    def test_a_withdrawn_product_is_409(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        withdrawn = add_product(db_session, title="Vanishing Hat", withdrawn=True)

        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id, withdrawn.id],
                address_id=checkout["address"].id,
            ),
        )

        assert response.status_code == 409

    def test_the_detail_names_the_product(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        withdrawn = add_product(db_session, title="Vanishing Hat", withdrawn=True)

        body = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id, withdrawn.id],
                address_id=checkout["address"].id,
            ),
        ).json()

        assert "Vanishing Hat" in body["detail"], "the client has to say which product"

    def test_no_partial_order_is_written(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        withdrawn = add_product(db_session, title="Vanishing Hat", withdrawn=True)
        before_orders, before_items = order_count(db_session), item_count(db_session)

        client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id, withdrawn.id],
                address_id=checkout["address"].id,
            ),
        )

        assert order_count(db_session) == before_orders
        assert item_count(db_session) == before_items, "the surviving line must not be recorded"

    def test_an_out_of_stock_product_is_409(
        self, client: Any, checkout: Any, db_session: Session
    ) -> None:
        """FR-078: browsable, but not orderable."""
        gone = add_product(db_session, title="Sold Out Sock", stock="out_of_stock")

        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[gone.id],
                address_id=checkout["address"].id,
            ),
        )

        assert response.status_code == 409


class TestRejectedRequests:
    def test_an_anonymous_request_is_401(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
            ),
        )

        assert response.status_code == 401

    def test_an_empty_basket_is_400(self, client: Any, checkout: Any) -> None:
        """The contract sets `minItems: 1` — an order with no lines is meaningless."""
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json={
                "items": [],
                "address_id": str(checkout["address"].id),
                "demo_card_id": "visa_success",
                "currency": "EUR",
            },
        )

        assert response.status_code == 400

    def test_a_zero_quantity_is_400(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                quantities=[0],
            ),
        )

        assert response.status_code == 400

    def test_an_unknown_card_id_is_400(self, client: Any, checkout: Any) -> None:
        """The card set is closed. An unrecognised id is a bad request, not a decline."""
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                demo_card_id="amex_platinum",
            ),
        )

        assert response.status_code == 400

    def test_a_malformed_currency_is_400(self, client: Any, checkout: Any) -> None:
        response = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(
                product_ids=[checkout["product"].id],
                address_id=checkout["address"].id,
                currency="euro",
            ),
        )

        assert response.status_code == 400

    def test_a_card_number_field_is_ignored_not_stored(self, client: Any, checkout: Any) -> None:
        """Principle I: even if a client invents one, nothing accepts it."""
        payload = order_payload(
            product_ids=[checkout["product"].id],
            address_id=checkout["address"].id,
        )
        payload["card_number"] = "4111111111111111"

        response = client.post(ORDERS, headers=AUTH_A, json=payload)

        assert response.status_code == 201
        assert "card_number" not in response.text
