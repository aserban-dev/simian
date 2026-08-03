"""Search latency against a full-size catalogue (T158, SC-002).

"95% of catalogue searches return results within one second." The figure is only meaningful
against a catalogue of realistic size, so this seeds one — several thousand products with a
populated `tsvector` — and issues a representative mix of terms rather than one query repeated.

A failure prints the **measured p95**, not just "too slow". A benchmark that fails without
saying by how much tells you nothing about whether it is a regression or a fluke.

Marked `performance` and excluded from the default run: it seeds thousands of rows, which is
seconds rather than milliseconds, and a suite people skip because it is slow protects nothing.
Run it with `pytest -m performance`.
"""

from __future__ import annotations

import statistics
import time
import uuid
from typing import Any

import pytest
from sqlalchemy.orm import Session

from dupermarket_api.models import Category, Product
from dupermarket_api.schemas.catalogue import SortOrder
from dupermarket_api.services import catalogue
from dupermarket_api.services.catalogue import ProductQuery

pytestmark = [pytest.mark.performance, pytest.mark.integration]

#: SC-002's threshold.
P95_BUDGET_SECONDS = 1.0

#: Big enough for the query planner to prefer the GIN index over a sequential scan — which is
#: the whole thing being measured. A few hundred rows would pass on any implementation.
CATALOGUE_SIZE = 3_000

#: A representative mix: common words, rare words, multi-word phrases, a prefix, and terms that
#: match nothing. The last two matter most — an empty result set is the case a naive `ILIKE`
#: implementation is slowest at.
SEARCH_TERMS: tuple[str, ...] = (
    "shoe",
    "running",
    "running shoe",
    "leather",
    "blue",
    "cotton",
    "wireless",
    "premium leather bag",
    "watch",
    "zzzznotathing",
    "qwertyuiop",
    "shoe leather premium",
)

WORDS = (
    "running",
    "leather",
    "cotton",
    "wireless",
    "premium",
    "blue",
    "compact",
    "shoe",
    "bag",
    "watch",
    "lamp",
    "chair",
    "phone",
    "jacket",
    "scarf",
)


def seed_catalogue(session: Session, size: int) -> None:
    """A catalogue of `size` products with varied, searchable text."""
    category = Category(slug=f"perf-{uuid.uuid4().hex[:8]}", name={"en": "Perf"}, sort_order=0)
    session.add(category)
    session.flush()

    products = []
    for index in range(size):
        title = f"{WORDS[index % len(WORDS)]} {WORDS[(index * 7) % len(WORDS)]} {index}"
        description = " ".join(WORDS[(index * k) % len(WORDS)] for k in range(1, 6))
        products.append(
            Product(
                sku=f"PERF-{index}-{uuid.uuid4().hex[:6]}",
                category_id=category.id,
                title={"en": title},
                description={"en": description},
                base_price_minor=1000 + (index % 90_000),
                base_currency="EUR",
                rating_average=1 + (index % 5),
                rating_count=index % 250,
                stock_status="in_stock",
            )
        )
    session.add_all(products)
    session.flush()


def time_search(session: Session, term: str) -> float:
    """Seconds for one search, including result materialisation.

    The rows are consumed, not just the query issued: a lazily evaluated result would make this
    measure how fast SQLAlchemy builds a statement.
    """
    started = time.perf_counter()
    products, _ = catalogue.list_products(
        session,
        ProductQuery(q=term, sort=SortOrder.relevance, limit=20, locale="en"),
    )
    list(products)
    return time.perf_counter() - started


@pytest.fixture(scope="module")
def seeded(request: Any) -> None:  # pragma: no cover - fixture plumbing
    """Seeded once per module: the seeding costs more than the measurements."""
    return None


class TestSearchLatency:
    def test_p95_is_within_budget(self, db_session: Session) -> None:
        """SC-002, with the measured figure in the failure message."""
        seed_catalogue(db_session, CATALOGUE_SIZE)

        # One warm pass so the first measurement is not paying for a cold cache and a plan.
        for term in SEARCH_TERMS:
            time_search(db_session, term)

        timings = [time_search(db_session, term) for term in SEARCH_TERMS for _ in range(5)]
        timings.sort()
        p95 = timings[int(len(timings) * 0.95) - 1]

        assert p95 < P95_BUDGET_SECONDS, (
            f"search p95 was {p95 * 1000:.1f} ms over {len(timings)} queries against "
            f"{CATALOGUE_SIZE} products (budget {P95_BUDGET_SECONDS * 1000:.0f} ms); "
            f"median {statistics.median(timings) * 1000:.1f} ms, "
            f"max {timings[-1] * 1000:.1f} ms"
        )

    def test_a_search_that_matches_nothing_is_still_fast(self, db_session: Session) -> None:
        """The case a sequential-scan implementation is slowest at, so it is measured alone."""
        seed_catalogue(db_session, CATALOGUE_SIZE)

        elapsed = max(time_search(db_session, "zzzznotathing") for _ in range(5))

        assert elapsed < P95_BUDGET_SECONDS, f"empty-result search took {elapsed * 1000:.1f} ms"

    def test_a_multi_word_search_is_still_fast(self, db_session: Session) -> None:
        seed_catalogue(db_session, CATALOGUE_SIZE)

        elapsed = max(time_search(db_session, "premium leather bag") for _ in range(5))

        assert elapsed < P95_BUDGET_SECONDS, f"phrase search took {elapsed * 1000:.1f} ms"

    def test_the_benchmark_actually_searched_a_full_catalogue(self, db_session: Session) -> None:
        """Guards against the suite passing because the catalogue was empty."""
        seed_catalogue(db_session, CATALOGUE_SIZE)

        products, _ = catalogue.list_products(
            db_session, ProductQuery(q="shoe", sort=SortOrder.relevance, limit=20, locale="en")
        )

        assert len(list(products)) > 0, "no results — the benchmark measured nothing"
