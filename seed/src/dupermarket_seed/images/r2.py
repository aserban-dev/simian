"""Uploading to R2, idempotently (T150).

FR-072 and research D9: the upload is skipped when the **content hash matches** what is already
recorded — not when the key exists.

That distinction is the whole design. Keying on existence is cheaper and wrong in both
directions: it never picks up a corrected source image, and it cannot tell "already uploaded
correctly" from "uploaded broken last time and still broken". Hashing the processed bytes makes
a re-run cost zero uploads while a genuinely changed image still gets replaced — which is
exactly what SC-012 measures.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol

CONTENT_TYPE = "image/webp"

# A year. These objects are addressed by a path that includes the product id and index, and the
# content behind a path only changes when the source image does — at which point the CDN is
# purged by the upload itself.
CACHE_CONTROL = "public, max-age=31536000, immutable"


class ObjectStore(Protocol):
    """The slice of an S3-compatible client this needs.

    An interface rather than boto3 directly, so the idempotency rule is testable without a
    bucket, a credential, or a network.
    """

    def put_object(self, *, Bucket: str, Key: str, Body: bytes, **kwargs: object) -> object: ...


@dataclass(frozen=True, slots=True)
class UploadResult:
    uploaded: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)

    @property
    def upload_count(self) -> int:
        return len(self.uploaded)

    @property
    def skip_count(self) -> int:
        return len(self.skipped)


class R2Uploader:
    """Uploads processed images, skipping those whose hash is unchanged."""

    def __init__(self, store: ObjectStore, bucket: str) -> None:
        self._store = store
        self._bucket = bucket
        self._result = UploadResult()

    @property
    def result(self) -> UploadResult:
        return self._result

    def upload_if_changed(
        self,
        *,
        key: str,
        body: bytes,
        content_sha256: str,
        known_sha256: str | None,
    ) -> bool:
        """Upload unless `known_sha256` already matches. Returns whether bytes were sent.

        `known_sha256` comes from the `product_image` row, so the comparison is against what the
        database believes is published — not against the bucket. Trusting the bucket would mean
        a listing call per image, which is the cost this design exists to avoid.
        """
        if known_sha256 is not None and known_sha256 == content_sha256:
            self._result.skipped.append(key)
            return False

        self._store.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=body,
            ContentType=CONTENT_TYPE,
            CacheControl=CACHE_CONTROL,
            Metadata={"sha256": content_sha256},
        )
        self._result.uploaded.append(key)
        return True


def public_url(base_url: str, key: str) -> str:
    """The URL the client will fetch. The backend stores paths and never proxies bytes."""
    return f"{base_url.rstrip('/')}/{key.lstrip('/')}"
