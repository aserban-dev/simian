"""The wishlist (T119).

FR-045. Three operations, and the interesting one is `add`: it is **idempotent by
construction**, not by a check. `wishlist_item` has a composite primary key of
`(user_id, product_id)`, so "already there" is a database no-op rather than a race between a
SELECT and an INSERT — two taps on the heart icon cannot produce two rows or an error.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Annotated

from fastapi import APIRouter, Path, Query, Response, status
from sqlalchemy import literal, select, tuple_
from sqlalchemy.dialects.postgresql import insert as pg_insert

from ..auth.user_provisioning import CurrentUser
from ..deps import ClockDep, DbDep, SettingsDep
from ..errors import BadCursor, NotFound
from ..models import Product, WishlistItem
from ..schemas.profile import WishlistItemInput, WishlistPage
from ..services.currency import CurrencyService
from ..services.cursor import Cursor, InvalidCursor
from ..services.presentation import product_summary

router = APIRouter(tags=["profile"])

_currency = CurrencyService()

WISHLIST_SORT = "wishlist_newest"


@router.get(
    "/me/wishlist",
    response_model=WishlistPage,
    summary="List wishlist products",
    operation_id="listWishlist",
)
def list_wishlist(
    user: CurrentUser,
    session: DbDep,
    settings: SettingsDep,
    currency: str | None = None,
    locale: str = "en",
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> WishlistPage:
    """FR-045. Newest first, keyset paged on `(created_at, product_id)`.

    A withdrawn product stays on the list and is returned as any other: FR-078 keeps such
    products browsable, and silently removing something a user saved would be worse than showing
    it as unavailable.
    """
    decoded: Cursor | None = None
    if cursor:
        try:
            decoded = Cursor.decode(cursor, expected_sort=WISHLIST_SORT)
        except InvalidCursor as exc:
            raise BadCursor("Start from the beginning of your wishlist to continue.") from exc

    query = (
        select(WishlistItem, Product)
        .join(Product, Product.id == WishlistItem.product_id)
        .where(WishlistItem.user_id == user.id)
        .order_by(WishlistItem.created_at.desc(), WishlistItem.product_id.desc())
        .limit(limit + 1)
    )
    if decoded is not None:
        # Keyset on the pair, exactly as order history does: `created_at` alone would drop or
        # repeat rows whenever two products were wishlisted in the same instant.
        try:
            last_added = dt.datetime.fromisoformat(str(decoded.last_value))
        except (TypeError, ValueError) as exc:
            raise BadCursor("Start from the beginning of your wishlist to continue.") from exc
        query = query.where(
            tuple_(WishlistItem.created_at, WishlistItem.product_id)
            < tuple_(
                literal(last_added, WishlistItem.created_at.type),
                literal(decoded.last_id, WishlistItem.product_id.type),
            )
        )

    rows = list(session.execute(query).all())
    has_more = len(rows) > limit
    rows = rows[:limit]

    target_currency = (currency or settings.base_currency).upper()
    items = []
    for _, product in rows:
        summary, _fallback = product_summary(
            product,
            currency=_currency,
            target_currency=target_currency,
            locale=locale,
            cdn_base_url=settings.r2_public_base_url,
        )
        items.append(summary)

    next_cursor = (
        Cursor(
            sort=WISHLIST_SORT,
            last_id=rows[-1][0].product_id,
            last_value=rows[-1][0].created_at.isoformat(),
        ).encode()
        if has_more and rows
        else None
    )
    return WishlistPage(items=items, next_cursor=next_cursor)


@router.post(
    "/me/wishlist",
    status_code=status.HTTP_201_CREATED,
    summary="Add a product to the wishlist",
    operation_id="addWishlistItem",
)
def add_wishlist_item(
    body: WishlistItemInput,
    user: CurrentUser,
    session: DbDep,
    clock: ClockDep,
) -> Response:
    """Idempotent: adding twice yields the same state and still returns 201 (per the contract).

    `ON CONFLICT DO NOTHING` on the composite primary key, so the second add is a no-op in the
    database rather than a check-then-insert that two concurrent taps could both pass.
    """
    if session.get(Product, body.product_id) is None:
        raise NotFound("We couldn't find that product.")

    session.execute(
        pg_insert(WishlistItem)
        .values(user_id=user.id, product_id=body.product_id, created_at=clock.now())
        .on_conflict_do_nothing(index_elements=["user_id", "product_id"])
    )
    session.flush()
    return Response(status_code=status.HTTP_201_CREATED)


@router.delete(
    "/me/wishlist/{productId}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove a product from the wishlist",
    operation_id="removeWishlistItem",
)
def remove_wishlist_item(
    product_id: Annotated[uuid.UUID, Path(alias="productId")],
    user: CurrentUser,
    session: DbDep,
) -> Response:
    """404 when it was not on the list — the contract declares it, and it tells a client whose
    optimistic UI has drifted that the two disagree.

    Loaded by primary key rather than deleted-and-counted: the composite key is
    `(user_id, product_id)`, so this is a single index lookup, and it keeps "was it there" and
    "remove it" as one obvious pair rather than a row count to interpret.
    """
    item = session.get(WishlistItem, (user.id, product_id))
    if item is None:
        raise NotFound("That product isn't on your wishlist.")

    session.delete(item)
    session.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
