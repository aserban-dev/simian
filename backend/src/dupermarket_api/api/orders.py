"""Order creation — the simulated checkout (T084).

The ordering of the checks in [`create_order`](#create_order) is the specification, not a style
choice. Read it as: is this a replay, is the card good, is the address yours, are the products
still buyable — and only then write anything.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Annotated

from fastapi import APIRouter, Path, Query, status
from sqlalchemy import select

from ..auth.user_provisioning import CurrentUser
from ..deps import ClockDep, DbDep, SettingsDep
from ..errors import BadCursor, Conflict, NotFound, PaymentDeclined
from ..models import Order
from ..schemas.catalogue import Money
from ..schemas.orders import (
    DeliveryStage,
    DeliveryStages,
    DeliveryTracking,
    LatLng,
    OrderAddress,
    OrderCreate,
    OrderDetail,
    OrderItem,
    OrderPage,
    OrderSummary,
)
from ..services import orders as order_service
from ..services.currency import CurrencyService
from ..services.cursor import Cursor, InvalidCursor

router = APIRouter(tags=["orders"])

_currency = CurrencyService()


def order_detail(order: Order, now: dt.datetime) -> OrderDetail:
    """Serialise a stored order. Every value here was written at creation."""
    snapshot = dict(order.address_snapshot)
    items = [
        OrderItem(
            product_id=item.product_id,
            quantity=item.quantity,
            unit_price=Money(amount_minor=item.unit_price_minor, currency=order.currency),
            title=item.title_snapshot,
            image_url=item.image_snapshot,
        )
        for item in order.items
    ]

    stage = order_service.current_stage(order, now)

    return OrderDetail(
        id=order.id,
        order_number=order.order_number,
        created_at=order.created_at,
        total=Money(amount_minor=order.total_minor, currency=order.currency),
        current_stage=DeliveryStage(stage),
        item_count=sum(item.quantity for item in order.items),
        thumbnail_url=items[0].image_url if items and items[0].image_url else None,
        items=items,
        address=OrderAddress(
            recipient_name=snapshot.get("recipient_name"),
            formatted=snapshot.get("formatted", ""),
        ),
        tracking=DeliveryTracking(
            origin=LatLng(lat=order.origin_lat, lng=order.origin_lng),
            destination=LatLng(lat=order.destination_lat, lng=order.destination_lng),
            window_start=order.processing_at,
            window_end=order.delivered_at,
            current_stage=DeliveryStage(stage),
            stages=DeliveryStages(
                processing_at=order.processing_at,
                shipped_at=order.shipped_at,
                out_for_delivery_at=order.out_for_delivery_at,
                delivered_at=order.delivered_at,
            ),
        ),
    )


def order_summary(order: Order, now: dt.datetime) -> OrderSummary:
    """The list view of an order. Deliberately without lines or tracking — a history screen
    shows neither, and sending them would make the page heavy for nothing."""
    first_image = next((item.image_snapshot for item in order.items if item.image_snapshot), None)
    return OrderSummary(
        id=order.id,
        order_number=order.order_number,
        created_at=order.created_at,
        total=Money(amount_minor=order.total_minor, currency=order.currency),
        current_stage=DeliveryStage(order_service.current_stage(order, now)),
        item_count=sum(item.quantity for item in order.items),
        thumbnail_url=first_image,
    )


@router.get(
    "/orders",
    response_model=OrderPage,
    summary="The authenticated user's order history, newest first",
    operation_id="listOrders",
)
def list_orders(
    user: CurrentUser,
    session: DbDep,
    clock: ClockDep,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> OrderPage:
    """FR-031, FR-032 — the caller's own orders, newest first, keyset paged."""
    decoded: Cursor | None = None
    if cursor:
        try:
            decoded = Cursor.decode(cursor, expected_sort=order_service.ORDER_HISTORY_SORT)
        except InvalidCursor as exc:
            # FR-060: recoverable. The client restarts paging, which the user never sees.
            raise BadCursor("Start from the beginning of your order history to continue.") from exc

    try:
        orders, has_more = order_service.list_orders(session, user, decoded, limit)
    except InvalidCursor as exc:
        raise BadCursor("Start from the beginning of your order history to continue.") from exc

    now = clock.now()
    next_cursor = order_service.next_order_cursor(orders, has_more)
    return OrderPage(
        items=[order_summary(order, now) for order in orders],
        next_cursor=next_cursor.encode() if next_cursor else None,
    )


@router.get(
    "/orders/{orderId}",
    response_model=OrderDetail,
    summary="Order detail including the tracking payload",
    operation_id="getOrder",
)
def get_order(
    order_id: Annotated[uuid.UUID, Path(alias="orderId")],
    user: CurrentUser,
    session: DbDep,
    clock: ClockDep,
) -> OrderDetail:
    """FR-036: origin, destination and the window, so the client can place the parcel itself.

    The lookup is scoped by `user_id` in the query rather than fetched-then-checked. Both
    reject the same requests, but only this one makes "not yours" and "does not exist" the same
    code path — and FR-032 requires them to be the same *answer*.
    """
    order = session.scalar(select(Order).where(Order.id == order_id, Order.user_id == user.id))
    if order is None:
        raise NotFound("We couldn't find that order.")

    return order_detail(order, clock.now())


@router.post(
    "/orders",
    response_model=OrderDetail,
    status_code=status.HTTP_201_CREATED,
    summary="Create an order (simulated checkout)",
    operation_id="createOrder",
)
def create_order(
    body: OrderCreate,
    user: CurrentUser,
    session: DbDep,
    settings: SettingsDep,
    clock: ClockDep,
) -> OrderDetail:
    """FR-022 through FR-030. No payment is attempted; no card data is accepted or stored."""
    now = clock.now()

    # A replay of a submission that already succeeded returns the original order. Checked first,
    # so a retry cannot be turned away by a stock change that happened after it was recorded.
    existing = order_service.find_existing_order(session, user, body.idempotency_key)
    if existing is not None:
        return order_detail(existing, now)

    # FR-025: the decline decides before anything is written, so "no order was created" is a
    # property of the control flow rather than of a rollback succeeding.
    if order_service.card_declines(body.demo_card_id):
        raise PaymentDeclined("That card was declined. Try another one — nothing was charged.")

    address = order_service.find_address(session, user, body.address_id)
    if address is None:
        # Another user's address is reported exactly as a missing one (FR-013).
        raise NotFound("We couldn't find that delivery address.")

    try:
        lines = order_service.resolve_lines(
            session, [(item.product_id, item.quantity) for item in body.items]
        )
    except order_service.ProductUnavailable as exc:
        # FR-021's race half: the whole order is rejected and named, never partly recorded.
        raise Conflict(
            f"{exc.title} is no longer available. Remove it and try again — "
            "nothing has been ordered."
        ) from exc

    if not lines:
        raise NotFound("One of those products is no longer in the catalogue.")

    order = order_service.build_order(
        session=session,
        user=user,
        address=address,
        lines=lines,
        target_currency=body.currency.upper(),
        base_currency=settings.base_currency,
        cdn_base_url=settings.r2_public_base_url,
        now=now,
        idempotency_key=body.idempotency_key,
        convert=_currency.convert,
    )
    return order_detail(order, now)
