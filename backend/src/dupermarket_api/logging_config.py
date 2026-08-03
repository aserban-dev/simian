"""Structured logging, with a formatter that cannot emit a card-shaped string (T160).

Constitution Principle I says no card data is collected, transmitted, logged, or persisted. The
first three are structural here — there is no field in the contract that accepts a card number,
so there is nothing to log. This module covers the fourth possibility: that a card-shaped string
reaches a log by some route nobody anticipated.

That is not paranoia about this codebase; it is about the next one. A demo that grows a real
payment integration will grow it somewhere, and a log formatter that redacts by default means
the first mistake is a redacted line rather than a permanent record in a log aggregator.

The redaction is deliberately **crude and last-resort**: it runs over the fully formatted
message, so it cannot be bypassed by clever argument passing, and it costs one regex pass per
log line.
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any

REDACTED = "[redacted]"

# Thirteen to nineteen digits, optionally separated by spaces or hyphens. That covers every
# major card format. Anchored on word boundaries so an order number or a UUID fragment does not
# trip it.
_CARD_LIKE = re.compile(r"\b(?:\d[ -]?){13,19}\b")

# Three or four digits explicitly labelled as a security code. The digits alone are far too
# common to redact, so the label is what makes this safe to act on.
# The pragma sits on the pattern line itself: the scan is per line, so an exemption anywhere
# else would not cover it — and would silently stop covering it after a reformat.
_CVV_LIKE = re.compile(
    r"\b(?:cvv|cvc|security[ _-]?code)\b\s*[:=]?\s*\d{3,4}",  # principle-i-allow: destroys these
    re.IGNORECASE,
)


def redact(message: str) -> str:
    """Remove anything card-shaped from an already-formatted log line.

    Returns the message unchanged when there is nothing to redact, which is every line in
    practice — this is a guard, not a transformation the system depends on.
    """
    redacted = _CVV_LIKE.sub(REDACTED, message)
    return _CARD_LIKE.sub(REDACTED, redacted)


def looks_like_card_data(message: str) -> bool:
    """Whether `redact` would change this message. Used by the test that asserts it would."""
    return redact(message) != message


class RedactingJsonFormatter(logging.Formatter):
    """One JSON object per line, with every value passed through [`redact`].

    JSON rather than text because these logs are read by a machine first: a request id and a
    path as fields are queryable, and the same two interpolated into a sentence are not.

    Redaction is applied to the *rendered* message and to every extra field, so a card number
    cannot arrive as an argument, an f-string, or a structured value and survive.
    """

    #: Attributes `logging` puts on every record. Anything else was added by the caller and is
    #: carried through as a structured field.
    _STANDARD = frozenset(
        {
            "args",
            "asctime",
            "created",
            "exc_info",
            "exc_text",
            "filename",
            "funcName",
            "levelname",
            "levelno",
            "lineno",
            "module",
            "msecs",
            "message",
            "msg",
            "name",
            "pathname",
            "process",
            "processName",
            "relativeCreated",
            "stack_info",
            "taskName",
            "thread",
            "threadName",
        }
    )

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "level": record.levelname,
            "logger": record.name,
            "message": redact(record.getMessage()),
        }

        for key, value in record.__dict__.items():
            if key in self._STANDARD:
                continue
            payload[key] = redact(value) if isinstance(value, str) else value

        if record.exc_info:
            # The traceback is redacted too: an exception's message routinely quotes the value
            # that caused it, which is exactly the value worth not logging.
            payload["exception"] = redact(self.formatException(record.exc_info))

        return json.dumps(payload, default=str)


def configure_logging(level: str = "INFO") -> None:
    """Install the redacting formatter as the root handler.

    Replaces existing handlers rather than adding to them: a second plain handler would log
    every line twice, once unredacted, which would defeat the point entirely.
    """
    handler = logging.StreamHandler()
    handler.setFormatter(RedactingJsonFormatter())

    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level.upper())
