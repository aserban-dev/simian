"""Category tree. Public — browsing needs no account (FR-010)."""

from __future__ import annotations

from fastapi import APIRouter

from ..deps import DbDep, SettingsDep
from ..models import Category
from ..schemas.catalogue import Category as CategorySchema
from ..schemas.catalogue import CategoryList
from ..services import catalogue
from ..services.presentation import cdn_url, localise

router = APIRouter(tags=["catalogue"])


def _to_schema(node: Category, *, locale: str, cdn_base_url: str) -> CategorySchema:
    return CategorySchema(
        id=node.id,
        slug=node.slug,
        name=localise(node.name, locale),
        image_url=cdn_url(cdn_base_url, node.image_url) if node.image_url else None,
        sort_order=node.sort_order,
        children=[
            _to_schema(child, locale=locale, cdn_base_url=cdn_base_url) for child in node.children
        ],
    )


@router.get(
    "/categories",
    response_model=CategoryList,
    summary="Category tree",
    operation_id="listCategories",
)
def list_categories(session: DbDep, settings: SettingsDep, locale: str = "en") -> CategoryList:
    """Whole tree, nested. Public (FR-001, FR-010)."""
    roots = catalogue.category_tree(session)
    return CategoryList(
        items=[
            _to_schema(root, locale=locale, cdn_base_url=settings.r2_public_base_url)
            for root in roots
        ]
    )
