"""Contract tests that run against the OpenAPI document itself.

These need no server, no database, and no application code, so they run from the moment the
contract exists. They assert the constitutional properties of the API surface — the ones that
are cheap to state and easy to erode:

* no payment card field anywhere (Principle I)
* every non-public operation requires authentication (FR-013)
* catalogue reads are the *only* public operations (FR-010)
* another user's resource returns 404, never 403 (FR-013, FR-032)

The behavioural half of the contract suite — actually calling each endpoint and validating the
response — lands with ``/speckit-implement`` (tasks T038, T060, T070, T094, T102, T109, T110,
T124). These tests are the half that can be true today, and they are the half most likely to be
quietly violated by a future edit.
"""

from __future__ import annotations

import re
from typing import Any

import pytest

pytestmark = pytest.mark.contract


# Field names that only exist to carry a real payment instrument.
FORBIDDEN_FIELD_PATTERN = re.compile(
    r"(card_?number|cardnum|\bpan\b|cvv|cvc|\bcsc\b|security_?code"
    r"|expiry|exp_?month|exp_?year|cardholder|card_?holder)",
    re.IGNORECASE,
)

# Operations that are legitimately unauthenticated (FR-010). Anything public and not on this
# list is a bug in the contract, not an omission from this list.
EXPECTED_PUBLIC_OPERATIONS = {
    "listCategories",
    "listProducts",
    "getProduct",
    "listReviews",
}


def _walk_schema_properties(node: Any, path: str = "") -> list[tuple[str, str]]:
    """Yield every (json-path, property-name) pair reachable in a schema fragment."""
    found: list[tuple[str, str]] = []
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "properties" and isinstance(value, dict):
                for prop_name, prop_schema in value.items():
                    found.append((f"{path}.{prop_name}", prop_name))
                    found.extend(_walk_schema_properties(prop_schema, f"{path}.{prop_name}"))
            else:
                found.extend(_walk_schema_properties(value, f"{path}.{key}"))
    elif isinstance(node, list):
        for i, item in enumerate(node):
            found.extend(_walk_schema_properties(item, f"{path}[{i}]"))
    return found


def test_contract_document_is_valid_openapi_31(contract: dict[str, Any]) -> None:
    """The contract is the input to every other contract test, so it must parse and validate."""
    validator = pytest.importorskip(
        "openapi_spec_validator", reason="openapi-spec-validator is required"
    )
    validator.validate(contract)
    assert contract["openapi"].startswith("3.1")


def test_no_payment_card_fields_anywhere(contract: dict[str, Any]) -> None:
    """FR-023: no input anywhere accepts payment card details (constitution Principle I).

    Walks every schema property in the document, not just request bodies — a card field on a
    *response* would mean the system stored one.
    """
    offenders = [
        f"{json_path} ({name})"
        for json_path, name in _walk_schema_properties(contract)
        if FORBIDDEN_FIELD_PATTERN.search(name)
    ]
    assert not offenders, (
        "payment card fields found in the API contract, violating the simulation "
        f"boundary: {offenders}"
    )


def test_checkout_accepts_only_a_demo_card_identifier(contract: dict[str, Any]) -> None:
    """FR-023, FR-024: checkout carries a demo card id and nothing else payment-related."""
    body = contract["paths"]["/orders"]["post"]["requestBody"]
    props = body["content"]["application/json"]["schema"]["properties"]

    assert "demo_card_id" in props, "checkout must identify the demo card"
    ref = props["demo_card_id"]["$ref"]
    enum = contract["components"]["schemas"][ref.rsplit("/", 1)[-1]]["enum"]

    assert "decline" in enum, "FR-024: a deterministic decline card must exist"
    assert all(not FORBIDDEN_FIELD_PATTERN.search(k) for k in props)


def test_declined_checkout_is_a_declared_outcome(contract: dict[str, Any]) -> None:
    """FR-025: the decline path is part of the contract, not an undocumented error."""
    responses = contract["paths"]["/orders"]["post"]["responses"]
    assert "402" in responses
    assert "decline" in responses["402"]["description"].lower()


