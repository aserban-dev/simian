"""`verify.py` fails loudly (T142).

FR-074: every product ends the run with at least one image, and every stored reference
resolves. A run that violates either **must fail** — non-zero exit, named findings.

The failure mode this guards is a seed pipeline where every individual step succeeded and the
catalogue still has holes in it: a product whose pool was empty, or an upload that silently
404s. Neither shows up anywhere except by looking afterwards.
"""

from __future__ import annotations

import io

from dupermarket_seed.verify import EXIT_FAILED, EXIT_OK, ImageRef, main, verify

RESOLVING = {"products/p1/0.webp", "products/p2/0.webp", "products/p2/1.webp"}


def resolves(path: str) -> bool:
    return path in RESOLVING


class TestAHealthyRun:
    def test_passes(self) -> None:
        report = verify(
            ["p1", "p2"],
            [
                ImageRef("p1", "products/p1/0.webp", 0),
                ImageRef("p2", "products/p2/0.webp", 0),
                ImageRef("p2", "products/p2/1.webp", 1),
            ],
            resolves=resolves,
        )

        assert report.ok
        assert report.exit_code == EXIT_OK

    def test_says_so(self) -> None:
        report = verify(["p1"], [ImageRef("p1", "products/p1/0.webp")], resolves=resolves)

        assert "passed" in " ".join(report.lines())


class TestAProductWithNoImage:
    def test_fails(self) -> None:
        report = verify(["p1", "p3"], [ImageRef("p1", "products/p1/0.webp")], resolves=resolves)

        assert not report.ok
        assert report.exit_code == EXIT_FAILED

    def test_names_the_product(self) -> None:
        report = verify(["p1", "p3"], [ImageRef("p1", "products/p1/0.webp")], resolves=resolves)

        assert report.products_without_images == ["p3"]
        assert "p3" in " ".join(report.lines())

    def test_an_entirely_imageless_catalogue_fails(self) -> None:
        report = verify(["p1", "p2"], [], resolves=resolves)

        assert report.exit_code == EXIT_FAILED
        assert len(report.products_without_images) == 2

    def test_the_message_cites_the_requirement(self) -> None:
        # So whoever reads a red CI log knows which rule was broken, not just that one was.
        report = verify(["p3"], [], resolves=resolves)

        assert "FR-074" in " ".join(report.lines())


class TestAnUnresolvablePath:
    def test_fails(self) -> None:
        report = verify(
            ["p1"],
            [ImageRef("p1", "products/p1/missing.webp")],
            resolves=resolves,
        )

        assert not report.ok
        assert report.exit_code == EXIT_FAILED

    def test_names_the_path(self) -> None:
        report = verify(
            ["p1"],
            [ImageRef("p1", "products/p1/missing.webp")],
            resolves=resolves,
        )

        assert report.unresolvable_paths == ["products/p1/missing.webp"]

    def test_one_bad_path_among_many_good_ones_still_fails(self) -> None:
        """A single broken image is a broken catalogue; "mostly fine" is not a passing state."""
        report = verify(
            ["p1", "p2"],
            [
                ImageRef("p1", "products/p1/0.webp", 0),
                ImageRef("p2", "products/p2/0.webp", 0),
                ImageRef("p2", "products/p2/gone.webp", 1),
            ],
            resolves=resolves,
        )

        assert report.exit_code == EXIT_FAILED


class TestDuplicateSortOrders:
    def test_two_primary_images_are_a_failure(self) -> None:
        """Otherwise the "primary" image is whichever row the database returns first, and the
        catalogue renders differently on each read."""
        report = verify(
            ["p2"],
            [
                ImageRef("p2", "products/p2/0.webp", 0),
                ImageRef("p2", "products/p2/1.webp", 0),
            ],
            resolves=resolves,
        )

        assert not report.ok
        assert report.duplicate_sort_orders == ["p2"]

    def test_distinct_orders_are_fine(self) -> None:
        report = verify(
            ["p2"],
            [
                ImageRef("p2", "products/p2/0.webp", 0),
                ImageRef("p2", "products/p2/1.webp", 1),
            ],
            resolves=resolves,
        )

        assert report.ok


class TestTheExitCode:
    def test_a_failing_report_exits_non_zero(self) -> None:
        report = verify(["p3"], [], resolves=resolves)
        stream = io.StringIO()

        assert main(report, stream=stream) == EXIT_FAILED

    def test_a_passing_report_exits_zero(self) -> None:
        report = verify(["p1"], [ImageRef("p1", "products/p1/0.webp")], resolves=resolves)
        stream = io.StringIO()

        assert main(report, stream=stream) == EXIT_OK

    def test_the_findings_are_printed(self) -> None:
        report = verify(["p3"], [], resolves=resolves)
        stream = io.StringIO()

        main(report, stream=stream)

        assert "p3" in stream.getvalue()

    def test_a_long_list_of_findings_is_truncated_not_dumped(self) -> None:
        # A CI log with 40,000 product ids in it is a log nobody reads.
        report = verify([f"p{i}" for i in range(500)], [], resolves=resolves)

        line = " ".join(report.lines())
        assert "500 product(s)" in line
        assert "…" in line
