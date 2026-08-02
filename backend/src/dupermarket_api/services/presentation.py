"""Model → response mapping.

Everything that turns a stored row into something a client renders lives here: locale
resolution, currency conversion, CDN URL construction, discount arithmetic. Keeping it out of
the routers makes it unit-testable without a database or an HTTP client, which is most of how
FR-006, FR-047, FR-052 and FR-077 are covered.

**Discount convention** (FR-077). `product.base_price_minor` is the **list** price, and
`discount_percentage` is taken off it — matching the DummyJSON source shape (§17.5), where
`price` is the list price and `discountPercentage` is the reduction. So:

    displayed price = base * (1 - discount/100)      <- what the user pays
    original_price  = base                            <- struck through, only when discounted

Stating it here because the inverse reading (base is the discounted price, original is derived
upwards) is equally plausible from the column names alone, and the two disagree on every
discounted product.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from ..models import Product, ProductImage, Review
from ..schemas.catalogue import (
    ImageAttribution,
    Money,
    ProductDetail,
    ProductSummary,
    StockStatus,
)
from ..schemas.catalogue import (
    ProductImage as ProductImageSchema,
)
from ..schemas.catalogue import (
    Review as ReviewSchema,
)
from .currency import CurrencyService

FALLBACK_LOCALE = "en"


def localise(value: dict[str, str] | None, locale: str) -> str:
    """FR-047: requested locale, then English, then empty — never a key, never a crash."""
    if not value:
        return ""
    return value.get(locale) or value.get(FALLBACK_LOCALE) or ""


def cdn_url(base_url: str, path: str) -> str:
    """Build a public CDN URL. The API never proxies image bytes (Principle V)."""
    if path.startswith(("http://", "https://")):
        return path
    return f"{base_url.rstrip('/')}/{path.lstrip('/')}"


def discounted_minor(base_price_minor: int, discount_percentage: Any | None) -> int:
    """Apply the discount to the list price, rounding half-up to the minor unit."""
    if not discount_percentage:
        return base_price_minor
    factor = Decimal(1) - (Decimal(str(discount_percentage)) / Decimal(100))
    reduced = (Decimal(base_price_minor) * factor).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    # A 100% discount would render as free, which is not a state this catalogue models.
    return max(int(reduced), 0)


def _image_schema(image: ProductImage, base_url: str) -> ProductImageSchema:
    attribution = None
    if image.photographer or image.source_url:
        # FR-075: only emit attribution when there is something to attribute.
        attribution = ImageAttribution(
            source=image.source_name,
            photographer=image.photographer,
            source_url=image.source_url,
        )
    return ProductImageSchema(
        url=cdn_url(base_url, image.cdn_path),
        sort_order=image.sort_order,
        alt_text=image.alt_text,
        attribution=attribution,
    )


def product_summary(
    product: Product,
    *,
    currency: CurrencyService,
    target_currency: str,
    locale: str,
    cdn_base_url: str,
) -> tuple[ProductSummary, bool]:
    """Map a product to its list representation. Returns (summary, used_currency_fallback)."""
    list_price = product.base_price_minor
    price_minor = discounted_minor(list_price, product.discount_percentage)
    has_discount = price_minor != list_price

    # FR-077: one call, so the pair can never land in different currencies.
    price, original = currency.convert_pair(
        price_minor,
        list_price if has_discount else None,
        product.base_currency,
        target_currency,
    )

    images = sorted(product.images, key=lambda i: i.sort_order)
    thumbnail = images[0] if images else None

    summary = ProductSummary(
        id=product.id,
        title=localise(product.title, locale),
        price=Money(amount_minor=price.amount_minor, currency=price.currency),
        original_price=(
            Money(amount_minor=original.amount_minor, currency=original.currency)
            if original is not None
            else None
        ),
        # FR-061 depends on this not raising: a product with no image yields an empty URL and
        # the client renders its placeholder, rather than the whole grid failing.
        thumbnail_url=cdn_url(cdn_base_url, thumbnail.cdn_path) if thumbnail else "",
        thumbnail_alt=thumbnail.alt_text if thumbnail else localise(product.title, locale),
        rating_average=float(product.rating_average),
        rating_count=product.rating_count,
        stock_status=StockStatus(product.stock_status),
    )
    return summary, price.used_fallback


def product_detail(
    product: Product,
    *,
    currency: CurrencyService,
    target_currency: str,
    locale: str,
    cdn_base_url: str,
) -> ProductDetail:
    summary, _ = product_summary(
        product,
        currency=currency,
        target_currency=target_currency,
        locale=locale,
        cdn_base_url=cdn_base_url,
    )
    images = [
        _image_schema(image, cdn_base_url)
        for image in sorted(product.images, key=lambda i: i.sort_order)
    ]
    return ProductDetail(
        **summary.model_dump(),
        description=localise(product.description, locale),
        sku=product.sku,
        category_slug=product.category.slug if product.category else "",
        images=images,
    )


def review_schema(review: Review) -> ReviewSchema:
    """FR-079: a closed set. Author fields come from the provider profile and nothing else."""
    author = review.user
    return ReviewSchema(
        id=review.id,
        rating=review.rating,
        comment=review.comment,
        author_name=author.display_name if author else None,
        author_avatar_url=author.avatar_url if author else None,
        created_at=review.created_at,
    )
