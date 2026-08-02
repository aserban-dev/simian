"""Opaque keyset cursors.

Research D3: offset pagination breaks FR-002. A row inserted or a rating updated between two
page fetches shifts the window, so a product is silently duplicated or skipped — precisely the
failure FR-002 forbids. A keyset cursor encodes the last row's sort key plus its id, so the next
page continues from a fixed point regardless of what changed behind it.

The cursor is opaque to clients: base64url of a compact JSON payload. It is *not* signed or
encrypted, because it contains only public catalogue ordering data. If a client tampers with
one, the worst outcome is a wrong page for that client, so validation only needs to reject
malformed input rather than authenticate it.
"""

from __future__ import annotations

import base64
import binascii
import json
import uuid
from dataclasses import dataclass
from typing import Any, Final

CURSOR_VERSION: Final = 1


class InvalidCursor(ValueError):
    """A cursor that cannot be decoded, or that was minted for a different sort order."""


@dataclass(frozen=True, slots=True)
class Cursor:
    """The position of the last row of the previous page."""

    sort: str
    last_id: uuid.UUID
    # The sort key's value on that row. None for sorts keyed only on id.
    last_value: Any = None

    def encode(self) -> str:
        payload = {
            "v": CURSOR_VERSION,
            "s": self.sort,
            "i": str(self.last_id),
            "k": self.last_value,
        }
        raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
        return base64.urlsafe_b64encode(raw).decode().rstrip("=")

    @classmethod
    def decode(cls, value: str, *, expected_sort: str) -> Cursor:
        if not value:
            raise InvalidCursor("empty cursor")

        # Padding is stripped on encode to keep URLs tidy; restore it before decoding.
        padded = value + "=" * (-len(value) % 4)
        try:
            payload = json.loads(base64.urlsafe_b64decode(padded))
        except (binascii.Error, ValueError, UnicodeDecodeError) as exc:
            raise InvalidCursor("cursor is not decodable") from exc

        if not isinstance(payload, dict):
            raise InvalidCursor("cursor is not an object")
        if payload.get("v") != CURSOR_VERSION:
            # A cursor minted by an older deployment may encode a different key set. Rejecting
            # it means the client restarts paging, which is correct and visible; accepting it
            # could silently skip rows.
            raise InvalidCursor("cursor version is not supported")

        sort = payload.get("s")
        if sort != expected_sort:
            # Changing the sort invalidates the cursor: its key means something else now.
            # Continuing would page through an order that no longer exists.
            raise InvalidCursor("cursor was minted for a different sort order")

        try:
            last_id = uuid.UUID(str(payload["i"]))
        except (KeyError, ValueError, AttributeError) as exc:
            raise InvalidCursor("cursor has no usable id") from exc

        return cls(sort=sort, last_id=last_id, last_value=payload.get("k"))
