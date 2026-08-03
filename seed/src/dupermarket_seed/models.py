"""The shapes that move through the pipeline.

Deliberately not the API's SQLAlchemy models. The seed reads from two sources with different
schemas, normalises them, synthesises what is missing, and only then writes rows — and keeping a
staging type in between means each stage can be tested on its own, with no database.

Every monetary value here is an integer count of minor units (research D4). A float would be
wrong for the same reason it is wrong everywhere else in this system, and it would be wrong
*silently*, because seeded prices are never compared against an invoice.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class SourceImage:
    """An image as the source offers it, before processing.

    `photographer` and `source_url` are captured at ingest (FR-075) because they cannot be
    recovered later: once the bytes are on our CDN, nothing about them says who took the photo.
    """

    url: str
    source: str
    photographer: str | None = None
    source_url: str | None = None


@dataclass(frozen=True, slots=True)
class SourceProduct:
    """One product as ingested, before normalisation.

    `price_minor` is optional because the two sources disagree: DummyJSON has prices, the Kaggle
    fashion CSV does not. Synthesis (FR-073) fills the gap.
    """

    source_id: str
    title: str
    description: str
    source_category: str
    images: list[SourceImage] = field(default_factory=list)
    price_minor: int | None = None
    rating: float | None = None
    rating_count: int = 0


@dataclass(frozen=True, slots=True)
class NormalisedProduct:
    """A product in the app's own taxonomy, ready to be written."""

    source_id: str
    title: str
    description: str
    category_slug: str
    price_minor: int
    images: list[SourceImage] = field(default_factory=list)
    rating: float = 0.0
    rating_count: int = 0
