"""The catalogue API, end to end: real routers, real database, real HTTP.

Everything below this line has been exercised only against stubs until now. These are the
first tests where a request travels through FastAPI, the service layer, PostgreSQL and back
out as JSON.

Covers T038 (catalogue contract tests) against a live stack.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Any

import pytest
from sqlalchemy.orm import Session

from dupermarket_api.models import Category, Product, ProductImage, Review

pytestmark = pytest.mark.integration

NOW = dt.datetime(2026, 8, 2, 12, tzinfo=dt.UTC)
API = "/v1"


@pytest.fixture
def seeded(db_session: Session) -> dict[str, Any]:
    """A small catalogue: two categories, three products, images, one seeded review."""
    clothing = Category(slug="clothing", name={"en": "Clothing", "es": "Ropa"}, sort_order=0)
    shirts = Category(slug="shirts", name={"en": "Shirts"}, sort_order=0)
    db_session.add_all([clothing, shirts])
    db_session.flush()
    shirts.parent_id = clothing.id

    products: list[Product] = []
    for i, (title, price, discount) in enumerate(
        [("Oxford Shirt", 4999, None), ("Linen Shirt", 2999, 25), ("Sold Out Shirt", 1999, None)]
    ):
        product = Product(
            sku=f"SKU-{i}",
            category_id=shirts.id,
            title={"en": title},
            description={"en": f"{title} description with cotton"},
            base_price_minor=price,
            base_currency="EUR",
            discount_percentage=discount,
            rating_average=4.0,
            rating_count=2,
            stock_status="out_of_stock" if i == 2 else "in_stock",
            created_at=NOW - dt.timedelta(hours=i),
        )
        db_session.add(product)
        db_session.flush()
        db_session.add(
            ProductImage(
                product_id=product.id,
                cdn_path=f"products/{product.id}/0.webp",
                sort_order=0,
                alt_text=f"{title} photo",
                source_name="pexels",
                photographer="Ada Lovelace",
                content_sha256="0" * 64,
            )
        )
        products.append(product)

    db_session.add(Review(product_id=products[0].id, user_id=None, rating=5, comment="Great"))
    db_session.flush()
    return {"clothing": clothing, "shirts": shirts, "products": products}


class TestPublicAccess:
    """FR-010: browsing needs no account."""

    def test_categories_are_readable_anonymously(self, client: Any, seeded: dict[str, Any]) -> None:
        response = client.get(f"{API}/categories")
        assert response.status_code == 200

        items = response.json()["items"]
        assert [c["slug"] for c in items] == ["clothing"]
        assert [c["slug"] for c in items[0]["children"]] == ["shirts"]

    def test_products_are_readable_anonymously(self, client: Any, seeded: dict[str, Any]) -> None:
        response = client.get(f"{API}/products")
        assert response.status_code == 200
        assert len(response.json()["items"]) == 3

    def test_product_detail_is_readable_anonymously(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        product = seeded["products"][0]
        response = client.get(f"{API}/products/{product.id}")
        assert response.status_code == 200

        body = response.json()
        assert body["title"] == "Oxford Shirt"
        assert body["description"].startswith("Oxford Shirt description")
        assert body["category_slug"] == "shirts"
        assert len(body["images"]) == 1

    def test_reviews_are_readable_anonymously(self, client: Any, seeded: dict[str, Any]) -> None:
        product = seeded["products"][0]
        response = client.get(f"{API}/products/{product.id}/reviews")
        assert response.status_code == 200
        assert response.json()["items"][0]["comment"] == "Great"


class TestResponseShape:
    def test_images_are_served_as_cdn_urls_not_proxied(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """Principle V: the API stores paths and never serves image bytes."""
        product = seeded["products"][0]
        body = client.get(f"{API}/products/{product.id}").json()

        assert body["images"][0]["url"].startswith("https://cdn.test/products/")
        assert body["thumbnail_url"].startswith("https://cdn.test/")

    def test_attribution_is_exposed_for_credits(self, client: Any, seeded: dict[str, Any]) -> None:
        """FR-075."""
        product = seeded["products"][0]
        body = client.get(f"{API}/products/{product.id}").json()
        assert body["images"][0]["attribution"]["photographer"] == "Ada Lovelace"

    def test_money_is_an_integer_of_minor_units(self, client: Any, seeded: dict[str, Any]) -> None:
        """Research D4: a float here would be a defect in the wire format."""
        body = client.get(f"{API}/products").json()
        for item in body["items"]:
            assert isinstance(item["price"]["amount_minor"], int)

    def test_a_discount_yields_a_struck_through_original(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """FR-077, through the whole stack for the first time."""
        body = client.get(f"{API}/products").json()
        linen = next(i for i in body["items"] if i["title"] == "Linen Shirt")

        assert linen["price"]["amount_minor"] == 2249  # 29.99 less 25%
        assert linen["original_price"]["amount_minor"] == 2999
        assert linen["price"]["currency"] == linen["original_price"]["currency"]

    def test_an_undiscounted_product_has_no_original_price(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        body = client.get(f"{API}/products").json()
        oxford = next(i for i in body["items"] if i["title"] == "Oxford Shirt")
        assert oxford["original_price"] is None

    def test_a_review_exposes_only_the_permitted_fields(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """FR-079, asserted on the real payload."""
        product = seeded["products"][0]
        review = client.get(f"{API}/products/{product.id}/reviews").json()["items"][0]

        assert set(review) == {
            "id",
            "rating",
            "comment",
            "author_name",
            "author_avatar_url",
            "created_at",
        }


class TestLocalisationAndCurrency:
    def test_a_requested_locale_is_used(self, client: Any, seeded: dict[str, Any]) -> None:
        """FR-047."""
        body = client.get(f"{API}/categories", params={"locale": "es"}).json()
        assert body["items"][0]["name"] == "Ropa"

    def test_a_missing_translation_falls_back_to_english(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """FR-047: never a key, never blank."""
        body = client.get(f"{API}/categories", params={"locale": "de"}).json()
        assert body["items"][0]["name"] == "Clothing"

    def test_a_known_currency_is_converted(self, client: Any, seeded: dict[str, Any]) -> None:
        body = client.get(f"{API}/products", params={"currency": "USD"}).json()
        assert body["currency"] == "USD"
        assert body["currency_fallback"] is False

    def test_an_unknown_currency_falls_back_and_says_so(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """FR-052."""
        body = client.get(f"{API}/products", params={"currency": "JPY"}).json()
        assert body["currency_fallback"] is True
        assert body["currency"] == "EUR"


class TestFilteringAndPaging:
    def test_filters_and_sort_work_over_http(self, client: Any, seeded: dict[str, Any]) -> None:
        body = client.get(
            f"{API}/products", params={"category": "shirts", "sort": "price_asc"}
        ).json()
        prices = [i["price"]["amount_minor"] for i in body["items"]]
        assert prices == sorted(prices)

    def test_paging_returns_a_usable_cursor(self, client: Any, seeded: dict[str, Any]) -> None:
        """FR-002 over HTTP: the cursor a client receives must work when sent back."""
        first = client.get(f"{API}/products", params={"limit": 2, "sort": "price_asc"}).json()
        assert first["next_cursor"] is not None

        second = client.get(
            f"{API}/products",
            params={"limit": 2, "sort": "price_asc", "cursor": first["next_cursor"]},
        ).json()

        first_ids = {i["id"] for i in first["items"]}
        second_ids = {i["id"] for i in second["items"]}
        assert not (first_ids & second_ids), "a product was served on both pages"

    def test_a_malformed_cursor_is_a_400_not_a_500(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """FR-060: a handled problem document, with a way forward."""
        response = client.get(f"{API}/products", params={"cursor": "not-a-cursor"})

        assert response.status_code == 400
        assert response.headers["content-type"].startswith("application/problem+json")
        assert "detail" in response.json()

    def test_a_cursor_from_another_sort_is_rejected(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        first = client.get(f"{API}/products", params={"limit": 1, "sort": "price_asc"}).json()
        response = client.get(
            f"{API}/products", params={"limit": 1, "sort": "rating", "cursor": first["next_cursor"]}
        )
        assert response.status_code == 400

    @pytest.mark.parametrize("term", ['"', "&", "(unbalanced", "C++", ":*"])
    def test_hostile_search_input_returns_200(
        self, client: Any, seeded: dict[str, Any], term: str
    ) -> None:
        """FR-003 / finding C2 — the end-to-end proof that this is not a 500."""
        response = client.get(f"{API}/products", params={"q": term})
        assert response.status_code == 200


class TestErrors:
    def test_an_unknown_product_is_a_404_problem_document(self, client: Any) -> None:
        response = client.get(f"{API}/products/{uuid.uuid4()}")

        assert response.status_code == 404
        assert response.headers["content-type"].startswith("application/problem+json")
        body = response.json()
        assert body["title"]
        assert "traceback" not in response.text.lower()

    def test_a_malformed_uuid_is_a_400_not_a_500(self, client: Any) -> None:
        response = client.get(f"{API}/products/not-a-uuid")
        assert response.status_code == 400

    def test_a_withdrawn_product_is_a_404(self, client: Any, db_session: Session) -> None:
        category = Category(slug="x", name={"en": "X"}, sort_order=0)
        db_session.add(category)
        db_session.flush()
        product = Product(
            sku="GONE",
            category_id=category.id,
            title={"en": "Gone"},
            description={"en": "Gone"},
            base_price_minor=100,
            base_currency="EUR",
            stock_status="in_stock",
            withdrawn_at=NOW,
        )
        db_session.add(product)
        db_session.flush()

        assert client.get(f"{API}/products/{product.id}").status_code == 404


class TestReviewCreation:
    """FR-008, FR-009, FR-013 — the only authenticated operation in US1."""

    def test_an_anonymous_review_is_rejected(self, client: Any, seeded: dict[str, Any]) -> None:
        product = seeded["products"][0]
        response = client.post(f"{API}/products/{product.id}/reviews", json={"rating": 5})

        assert response.status_code == 401
        assert response.headers["content-type"].startswith("application/problem+json")

    def test_an_invalid_token_is_rejected(self, client: Any, seeded: dict[str, Any]) -> None:
        product = seeded["products"][0]
        response = client.post(
            f"{API}/products/{product.id}/reviews",
            json={"rating": 5},
            headers={"Authorization": "Bearer nope"},
        )
        assert response.status_code == 401

    def test_a_signed_in_user_can_review_and_the_rating_updates(
        self, client: Any, seeded: dict[str, Any], db_session: Session
    ) -> None:
        """FR-008 + FR-009 in one round trip."""
        product = seeded["products"][1]  # no reviews yet
        response = client.post(
            f"{API}/products/{product.id}/reviews",
            json={"rating": 4, "comment": "Good"},
            headers={"Authorization": "Bearer user-a"},
        )

        assert response.status_code == 201
        assert response.json()["rating"] == 4
        assert response.json()["author_name"] == "User A"

        db_session.expire_all()
        refreshed = db_session.get(Product, product.id)
        assert refreshed is not None
        assert refreshed.rating_count == 1
        assert float(refreshed.rating_average) == 4.0

    def test_a_second_review_by_the_same_user_is_a_409(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        """FR-008: the contract declares 409, and the app must produce it, not a 500."""
        product = seeded["products"][1]
        headers = {"Authorization": "Bearer user-a"}

        assert (
            client.post(
                f"{API}/products/{product.id}/reviews", json={"rating": 5}, headers=headers
            ).status_code
            == 201
        )
        second = client.post(
            f"{API}/products/{product.id}/reviews", json={"rating": 1}, headers=headers
        )

        assert second.status_code == 409
        assert second.headers["content-type"].startswith("application/problem+json")

    def test_two_users_may_each_review_the_same_product(
        self, client: Any, seeded: dict[str, Any]
    ) -> None:
        product = seeded["products"][1]
        for token in ("user-a", "user-b"):
            response = client.post(
                f"{API}/products/{product.id}/reviews",
                json={"rating": 5},
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 201, token

    def test_an_out_of_range_rating_is_a_400(self, client: Any, seeded: dict[str, Any]) -> None:
        product = seeded["products"][1]
        response = client.post(
            f"{API}/products/{product.id}/reviews",
            json={"rating": 9},
            headers={"Authorization": "Bearer user-a"},
        )
        assert response.status_code == 400

    def test_reviewing_an_unknown_product_is_a_404(self, client: Any) -> None:
        response = client.post(
            f"{API}/products/{uuid.uuid4()}/reviews",
            json={"rating": 5},
            headers={"Authorization": "Bearer user-a"},
        )
        assert response.status_code == 404

    def test_a_first_authenticated_call_provisions_the_user(
        self, client: Any, seeded: dict[str, Any], db_session: Session
    ) -> None:
        """FR-014: no separate registration step."""
        from dupermarket_api.models import AppUser

        before = db_session.query(AppUser).count()
        client.post(
            f"{API}/products/{seeded['products'][1].id}/reviews",
            json={"rating": 5},
            headers={"Authorization": "Bearer user-a"},
        )
        assert db_session.query(AppUser).count() == before + 1
