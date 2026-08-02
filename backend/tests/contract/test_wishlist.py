"""The three `/me/wishlist` operations against the published contract (T110).

FR-045. The assertion that carries weight is idempotence: the contract says adding twice yields
the same state and still returns 201, because a heart icon gets double-tapped and an optimistic
UI retries. Anything that made the second add an error would surface as a spurious failure on a
gesture the user meant as one.
"""

from __future__ import annotations

import uuid
from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from dupermarket_api.models import WishlistItem
from tests.factories import add_product

pytestmark = [pytest.mark.contract, pytest.mark.integration]

WISHLIST = "/v1/me/wishlist"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


def item_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(WishlistItem)) or 0


@pytest.fixture
def product(client: Any, db_session: Session) -> Any:
    client.get(ME, headers=AUTH_A)
    return add_product(db_session, title="Running Shoe", price_minor=4999)


class TestAdd:
    def test_returns_201(self, client: Any, product: Any) -> None:
        response = client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        assert response.status_code == 201

    def test_adding_twice_still_returns_201(self, client: Any, product: Any) -> None:
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        response = client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        assert response.status_code == 201

    def test_adding_twice_creates_one_row(
        self, client: Any, product: Any, db_session: Session
    ) -> None:
        for _ in range(3):
            client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        assert item_count(db_session) == 1

    def test_an_unknown_product_is_404(self, client: Any, product: Any) -> None:
        response = client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(uuid.uuid4())})

        assert response.status_code == 404

    def test_a_malformed_product_id_is_400(self, client: Any, product: Any) -> None:
        assert client.post(WISHLIST, headers=AUTH_A, json={"product_id": "nope"}).status_code == 400

    def test_an_anonymous_request_is_401(self, client: Any, product: Any) -> None:
        assert client.post(WISHLIST, json={"product_id": str(product.id)}).status_code == 401


class TestList:
    def test_returns_the_wishlisted_products(self, client: Any, product: Any) -> None:
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        body = client.get(WISHLIST, headers=AUTH_A).json()

        assert [item["id"] for item in body["items"]] == [str(product.id)]

    def test_each_item_matches_the_contracted_ProductSummary(
        self, client: Any, product: Any, contract: dict[str, Any]
    ) -> None:
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        item = client.get(WISHLIST, headers=AUTH_A).json()["items"][0]

        for field in contract["components"]["schemas"]["ProductSummary"]["required"]:
            assert field in item, f"contract requires `{field}` on ProductSummary"

    def test_the_body_has_items_and_next_cursor(self, client: Any, product: Any) -> None:
        body = client.get(WISHLIST, headers=AUTH_A).json()

        assert "items" in body
        assert "next_cursor" in body

    def test_an_empty_wishlist_is_not_an_error(self, client: Any, product: Any) -> None:
        """FR-063: the client renders an empty state rather than catching a failure."""
        body = client.get(WISHLIST, headers=AUTH_A).json()

        assert body["items"] == []
        assert body["next_cursor"] is None

    def test_paging_returns_each_product_once(
        self, client: Any, product: Any, db_session: Session
    ) -> None:
        ids = {str(product.id)}
        for index in range(4):
            other = add_product(db_session, title=f"Thing {index}")
            ids.add(str(other.id))
            client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(other.id)})
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        seen: list[str] = []
        cursor: str | None = None
        for _ in range(20):
            params: dict[str, Any] = {"limit": 2}
            if cursor:
                params["cursor"] = cursor
            page = client.get(WISHLIST, headers=AUTH_A, params=params).json()
            seen.extend(item["id"] for item in page["items"])
            cursor = page["next_cursor"]
            if not cursor:
                break

        assert set(seen) == ids
        assert len(seen) == len(set(seen)), "a product was served on two pages"

    def test_another_users_wishlist_is_not_visible(self, client: Any, product: Any) -> None:
        client.get(ME, headers=AUTH_B)
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        assert client.get(WISHLIST, headers=AUTH_B).json()["items"] == []

    def test_a_malformed_cursor_is_400(self, client: Any, product: Any) -> None:
        response = client.get(WISHLIST, headers=AUTH_A, params={"cursor": "nonsense"})

        assert response.status_code == 400

    def test_an_anonymous_request_is_401(self, client: Any, product: Any) -> None:
        assert client.get(WISHLIST).status_code == 401


class TestRemove:
    def test_returns_204(self, client: Any, product: Any) -> None:
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        assert client.delete(f"{WISHLIST}/{product.id}", headers=AUTH_A).status_code == 204

    def test_it_disappears_from_the_list(self, client: Any, product: Any) -> None:
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        client.delete(f"{WISHLIST}/{product.id}", headers=AUTH_A)

        assert client.get(WISHLIST, headers=AUTH_A).json()["items"] == []

    def test_removing_something_absent_is_404(self, client: Any, product: Any) -> None:
        assert client.delete(f"{WISHLIST}/{product.id}", headers=AUTH_A).status_code == 404

    def test_one_user_cannot_remove_anothers_item(
        self, client: Any, product: Any, db_session: Session
    ) -> None:
        client.get(ME, headers=AUTH_B)
        client.post(WISHLIST, headers=AUTH_A, json={"product_id": str(product.id)})

        response = client.delete(f"{WISHLIST}/{product.id}", headers=AUTH_B)

        assert response.status_code == 404
        assert item_count(db_session) == 1, "the other user's item must survive"

    def test_an_anonymous_request_is_401(self, client: Any, product: Any) -> None:
        assert client.delete(f"{WISHLIST}/{product.id}").status_code == 401
