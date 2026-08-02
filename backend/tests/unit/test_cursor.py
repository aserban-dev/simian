"""Keyset cursor round-tripping and rejection.

The cursor is the mechanism FR-002 rests on: stable order across pages, nothing duplicated,
nothing skipped. These tests cover the encode/decode contract. That the *query* uses it
correctly under concurrent inserts is T040, which needs a live database.
"""

from __future__ import annotations

import base64
import json
import uuid

import pytest

from dupermarket_api.services.cursor import Cursor, InvalidCursor

pytestmark = pytest.mark.unit

PRODUCT_ID = uuid.UUID("3f2504e0-4f89-11d3-9a0c-0305e82c3301")


class TestRoundTrip:
    @pytest.mark.parametrize(
        ("sort", "value"),
        [
            ("price_asc", 1299),
            ("price_desc", 0),
            ("rating", 4.5),
            ("newest", "2026-08-02T12:00:00+00:00"),
            ("relevance", 0.87),
            ("newest", None),
        ],
    )
    def test_a_cursor_survives_a_round_trip(self, sort: str, value: object) -> None:
        """FR-002: the position must come back exactly, or paging drifts."""
        original = Cursor(sort=sort, last_id=PRODUCT_ID, last_value=value)
        decoded = Cursor.decode(original.encode(), expected_sort=sort)

        assert decoded.last_id == PRODUCT_ID
        assert decoded.last_value == value
        assert decoded.sort == sort

    def test_encoding_is_deterministic(self) -> None:
        """Principle III: the same position always produces the same cursor string."""
        cursor = Cursor(sort="price_asc", last_id=PRODUCT_ID, last_value=999)
        assert cursor.encode() == cursor.encode()

    def test_the_cursor_is_url_safe_and_unpadded(self) -> None:
        encoded = Cursor(sort="newest", last_id=PRODUCT_ID, last_value=None).encode()
        assert "=" not in encoded
        assert "+" not in encoded and "/" not in encoded

    def test_the_cursor_is_opaque_but_not_claimed_to_be_secret(self) -> None:
        # Documented as obfuscation, not security. This test states the expectation so nobody
        # later assumes a cursor authenticates anything.
        encoded = Cursor(sort="price_asc", last_id=PRODUCT_ID, last_value=1299).encode()
        payload = json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)))
        assert payload["i"] == str(PRODUCT_ID)


class TestRejection:
    @pytest.mark.parametrize(
        "value",
        [
            "",
            "not-base64!!",
            "YWJj",  # valid base64, but "abc" is not JSON
            base64.urlsafe_b64encode(b'["not", "an", "object"]').decode(),
            base64.urlsafe_b64encode(b'{"v":1,"s":"price_asc"}').decode(),  # no id
            base64.urlsafe_b64encode(b'{"v":1,"s":"price_asc","i":"nope"}').decode(),
        ],
    )
    def test_malformed_cursors_raise_invalid_cursor(self, value: str) -> None:
        """FR-060: a bad cursor becomes a handled 400, never an unhandled 500."""
        with pytest.raises(InvalidCursor):
            Cursor.decode(value, expected_sort="price_asc")

    def test_a_cursor_from_a_different_sort_is_rejected(self) -> None:
        """FR-002: the key means something else under another sort; continuing would skip rows."""
        cursor = Cursor(sort="price_asc", last_id=PRODUCT_ID, last_value=1299).encode()
        with pytest.raises(InvalidCursor, match="different sort"):
            Cursor.decode(cursor, expected_sort="rating")

    def test_a_cursor_from_an_older_version_is_rejected(self) -> None:
        """Restarting paging is visible and correct; silently skipping rows is not."""
        stale = base64.urlsafe_b64encode(
            json.dumps({"v": 0, "s": "price_asc", "i": str(PRODUCT_ID), "k": 1}).encode()
        ).decode()
        with pytest.raises(InvalidCursor, match="version"):
            Cursor.decode(stale, expected_sort="price_asc")

    def test_rejection_is_a_valueerror_subclass(self) -> None:
        # Callers that only catch ValueError still behave correctly.
        assert issubclass(InvalidCursor, ValueError)
