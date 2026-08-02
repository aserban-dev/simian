"""Row factories for the order suites.

Checkout touches five tables at once, and a test that builds them inline stops being about
checkout. These build the minimum valid row in each case, with only the fields a test would
plausibly vary exposed as arguments.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from dupermarket_api.models import Address, AppUser, Category, Product, ProductImage

NOW = dt.datetime(2026, 8, 2, 12, tzinfo=dt.UTC)


def user_for(session: Session, token: str = "user-a") -> AppUser:
    """The row the fake verifier's UID maps to, provisioned by any authenticated call."""
    user = session.scalar(select(AppUser).where(AppUser.firebase_uid == f"firebase-{token}"))
    assert user is not None, "make an authenticated request first — provisioning is lazy (FR-014)"
    return user


def add_category(session: Session, slug: str = "shoes") -> Category:
    category = Category(slug=f"{slug}-{uuid.uuid4().hex[:6]}", name={"en": slug}, sort_order=0)
    session.add(category)
    session.flush()
    return category


def add_product(
    session: Session,
    category: Category | None = None,
    *,
    title: str = "Running Shoe",
    price_minor: int = 4999,
    discount_percentage: float | None = None,
    stock: str = "in_stock",
    withdrawn: bool = False,
    with_image: bool = True,
) -> Product:
    category = category or add_category(session)
    product = Product(
        sku=f"SKU-{uuid.uuid4().hex[:8]}",
        category_id=category.id,
        title={"en": title},
        description={"en": f"{title} description"},
        base_price_minor=price_minor,
        base_currency="EUR",
        discount_percentage=discount_percentage,
        rating_average=4.5,
        rating_count=10,
        stock_status=stock,
        withdrawn_at=NOW if withdrawn else None,
    )
    session.add(product)
    session.flush()

    if with_image:
        session.add(
            ProductImage(
                product_id=product.id,
                cdn_path=f"products/{product.id}.webp",
                sort_order=0,
                alt_text=f"{title} photo",
                source_name="Pexels",
                content_sha256="0" * 64,
            )
        )
        session.flush()
    return product


def add_address(
    session: Session,
    user: AppUser,
    *,
    line1: str = "1 Test Street",
    city: str = "Bucharest",
    lat: float = 44.43,
    lng: float = 26.10,
    is_default: bool = True,
) -> Address:
    address = Address(
        user_id=user.id,
        line1=line1,
        city=city,
        country_code="RO",
        lat=lat,
        lng=lng,
        is_default=is_default,
    )
    session.add(address)
    session.flush()
    return address


def order_payload(
    *,
    product_ids: list[uuid.UUID],
    address_id: uuid.UUID,
    quantities: list[int] | None = None,
    demo_card_id: str = "visa_success",
    currency: str = "EUR",
    idempotency_key: str | None = None,
) -> dict[str, Any]:
    quantities = quantities or [1] * len(product_ids)
    body: dict[str, Any] = {
        "items": [
            {"product_id": str(pid), "quantity": qty}
            for pid, qty in zip(product_ids, quantities, strict=True)
        ],
        "address_id": str(address_id),
        "demo_card_id": demo_card_id,
        "currency": currency,
    }
    if idempotency_key is not None:
        body["idempotency_key"] = idempotency_key
    return body
