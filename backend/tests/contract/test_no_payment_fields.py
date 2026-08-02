"""No payment card field exists anywhere in the contract (T071).

Constitution Principle I and FR-023. The point of this suite is that it is *mechanical*: "we did
not add a card field" is a claim that decays, while a walk over every schema, parameter and
request body in `contracts/openapi.yaml` is a fact re-checked on every run.

`tests/contract/test_app_matches_contract.py` makes the same assertion against the running app's
generated schema. Both are needed: this one catches a field documented but not built, that one
catches a field built but not documented.
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from typing import Any

import pytest

pytestmark = pytest.mark.contract

# Substrings that betray a payment instrument. Deliberately broad: a false positive here costs a
# rename, a false negative costs the constitutional boundary the whole project is built on.
FORBIDDEN_PATTERNS: tuple[str, ...] = (
    "card_number",
    "cardnumber",
    "pan",
    "cvv",
    "cvc",
    "security_code",
    "securitycode",
    "expiry",
    "exp_month",
    "exp_year",
    "cardholder",
    "iban",
    "account_number",
    "routing_number",
    "sort_code",
    "billing_address",
    "payment_method",
    "payment_token",
)

# `pan` as a whole word only — otherwise "company", "expand" and "panel" all trip it.
_WHOLE_WORD_ONLY = {"pan"}


def offends(name: str) -> str | None:
    lowered = name.lower()
    for pattern in FORBIDDEN_PATTERNS:
        if pattern in _WHOLE_WORD_ONLY:
            if re.fullmatch(rf"{pattern}|.*_{pattern}|{pattern}_.*", lowered):
                return pattern
        elif pattern in lowered:
            return pattern
    return None


def walk_property_names(node: Any, path: str = "") -> Iterator[tuple[str, str]]:
    """Every property name in the document, with the path it was found at."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "properties" and isinstance(value, dict):
                for prop in value:
                    yield prop, f"{path}.properties.{prop}"
            yield from walk_property_names(value, f"{path}.{key}")
    elif isinstance(node, list):
        for index, item in enumerate(node):
            yield from walk_property_names(item, f"{path}[{index}]")


class TestSchemas:
    def test_no_schema_property_looks_like_a_payment_field(self, contract: dict[str, Any]) -> None:
        offenders = [
            f"{path} (matched '{pattern}')"
            for name, path in walk_property_names(contract["components"]["schemas"], "schemas")
            if (pattern := offends(name)) is not None
        ]
        assert not offenders, f"payment-shaped fields in the contract's schemas: {offenders}"

    def test_the_walk_actually_visits_properties(self, contract: dict[str, Any]) -> None:
        """Guards against the suite passing because the traversal found nothing at all."""
        names = [name for name, _ in walk_property_names(contract["components"]["schemas"])]
        assert len(names) > 50, f"only {len(names)} properties walked; the traversal is broken"

    def test_the_detector_recognises_a_card_field(self) -> None:
        """The other half of the same guard: a real card field must not slip past `offends`."""
        for name in ("card_number", "cardNumber", "cvv", "expiry_month", "cardholder_name"):
            assert offends(name) is not None, f"{name} should have been rejected"

    def test_the_detector_tolerates_innocent_names(self) -> None:
        for name in ("company", "expand", "panel", "span", "japan"):
            assert offends(name) is None, f"{name} is not a payment field"


class TestRequestBodies:
    def test_no_request_body_property_looks_like_a_payment_field(
        self, operations: list[dict[str, Any]]
    ) -> None:
        offenders = [
            f"{op['operation_id']}: {path}"
            for op in operations
            for name, path in walk_property_names(op["op"].get("requestBody", {}), "body")
            if offends(name) is not None
        ]
        assert not offenders, f"payment-shaped request fields: {offenders}"

    def test_no_query_or_path_parameter_looks_like_a_payment_field(
        self, operations: list[dict[str, Any]]
    ) -> None:
        offenders = [
            f"{op['operation_id']}: {param.get('name')}"
            for op in operations
            for param in op["op"].get("parameters", [])
            if isinstance(param, dict) and offends(str(param.get("name", ""))) is not None
        ]
        assert not offenders, f"payment-shaped parameters: {offenders}"


class TestTheOnlyCardConceptIsCosmetic:
    def test_the_demo_card_id_enum_is_closed(self, contract: dict[str, Any]) -> None:
        """A fixed set of ids, so there is no free-text field where a real card could be typed."""
        schema = contract["components"]["schemas"]["DemoCardId"]

        assert schema["type"] == "string"
        assert set(schema["enum"]) == {"visa_success", "mastercard_success", "decline"}

    def test_at_least_one_demo_card_declines(self, contract: dict[str, Any]) -> None:
        """FR-024: the decline path has to be reachable deterministically."""
        assert "decline" in contract["components"]["schemas"]["DemoCardId"]["enum"]

    def test_the_contract_says_no_payment_processor_is_involved(
        self, contract: dict[str, Any]
    ) -> None:
        """Principle I stated where an API consumer will actually read it."""
        described = str(contract["paths"]["/orders"]["post"]["description"]).lower()

        assert "card number" in described
        assert "expiry" in described or "security code" in described
