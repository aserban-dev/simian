"""An operator override wins (T143).

FR-076: an operator-supplied product-to-image mapping takes precedence over automatic
resolution. The point of an override is that a person looked at what automation produced and
disagreed — so anything that could beat it would make it advisory rather than an override.

The precedence order asserted here is: **override > the source's own image > a Pexels pool
photograph** (research D9).
"""

from __future__ import annotations

from pathlib import Path

from dupermarket_seed.images.assign import (
    OVERRIDE_SOURCE,
    assign_all,
    assign_image,
    load_overrides,
    products_without_images,
)
from dupermarket_seed.models import NormalisedProduct, SourceImage

POOL = [SourceImage(url=f"https://pexels/{i}.jpg", source="Pexels") for i in range(30)]


def product(source_id: str = "kaggle:1", *, with_own_image: bool = True) -> NormalisedProduct:
    return NormalisedProduct(
        source_id=source_id,
        title="Dress",
        description="A dress",
        category_slug="womens-clothing",
        price_minor=4999,
        images=[SourceImage(url="https://source/own.jpg", source="Kaggle")]
        if with_own_image
        else [],
    )


def write_overrides(path: Path, rows: str) -> Path:
    csv_path = path / "overrides.csv"
    csv_path.write_text(rows, encoding="utf-8")
    return csv_path


class TestPrecedence:
    def test_an_override_beats_the_pool(self) -> None:
        overrides = {"kaggle:1": SourceImage(url="https://chosen/by-hand.jpg", source="operator")}

        chosen = assign_image(product(with_own_image=False), overrides=overrides, pool=POOL)

        assert chosen is not None
        assert chosen.url == "https://chosen/by-hand.jpg"

    def test_an_override_beats_the_products_own_image(self) -> None:
        """The strongest form: even a genuine product photograph loses to a human decision."""
        overrides = {"kaggle:1": SourceImage(url="https://chosen/by-hand.jpg", source="operator")}

        chosen = assign_image(product(), overrides=overrides, pool=POOL)

        assert chosen is not None
        assert chosen.url == "https://chosen/by-hand.jpg"

    def test_without_an_override_the_source_image_is_used(self) -> None:
        chosen = assign_image(product(), overrides={}, pool=POOL)

        assert chosen is not None
        assert chosen.url == "https://source/own.jpg"

    def test_without_either_a_pool_image_is_dealt(self) -> None:
        chosen = assign_image(product(with_own_image=False), overrides={}, pool=POOL)

        assert chosen is not None
        assert chosen.source == "Pexels"

    def test_with_nothing_available_the_result_is_none(self) -> None:
        """Not an exception: `verify.py` is where FR-074 fails the run, in one place."""
        assert assign_image(product(with_own_image=False), overrides={}, pool=[]) is None

    def test_an_override_only_applies_to_its_own_product(self) -> None:
        overrides = {"kaggle:1": SourceImage(url="https://chosen/by-hand.jpg", source="operator")}

        assigned = assign_all(
            [product("kaggle:1"), product("kaggle:2")],
            overrides=overrides,
            pools={"womens-clothing": POOL},
        )

        assert assigned["kaggle:1"].url == "https://chosen/by-hand.jpg"
        assert assigned["kaggle:2"].url == "https://source/own.jpg"


class TestLoadingTheFile:
    def test_rows_are_keyed_by_source_id(self, tmp_path: Path) -> None:
        path = write_overrides(
            tmp_path,
            "source_id,image_url\nkaggle:1,https://chosen/a.jpg\nkaggle:2,https://chosen/b.jpg\n",
        )

        overrides = load_overrides(path)

        assert set(overrides) == {"kaggle:1", "kaggle:2"}
        assert overrides["kaggle:1"].url == "https://chosen/a.jpg"

    def test_attribution_columns_are_read(self, tmp_path: Path) -> None:
        """FR-075 applies to an overridden image too — it still came from somewhere."""
        path = write_overrides(
            tmp_path,
            "source_id,image_url,photographer,source\n"
            "kaggle:1,https://chosen/a.jpg,Ada Photographer,Pexels\n",
        )

        overrides = load_overrides(path)

        assert overrides["kaggle:1"].photographer == "Ada Photographer"
        assert overrides["kaggle:1"].source == "Pexels"

    def test_a_row_with_no_url_is_ignored(self, tmp_path: Path) -> None:
        path = write_overrides(tmp_path, "source_id,image_url\nkaggle:1,\n")

        assert load_overrides(path) == {}

    def test_a_row_with_no_source_id_is_ignored(self, tmp_path: Path) -> None:
        path = write_overrides(tmp_path, "source_id,image_url\n,https://chosen/a.jpg\n")

        assert load_overrides(path) == {}

    def test_a_missing_file_is_not_an_error(self, tmp_path: Path) -> None:
        # Overrides are optional; requiring the file would make the common case need a stub.
        assert load_overrides(tmp_path / "absent.csv") == {}

    def test_the_default_credit_names_the_operator(self, tmp_path: Path) -> None:
        path = write_overrides(tmp_path, "source_id,image_url\nkaggle:1,https://chosen/a.jpg\n")

        assert load_overrides(path)["kaggle:1"].source == OVERRIDE_SOURCE


class TestOverridesRescueImagelessProducts:
    def test_an_override_removes_a_product_from_the_missing_list(self) -> None:
        """The operator's escape hatch for FR-074: a product the pipeline could not illustrate."""
        stranded = product("kaggle:9", with_own_image=False)

        before = assign_all([stranded], pools={"womens-clothing": []})
        after = assign_all(
            [stranded],
            overrides={"kaggle:9": SourceImage(url="https://chosen/a.jpg", source="operator")},
            pools={"womens-clothing": []},
        )

        assert products_without_images([stranded], before) == ["kaggle:9"]
        assert products_without_images([stranded], after) == []
