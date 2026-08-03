"""Image processing (T149).

Research D9: every image becomes WebP at two sizes — 300 px thumbnail, 1200 px detail — with
EXIF stripped and a SHA-256 taken of the processed bytes.

Two of those are not cosmetic:

* **EXIF is stripped** because stock photography routinely carries GPS coordinates and camera
  serial numbers, and re-hosting someone's location data is not something to do by accident.
* **The hash is of the *processed* bytes**, not the source URL. That is what makes idempotency
  work in the direction FR-072 actually needs: a source image that changed is re-uploaded, and
  one that did not is skipped, even if the URL is identical either way.
"""

from __future__ import annotations

import hashlib
import io
from dataclasses import dataclass

from PIL import Image

THUMBNAIL_PX = 300
DETAIL_PX = 1200
WEBP_QUALITY = 82


@dataclass(frozen=True, slots=True)
class ProcessedImage:
    """Processed bytes and the hash that decides whether to upload them."""

    thumbnail: bytes
    detail: bytes
    content_sha256: str
    width: int
    height: int


def sha256_of(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _fit(image: Image.Image, longest_edge: int) -> Image.Image:
    """Scale so the longest edge is `longest_edge`, preserving aspect ratio.

    Never upscales: enlarging a small source produces a blurry image that looks worse than the
    original at its own size, and the client renders whatever it is given.
    """
    width, height = image.size
    longest = max(width, height)
    if longest <= longest_edge:
        return image.copy()

    scale = longest_edge / longest
    size = (max(1, round(width * scale)), max(1, round(height * scale)))
    return image.resize(size, Image.LANCZOS)


def _to_webp(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    # `save` on an image built from `_strip_metadata` carries no EXIF, so nothing to exclude
    # explicitly — but the quality and method are pinned so the bytes are reproducible, which
    # is what makes the content hash stable across runs (FR-072).
    image.save(buffer, format="WEBP", quality=WEBP_QUALITY, method=4)
    return buffer.getvalue()


def _strip_metadata(image: Image.Image) -> Image.Image:
    """Rebuild the image from its pixels alone.

    Copying the data into a fresh `Image` is what actually drops EXIF, ICC profiles and any
    other ancillary chunks — `save(exif=None)` leaves several of them in place.
    """
    converted = image.convert("RGB")
    clean = Image.new("RGB", converted.size)
    clean.putdata(list(converted.getdata()))
    return clean


def process(raw: bytes) -> ProcessedImage:
    """Source bytes to two WebP renditions plus their hash.

    The hash covers the detail rendition only. Both are produced from the same source by
    deterministic steps, so one hash identifies the pair — and hashing both would double the
    work to answer the same question.
    """
    with Image.open(io.BytesIO(raw)) as opened:
        clean = _strip_metadata(opened)

    detail_image = _fit(clean, DETAIL_PX)
    thumbnail_image = _fit(clean, THUMBNAIL_PX)

    detail = _to_webp(detail_image)
    thumbnail = _to_webp(thumbnail_image)

    return ProcessedImage(
        thumbnail=thumbnail,
        detail=detail,
        content_sha256=sha256_of(detail),
        width=detail_image.width,
        height=detail_image.height,
    )


def cdn_path_for(product_id: str, index: int) -> str:
    """Research D9's layout: `products/{product_id}/{index}.webp`.

    Index-based rather than hash-based so a product's images have a stable order and the primary
    one is always `0` — the client picks `sort_order` 0 for the thumbnail.
    """
    return f"products/{product_id}/{index}.webp"


def thumbnail_path_for(product_id: str, index: int) -> str:
    return f"products/{product_id}/{index}_thumb.webp"
