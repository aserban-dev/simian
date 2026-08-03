"""DummyJSON ingest (T144).

Fetches and stages; it does not normalise, price, or filter. Keeping ingest to "turn their
shape into our staging shape" means the exclusion rule lives in exactly one place
(`normalise.py`) rather than being partly enforced by each source.

Attribution is captured here (FR-075) because this is the last moment it exists: DummyJSON's
images carry their own provenance, and once bytes are processed and uploaded to our CDN nothing
about them records where they came from.
"""

from __future__ import annotations

from typing import Any

import httpx

from ..models import SourceImage, SourceProduct

BASE_URL = "https://dummyjson.com"
SOURCE_NAME = "DummyJSON"
PAGE_LIMIT = 100


def parse_product(raw: dict[str, Any]) -> SourceProduct | None:
    """One DummyJSON row into staging shape, or None if it is unusable.

    A row with no id or no title cannot become a product, and guessing values for it would put
    a placeholder in a catalogue whose whole purpose is to look real.
    """
    source_id = raw.get("id")
    title = str(raw.get("title") or "").strip()
    if source_id is None or not title:
        return None

    images = [
        SourceImage(url=str(url), source=SOURCE_NAME)
        for url in (raw.get("images") or [])
        if isinstance(url, str) and url.startswith(("http://", "https://"))
    ]
    thumbnail = raw.get("thumbnail")
    if not images and isinstance(thumbnail, str) and thumbnail.startswith("http"):
        images = [SourceImage(url=thumbnail, source=SOURCE_NAME)]

    return SourceProduct(
        source_id=f"dummyjson:{source_id}",
        title=title,
        description=str(raw.get("description") or "").strip(),
        source_category=str(raw.get("category") or ""),
        images=images,
        price_minor=_price_minor(raw.get("price")),
        rating=_rating(raw.get("rating")),
        rating_count=len(raw.get("reviews") or []),
    )


def _price_minor(value: Any) -> int | None:
    """Their price is a float in major units; ours is an integer count of minor units.

    Rounded rather than truncated, and converted here at the boundary — this is the only point
    in the pipeline where a float touches a price (research D4).
    """
    if not isinstance(value, (int, float)):
        return None
    return round(float(value) * 100)


def _rating(value: Any) -> float | None:
    if not isinstance(value, (int, float)):
        return None
    return max(0.0, min(5.0, float(value)))


def parse_page(payload: dict[str, Any]) -> list[SourceProduct]:
    return [
        product
        for raw in (payload.get("products") or [])
        if isinstance(raw, dict) and (product := parse_product(raw)) is not None
    ]


def fetch_all(client: httpx.Client, *, limit: int = PAGE_LIMIT) -> list[SourceProduct]:
    """Every product, paged.

    The client is injected so a test can supply a transport rather than the network, and so the
    caller owns timeouts and retries — this module has no opinion about either.
    """
    products: list[SourceProduct] = []
    skip = 0
    while True:
        response = client.get(f"{BASE_URL}/products", params={"limit": limit, "skip": skip})
        response.raise_for_status()
        payload = response.json()

        page = parse_page(payload)
        products.extend(page)

        skip += limit
        total = payload.get("total")
        if not page or not isinstance(total, int) or skip >= total:
            return products
