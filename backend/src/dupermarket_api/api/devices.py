"""Push token registration (T127).

One operation, and the whole of its interest is in the word **reassigns**.

`device.fcm_token` is unique across all users, not per user. A shared or resold phone that signs
out and back in as somebody else would otherwise keep two rows for one token, and FCM would
deliver the first user's order updates to the second — a privacy failure that looks like a
harmless duplicate row right up until it happens. Registering a token therefore *moves* it to
the caller rather than adding a second claim on it.

The server sends no per-stage push (research D6): delivery notifications are scheduled on-device
from the immutable timestamps. Tokens exist here for promotional sends and offline catch-up.
"""

from __future__ import annotations

from typing import Annotated, Literal

from fastapi import APIRouter, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import select

from ..auth.user_provisioning import CurrentUser
from ..deps import ClockDep, DbDep
from ..models import Device

router = APIRouter(tags=["devices"])


class DeviceRegistration(BaseModel):
    fcm_token: Annotated[str, Field(min_length=1)]
    platform: Literal["ios", "android"]


@router.post(
    "/me/devices",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Register a push notification token",
    operation_id="registerDevice",
)
def register_device(
    body: DeviceRegistration,
    user: CurrentUser,
    session: DbDep,
    clock: ClockDep,
) -> Response:
    """Upsert on the token, reassigning it across users when needed.

    Deliberately not `INSERT ... ON CONFLICT`: the row is looked up first because reassignment
    has to update `user_id`, and spelling that out is clearer than an upsert clause that quietly
    changes ownership. The unique index on `fcm_token` is what guarantees there is at most one
    row to find.

    Always 204, whether the token was new, refreshed, or taken from another account. A client
    re-registers on every launch and on every token rotation; distinguishing those cases would
    give it three responses to handle and nothing to do differently with any of them.
    """
    existing = session.scalar(select(Device).where(Device.fcm_token == body.fcm_token))

    if existing is None:
        session.add(
            Device(
                user_id=user.id,
                fcm_token=body.fcm_token,
                platform=body.platform,
                last_seen_at=clock.now(),
            )
        )
    else:
        # The reassignment. If this token belonged to another user, it is this user's now.
        existing.user_id = user.id
        existing.platform = body.platform
        existing.last_seen_at = clock.now()

    session.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
