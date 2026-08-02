"""Checkout: validation, snapshots, totals, and the delivery timeline (T082, T083).

Four rules that each exist because of a specific failure:

* **The card decides before anything is written** (FR-024, FR-025). A decline that rolled back a
  half-built order would leave sequence gaps and, worse, would make "no order was created"
  depend on the rollback working. Here it cannot fail, because nothing was started.
* **Line items are copied, not referenced** (FR-027). The catalogue is mutable; order history is
  not. Three columns of duplication buy that.
* **The whole timeline is assigned at creation** (FR-033, research D5), deterministically
  jittered from the order id, and never updated afterwards — the database trigger enforces the
  second half.
* **Totals are integers throughout** (research D4). Money never becomes a float on this path.

There is no payment integration in this file, and adding one would be a constitutional
amendment rather than a feature (Principle I).
"""

from __future__ import annotations

import datetime as dt
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Address, AppUser, Order, OrderItem, Product
from ..schemas.orders import DemoCardId
from .delivery import Timeline, current_stage_at, delivery_timeline, nearest_warehouse
from .presentation import cdn_url, discounted_minor, localise

# --- money -------------------------------------------------------------------------------


def unit_price_base_minor(base_price_minor: int, discount_percentage: Any | None) -> int:
    """The price actually charged for one unit, in base-currency minor units.

    Delegates to the catalogue's own discount rule so a product cannot cost one thing on the
    listing screen and another at checkout.
    """
    return discounted_minor(base_price_minor, discount_percentage)


def line_total_minor(unit_minor: int, quantity: int) -> int:
    """Exact integer arithmetic — no float ever touches a monetary value (research D4)."""
    if quantity < 1:
        raise ValueError("quantity must be at least 1")
    if unit_minor < 0:
        raise ValueError("a unit price cannot be negative")
    return unit_minor * quantity


def subtotal_minor(lines: Sequence[tuple[int, int]]) -> int:
    """Sum of `(unit_minor, quantity)` pairs."""
    return sum(line_total_minor(unit, qty) for unit, qty in lines)


# --- the demo cards ----------------------------------------------------------------------

DECLINING_CARDS: frozenset[DemoCardId] = frozenset({DemoCardId.decline})


def card_declines(demo_card_id: DemoCardId) -> bool:
    """FR-024: deterministic, and decided from a constant rather than by chance.

    A random decline would be more lifelike and completely untestable — SC-008's determinism
    requirement rules it out.
    """
    return demo_card_id in DECLINING_CARDS


# --- the delivery simulation ---------------------------------------------------------------
#
# Lives in `delivery.py` (T096). Re-exported here because order creation is the one caller that
# needs it, and because a second copy of the window rules is exactly how the stored timeline and
# the derived stage would drift apart.

# --- errors ------------------------------------------------------------------------------


class ProductUnavailable(Exception):
    """A line cannot be ordered. Carries the title so the client can name it (FR-021)."""

    def __init__(self, title: str) -> None:
        super().__init__(title)
        self.title = title


# --- creation ----------------------------------------------------------------------------


def timeline_of(order: Order) -> Timeline:
    """The stored timeline, as the shared value type."""
    return Timeline(
        processing_at=order.processing_at,
        shipped_at=order.shipped_at,
        out_for_delivery_at=order.out_for_delivery_at,
        delivered_at=order.delivered_at,
    )


def current_stage(order: Order, now: dt.datetime) -> str:
    """The present stage of a stored order (FR-035). One rule, in `delivery.py`."""
    return current_stage_at(timeline_of(order), now)


@dataclass(frozen=True, slots=True)
class ResolvedLine:
    product: Product
    quantity: int
    unit_base_minor: int


def order_number_for(order_id: uuid.UUID) -> str:
    """Short, stable, and derived — so it never needs its own sequence or uniqueness check."""
    return f"DM-{order_id.hex[:10].upper()}"


def find_address(session: Session, user: AppUser, address_id: uuid.UUID) -> Address | None:
    """Scoped to the owner. A foreign address is simply not found (FR-013)."""
    return session.scalar(
        select(Address).where(
            Address.id == address_id,
            Address.user_id == user.id,
            Address.deleted_at.is_(None),
        )
    )


def find_existing_order(session: Session, user: AppUser, key: str | None) -> Order | None:
    """The idempotent replay path. Scoped to the user, or it would leak another's order."""
    if not key:
        return None
    return session.scalar(
        select(Order).where(Order.user_id == user.id, Order.idempotency_key == key)
    )


