"""The authenticated user's own profile (T065).

Three operations, all resolved from the credential rather than from a client-supplied id — which
is what makes FR-013 structural here rather than a check somebody has to remember: there is no
identifier to tamper with, so no request can address another user's profile.

`DELETE /me` is a *request*, not an erasure — see `request_account_deletion` below.
"""

from __future__ import annotations

from fastapi import APIRouter, Response, status
from sqlalchemy import delete

from ..auth.user_provisioning import CurrentUser
from ..deps import ClockDep, DbDep
from ..models import Device
from ..schemas.user import User as UserSchema
from ..schemas.user import UserUpdate

router = APIRouter(tags=["profile"])


@router.get(
    "/me",
    response_model=UserSchema,
    summary="The authenticated user's profile",
    operation_id="getMe",
)
def get_me(user: CurrentUser) -> UserSchema:
    """FR-014: the row is created by the `CurrentUser` dependency on first call.

    There is deliberately no "register" step to reach before this works.
    """
    return UserSchema.model_validate(user)


@router.patch(
    "/me",
    response_model=UserSchema,
    summary="Update the profile",
    operation_id="updateMe",
)
def update_me(body: UserUpdate, user: CurrentUser, session: DbDep) -> UserSchema:
    """FR-046, FR-048, FR-049 for the overrides; FR-081 for the name.

    The two are updated by different rules on purpose, and the rules are opposites:

    * An override the client sends as null is **cleared** — that is how a user goes back to
      following their device language or currency.
    * A name the client sends as null, or empty, or does not send at all, changes **nothing**.
      Apple hands over the user's name once, at first authorisation, and never again; if a later
      nameless sign-in could clear it, the account would be permanently unnamed with no way to
      ask Apple for it a second time.
    """
    if body.was_provided("language_override"):
        user.language_override = body.language_override
    if body.was_provided("currency_override"):
        user.currency_override = body.currency_override
    if body.was_provided("notification_prefs") and body.notification_prefs is not None:
        user.notification_prefs = body.notification_prefs

    # No `was_provided` check: for the name, "sent as null" and "not sent" are the same
    # non-event. Only a non-empty value is a change (FR-081).
    if body.display_name:
        user.display_name = body.display_name

    session.flush()
    return UserSchema.model_validate(user)


@router.delete(
    "/me",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Request account deletion",
    operation_id="requestAccountDeletion",
)
def request_account_deletion(user: CurrentUser, session: DbDep, clock: ClockDep) -> Response:
    """FR-017 — accepted, recorded, and acted on only as far as push.

    202 rather than 204 because nothing has been deleted yet: v1 processes the request manually.
    What *is* immediate is device deregistration, in the same transaction as the timestamp, so
    there is no window in which the account is marked for deletion and can still be pushed to.

    An order mid-delivery does not block this. FR-017 calls that case out explicitly: the request
    is accepted, the order completes, and it stays readable — so there is nothing to check for
    and nothing to reject.

    Re-requesting keeps the original timestamp: the first request is the one the user made, and
    a later call must not quietly restart whatever retention clock it started.
    """
    if user.deletion_requested_at is None:
        user.deletion_requested_at = clock.now()

    # Scoped to this user, and re-run on every request so a device registered between two
    # requests cannot survive in the gap.
    session.execute(delete(Device).where(Device.user_id == user.id))
    session.flush()

    return Response(status_code=status.HTTP_202_ACCEPTED)
