"""The four `/me/addresses` operations against the published contract (T109).

The case worth reading first is `422` (FR-043): an address that cannot be resolved to
coordinates is **not saved at all**. A partial address would be a row the delivery simulation
cannot place on a map — discovered at checkout, long after the user typed it.
"""

from __future__ import annotations

import uuid
from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from dupermarket_api.models import Address
from tests.factories import user_for

pytestmark = [pytest.mark.contract, pytest.mark.integration]

ADDRESSES = "/v1/me/addresses"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


def payload(**overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "label": "Home",
        "recipient_name": "Sam Shopper",
        "line1": "1 Test Street",
        "city": "Bucharest",
        "postal_code": "010101",
        "country_code": "RO",
        "is_default": False,
    }
    body.update(overrides)
    return body


def address_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(Address)) or 0


@pytest.fixture
def signed_in(client: Any) -> None:
    client.get(ME, headers=AUTH_A)


class TestCreate:
    def test_returns_201(self, client: Any, signed_in: None) -> None:
        assert client.post(ADDRESSES, headers=AUTH_A, json=payload()).status_code == 201

    def test_the_body_matches_the_contracted_Address(
        self, client: Any, signed_in: None, contract: dict[str, Any]
    ) -> None:
        body = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        input_required = contract["components"]["schemas"]["AddressInput"]["required"]
        own_required = contract["components"]["schemas"]["Address"]["allOf"][1]["required"]
        for field in [*input_required, *own_required]:
            assert field in body, f"contract requires `{field}` on Address"

    def test_coordinates_are_resolved_on_write(self, client: Any, signed_in: None) -> None:
        """FR-042: the response already carries them; no read will resolve them again."""
        body = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        assert body["lat"] == pytest.approx(44.4268, abs=0.5)
        assert body["lng"] == pytest.approx(26.1025, abs=0.5)

    def test_the_first_address_becomes_the_default(self, client: Any, signed_in: None) -> None:
        """FR-041: 'exactly one default' is unsatisfiable if the first one is not it."""
        body = client.post(ADDRESSES, headers=AUTH_A, json=payload(is_default=False)).json()

        assert body["is_default"] is True

    def test_a_missing_line1_is_400(self, client: Any, signed_in: None) -> None:
        body = payload()
        del body["line1"]

        assert client.post(ADDRESSES, headers=AUTH_A, json=body).status_code == 400

    def test_a_malformed_country_code_is_400(self, client: Any, signed_in: None) -> None:
        assert (
            client.post(ADDRESSES, headers=AUTH_A, json=payload(country_code="rou")).status_code
            == 400
        )

    def test_an_anonymous_request_is_401(self, client: Any) -> None:
        assert client.post(ADDRESSES, json=payload()).status_code == 401


class TestSavingSeveralAddresses:
    """FR-040 — *multiple* addresses, each creatable, updatable and deletable.

    The plural is the requirement. A design that allowed only one would satisfy every other
    assertion in this file, so it is asserted on its own.
    """

    def test_several_addresses_can_be_saved(self, client: Any, signed_in: None) -> None:
        for label, city, country in (
            ("Home", "Bucharest", "RO"),
            ("Work", "Cluj-Napoca", "RO"),
            ("Parents", "Madrid", "ES"),
        ):
            response = client.post(
                ADDRESSES,
                headers=AUTH_A,
                json=payload(label=label, city=city, country_code=country),
            )
            assert response.status_code == 201, response.text

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        assert {item["label"] for item in items} == {"Home", "Work", "Parents"}

    def test_each_one_keeps_its_own_coordinates(self, client: Any, signed_in: None) -> None:
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home"))
        client.post(
            ADDRESSES,
            headers=AUTH_A,
            json=payload(label="Parents", city="Madrid", country_code="ES"),
        )

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        coordinates = {(item["lat"], item["lng"]) for item in items}
        assert len(coordinates) == 2, "each address is geocoded to its own location"

    def test_one_can_be_updated_without_touching_the_others(
        self, client: Any, signed_in: None
    ) -> None:
        home = client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home")).json()
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work", city="Cluj-Napoca"))

        client.patch(
            f"{ADDRESSES}/{home['id']}", headers=AUTH_A, json=payload(label="Home renamed")
        )

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        assert {item["label"] for item in items} == {"Home renamed", "Work"}

    def test_one_can_be_deleted_leaving_the_rest(self, client: Any, signed_in: None) -> None:
        home = client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home")).json()
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work", city="Cluj-Napoca"))
        client.post(
            ADDRESSES,
            headers=AUTH_A,
            json=payload(label="Parents", city="Madrid", country_code="ES"),
        )

        client.delete(f"{ADDRESSES}/{home['id']}", headers=AUTH_A)

        items = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        assert {item["label"] for item in items} == {"Work", "Parents"}


class TestUnresolvableAddress:
    """FR-043 — told, and nothing saved."""

    def test_it_is_422(self, client: Any, signed_in: None) -> None:
        response = client.post(
            ADDRESSES, headers=AUTH_A, json=payload(city="Atlantis", country_code="XX")
        )

        assert response.status_code == 422

    def test_nothing_is_saved(self, client: Any, signed_in: None, db_session: Session) -> None:
        before = address_count(db_session)

        client.post(ADDRESSES, headers=AUTH_A, json=payload(city="Atlantis", country_code="XX"))

        assert address_count(db_session) == before, "FR-043 forbids saving a partial address"

    def test_the_message_says_what_to_do(self, client: Any, signed_in: None) -> None:
        body = client.post(
            ADDRESSES, headers=AUTH_A, json=payload(city="Atlantis", country_code="XX")
        ).json()

        assert body["detail"]
        assert body["status"] == 422

    def test_it_is_a_problem_document(self, client: Any, signed_in: None) -> None:
        response = client.post(
            ADDRESSES, headers=AUTH_A, json=payload(city="Atlantis", country_code="XX")
        )

        assert response.headers["content-type"].startswith("application/problem+json")


