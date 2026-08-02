"""Response-shape rules that carry requirements.

The point of asserting on the *whole* field set rather than on the absence of a particular
field: a leak arrives as an addition, not a removal, so a test that only checks what must not be
there passes right up until someone adds something new.
"""

from __future__ import annotations

import pytest

from dupermarket_api.schemas.catalogue import ProductSummary, Review

pytestmark = pytest.mark.unit


class TestReviewIsAClosedSet:
    def test_a_review_exposes_exactly_the_permitted_fields(self) -> None:
        """FR-079: reviews are readable anonymously, so this set is published to the world."""
        assert set(Review.model_fields) == {
            "id",
            "rating",
            "comment",
            "author_name",
            "author_avatar_url",
            "created_at",
        }, (
            "the Review schema changed. Adding a field here publishes it to unauthenticated "
            "callers — FR-079 requires that to be a deliberate decision, so update the "
            "requirement first, then this test."
        )

    def test_no_author_identifier_is_exposed(self) -> None:
        """FR-013, FR-079: the author's id would let anyone enumerate a user's whole history."""
        leaky = {"user_id", "author_id", "firebase_uid", "email", "author_email"}
        assert not (set(Review.model_fields) & leaky)


class TestProductPricing:
    def test_a_discounted_original_price_is_optional_not_required(self) -> None:
        """FR-077: most products have no discount, and an invented original would be a lie."""
        assert ProductSummary.model_fields["original_price"].default is None

    def test_stock_status_is_exposed_so_the_client_can_label_it(self) -> None:
        """FR-078: out-of-stock products stay browsable and are labelled, not hidden."""
        assert "stock_status" in ProductSummary.model_fields

    def test_prices_are_money_objects_not_bare_numbers(self) -> None:
        """Research D4: a bare number invites float arithmetic at the call site."""
        annotation = str(ProductSummary.model_fields["price"].annotation)
        assert "Money" in annotation
