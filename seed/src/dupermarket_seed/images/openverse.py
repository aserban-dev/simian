"""Openverse image pools — the no-key fallback source.

`pexels.py` is the primary pool source and the one the constitution names. This exists because
Pexels needs an API key, and a seed pipeline that cannot run at all until someone signs up for
one is a pipeline nobody runs.

Openverse (the WordPress Foundation's aggregator) needs **no key**, and — more usefully — it
returns the licence *per image* rather than a blanket site-wide claim. That matters for the
constitution's re-hosting rule: instead of trusting a site's terms page, each image carries the
licence it is offered under, and this module admits only the ones that permit re-hosting.

Attribution is captured for every image (FR-075). CC0 and public-domain images do not require
it, but the credits screen shows it anyway — a photographer who waived the requirement is still
the photographer.
"""

from __future__ import annotations

import json
from pathlib import Path

import httpx

from ..models import SourceImage

SOURCE_NAME = "Openverse"
API_URL = "https://api.openverse.org/v1/images/"

# Licences that permit re-hosting on our own CDN.
#
# `cc0` and `pdm` carry no conditions at all. `by` requires credit, which the credits screen
# gives (FR-075). Deliberately absent: anything with `nd` (no derivatives — we resize and
# re-encode, which is a derivative) and anything with `nc`, whose boundary is unclear enough
# that a demo shop is not the place to test it.
ALLOWED_LICENCES: tuple[str, ...] = ("cc0", "pdm", "by")

# Openverse caps *anonymous* requests at 20 results; asking for more is a 401, not a truncated
# page. Twenty is the bottom of research D9's 20–40 pool range, so a keyless run still produces
# a usable pool — registering for a key raises the cap if a wider one is wanted later.
POOL_SIZE = 20

# Queries that actually return product photography. Same finding as Pexels (research D9):
# searching a product *title* returns nothing usable; a category term returns usable stock.
CATEGORY_QUERIES: dict[str, str] = {
    "beauty": "cosmetics",
    "accessories": "handbag",
    "home": "furniture interior",
    "electronics": "laptop computer",
    "sport": "sports equipment",
    "mens-clothing": "shirt clothing",
    "womens-clothing": "dress clothing",
    "mens-shoes": "shoes",
    "womens-shoes": "shoes",
}


def parse_pool(payload: dict[str, object]) -> list[SourceImage]:
    """Images from an Openverse response, keeping only re-hostable ones."""
    results = payload.get("results")
    if not isinstance(results, list):
        return []

    pool: list[SourceImage] = []
    for item in results:
        if not isinstance(item, dict):
            continue

        licence = str(item.get("license") or "").lower()
        if licence not in ALLOWED_LICENCES:
            # Belt and braces: the query already filters, but a licence we did not ask for
            # arriving anyway must not end up on our CDN.
            continue

        url = item.get("url")
        if not isinstance(url, str) or not url.startswith("http"):
            continue

        pool.append(
            SourceImage(
                url=url,
                source=f"{SOURCE_NAME} ({licence.upper()})",
                photographer=str(item.get("creator") or "") or None,
                source_url=str(item.get("foreign_landing_url") or "") or None,
            )
        )
    return pool


class OpenversePools:
    """Category pools, fetched once and cached to disk — same contract as `PexelsPools`."""

    def __init__(self, client: httpx.Client, cache_dir: Path) -> None:
        self._client = client
        self._cache_dir = cache_dir
        self._memory: dict[str, list[SourceImage]] = {}

    def _cache_file(self, category_slug: str) -> Path:
        return self._cache_dir / f"openverse-{category_slug}.json"

    def pool_for(self, category_slug: str) -> list[SourceImage]:
        if category_slug in self._memory:
            return self._memory[category_slug]

        path = self._cache_file(category_slug)
        if path.exists():
            try:
                raw = json.loads(path.read_text(encoding="utf-8"))
                pool = [SourceImage(**entry) for entry in raw if isinstance(entry, dict)]
                self._memory[category_slug] = pool
                return pool
            except (OSError, ValueError):
                pass  # a corrupt cache is refetched, not fatal

        pool = self._fetch(category_slug)
        self._memory[category_slug] = pool
        if pool:
            self._write_cache(category_slug, pool)
        return pool

    def _write_cache(self, category_slug: str, pool: list[SourceImage]) -> None:
        self._cache_dir.mkdir(parents=True, exist_ok=True)
        self._cache_file(category_slug).write_text(
            json.dumps(
                [
                    {
                        "url": i.url,
                        "source": i.source,
                        "photographer": i.photographer,
                        "source_url": i.source_url,
                    }
                    for i in pool
                ],
                indent=2,
            ),
            encoding="utf-8",
        )

    def _fetch(self, category_slug: str) -> list[SourceImage]:
        response = self._client.get(
            API_URL,
            params={
                "q": CATEGORY_QUERIES.get(category_slug, category_slug),
                "license": ",".join(ALLOWED_LICENCES),
                "extension": "jpg",
                "page_size": POOL_SIZE,
            },
            headers={"User-Agent": "dupermarket-seed/0.1 (catalogue seeding)"},
        )
        response.raise_for_status()
        return parse_pool(response.json())
