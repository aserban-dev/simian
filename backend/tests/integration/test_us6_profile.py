"""US6 — addresses against a real PostgreSQL (T111, T112, T113).

Three properties that cannot be demonstrated without actual rows:

* **T111 / FR-041** — "exactly one default" is a *partial unique index*, so the interesting
  assertion is that the database refuses a second default even if application code tries.
* **T112 / FR-044** — deleting an address must not alter an order that shipped to it. Only real
  foreign keys and a real soft delete can show that.
* **T113 / FR-042** — geocoding happens once, on write, and never on read. That is a claim about
  a call count, so it is asserted with a counting fake.
"""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from dupermarket_api.models import Address, Order
from dupermarket_api.services.geocoding import CountingGeocoder, get_geocoder
from tests.factories import add_product, order_payload, user_for

pytestmark = pytest.mark.integration

ADDRESSES = "/v1/me/addresses"
ORDERS = "/v1/orders"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}


def payload(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "label": "Home",
        "line1": "1 Test Street",
        "city": "Bucharest",
        "country_code": "RO",
        "is_default": False,
    }
    body.update(overrides)
    return body


@pytest.fixture
def counting_geocoder(app: Any) -> CountingGeocoder:
    """Substitutes the seam so calls into it can be counted (FR-042)."""
    geocoder = CountingGeocoder()
    app.dependency_overrides[get_geocoder] = lambda: geocoder
    return geocoder


@pytest.fixture
def signed_in(client: Any) -> None:
    client.get(ME, headers=AUTH_A)


