"""Deciding which image a product gets (FR-073, FR-076, T152).

Three sources, in a fixed order of precedence:

1. **An operator override** from `overrides.csv` — wins over everything (FR-076). It exists for
   the cases a person looked at and disagreed with, and an override that could be beaten by
   automation would not be an override.
2. **The source's own image**, when it has one. It genuinely depicts the product, which no
   stock photograph does.
3. **A Pexels pool photograph**, dealt by an RNG seeded on the product id (research D9), so the
   same product always receives the same picture (FR-073).

The dealing is a modulo of a hash, not `random.choice`. Same reason as prices: `random`'s stream
is not stable across Python versions, and an image assignment that changed on an interpreter
upgrade would silently re-upload the entire catalogue.
"""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path

from ..models import NormalisedProduct, SourceImage

OVERRIDE_SOURCE = "operator override"

SOURCE_ID_COLUMN = "source_id"
IMAGE_URL_COLUMN = "image_url"
PHOTOGRAPHER_COLUMN = "photographer"
CREDIT_SOURCE_COLUMN = "source"


def load_overrides(path: Path) -> dict[str, SourceImage]:
    """Read `overrides.csv`, keyed by source id.

    A missing file is an empty mapping, not an error: overrides are optional by definition, and
    requiring the file would make the common case need a placeholder.
    """
    if not path.exists():
        return {}

    overrides: dict[str, SourceImage] = {}
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            source_id = (row.get(SOURCE_ID_COLUMN) or "").strip()
            url = (row.get(IMAGE_URL_COLUMN) or "").strip()
            if not source_id or not url:
                continue
            overrides[source_id] = SourceImage(
                url=url,
                source=(row.get(CREDIT_SOURCE_COLUMN) or "").strip() or OVERRIDE_SOURCE,
                photographer=(row.get(PHOTOGRAPHER_COLUMN) or "").strip() or None,
            )
    return overrides


def _deal_index(product_id: str, pool_size: int) -> int:
    """Which pool entry this product gets. Deterministic (FR-073)."""
    digest = hashlib.sha256(f"{product_id}:image".encode()).digest()
    return int.from_bytes(digest[:4], "big") % pool_size


def assign_image(
    product: NormalisedProduct,
    *,
    overrides: dict[str, SourceImage] | None = None,
    pool: list[SourceImage] | None = None,
) -> SourceImage | None:
    """The image this product should carry, or None when nothing is available.

    None is a failure the run must not survive — FR-074 requires every product to end with at
    least one image — but it is `verify.py` that decides that, not this function. Returning None
    keeps assignment total and puts the loud failure in one place.
    """
    override = (overrides or {}).get(product.source_id)
    if override is not None:
        return override

    if product.images:
        return product.images[0]

    if pool:
        return pool[_deal_index(product.source_id, len(pool))]

    return None


def assign_all(
    products: list[NormalisedProduct],
    *,
    overrides: dict[str, SourceImage] | None = None,
    pools: dict[str, list[SourceImage]] | None = None,
) -> dict[str, SourceImage]:
    """Image per product, by source id. Products with nothing available are absent."""
    assigned: dict[str, SourceImage] = {}
    for product in products:
        image = assign_image(
            product,
            overrides=overrides,
            pool=(pools or {}).get(product.category_slug),
        )
        if image is not None:
            assigned[product.source_id] = image
    return assigned


def products_without_images(
    products: list[NormalisedProduct],
    assigned: dict[str, SourceImage],
) -> list[str]:
    """FR-074's input: which products would ship with no image."""
    return [p.source_id for p in products if p.source_id not in assigned]