def test_every_non_public_operation_requires_authentication(
    operations: list[dict[str, Any]],
) -> None:
    """FR-013: user-scoped resources are unreachable without a valid credential."""
    unsecured = [
        op["operation_id"]
        for op in operations
        if not op["public"] and "401" not in op["op"].get("responses", {})
    ]
    assert not unsecured, (
        f"operations missing a documented 401 response: {unsecured}. "
        "Every authenticated operation must declare how it rejects an anonymous caller."
    )


def test_only_catalogue_reads_are_public(operations: list[dict[str, Any]]) -> None:
    """FR-010: browsing needs no account — and nothing else may be public."""
    public = {op["operation_id"] for op in operations if op["public"]}
    assert public == EXPECTED_PUBLIC_OPERATIONS, (
        f"public operations changed. Expected {sorted(EXPECTED_PUBLIC_OPERATIONS)}, "
        f"found {sorted(public)}. Making an operation public is a security decision; "
        "update this test deliberately."
    )


def test_user_owned_resources_return_404_not_403(operations: list[dict[str, Any]]) -> None:
    """FR-013, FR-032: a 403 would confirm that another user's resource id is real."""
    offenders = [
        op["operation_id"]
        for op in operations
        if not op["public"] and "403" in op["op"].get("responses", {})
    ]
    assert not offenders, (
        f"operations declaring 403: {offenders}. Use 404 so the response does not reveal "
        "whether the resource exists."
    )


def test_order_response_exposes_tracking_for_on_device_computation(
    contract: dict[str, Any],
) -> None:
    """FR-036, FR-037: the server hands over origin, destination, and window — not a position."""
    tracking = contract["components"]["schemas"]["DeliveryTracking"]["properties"]
    for required in ("origin", "destination", "window_start", "window_end", "stages"):
        assert required in tracking

    flat = str(contract["components"]["schemas"])
    for leaked in ("parcel_position", "current_lat", "current_lng", "parcel_lat"):
        assert leaked not in flat, (
            f"{leaked} found in the contract. Parcel position is computed on the device "
            "(FR-037); the server must stay stateless with respect to it."
        )


def test_order_items_are_snapshots(contract: dict[str, Any]) -> None:
    """FR-027: an order line carries its own title, price, and image, not a live lookup."""
    props = contract["components"]["schemas"]["OrderItem"]["properties"]
    for snapshot_field in ("title", "unit_price", "image_url"):
        assert snapshot_field in props, (
            f"OrderItem.{snapshot_field} missing. Without it, a catalogue change would "
            "rewrite what a user sees they paid."
        )


def test_money_is_never_a_float(contract: dict[str, Any]) -> None:
    """Research D4: money is an integer count of minor units. Floats cannot represent 0.99."""
    money = contract["components"]["schemas"]["Money"]["properties"]
    assert money["amount_minor"]["type"] == "integer"

    for name, schema in contract["components"]["schemas"].items():
        for json_path, prop in _walk_schema_properties(schema, name):
            if prop in {"price", "total", "unit_price", "subtotal"} and isinstance(schema, dict):
                assert "number" not in str(json_path), (
                    f"{json_path} looks like a floating-point money field"
                )


def test_list_operations_are_keyset_paginated(operations: list[dict[str, Any]]) -> None:
    """FR-002: cursor paging is what keeps paging stable while the catalogue changes."""
    listers = [
        op
        for op in operations
        if op["method"] == "get"
        and op["operation_id"].startswith("list")
        and op["operation_id"] != "listCategories"  # the tree is returned whole
        and op["operation_id"] != "listAddresses"  # bounded, small, unpaginated by design
    ]
    assert listers, "expected paginated list operations in the contract"

    for op in listers:
        names = {
            p.get("name") or p.get("$ref", "").rsplit("/", 1)[-1]
            for p in op["op"].get("parameters", [])
        }
        assert "Cursor" in names or "cursor" in names, (
            f"{op['operation_id']} has no cursor parameter; offset paging would drop or "
            "duplicate products as the catalogue changes (FR-002)"
        )