def resolve_lines(
    session: Session,
    items: Sequence[tuple[uuid.UUID, int]],
    locale: str = "en",
) -> list[ResolvedLine]:
    """Load each product and check it can still be bought.

    Raises [`ProductUnavailable`] on the first withdrawn or out-of-stock line. FR-021 requires
    the *whole* order to be rejected in that case — a line silently dropped from an order the
    user already confirmed is the outcome the requirement exists to prevent — so this raises
    rather than filtering.
    """
    resolved: list[ResolvedLine] = []
    for product_id, quantity in items:
        product = session.get(Product, product_id)
        if product is None:
            return []  # signals "not found" to the caller; a 404, not a 409

        if product.withdrawn_at is not None or product.stock_status == "out_of_stock":
            raise ProductUnavailable(localise(product.title, locale) or "That product")

        resolved.append(
            ResolvedLine(
                product=product,
                quantity=quantity,
                unit_base_minor=unit_price_base_minor(
                    product.base_price_minor, product.discount_percentage
                ),
            )
        )
    return resolved


def format_address(address: Address) -> str:
    parts = [address.line1, address.line2, address.postal_code, address.city, address.country_code]
    return ", ".join(part for part in parts if part)


def address_snapshot(address: Address) -> dict[str, str]:
    """FR-044: what the order shipped to, frozen at purchase time."""
    snapshot = {
        "line1": address.line1,
        "city": address.city,
        "country_code": address.country_code,
        "formatted": format_address(address),
    }
    if address.recipient_name:
        snapshot["recipient_name"] = address.recipient_name
    if address.postal_code:
        snapshot["postal_code"] = address.postal_code
    return snapshot


def primary_image_url(product: Product, cdn_base_url: str) -> str:
    """The image recorded on the line. Empty when the product has none — a missing image is a
    placeholder on the client (Principle IV), not a reason to reject a checkout."""
    images = sorted(product.images, key=lambda image: image.sort_order)
    return cdn_url(cdn_base_url, images[0].cdn_path) if images else ""


def build_order(
    *,
    session: Session,
    user: AppUser,
    address: Address,
    lines: Sequence[ResolvedLine],
    target_currency: str,
    base_currency: str,
    cdn_base_url: str,
    now: dt.datetime,
    idempotency_key: str | None,
    convert: Any,
    locale: str = "en",
) -> Order:
    """Write the order and its lines (FR-026, FR-027).

    Line prices are converted individually and the total is their sum, rather than converting
    one grand total: what the user is shown per line then adds up to what they are charged. The
    other way round leaves a rounding remainder that nobody can account for.
    """
    order_id = uuid.uuid4()
    timeline = delivery_timeline(order_id, now)
    warehouse = nearest_warehouse(address.lat, address.lng)

    base_total = subtotal_minor([(line.unit_base_minor, line.quantity) for line in lines])

    converted_units: list[int] = []
    used_currency = target_currency
    rate = Decimal("1.0")
    for line in lines:
        converted = convert(line.unit_base_minor, base_currency, target_currency)
        converted_units.append(converted.amount_minor)
        # FR-052: a currency with no rate falls back to base, and the whole order follows it
        # rather than mixing currencies across lines.
        used_currency = converted.currency
        rate = converted.rate

    total = subtotal_minor(
        [(unit, line.quantity) for unit, line in zip(converted_units, lines, strict=True)]
    )

    order = Order(
        id=order_id,
        order_number=order_number_for(order_id),
        user_id=user.id,
        address_id=address.id,
        address_snapshot=address_snapshot(address),
        total_minor=total,
        currency=used_currency,
        base_total_minor=base_total,
        fx_rate=rate,
        origin_lat=warehouse.lat,
        origin_lng=warehouse.lng,
        destination_lat=address.lat,
        destination_lng=address.lng,
        processing_at=timeline.processing_at,
        shipped_at=timeline.shipped_at,
        out_for_delivery_at=timeline.out_for_delivery_at,
        delivered_at=timeline.delivered_at,
        idempotency_key=idempotency_key,
        created_at=now,
    )
    session.add(order)

    for line, unit_minor in zip(lines, converted_units, strict=True):
        session.add(
            OrderItem(
                order_id=order_id,
                product_id=line.product.id,
                quantity=line.quantity,
                unit_price_minor=unit_minor,
                title_snapshot=localise(line.product.title, locale),
                image_snapshot=primary_image_url(line.product, cdn_base_url),
                created_at=now,
            )
        )

    session.flush()
    return order
