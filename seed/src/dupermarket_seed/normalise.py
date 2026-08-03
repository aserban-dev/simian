"""Source taxonomy to app taxonomy, with exclusions (T146).

FR-071: food, vehicle and motorcycle categories never reach the catalogue. The exclusion is
applied here, once, rather than by each ingest module — two sources filtering independently is
two places for a category to slip through, and the one that slips is always the one nobody
tested.

The mapping is explicit rather than inferred. A source category with no mapping is **dropped**,
not passed through under its own name: an unrecognised category is exactly how an excluded one
would arrive after the source renames it.
"""

from __future__ import annotations

from .models import NormalisedProduct, SourceProduct

# FR-071. Matched on a normalised form of the source category, so `Motorcycle`,
# `motorcycle` and `motor-cycle` are all the same exclusion.
EXCLUDED_CATEGORIES: frozenset[str] = frozenset(
    {
        "groceries",
        "grocery",
        "food",
        "foods",
        "vehicle",
        "vehicles",
        "motorcycle",
        "motorcycles",
        "automotive",
    }
)

# Source category → app category slug. Everything not listed here is dropped.
CATEGORY_MAP: dict[str, str] = {
    # DummyJSON
    "beauty": "beauty",
    "fragrances": "beauty",
    "skin-care": "beauty",
    "furniture": "home",
    "home-decoration": "home",
    "kitchen-accessories": "home",
    "laptops": "electronics",
    "smartphones": "electronics",
    "mobile-accessories": "electronics",
    "tablets": "electronics",
    "sports-accessories": "sport",
    "sunglasses": "accessories",
    "womens-bags": "accessories",
    "womens-jewellery": "accessories",
    "womens-watches": "accessories",
    "mens-watches": "accessories",
    "mens-shirts": "mens-clothing",
    "mens-shoes": "mens-shoes",
    "womens-dresses": "womens-clothing",
    "womens-shoes": "womens-shoes",
    "tops": "womens-clothing",
    # Kaggle fashion
    "apparel": "womens-clothing",
    "footwear": "womens-shoes",
    "accessories": "accessories",
    "personal care": "beauty",
}


def canonical(source_category: str) -> str:
    """Lowercase, trimmed, and with separators unified.

    Both sources spell categories differently — `Home Decoration`, `home-decoration`,
    `home_decoration` — and matching on the raw string would let the same category be excluded
    in one source and admitted in the other.
    """
    return source_category.strip().lower().replace("_", "-").replace(" ", "-")


def is_excluded(source_category: str) -> bool:
    """FR-071. Checked before the mapping, so an excluded category cannot be mapped in."""
    key = canonical(source_category)
    return key in EXCLUDED_CATEGORIES or key.replace("-", "") in {
        c.replace("-", "") for c in EXCLUDED_CATEGORIES
    }


def category_slug_for(source_category: str) -> str | None:
    """The app slug for a source category, or None when it does not belong in the catalogue."""
    if is_excluded(source_category):
        return None
    return CATEGORY_MAP.get(canonical(source_category))


def normalise(
    product: SourceProduct,
    *,
    price_minor: int | None = None,
) -> NormalisedProduct | None:
    """Map one product into the app's taxonomy, or drop it.

    `price_minor` overrides the source's own price and is how synthesis is injected (FR-073) —
    passed in rather than computed here so this stays a pure mapping and the RNG lives in one
    place.

    Returns None when the product does not belong in the catalogue, which callers treat as an
    ordinary outcome: most of a source's rows are dropped, and that is the point.
    """
    slug = category_slug_for(product.source_category)
    if slug is None:
        return None

    price = price_minor if price_minor is not None else product.price_minor
    if price is None or price < 0:
        # A product with no price and no synthesis is not renderable. Dropping it is better than
        # inventing a zero, which would display as free.
        return None

    return NormalisedProduct(
        source_id=product.source_id,
        title=product.title.strip(),
        description=product.description.strip(),
        category_slug=slug,
        price_minor=price,
        images=list(product.images),
        rating=product.rating or 0.0,
        rating_count=product.rating_count,
    )


def normalise_all(
    products: list[SourceProduct],
    *,
    price_for: object = None,
) -> list[NormalisedProduct]:
    """Normalise a batch, dropping everything excluded or unmapped.

    `price_for` is an optional `(SourceProduct) -> int` used when the source has no price.
    """
    out: list[NormalisedProduct] = []
    for product in products:
        synthesised: int | None = None
        if product.price_minor is None and callable(price_for):
            synthesised = price_for(product)
        normalised = normalise(product, price_minor=synthesised)
        if normalised is not None:
            out.append(normalised)
    return out
