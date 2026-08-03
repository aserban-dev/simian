"""A second seed run changes nothing (T141).

FR-072 and SC-012. The measurable claim is **zero uploads on a re-run**, and the mechanism is a
content hash rather than a key-existence check (research D9).

That distinction is what these tests are really about. Keying on existence would pass a naive
"did we upload twice" test while failing in both directions in production: it never picks up a
corrected source image, and it cannot distinguish "already correct" from "uploaded broken last
time". So the tests below check the *changed* case as carefully as the unchanged one.
"""

from __future__ import annotations

from typing import Any

from dupermarket_seed.images.assign import assign_all, load_overrides
from dupermarket_seed.images.r2 import R2Uploader, public_url
from dupermarket_seed.models import NormalisedProduct, SourceImage


class RecordingStore:
    """Stands in for the R2 client. Records every write so uploads can be counted."""

    def __init__(self) -> None:
        self.puts: list[dict[str, Any]] = []

    def put_object(self, *, Bucket: str, Key: str, Body: bytes, **kwargs: Any) -> object:
        self.puts.append({"bucket": Bucket, "key": Key, "body": Body, **kwargs})
        return {}


def product(source_id: str = "kaggle:1", slug: str = "beauty") -> NormalisedProduct:
    return NormalisedProduct(
        source_id=source_id,
        title="Mascara",
        description="A mascara",
        category_slug=slug,
        price_minor=1999,
        images=[SourceImage(url="https://cdn/a.jpg", source="DummyJSON")],
    )


class TestUploadSkipping:
    def test_the_first_upload_sends_bytes(self) -> None:
        store = RecordingStore()
        uploader = R2Uploader(store, "dupermarket")

        sent = uploader.upload_if_changed(
            key="products/p1/0.webp",
            body=b"webp-bytes",
            content_sha256="abc",
            known_sha256=None,
        )

        assert sent is True
        assert len(store.puts) == 1

    def test_an_unchanged_image_is_skipped(self) -> None:
        store = RecordingStore()
        uploader = R2Uploader(store, "dupermarket")

        sent = uploader.upload_if_changed(
            key="products/p1/0.webp",
            body=b"webp-bytes",
            content_sha256="abc",
            known_sha256="abc",
        )

        assert sent is False
        assert store.puts == []

    def test_a_changed_image_is_re_uploaded(self) -> None:
        """The half a key-existence check gets wrong: a corrected source must reach the CDN."""
        store = RecordingStore()
        uploader = R2Uploader(store, "dupermarket")

        sent = uploader.upload_if_changed(
            key="products/p1/0.webp",
            body=b"different-bytes",
            content_sha256="def",
            known_sha256="abc",
        )

        assert sent is True
        assert len(store.puts) == 1

    def test_a_second_run_over_the_same_catalogue_uploads_nothing(self) -> None:
        """SC-012, stated directly."""
        store = RecordingStore()
        known: dict[str, str] = {}

        for run in range(2):
            uploader = R2Uploader(store, "dupermarket")
            for index in range(20):
                key = f"products/p{index}/0.webp"
                digest = f"sha-{index}"
                uploader.upload_if_changed(
                    key=key,
                    body=b"bytes",
                    content_sha256=digest,
                    known_sha256=known.get(key),
                )
                known[key] = digest

            if run == 0:
                assert uploader.result.upload_count == 20
            else:
                assert uploader.result.upload_count == 0
                assert uploader.result.skip_count == 20

    def test_the_hash_is_recorded_as_object_metadata(self) -> None:
        # So a person looking at the bucket can tell what is there without the database.
        store = RecordingStore()

        R2Uploader(store, "dupermarket").upload_if_changed(
            key="products/p1/0.webp",
            body=b"bytes",
            content_sha256="abc",
            known_sha256=None,
        )

        assert store.puts[0]["Metadata"] == {"sha256": "abc"}

    def test_uploads_are_webp_with_a_long_cache_life(self) -> None:
        store = RecordingStore()

        R2Uploader(store, "dupermarket").upload_if_changed(
            key="products/p1/0.webp",
            body=b"bytes",
            content_sha256="abc",
            known_sha256=None,
        )

        assert store.puts[0]["ContentType"] == "image/webp"
        assert "immutable" in store.puts[0]["CacheControl"]


class TestAssignmentIsStableAcrossRuns:
    """FR-073: an unstable assignment would make every run re-upload everything."""

    def test_the_same_product_is_dealt_the_same_pool_image(self) -> None:
        pool = [SourceImage(url=f"https://pexels/{i}.jpg", source="Pexels") for i in range(30)]
        without_own_image = NormalisedProduct(
            source_id="kaggle:99",
            title="Dress",
            description="A dress",
            category_slug="womens-clothing",
            price_minor=4999,
        )

        first = assign_all([without_own_image], pools={"womens-clothing": pool})
        second = assign_all([without_own_image], pools={"womens-clothing": pool})

        assert first == second

    def test_different_products_spread_across_the_pool(self) -> None:
        pool = [SourceImage(url=f"https://pexels/{i}.jpg", source="Pexels") for i in range(30)]
        products = [
            NormalisedProduct(
                source_id=f"kaggle:{i}",
                title="Dress",
                description="A dress",
                category_slug="womens-clothing",
                price_minor=4999,
            )
            for i in range(200)
        ]

        assigned = assign_all(products, pools={"womens-clothing": pool})

        assert len({image.url for image in assigned.values()}) > 20

    def test_a_products_own_image_beats_the_pool(self) -> None:
        """The source's image genuinely depicts the product; no stock photograph does."""
        pool = [SourceImage(url="https://pexels/0.jpg", source="Pexels")]

        assigned = assign_all([product()], pools={"beauty": pool})

        assert assigned["kaggle:1"].url == "https://cdn/a.jpg"


class TestOverridesAreLoadedIdempotently:
    def test_a_missing_overrides_file_is_an_empty_mapping(self, tmp_path: Any) -> None:
        assert load_overrides(tmp_path / "nope.csv") == {}


class TestPublicUrls:
    def test_the_url_joins_cleanly(self) -> None:
        assert (
            public_url("https://cdn.dupermarket.test/", "/products/p1/0.webp")
            == "https://cdn.dupermarket.test/products/p1/0.webp"
        )
