"""Order arithmetic in integer minor units (T075, research D4).

Money is an exact integer count of minor units from end to end. The failure mode this guards is
not "the total is slightly wrong" — it is that a float creeps in somewhere, and the error then
depends on the values, which makes it invisible in a demo and wrong in a test that asserts
equality. So the assertions here are about *types* as much as amounts.

Charm pricing makes this concrete: `.99` and `.49` endings are exactly the values binary floats
cannot represent.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from dupermarket_api.services.orders import line_total_minor, subtotal_minor, unit_price_base_minor

pytestmark = pytest.mark.unit


class TestLineTotals:
    def test_a_single_unit_costs_its_unit_price(self) -> None:
        assert line_total_minor(1999, 1) == 1999

    def test_quantity_multiplies(self) -> None:
        assert line_total_minor(1999, 3) == 5997

    def test_the_result_is_an_int_not_a_float(self) -> None:
        assert isinstance(line_total_minor(1999, 3), int)
        assert not isinstance(line_total_minor(1999, 3), float)

    def test_charm_prices_accumulate_exactly(self) -> None:
        """`0.99 * 3` is 2.9699999999999998 in binary floating point. Here it is 297."""
        assert line_total_minor(99, 3) == 297

    def test_the_maximum_quantity_does_not_overflow_into_a_float(self) -> None:
        assert line_total_minor(999_99, 99) == 9_899_901

    def test_a_zero_price_is_allowed(self) -> None:
        # A free gift line is not an error; a negative price would be.
        assert line_total_minor(0, 4) == 0

    def test_a_negative_quantity_is_rejected(self) -> None:
        with pytest.raises(ValueError):
            line_total_minor(1999, -1)

    def test_a_zero_quantity_is_rejected(self) -> None:
        with pytest.raises(ValueError):
            line_total_minor(1999, 0)

    def test_a_negative_price_is_rejected(self) -> None:
        with pytest.raises(ValueError):
            line_total_minor(-1, 1)


class TestSubtotals:
    def test_an_empty_basket_is_zero(self) -> None:
        assert subtotal_minor([]) == 0

    def test_lines_sum(self) -> None:
        assert subtotal_minor([(1999, 2), (500, 1)]) == 4498

    def test_the_sum_is_an_int(self) -> None:
        assert isinstance(subtotal_minor([(1999, 2), (99, 3)]), int)

    def test_many_charm_prices_stay_exact(self) -> None:
        """Ten lines at 19.99 is 199.90 exactly — the classic float-drift case."""
        assert subtotal_minor([(1999, 1)] * 10) == 19_990

    def test_order_of_lines_does_not_change_the_total(self) -> None:
        lines = [(1999, 2), (499, 3), (12345, 1)]
        assert subtotal_minor(lines) == subtotal_minor(list(reversed(lines)))


class TestUnitPriceFromTheCatalogue:
    """The discount is applied once, at a single place, and yields an integer."""

    def test_an_undiscounted_product_costs_its_base_price(self) -> None:
        assert unit_price_base_minor(4999, None) == 4999

    def test_a_discount_reduces_the_price(self) -> None:
        assert unit_price_base_minor(10_000, Decimal("10")) == 9000

    def test_the_discounted_price_is_an_int(self) -> None:
        assert isinstance(unit_price_base_minor(4999, Decimal("15")), int)

    def test_a_fractional_result_is_rounded_not_truncated_to_a_float(self) -> None:
        # 4999 less 15% is 4249.15 — the stored value must be a whole number of minor units.
        result = unit_price_base_minor(4999, Decimal("15"))
        assert result in {4249, 4250}
        assert isinstance(result, int)

    def test_a_zero_discount_changes_nothing(self) -> None:
        assert unit_price_base_minor(4999, Decimal("0")) == 4999

    def test_a_full_discount_is_free_not_negative(self) -> None:
        assert unit_price_base_minor(4999, Decimal("100")) == 0
