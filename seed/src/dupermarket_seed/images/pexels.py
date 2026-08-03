"""Pexels fallback pools (T148).

Research D9: a product without a usable source image gets one from a **per-category pool** of
20–40 stock photographs, dealt out by an RNG seeded on the product id.

Three constraints shape this:

* **Pexels, not Unsplash** — the constitution's image-licensing rule. Pexels' terms permit
  re-hosting; Unsplash's require hotlinking, which would put a third-party domain in the render
  path of every product tile.
* **Category-keyed queries, never product titles.** Searching "Essence Mascara Lash Princess"
  returns nothing usable; searching "cosmetics" returns forty usable shots. That is the source
  spec's own finding (§19.1) and D9 records it holding.
* **Throttled and cached to disk.** The API allows 200 requests an hour, and a pool is fetched
  once per category and then reused across every run — so a re-seed costs zero requests, which
  is what FR-072 needs.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from pathlib import Path

import httpx

from ..models import SourceImage

SOURCE_NAME = "Pexels"
API_URL = "https://api.pexels.com/v1/search"

POOL_MIN = 20
POOL_MAX = 40

# The published limit is 200 requests per hour. Staying under it by construction — one request
# per category, then cache — matters more than the exact figure, but the pause is here so a
# cold run across every category cannot burst.
REQUESTS_PER_HOUR = 200
MIN_SECONDS_BETWEEN_REQUESTS = 3600 / REQUESTS_PER_HOUR

# Category slug → the query that actually returns usable stock. Deliberately generic.
CATEGORY_QUERIES: dict[str, str] = {
    "beauty": "cosmetics flatlay",
    "accessories": "fashion accessories",
    "home": "home interior decor",
    "electronics": "consumer electronics",
    "sport": "sports equipment",
    "mens-clothing": "mens fashion clothing",
    "womens-clothing": "womens fashion clothing",
    "mens-shoes": "mens shoes",
    "womens-shoes": "womens shoes",
}


@dataclass(frozen=True, slots=True)
class RateLimiter:
    """A floor on the gap between requests.

    A plain sleep rather than a token bucket: there is one request per category per cold run, so
    the interesting property is "never bursts", not "maximises throughput".
    """

    min_interval: float = MIN_SECONDS_BETWEEN_REQUESTS

    def wait(self, last_request_at: float | None, now: float) -> float:
        """Seconds to pause before the next request. Zero when enough time has passed."""
        if last_request_at is None:
            return 0.0
        elapsed = now - last_request_at
        return max(0.0, self.min_interval - elapsed)


def parse_pool(payload: dict[str, object]) -> list[SourceImage]:
    """Photos from a Pexels search response, with attribution (FR-075).

    `photographer` and `url` are carried through because the licence asks for credit and a link
    back, and this is the only point at which either is available.
    """
    photos = payload.get("photos")
    if not isinstance(photos, list):
        return []

    pool: list[SourceImage] = []
    for photo in photos:
        if not isinstance(photo, dict):
            continue
        sources = photo.get("src")
        url = sources.get("large") if isinstance(sources, dict) else None
        if not isinstance(url, str):
            continue
        pool.append(
            SourceImage(
                url=url,
                source=SOURCE_NAME,
                photographer=str(photo.get("photographer") or "") or None,
                source_url=str(photo.get("url") or "") or None,
            )
        )
    return pool


class PexelsPools:
    """Category pools, fetched once and cached on disk.

    The cache is the idempotency mechanism for this stage: a second run reads the same pool from
    disk, so the same product is dealt the same photograph and nothing is re-requested.
    """

    def __init__(
        self,
        client: httpx.Client,
        cache_dir: Path,
        *,
        api_key: str = "",
        limiter: RateLimiter | None = None,
        sleep: object = time.sleep,
        clock: object = time.monotonic,
    ) -> None:
        self._client = client
        self._cache_dir = cache_dir
        self._api_key = api_key
        self._limiter = limiter or RateLimiter()
        self._sleep = sleep
        self._clock = clock
        self._last_request_at: float | None = None
        self._memory: dict[str, list[SourceImage]] = {}

    def _cache_file(self, category_slug: str) -> Path:
        return self._cache_dir / f"pexels-{category_slug}.json"

    def _read_cache(self, category_slug: str) -> list[SourceImage] | None:
        path = self._cache_file(category_slug)
        if not path.exists():
            return None
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            # A corrupt cache is refetched rather than fatal — it is a cache.
            return None
        return [SourceImage(**entry) for entry in raw if isinstance(entry, dict)]

    def _write_cache(self, category_slug: str, pool: list[SourceImage]) -> None:
        self._cache_dir.mkdir(parents=True, exist_ok=True)
        self._cache_file(category_slug).write_text(
            json.dumps(
                [
                    {
                        "url": image.url,
                        "source": image.source,
                        "photographer": image.photographer,
                        "source_url": image.source_url,
                    }
                    for image in pool
                ],
                indent=2,
            ),
            encoding="utf-8",
        )

    def pool_for(self, category_slug: str) -> list[SourceImage]:
        """The pool for a category, from memory, then disk, then the API."""
        if category_slug in self._memory:
            return self._memory[category_slug]

        cached = self._read_cache(category_slug)
        if cached:
            self._memory[category_slug] = cached
            return cached

        pool = self._fetch(category_slug)
        self._memory[category_slug] = pool
        if pool:
            self._write_cache(category_slug, pool)
        return pool

    def _fetch(self, category_slug: str) -> list[SourceImage]:
        pause = self._limiter.wait(self._last_request_at, self._clock())  # type: ignore[operator]
        if pause > 0:
            self._sleep(pause)  # type: ignore[operator]

        query = CATEGORY_QUERIES.get(category_slug, category_slug)
        response = self._client.get(
            API_URL,
            params={"query": query, "per_page": POOL_MAX},
            headers={"Authorization": self._api_key} if self._api_key else None,
        )
        self._last_request_at = self._clock()  # type: ignore[operator]
        response.raise_for_status()
        return parse_pool(response.json())
