"""Image pool sources and the licence filter (T148, T152).

The constitution's image rule is the one that has to hold here: assets re-hosted on R2 must come
from a source whose terms permit re-hosting. Openverse makes that checkable per image rather
than per site, so the filter below is the enforcement point — and a licence we did not ask for
arriving anyway must not reach the CDN.

Attribution is captured for every image (FR-075) whether the licence demands it or not.
"""

from __future__ import annotations

from typing import Any

from dupermarket_seed.images.openverse import ALLOWED_LICENCES, POOL_SIZE
from dupermarket_seed.images.openverse import parse_pool as parse_openverse
from dupermarket_seed.images.pexels import RateLimiter
from dupermarket_seed.images.pexels import parse_pool as parse_pexels


def openverse_item(**overrides: Any) -> dict[str, Any]:
    item: dict[str, Any] = {
        "url": "https://live.example/photo.jpg",
        "license": "cc0",
        "license_version": "1.0",
        "creator": "Ada Photographer",
        "foreign_landing_url": "https://example/photo",
    }
    item.update(overrides)
    return item


class TestOpenverseLicenceFilter:
    def test_permissive_licences_are_admitted(self) -> None:
        for licence in ALLOWED_LICENCES:
            pool = parse_openverse({"results": [openverse_item(license=licence)]})
            assert len(pool) == 1, licence

    def test_no_derivatives_is_rejected(self) -> None:
        """We resize and re-encode, which is a derivative — `nd` forbids exactly that."""
        pool = parse_openverse({"results": [openverse_item(license="by-nd")]})

        assert pool == []

    def test_non_commercial_is_rejected(self) -> None:
        # The boundary is unclear enough that a demo shop is not the place to test it.
        pool = parse_openverse({"results": [openverse_item(license="by-nc")]})

        assert pool == []

    def test_an_unknown_licence_is_rejected(self) -> None:
        pool = parse_openverse({"results": [openverse_item(license="all-rights-reserved")]})

        assert pool == []

    def test_a_missing_licence_is_rejected(self) -> None:
        """Absent is not permissive. Defaulting the other way would put unlicensed bytes on R2."""
        item = openverse_item()
        del item["license"]

        assert parse_openverse({"results": [item]}) == []

    def test_a_mixed_response_keeps_only_the_permissive_ones(self) -> None:
        pool = parse_openverse(
            {
                "results": [
                    openverse_item(license="cc0", url="https://live.example/a.jpg"),
                    openverse_item(license="by-nc-nd", url="https://live.example/b.jpg"),
                    openverse_item(license="by", url="https://live.example/c.jpg"),
                ]
            }
        )

        assert [image.url for image in pool] == [
            "https://live.example/a.jpg",
            "https://live.example/c.jpg",
        ]

    def test_the_licence_is_recorded_in_the_credit(self) -> None:
        pool = parse_openverse({"results": [openverse_item(license="by")]})

        assert "BY" in pool[0].source

    def test_attribution_is_captured(self) -> None:
        """FR-075: the only moment the photographer is knowable."""
        pool = parse_openverse({"results": [openverse_item()]})

        assert pool[0].photographer == "Ada Photographer"
        assert pool[0].source_url == "https://example/photo"

    def test_a_non_http_url_is_rejected(self) -> None:
        assert parse_openverse({"results": [openverse_item(url="ftp://example/a.jpg")]}) == []

    def test_a_malformed_response_yields_an_empty_pool(self) -> None:
        # A source outage should leave a category without a pool, not crash the run.
        assert parse_openverse({}) == []
        assert parse_openverse({"results": "not a list"}) == []

    def test_the_pool_size_stays_within_the_anonymous_cap(self) -> None:
        # Above 20 Openverse returns 401 rather than a truncated page, so this is a hard limit.
        assert POOL_SIZE <= 20


class TestPexelsPool:
    def test_photos_are_parsed_with_attribution(self) -> None:
        pool = parse_pexels(
            {
                "photos": [
                    {
                        "src": {"large": "https://pexels/a.jpg"},
                        "photographer": "Ada Photographer",
                        "url": "https://pexels/photo/1",
                    }
                ]
            }
        )

        assert pool[0].url == "https://pexels/a.jpg"
        assert pool[0].photographer == "Ada Photographer"
        assert pool[0].source == "Pexels"

    def test_a_photo_with_no_large_rendition_is_skipped(self) -> None:
        assert parse_pexels({"photos": [{"src": {}}]}) == []

    def test_a_malformed_response_yields_an_empty_pool(self) -> None:
        assert parse_pexels({}) == []


class TestRateLimiting:
    def test_the_first_request_does_not_wait(self) -> None:
        assert RateLimiter().wait(None, now=100.0) == 0.0

    def test_a_recent_request_forces_a_pause(self) -> None:
        limiter = RateLimiter(min_interval=18.0)

        assert limiter.wait(last_request_at=100.0, now=105.0) == 13.0

    def test_an_old_request_does_not(self) -> None:
        limiter = RateLimiter(min_interval=18.0)

        assert limiter.wait(last_request_at=100.0, now=200.0) == 0.0

    def test_the_default_interval_stays_under_the_published_limit(self) -> None:
        # 200 requests/hour is the documented ceiling; the floor between requests must respect it.
        assert RateLimiter().min_interval >= 3600 / 200