class TestExactlyOneDefault:
    """T111 / FR-041."""

    def test_setting_a_new_default_clears_the_old_one(self, client: Any, signed_in: None) -> None:
        first = client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home")).json()
        assert first["is_default"] is True

        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work", is_default=True))

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        defaults = [item for item in items if item["is_default"]]
        assert len(defaults) == 1
        assert defaults[0]["label"] == "Work"

    def test_the_promotion_is_atomic(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        """Never two defaults, not even momentarily — the index would reject the write."""
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home"))
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work", is_default=True))
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Gym", is_default=True))

        count = db_session.scalar(
            select(func.count())
            .select_from(Address)
            .where(Address.is_default, Address.deleted_at.is_(None))
        )
        assert count == 1

    def test_promoting_by_update_also_demotes_the_other(self, client: Any, signed_in: None) -> None:
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home"))
        work = client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work")).json()

        client.patch(
            f"{ADDRESSES}/{work['id']}", headers=AUTH_A, json=payload(label="Work", is_default=True)
        )

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        assert [item["label"] for item in items if item["is_default"]] == ["Work"]

    def test_the_database_refuses_a_second_default(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        """The guarantee is the index, not the application. Proven by going around the API."""
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home"))
        user = user_for(db_session)

        db_session.add(
            Address(
                user_id=user.id,
                line1="2 Sneaky Road",
                city="Bucharest",
                country_code="RO",
                lat=44.4,
                lng=26.1,
                is_default=True,
            )
        )

        with pytest.raises(IntegrityError):
            db_session.flush()
        db_session.rollback()

    def test_a_soft_deleted_default_does_not_occupy_the_slot(
        self, client: Any, signed_in: None
    ) -> None:
        """The index is partial on `deleted_at IS NULL`, which is what makes promotion possible."""
        first = client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home")).json()
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work"))

        client.delete(f"{ADDRESSES}/{first['id']}", headers=AUTH_A)

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        assert [item["label"] for item in items if item["is_default"]] == ["Work"]


class TestDeletingAnAddressLeavesOrdersAlone:
    """T112 / FR-044."""

    @pytest.fixture
    def ordered(self, client: Any, db_session: Session, signed_in: None) -> Any:
        product = add_product(db_session, title="Running Shoe", price_minor=4999)
        address = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()
        order = client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(product_ids=[product.id], address_id=address["id"]),
        )
        assert order.status_code == 201, order.text
        return {"address": address, "order": order.json()}

    def test_the_order_still_reads_back_after_the_address_is_deleted(
        self, client: Any, ordered: Any
    ) -> None:
        client.delete(f"{ADDRESSES}/{ordered['address']['id']}", headers=AUTH_A)

        response = client.get(f"{ORDERS}/{ordered['order']['id']}", headers=AUTH_A)

        assert response.status_code == 200

    def test_the_recorded_address_is_unchanged(self, client: Any, ordered: Any) -> None:
        before = client.get(f"{ORDERS}/{ordered['order']['id']}", headers=AUTH_A).json()["address"]

        client.delete(f"{ADDRESSES}/{ordered['address']['id']}", headers=AUTH_A)

        after = client.get(f"{ORDERS}/{ordered['order']['id']}", headers=AUTH_A).json()["address"]
        assert after == before

    def test_the_order_row_keeps_its_snapshot(
        self, client: Any, ordered: Any, db_session: Session
    ) -> None:
        client.delete(f"{ADDRESSES}/{ordered['address']['id']}", headers=AUTH_A)

        order = db_session.get(Order, ordered["order"]["id"])
        assert order is not None
        assert "1 Test Street" in str(order.address_snapshot)

    def test_the_delete_is_soft_so_the_foreign_key_still_resolves(
        self, client: Any, ordered: Any, db_session: Session
    ) -> None:
        """`ondelete=RESTRICT` means a hard delete would fail outright; soft delete is why it
        does not have to."""
        client.delete(f"{ADDRESSES}/{ordered['address']['id']}", headers=AUTH_A)

        order = db_session.get(Order, ordered["order"]["id"])
        assert order is not None
        assert db_session.get(Address, order.address_id) is not None


class TestGeocodingHappensOnceOnWrite:
    """T113 / FR-042 — a call count, not a claim."""

    def test_creating_geocodes_exactly_once(
        self, client: Any, signed_in: None, counting_geocoder: CountingGeocoder
    ) -> None:
        client.post(ADDRESSES, headers=AUTH_A, json=payload())

        assert counting_geocoder.calls == 1

    def test_reading_the_list_geocodes_nothing(
        self, client: Any, signed_in: None, counting_geocoder: CountingGeocoder
    ) -> None:
        client.post(ADDRESSES, headers=AUTH_A, json=payload())
        before = counting_geocoder.calls

        for _ in range(5):
            client.get(ADDRESSES, headers=AUTH_A)

        assert counting_geocoder.calls == before, "FR-042 forbids read-path geocoding"

    def test_checking_out_geocodes_nothing(
        self,
        client: Any,
        signed_in: None,
        db_session: Session,
        counting_geocoder: CountingGeocoder,
    ) -> None:
        """The read path that would be easiest to get wrong: an order needs coordinates, and
        they are already stored."""
        product = add_product(db_session, title="Running Shoe")
        address = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()
        before = counting_geocoder.calls

        client.post(
            ORDERS,
            headers=AUTH_A,
            json=order_payload(product_ids=[product.id], address_id=address["id"]),
        )

        assert counting_geocoder.calls == before

    def test_renaming_an_address_does_not_geocode(
        self, client: Any, signed_in: None, counting_geocoder: CountingGeocoder
    ) -> None:
        """Geocoding is metered; a label change does not move the pin."""
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()
        before = counting_geocoder.calls

        client.patch(
            f"{ADDRESSES}/{created['id']}",
            headers=AUTH_A,
            json=payload(label="Renamed", recipient_name="Someone Else"),
        )

        assert counting_geocoder.calls == before

    def test_moving_an_address_geocodes_once(
        self, client: Any, signed_in: None, counting_geocoder: CountingGeocoder
    ) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()
        before = counting_geocoder.calls

        client.patch(
            f"{ADDRESSES}/{created['id']}",
            headers=AUTH_A,
            json=payload(city="Madrid", country_code="ES"),
        )

        assert counting_geocoder.calls == before + 1

    def test_a_failed_resolution_still_only_costs_one_call(
        self, client: Any, signed_in: None, counting_geocoder: CountingGeocoder
    ) -> None:
        client.post(ADDRESSES, headers=AUTH_A, json=payload(city="Atlantis", country_code="XX"))

        assert counting_geocoder.calls == 1
