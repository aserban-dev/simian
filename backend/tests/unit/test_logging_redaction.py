"""The log formatter cannot emit a card-shaped string (T160).

Constitution Principle I. There is no field in this system that accepts card data, so nothing
*should* ever reach a log — this is the guard for the case where something does anyway, by a
route nobody anticipated.

The tests below matter in both directions. A redactor that catches card numbers and also
mangles order numbers, UUIDs and prices would be removed within a week, and the protection would
go with it.
"""

from __future__ import annotations

import json
import logging

import pytest

from dupermarket_api.logging_config import (
    REDACTED,
    RedactingJsonFormatter,
    looks_like_card_data,
    redact,
)

pytestmark = pytest.mark.unit


def record(message: str, **extra: object) -> logging.LogRecord:
    rec = logging.LogRecord(
        name="dupermarket_api.test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg=message,
        args=(),
        exc_info=None,
    )
    for key, value in extra.items():
        setattr(rec, key, value)
    return rec


class TestCardNumbersAreRedacted:
    @pytest.mark.parametrize(
        "number",
        [
            "4111111111111111",  # Visa
            "5500005555555559",  # Mastercard
            "340000000000009",  # Amex, 15 digits
            "4111 1111 1111 1111",  # spaced
            "4111-1111-1111-1111",  # hyphenated
            "36000000000008",  # Diners, 14 digits
        ],
    )
    def test_a_card_number_never_survives(self, number: str) -> None:
        out = redact(f"payment attempted with {number}")

        assert number not in out
        assert REDACTED in out

    def test_a_card_number_inside_json_is_redacted(self) -> None:
        out = redact('{"card_number": "4111111111111111"}')

        assert "4111111111111111" not in out

    def test_two_card_numbers_in_one_line_are_both_redacted(self) -> None:
        out = redact("from 4111111111111111 to 5500005555555559")

        assert "4111" not in out
        assert "5500" not in out

    def test_a_labelled_security_code_is_redacted(self) -> None:
        for line in ("cvv: 123", "CVC=4567", "security_code: 999"):
            assert REDACTED in redact(line), line

    def test_the_detector_agrees_with_the_redactor(self) -> None:
        assert looks_like_card_data("4111111111111111") is True
        assert looks_like_card_data("nothing to see here") is False


class TestOrdinaryValuesSurvive:
    """A redactor that mangles normal output gets deleted, and takes the protection with it."""

    @pytest.mark.parametrize(
        "value",
        [
            "DM-9F2A4C1B0E",  # order number
            "3f2504e0-4f89-11d3-9a0c-0305e82c3301",  # uuid
            "total_minor=4999",  # a price
            "GET /v1/products?limit=20 200",  # a request line
            "processing_at=2026-08-03T12:00:00Z",  # a timestamp
            "user firebase-user-a signed in",
            "127.0.0.1",
            "quantity 3 of product 12",
        ],
    )
    def test_it_is_untouched(self, value: str) -> None:
        assert redact(value) == value

    def test_a_twelve_digit_number_is_not_a_card(self) -> None:
        # Below the shortest real card length; redacting it would catch ordinary identifiers.
        assert redact("reference 123456789012") == "reference 123456789012"


class TestTheFormatter:
    def test_output_is_one_json_object(self) -> None:
        rendered = RedactingJsonFormatter().format(record("hello"))

        payload = json.loads(rendered)
        assert payload["message"] == "hello"
        assert payload["level"] == "INFO"

    def test_the_message_is_redacted(self) -> None:
        rendered = RedactingJsonFormatter().format(record("card 4111111111111111"))

        assert "4111111111111111" not in rendered

    def test_structured_extras_are_redacted_too(self) -> None:
        """A card arriving as a field rather than in the sentence must not slip through."""
        rendered = RedactingJsonFormatter().format(
            record("payment", suspicious_field="4111111111111111")
        )

        assert "4111111111111111" not in rendered

    def test_structured_extras_are_preserved(self) -> None:
        rendered = RedactingJsonFormatter().format(record("request", path="/v1/orders", status=201))

        payload = json.loads(rendered)
        assert payload["path"] == "/v1/orders"
        assert payload["status"] == 201

    def test_a_traceback_is_redacted(self) -> None:
        """An exception message routinely quotes the value that caused it."""
        try:
            raise ValueError("bad card 4111111111111111")
        except ValueError:
            import sys

            rec = record("failed")
            rec.exc_info = sys.exc_info()
            rendered = RedactingJsonFormatter().format(rec)

        assert "4111111111111111" not in rendered
        assert "exception" in json.loads(rendered)

    def test_formatting_arguments_are_redacted_after_interpolation(self) -> None:
        # The redaction runs on the rendered message, so it cannot be bypassed by passing the
        # number as an argument rather than embedding it.
        rec = logging.LogRecord(
            name="t",
            level=logging.INFO,
            pathname=__file__,
            lineno=1,
            msg="card %s",
            args=("4111111111111111",),
            exc_info=None,
        )

        assert "4111111111111111" not in RedactingJsonFormatter().format(rec)
