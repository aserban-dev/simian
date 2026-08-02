#!/usr/bin/env python3
"""Verification gate for the Shopping App Simulator.

Three checks, all of them enforcing rules the constitution states but that nothing else
can hold true on its own:

1. **Requirement -> task coverage.** Every ``FR-xxx`` in ``spec.md`` must be referenced by at
   least one task in ``tasks.md``. A requirement nobody planned for is a requirement nobody
   will build.

2. **Requirement -> test coverage** (constitution Principle II, SC-005). Every ``FR-xxx``
   must be referenced by at least one test, via a marker in the test name or docstring::

       def test_declined_card_leaves_cart_intact():
           '''FR-025: a declined checkout creates no order and preserves the cart.'''

   This check is scoped to work that is **done**. A requirement becomes *due* as soon as any
   task referencing it is marked ``[X]`` in ``tasks.md``; until then it is *pending* and is
   reported but not enforced. Without that scoping the gate would fail continuously from the
   first commit of implementation to the last, which trains people to ignore it — and a gate
   everyone ignores is worse than no gate.

   ``--strict`` enforces every requirement regardless, which is what the final
   ``/speckit-verify`` run uses.

3. **Simulation boundary** (constitution Principle I, SC-013). Source is scanned for
   card-shaped literals, payment-card field names, and payment-processor imports. The demo
   card constants file is the single allowlisted location for a card-shaped literal, because
   the demo cards are cosmetic and have to render something.

Standard library only, so it runs anywhere Python does.

Exit codes: 0 all checks passed, 1 a check failed, 2 bad invocation.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_SPEC = "specs/001-shopping-app-simulator/spec.md"
DEFAULT_TASKS = "specs/001-shopping-app-simulator/tasks.md"

# Where tests live. Missing directories are skipped, not an error.
DEFAULT_TEST_DIRS = [
    "backend/tests",
    "seed/tests",
    "mobile/test",
    "mobile/integration_test",
]

# Where product code lives. The boundary scan covers these and nothing else — scanning the
# specs would flag this file's own documentation of the patterns it forbids.
DEFAULT_SOURCE_DIRS = [
    "backend/src",
    "backend/alembic",
    "mobile/lib",
    "seed/src",
]

TEST_FILE_SUFFIXES = (".py", ".dart")
SOURCE_FILE_SUFFIXES = (".py", ".dart", ".sql", ".kt", ".swift")

FR_PATTERN = re.compile(r"\bFR-(\d{3})\b")

# A comment is where a plan lives, not where a test lives. Counting FR ids in comments lets a
# to-do list masquerade as coverage — which it did, on the first run of this script against the
# scaffolded harness. Markers must appear in executable context: a Python docstring, or a test
# description string such as testWidgets('FR-061: ...').
FULL_LINE_COMMENT = re.compile(r"^\s*(#|//|/\*|\*/|\*(?!\*))")

# --- Simulation boundary patterns -------------------------------------------------------

# 13-19 digits, optionally split by spaces or hyphens. Deliberately broad.
CARD_LITERAL = re.compile(r"(?<![\d.])(?:\d[ -]?){12,18}\d(?![\d.])")

# Field and variable names that only exist to hold real card data.
CARD_FIELD_NAMES = re.compile(
    r"\b("
    r"card_?number|cardnum|pan\b|"
    r"cvv|cvc|csc\b|security_?code|"
    r"expiry_?(month|year|date)|exp_?(month|year)|"
    r"cardholder_?name|card_?holder"
    r")\b",
    re.IGNORECASE,
)

PAYMENT_PROCESSOR_IMPORT = re.compile(
    r"^\s*(?:import|from|require\(|export .* from)\s+.*\b"
    r"(stripe|braintree|adyen|paypal|squareup|square|checkout_?com|worldpay|klarna)\b",
    re.IGNORECASE | re.MULTILINE,
)

# The one file allowed to contain a card-shaped literal: the built-in cosmetic demo cards
# have to display something. Everything else is a violation.
CARD_LITERAL_ALLOWLIST = {
    "mobile/lib/features/checkout/demo_cards.dart",
}


@dataclass
class Result:
    name: str
    passed: bool
    lines: list[str] = field(default_factory=list)
    bootstrap: bool = False


def _iter_files(root: Path, dirs: list[str], suffixes: tuple[str, ...]) -> list[Path]:
    out: list[Path] = []
    for d in dirs:
        base = root / d
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*")):
            if p.is_file() and p.suffix in suffixes:
                out.append(p)
    return out


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _strip_comment_lines(text: str) -> str:
    """Drop whole-line comments so a planning note cannot be mistaken for coverage."""
    return "\n".join(
        line for line in text.splitlines() if not FULL_LINE_COMMENT.match(line)
    )


def parse_requirements(spec_path: Path) -> list[str]:
    """Return every FR id *defined* in the spec, in order, deduplicated.

    A definition is a bullet of the form ``- **FR-001**: ...``. References elsewhere in the
    document do not count, so a requirement mentioned in prose but never stated is not
    silently treated as covered.
    """
    definition = re.compile(r"^\s*[-*]\s+\*\*FR-(\d{3})\*\*\s*:", re.MULTILINE)
    ids = [f"FR-{n}" for n in definition.findall(_read(spec_path))]
    seen: set[str] = set()
    ordered: list[str] = []
    for fr in ids:
        if fr not in seen:
            seen.add(fr)
            ordered.append(fr)
    return ordered


COMPLETED_TASK = re.compile(r"^\s*-\s*\[[xX]\]\s*(T\d{3}.*)$", re.M)


def requirements_due(tasks_path: Path) -> set[str]:
    """Requirements referenced by at least one completed task.

    These are the ones a test must already exist for. Everything else is future work.
    """
    if not tasks_path.is_file():
        return set()
    due: set[str] = set()
    for line in COMPLETED_TASK.findall(_read(tasks_path)):
        due.update(f"FR-{n}" for n in FR_PATTERN.findall(line))
    return due


def check_task_coverage(requirements: list[str], tasks_path: Path) -> Result:
    if not tasks_path.is_file():
        return Result(
            "requirement -> task coverage",
            False,
            [f"tasks file not found: {tasks_path}"],
        )
    referenced = set(f"FR-{n}" for n in FR_PATTERN.findall(_read(tasks_path)))
    missing = [fr for fr in requirements if fr not in referenced]
    if missing:
        return Result(
            "requirement -> task coverage",
            False,
            [f"{len(missing)} requirement(s) have no task:", "  " + ", ".join(missing)],
        )
    return Result(
        "requirement -> task coverage",
        True,
        [f"all {len(requirements)} requirements referenced by at least one task"],
    )


def check_test_coverage(
    requirements: list[str],
    root: Path,
    test_dirs: list[str],
    due: set[str],
    strict: bool,
) -> Result:
    test_files = _iter_files(root, test_dirs, TEST_FILE_SUFFIXES)

    covered: dict[str, list[str]] = {}
    for path in test_files:
        rel = path.relative_to(root).as_posix()
        for n in set(FR_PATTERN.findall(_strip_comment_lines(_read(path)))):
            covered.setdefault(f"FR-{n}", []).append(rel)

    hit = sum(1 for fr in requirements if fr in covered)
    enforced = set(requirements) if strict else due
    pending = [fr for fr in requirements if fr not in enforced]
    missing = [fr for fr in requirements if fr in enforced and fr not in covered]

    lines = [
        f"{hit}/{len(requirements)} requirements have a test "
        f"across {len(test_files)} test file(s)"
    ]
    if strict:
        lines.append("strict: every requirement is enforced")
    else:
        lines.append(
            f"enforcing {len(enforced)} requirement(s) due from completed tasks; "
            f"{len(pending)} still pending implementation"
        )

    if missing:
        lines.append(f"{len(missing)} DUE requirement(s) have no test:")
        lines.append("  " + ", ".join(missing))
        lines.append("  A task is not done while the tests for its requirements are absent.")
        return Result("requirement -> test coverage", False, lines)

    return Result("requirement -> test coverage", True, lines, bootstrap=not enforced)


def check_simulation_boundary(root: Path, source_dirs: list[str]) -> Result:
    files = _iter_files(root, source_dirs, SOURCE_FILE_SUFFIXES)
    violations: list[str] = []

    for path in files:
        rel = path.relative_to(root).as_posix()
        text = _read(path)

        for match in PAYMENT_PROCESSOR_IMPORT.finditer(text):
            line_no = text[: match.start()].count("\n") + 1
            violations.append(
                f"{rel}:{line_no}: payment processor import — {match.group(0).strip()!r}"
            )

        for match in CARD_FIELD_NAMES.finditer(text):
            line_no = text[: match.start()].count("\n") + 1
            violations.append(
                f"{rel}:{line_no}: payment card field name — {match.group(0)!r}"
            )

        if rel not in CARD_LITERAL_ALLOWLIST:
            for match in CARD_LITERAL.finditer(text):
                digits = re.sub(r"\D", "", match.group(0))
                if len(digits) < 13:
                    continue
                line_no = text[: match.start()].count("\n") + 1
                violations.append(
                    f"{rel}:{line_no}: card-shaped literal ({len(digits)} digits). "
                    f"Only {sorted(CARD_LITERAL_ALLOWLIST)[0]} may contain one."
                )

    if violations:
        return Result(
            "simulation boundary",
            False,
            ["constitution Principle I violated:", *(f"  {v}" for v in violations)],
        )

    scanned = f"{len(files)} source file(s)" if files else "no source files yet"
    return Result("simulation boundary", True, [f"clean — scanned {scanned}"])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Traceability and simulation-boundary gate.",
    )
    parser.add_argument("--spec", default=DEFAULT_SPEC, help="path to spec.md")
    parser.add_argument("--tasks", default=DEFAULT_TASKS, help="path to tasks.md")
    parser.add_argument(
        "--tests", nargs="*", default=DEFAULT_TEST_DIRS, help="test directories"
    )
    parser.add_argument(
        "--source", nargs="*", default=DEFAULT_SOURCE_DIRS, help="source directories"
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="enforce every requirement, not just those due from completed tasks",
    )
    args = parser.parse_args(argv)

    spec_path = REPO_ROOT / args.spec
    if not spec_path.is_file():
        print(f"error: spec not found: {spec_path}", file=sys.stderr)
        return 2

    requirements = parse_requirements(spec_path)
    if not requirements:
        print(f"error: no FR-xxx definitions found in {spec_path}", file=sys.stderr)
        return 2

    tasks_path = REPO_ROOT / args.tasks
    due = requirements_due(tasks_path)

    results = [
        check_task_coverage(requirements, tasks_path),
        check_test_coverage(requirements, REPO_ROOT, args.tests, due, args.strict),
        check_simulation_boundary(REPO_ROOT, args.source),
    ]

    print(f"Traceability gate — {len(requirements)} requirements in {args.spec}\n")
    failed = False
    for r in results:
        if not r.passed:
            mark, failed = "FAIL", True
        elif r.bootstrap:
            mark = "SKIP"
        else:
            mark = "PASS"
        print(f"[{mark}] {r.name}")
        for line in r.lines:
            print(f"       {line}")
        print()

    print("RESULT:", "FAIL" if failed else "PASS")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
