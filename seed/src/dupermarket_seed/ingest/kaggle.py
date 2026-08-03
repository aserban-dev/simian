"""Kaggle fashion-dataset ingest (T145).

A CSV reader, not a downloader: the dataset is fetched by an operator once and read from disk.
Automating the download would need a Kaggle credential in CI for data that never changes.

This source has **no prices**, which is the reason `prices.py` exists — every row it yields
leaves `price_minor` as None and is priced by synthesis (FR-073).

`csv.DictReader` reads lazily and the file is large, so `read_products` is a generator. A seed
run that loaded 44,000 rows into memory before doing anything with them would work and would be
the kind of thing that stops working on the next dataset.
"""

from __future__ import annotations

import csv
from collections.abc import Iterator
from pathlib import Path

from ..models import SourceImage, SourceProduct

SOURCE_NAME = "Kaggle Fashion Product Images"

# The dataset's own column names. Listed rather than guessed so a schema change fails at the
# header check below instead of silently producing empty titles.
ID_COLUMN = "id"
NAME_COLUMN = "productDisplayName"
CATEGORY_COLUMN = "masterCategory"
SUBCATEGORY_COLUMN = "subCategory"
COLOUR_COLUMN = "baseColour"
USAGE_COLUMN = "usage"

REQUIRED_COLUMNS = (ID_COLUMN, NAME_COLUMN, CATEGORY_COLUMN)


class MissingColumns(ValueError):
    """The CSV is not the dataset this reader understands."""


def describe(row: dict[str, str]) -> str:
    """A short description from the columns the dataset does have.

    The source has no description field. Composing one from colour, usage and subcategory gives
    something honest to show; inventing prose would be a different kind of synthetic.
    """
    parts = [
        row.get(COLOUR_COLUMN, "").strip(),
        row.get(SUBCATEGORY_COLUMN, "").strip(),
        row.get(USAGE_COLUMN, "").strip(),
    ]
    meaningful = [part for part in parts if part and part.lower() != "na"]
    return " · ".join(meaningful)


def parse_row(row: dict[str, str], *, images_dir: Path | None = None) -> SourceProduct | None:
    source_id = (row.get(ID_COLUMN) or "").strip()
    title = (row.get(NAME_COLUMN) or "").strip()
    if not source_id or not title:
        return None

    images: list[SourceImage] = []
    if images_dir is not None:
        candidate = images_dir / f"{source_id}.jpg"
        if candidate.exists():
            # A local path rather than a URL: the processing stage reads bytes, and it does not
            # care which of the two it was handed.
            images = [SourceImage(url=str(candidate), source=SOURCE_NAME)]

    return SourceProduct(
        source_id=f"kaggle:{source_id}",
        title=title,
        description=describe(row),
        source_category=(row.get(CATEGORY_COLUMN) or "").strip(),
        images=images,
        # No prices in this dataset — synthesised downstream (FR-073).
        price_minor=None,
    )


def read_products(
    csv_path: Path,
    *,
    images_dir: Path | None = None,
    limit: int | None = None,
) -> Iterator[SourceProduct]:
    """Stream products from the dataset CSV.

    Raises [`MissingColumns`] rather than yielding nothing when the header is wrong: a seed run
    that quietly produced zero products would look like an empty source.
    """
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        header = set(reader.fieldnames or [])
        missing = [column for column in REQUIRED_COLUMNS if column not in header]
        if missing:
            raise MissingColumns(f"{csv_path} is missing columns: {missing}")

        yielded = 0
        for row in reader:
            product = parse_row(row, images_dir=images_dir)
            if product is None:
                continue
            yield product
            yielded += 1
            if limit is not None and yielded >= limit:
                return
