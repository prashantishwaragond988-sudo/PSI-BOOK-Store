"""Blueprint registration for modular backend routes."""

from __future__ import annotations

from flask import Flask

from routes.admin_routes import admin_bp
from routes.auth_routes import auth_bp
from routes.delivery_routes import delivery_bp
from routes.shop_routes import shop_bp
from routes.user_routes import user_bp

# Default footprint keeps the old admin-only behaviour.
DEFAULT_INCLUDE = ("auth", "admin")


def register_routes(app: Flask, include: tuple | list | None = None) -> None:
    include = include or DEFAULT_INCLUDE
    mapping = {
        "auth": auth_bp,
        "admin": admin_bp,
        "shop": shop_bp,
        "user": user_bp,
        "delivery": delivery_bp,
    }

    for key in include:
        key = str(key or "").lower()
        if key not in mapping:
            raise ValueError(f"Unknown blueprint '{key}'")
        app.register_blueprint(mapping[key])


def register_extended_routes(app: Flask) -> None:
    """Backward compatibility wrapper."""
    register_routes(app, include=DEFAULT_INCLUDE)
