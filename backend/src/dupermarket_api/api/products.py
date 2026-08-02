"""Product listing, detail, and reviews.

Reads are public (FR-010). Writing a review requires a credential.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Path, Query, status

from ..auth.user_provisioning import CurrentUser
from ..deps import ClockDep, DbDep, SettingsDep
from ..errors import BadCursor, Conflict, NotFound
from ..models import Review
from ..schemas.catalogue import (
    ProductDetail,
    ProductPage,
    ReviewCreate,
    ReviewPage,
    SortOrder,
)
from ..schemas.catalogue import (
    Review as ReviewSchema,
)
from ..services import catalogue
from ..services.currency import CurrencyService
from ..services.cursor import Cursor, InvalidCursor
from ..services.presentation import product_detail, product_summary, review_schema

router = APIRouter(tags=["catalogue"])

_currency = CurrencyService()


def _decode_cursor(raw: str | None, sort: str) -> Cursor | None:
    """A malformed cursor is a handled 400, never an unhandled 500 (FR-060)."""
    if not raw:
        return None
    try:
        return Cursor.decode(raw, expected_sort=sort)
    except InvalidCursor as exc:
        raise BadCursor("Start browsing from the beginning to continue.") from exc


@router.get(
    "/products",
    response_model=ProductPage,
    summary="List, search, filter, and sort products",
    operation_id="listProducts",
)
def list_products(
    session: DbDep,
    settings: SettingsDep,
    category: str | None = None,
    q: str | None = None,
    min_price: Annotated[int | None, Query(ge=0)] = None,
    max_price: Annotated[int | None, Query(ge=0)] = None,
    min_rating: Annotated[float | None, Query(ge=0, le=5)] = None,
    sort: SortOrder = SortOrder.newest,
    currency: str | None = None,
    locale: str = "en",
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> ProductPage:
    """FR-002 – FR-005, FR-010. Keyset paged; withdrawn products never appear."""
    target_currency = (currency or settings.base_currency).upper()

    query = catalogue.ProductQuery(
        category_slug=category,
        q=q,
        min_price_minor=min_price,
        max_price_minor=max_price,
        min_rating=min_rating,
        sort=sort,
        cursor=_decode_cursor(cursor, sort.value),
        limit=limit,
        locale=locale,
    )

    products, has_more = catalogue.list_products(session, query)

    items = []
    used_fallback = False
    for product in products:
        summary, fallback = product_summary(
            product,
            currency=_currency,
            target_currency=target_currency,
            locale=locale,
            cdn_base_url=settings.r2_public_base_url,
        )
        items.append(summary)
        used_fallback = used_fallback or fallback

    next_cursor = catalogue.next_cursor_for(products, sort, has_more)
    return ProductPage(
        items=items,
        next_cursor=next_cursor.encode() if next_cursor else None,
        # FR-052: report the currency actually used, not the one requested.
        currency=items[0].price.currency if items else target_currency,
        currency_fallback=used_fallback,
    )


@router.get(
    "/products/{productId}",
    response_model=ProductDetail,
    summary="Product detail including images",
    operation_id="getProduct",
)
def get_product(
    product_id: Annotated[uuid.UUID, Path(alias="productId")],
    session: DbDep,
    settings: SettingsDep,
    currency: str | None = None,
    locale: str = "en",
) -> ProductDetail:
    """FR-006."""
    product = catalogue.get_product(session, product_id)
    if product is None:
        raise NotFound("We couldn't find that product.")

    return product_detail(
        product,
        currency=_currency,
        target_currency=(currency or settings.base_currency).upper(),
        locale=locale,
        cdn_base_url=settings.r2_public_base_url,
    )


@router.get(
    "/products/{productId}/reviews",
    response_model=ReviewPage,
    summary="Reviews for a product, newest first",
    operation_id="listReviews",
)
def list_reviews(
    product_id: Annotated[uuid.UUID, Path(alias="productId")],
    session: DbDep,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> ReviewPage:
    """FR-007."""
    if catalogue.get_product(session, product_id) is None:
        raise NotFound("We couldn't find that product.")

    reviews, has_more = catalogue.list_reviews(
        session, product_id, _decode_cursor(cursor, "newest"), limit
    )
    next_cursor = (
        Cursor(
            sort="newest",
            last_id=reviews[-1].id,
            last_value=reviews[-1].created_at.isoformat(),
        ).encode()
        if has_more and reviews
        else None
    )
    return ReviewPage(items=[review_schema(r) for r in reviews], next_cursor=next_cursor)


@router.post(
    "/products/{productId}/reviews",
    response_model=ReviewSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Add a review",
    operation_id="createReview",
)
def create_review(
    product_id: Annotated[uuid.UUID, Path(alias="productId")],
    body: ReviewCreate,
    user: CurrentUser,
    session: DbDep,
    clock: ClockDep,
) -> ReviewSchema:
    """FR-008: one review per user per product. FR-009: rating recomputed in the same write."""
    if catalogue.get_product(session, product_id) is None:
        raise NotFound("We couldn't find that product.")

    existing = session.query(Review).filter_by(product_id=product_id, user_id=user.id).first()
    if existing is not None:
        # The partial unique index would reject this anyway; catching it here turns a database
        # error into the 409 the contract declares.
        raise Conflict("You've already reviewed this product.")

    review = Review(
        product_id=product_id,
        user_id=user.id,
        rating=body.rating,
        comment=body.comment,
        created_at=clock.now(),
    )
    session.add(review)
    session.flush()

    catalogue.recompute_rating(session, product_id)
    return review_schema(review)
