"""Error responses.

Principle IV: a raw error never reaches the UI. Every failure leaves this application as an
RFC 9457 problem document whose `detail` is safe to show a user, with `retryable` telling the
client whether offering a retry makes sense (FR-060).

FR-013 also lives here: a resource that exists but belongs to someone else is reported as 404,
never 403, because a 403 confirms the identifier is real.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

logger = logging.getLogger(__name__)

PROBLEM_CONTENT_TYPE = "application/problem+json"
_PROBLEM_BASE = "https://dupermarket.example/problems"


class AppError(Exception):
    """Base for errors that are safe to surface. Anything else becomes a generic 500."""

    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    title: str = "Something went wrong"
    problem_type: str = "internal"
    retryable: bool = False

    def __init__(self, detail: str | None = None, **extra: Any) -> None:
        super().__init__(detail or self.title)
        self.detail = detail
        self.extra = extra


class NotFound(AppError):
    """Also used when a resource belongs to another user — deliberately indistinguishable."""

    status_code = status.HTTP_404_NOT_FOUND
    title = "Not found"
    problem_type = "not-found"


class BadCursor(AppError):
    """A page cursor that cannot be decoded, or was minted for a different sort order.

    A 400 with a recoverable message rather than a 500: the client's fix is to restart paging,
    which it can do without the user noticing (FR-060).
    """

    status_code = status.HTTP_400_BAD_REQUEST
    title = "That page link is no longer valid"
    problem_type = "bad-cursor"


class Unauthorized(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    title = "Sign in required"
    problem_type = "unauthorized"


class Conflict(AppError):
    status_code = status.HTTP_409_CONFLICT
    title = "Conflict"
    problem_type = "conflict"


class UnprocessableAddress(AppError):
    """FR-043: an address that cannot be resolved to coordinates is not saved at all."""

    # Starlette renamed this constant; the wire status is 422 either way, which is what
    # contracts/openapi.yaml declares for an unresolvable address.
    status_code = 422
    title = "We couldn't find that address"
    problem_type = "address-unresolvable"


class PaymentDeclined(AppError):
    """FR-024/FR-025: the simulated decline path. No payment was attempted."""

    status_code = status.HTTP_402_PAYMENT_REQUIRED
    title = "That card was declined"
    problem_type = "card-declined"
    retryable = True


def problem_response(
    *,
    status_code: int,
    title: str,
    problem_type: str,
    detail: str | None = None,
    retryable: bool = False,
    instance: str | None = None,
) -> JSONResponse:
    body: dict[str, Any] = {
        "type": f"{_PROBLEM_BASE}/{problem_type}",
        "title": title,
        "status": status_code,
        "retryable": retryable,
    }
    if detail:
        body["detail"] = detail
    if instance:
        body["instance"] = instance
    return JSONResponse(status_code=status_code, content=body, media_type=PROBLEM_CONTENT_TYPE)


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(request: Request, exc: AppError) -> JSONResponse:
        return problem_response(
            status_code=exc.status_code,
            title=exc.title,
            problem_type=exc.problem_type,
            detail=exc.detail,
            retryable=exc.retryable,
            instance=str(request.url.path),
        )

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        # Pydantic's raw error list leaks internal field paths and input values. Summarise.
        fields = sorted({str(e["loc"][-1]) for e in exc.errors() if e.get("loc")})
        detail = (
            f"Check these fields: {', '.join(fields)}." if fields else "The request was malformed."
        )
        return problem_response(
            status_code=status.HTTP_400_BAD_REQUEST,
            title="That request didn't look right",
            problem_type="bad-request",
            detail=detail,
            instance=str(request.url.path),
        )

    @app.exception_handler(SQLAlchemyError)
    async def _db_error(request: Request, exc: SQLAlchemyError) -> JSONResponse:
        # A driver error string can contain SQL, table names, and occasionally row data.
        logger.exception("database error on %s", request.url.path)
        return problem_response(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            title="The shop is having a moment",
            problem_type="service-unavailable",
            detail="We couldn't reach our data right now. Please try again.",
            retryable=True,
            instance=str(request.url.path),
        )

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("unhandled error on %s", request.url.path)
        return problem_response(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            title="Something went wrong on our side",
            problem_type="internal",
            detail="Please try again in a moment.",
            retryable=True,
            instance=str(request.url.path),
        )