class TestList:
    def test_returns_the_users_addresses(self, client: Any, signed_in: None) -> None:
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home"))
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Work", city="Cluj-Napoca"))

        body = client.get(ADDRESSES, headers=AUTH_A).json()

        assert {item["label"] for item in body["items"]} == {"Home", "Work"}

    def test_an_empty_list_is_not_an_error(self, client: Any, signed_in: None) -> None:
        assert client.get(ADDRESSES, headers=AUTH_A).json()["items"] == []

    def test_another_users_addresses_are_not_listed(self, client: Any) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Mine"))

        body = client.get(ADDRESSES, headers=AUTH_B).json()

        assert body["items"] == []

    def test_an_anonymous_request_is_401(self, client: Any) -> None:
        assert client.get(ADDRESSES).status_code == 401


class TestUpdate:
    def test_returns_200(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        response = client.patch(
            f"{ADDRESSES}/{created['id']}", headers=AUTH_A, json=payload(label="Renamed")
        )

        assert response.status_code == 200
        assert response.json()["label"] == "Renamed"

    def test_moving_the_address_moves_the_coordinates(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        moved = client.patch(
            f"{ADDRESSES}/{created['id']}",
            headers=AUTH_A,
            json=payload(city="Madrid", country_code="ES"),
        ).json()

        assert moved["lat"] != created["lat"]

    def test_an_unresolvable_update_is_422_and_changes_nothing(
        self, client: Any, signed_in: None
    ) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        response = client.patch(
            f"{ADDRESSES}/{created['id']}",
            headers=AUTH_A,
            json=payload(city="Atlantis", country_code="XX"),
        )

        assert response.status_code == 422
        unchanged = client.get(ADDRESSES, headers=AUTH_A).json()["items"][0]
        assert unchanged["city"] == "Bucharest"

    def test_another_users_address_is_404(self, client: Any) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        response = client.patch(
            f"{ADDRESSES}/{created['id']}", headers=AUTH_B, json=payload(label="Theirs")
        )

        assert response.status_code == 404

    def test_an_unknown_address_is_404(self, client: Any, signed_in: None) -> None:
        assert (
            client.patch(f"{ADDRESSES}/{uuid.uuid4()}", headers=AUTH_A, json=payload()).status_code
            == 404
        )

    def test_an_anonymous_request_is_401(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        assert client.patch(f"{ADDRESSES}/{created['id']}", json=payload()).status_code == 401


class TestDelete:
    def test_returns_204(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        assert client.delete(f"{ADDRESSES}/{created['id']}", headers=AUTH_A).status_code == 204

    def test_it_disappears_from_the_list(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        client.delete(f"{ADDRESSES}/{created['id']}", headers=AUTH_A)

        assert client.get(ADDRESSES, headers=AUTH_A).json()["items"] == []

    def test_the_row_survives_as_a_soft_delete(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        """FR-044: an order points at this row, so it must not actually go away."""
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        client.delete(f"{ADDRESSES}/{created['id']}", headers=AUTH_A)

        row = db_session.get(Address, uuid.UUID(created["id"]))
        assert row is not None
        assert row.deleted_at is not None

    def test_deleting_the_default_promotes_another(self, client: Any, signed_in: None) -> None:
        first = client.post(ADDRESSES, headers=AUTH_A, json=payload(label="Home")).json()
        client.post(
            ADDRESSES, headers=AUTH_A, json=payload(label="Work", city="Madrid", country_code="ES")
        )

        client.delete(f"{ADDRESSES}/{first['id']}", headers=AUTH_A)

        remaining = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        assert len(remaining) == 1
        assert remaining[0]["is_default"] is True

    def test_another_users_address_is_404(self, client: Any) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        assert client.delete(f"{ADDRESSES}/{created['id']}", headers=AUTH_B).status_code == 404

    def test_deleting_twice_is_404_the_second_time(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()
        client.delete(f"{ADDRESSES}/{created['id']}", headers=AUTH_A)

        assert client.delete(f"{ADDRESSES}/{created['id']}", headers=AUTH_A).status_code == 404

    def test_an_anonymous_request_is_401(self, client: Any, signed_in: None) -> None:
        created = client.post(ADDRESSES, headers=AUTH_A, json=payload()).json()

        assert client.delete(f"{ADDRESSES}/{created['id']}").status_code == 401


class TestOwnership:
    def test_each_users_addresses_are_their_own(self, client: Any, db_session: Session) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(ADDRESSES, headers=AUTH_A, json=payload(label="A"))
        client.post(ADDRESSES, headers=AUTH_B, json=payload(label="B"))

        a = client.get(ADDRESSES, headers=AUTH_A).json()["items"]
        b = client.get(ADDRESSES, headers=AUTH_B).json()["items"]

        assert [item["label"] for item in a] == ["A"]
        assert [item["label"] for item in b] == ["B"]
        assert user_for(db_session).id != user_for(db_session, "user-b").id
