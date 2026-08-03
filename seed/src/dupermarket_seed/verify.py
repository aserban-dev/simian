"""Post-run assertions (T151).

FR-074: every product ends the run with at least one image, and every stored image reference
resolves. **A run that violates either must fail loudly** — which here means a non-zero exit
code and a list of what is wrong, not a warning in a log nobody reads.

This is the seed pipeline's equivalent of the traceability gate: the pipeline can succeed at
every individual step and still leave a catalogue with holes in it, and the only way to know is
to look afterwards.
"""

from __future__ import annotations

import sys
from collections.abc import Callable, Iterable
from dataclasses import dataclass, field

EXIT_OK = 0
EXIT_FAILED = 1


@dataclass(frozen=True, slots=True)
class ImageRef:
    """A stored image reference, as `verify` needs to see it."""

    product_id: str
    cdn_path: str
    sort_order: int = 0


@dataclass
class VerificationReport:
    products_without_images: list[str] = field(default_factory=list)
    unresolvable_paths: list[str] = field(default_factory=list)
    duplicate_sort_orders: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not (
            self.products_without_images or self.unresolvable_paths or self.duplicate_sort_orders
        )

    @property
    def exit_code(self) -> int:
        return EXIT_OK if self.ok else EXIT_FAILED

    def lines(self) -> list[str]:
        """Human-readable findings, most consequential first."""
        out: list[str] = []
        if self.products_without_images:
            out.append(
                f"{len(self.products_without_images)} product(s) have no image (FR-074): "
                + ", ".join(self.products_without_images[:10])
                + (" …" if len(self.products_without_images) > 10 else "")
            )
        if self.unresolvable_paths:
            out.append(
                f"{len(self.unresolvable_paths)} image path(s) do not resolve (FR-074): "
                + ", ".join(self.unresolvable_paths[:10])
                + (" …" if len(self.unresolvable_paths) > 10 else "")
            )
        if self.duplicate_sort_orders:
            out.append(
                "product(s) with a repeated image sort order: "
                + ", ".join(self.duplicate_sort_orders[:10])
            )
        if not out:
            out.append("seed verification passed")
        return out


def verify(
    product_ids: Iterable[str],
    images: Iterable[ImageRef],
    *,
    resolves: Callable[[str], bool],
) -> VerificationReport:
    """Check a completed seed run.

    `resolves` is injected — an HTTP HEAD in production, a set membership in a test. The
    resolution check is the expensive half and the half most worth faking, and injecting it
    keeps this function a pure decision.
    """
    report = VerificationReport()

    by_product: dict[str, list[ImageRef]] = {}
    for image in images:
        by_product.setdefault(image.product_id, []).append(image)

    for product_id in product_ids:
        if not by_product.get(product_id):
            report.products_without_images.append(product_id)

    for product_id, refs in by_product.items():
        orders = [ref.sort_order for ref in refs]
        if len(orders) != len(set(orders)):
            # Two images claiming position 0 means the "primary" image is whichever the database
            # happens to return first — a catalogue that renders differently on each read.
            report.duplicate_sort_orders.append(product_id)

    for image in images:
        if not resolves(image.cdn_path):
            report.unresolvable_paths.append(image.cdn_path)

    return report


def main(report: VerificationReport, *, stream: object = None) -> int:
    """Print the findings and return the exit code. Kept separate so `verify` stays pure."""
    out = stream or sys.stdout
    for line in report.lines():
        print(line, file=out)  # type: ignore[arg-type]
    return report.exit_code
