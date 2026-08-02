"""The implemented app versus the published contract.

`contracts/openapi.yaml` is the source of truth; the app must not drift from it. This suite
compares the app's *generated* schema against that document — no database, no server, so it runs
on every push and fails the moment a route is added, renamed, or made public by accident.

It checks the operations actually implemented so far, and reports the rest as not-yet-built
rather than failing. Which is which comes from the app itself, so a newly registered router is
covered the moment it is wired in — there is no list here to forget to update.
"""

from __future__ import annotations

from typing import Any

import pytest

from dupermarket_api.config import Settings
from dupermarket_api.main import API_PREFIX, create_app

pytestmark = pytest.mark.contract

HTTP_METHODS = ("get", "post", "put", "patch", "delete")


@pytest.fixture(scope="module")
def app_spec() -> dict[str, Any]:
    app = create_app(
        Settings(
            database_url="postgresql+psycopg://u:p@localhost/none",
            firebase_project_id="contract-test",
        )
    )
    return app.openapi()


@pytest.fixture(scope="module")
def implemented(app_spec: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Implemented operations keyed by operationId, with the API prefix stripped."""
    out: dict[str, dict[str, Any]] = {}
    for path, item in app_spec["paths"].items():
        for method, op in item.items():
            if method not in HTTP_METHODS:
                continue
            op_id = op.get("operationId")
            if op_id:
                out[op_id] = {
                    "path": path.removeprefix(API_PREFIX),
                    "method": method,
                    "op": op,
                }
    return out


def test_at_least_one_operation_is_implemented(implemented: dict[str, Any]) -> None:
    # Guards against the whole suite passing vacuously if router registration breaks.
    assert implemented, "no operations found; routers are not registered"


def test_every_implemented_operation_exists_in_the_contract(
    implemented: dict[str, Any], operations: list[dict[str, Any]]
) -> None:
    """An endpoint the contract does not declare is undocumented API surface."""
    declared = {op["operation_id"] for op in operations}
    undeclared = sorted(set(implemented) - declared)
    assert not undeclared, (
        f"operations exist in the app but not in contracts/openapi.yaml: {undeclared}. "
        "Update the contract first — it is what the contract tests are generated from."
    )


def test_implemented_paths_match_the_contract_exactly(
    implemented: dict[str, Any], operations: list[dict[str, Any]]
) -> None:
    """A path that differs by a parameter name is a different URL to every client."""
    by_id = {op["operation_id"]: op for op in operations}
    mismatches = [
        f"{op_id}: app has {impl['path']}, contract declares {by_id[op_id]['path']}"
        for op_id, impl in implemented.items()
        if op_id in by_id and impl["path"] != by_id[op_id]["path"]
    ]
    assert not mismatches, mismatches


def test_implemented_methods_match_the_contract(
    implemented: dict[str, Any], operations: list[dict[str, Any]]
) -> None:
    by_id = {op["operation_id"]: op for op in operations}
    mismatches = [
        f"{op_id}: app uses {impl['method'].upper()}, contract declares "
        f"{by_id[op_id]['method'].upper()}"
        for op_id, impl in implemented.items()
        if op_id in by_id and impl["method"] != by_id[op_id]["method"]
    ]
    assert not mismatches, mismatches


def test_public_operations_are_the_same_set_in_both(
    implemented: dict[str, Any], operations: list[dict[str, Any]]
) -> None:
    """FR-010, FR-013: accidentally publishing an endpoint is the expensive mistake here.

    An operation is public in the app when it has no security requirement on it. The contract
    declares public operations with an explicit empty `security: []`.
    """
    contract_public = {op["operation_id"] for op in operations if op["public"]}
    app_public = {op_id for op_id, impl in implemented.items() if not impl["op"].get("security")}

    became_public = sorted(app_public - contract_public)
    became_private = sorted((set(implemented) & contract_public) - app_public)

    assert not became_public, (
        f"implemented but NOT requiring authentication, while the contract says they should: "
        f"{became_public}"
    )
    assert not became_private, (
        f"require authentication in the app but the contract declares them public: {became_private}"
    )


def test_no_implemented_request_body_accepts_payment_card_data(implemented: dict[str, Any]) -> None:
    """Principle I, checked against the real app rather than only the document."""
    forbidden = ("card_number", "cardnumber", "cvv", "cvc", "security_code", "expiry", "pan")
    offenders = [
        f"{op_id}:{field}"
        for op_id, impl in implemented.items()
        for field in _request_body_fields(impl["op"])
        if any(f in field.lower() for f in forbidden)
    ]
    assert not offenders, f"payment card fields in implemented request bodies: {offenders}"


def _request_body_fields(op: dict[str, Any]) -> list[str]:
    body = op.get("requestBody", {})
    fields: list[str] = []
    for media in body.get("content", {}).values():
        schema = media.get("schema", {})
        fields.extend(schema.get("properties", {}).keys())
    return fields


def test_coverage_progress_is_reported(
    implemented: dict[str, Any], operations: list[dict[str, Any]]
) -> None:
    """Not an assertion about completeness — a visible count, so progress is not guessed."""
    total = len(operations)
    done = len(set(implemented) & {op["operation_id"] for op in operations})
    print(f"\ncontract operations implemented: {done}/{total}")
    assert done <= total
