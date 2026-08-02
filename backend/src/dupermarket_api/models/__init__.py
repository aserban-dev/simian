"""SQLAlchemy models. Importing this package registers every table on `Base.metadata`."""

from .base import Base
from .catalogue import Category, Product, ProductImage, Review
from .identity import Address, AppUser, Device, WishlistItem
from .orders import WRITE_ONCE_TRIGGER_SQL, Order, OrderItem

__all__ = [
    "WRITE_ONCE_TRIGGER_SQL",
    "Address",
    "AppUser",
    "Base",
    "Category",
    "Device",
    "Order",
    "OrderItem",
    "Product",
    "ProductImage",
    "Review",
    "WishlistItem",
]
