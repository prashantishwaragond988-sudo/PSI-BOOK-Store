"""Session and role authorization helpers."""

from __future__ import annotations

from functools import wraps
from typing import Callable

from flask import jsonify, redirect, request, session

from models.constants import ALL_ROLES
from utils.http import wants_json


def clear_role_session() -> None:
    session.pop("user_id", None)
    session.pop("role", None)


def set_role_session(user_id: str, role: str) -> None:
    session["user_id"] = user_id
    session["role"] = role


def current_role() -> str:
    return str(session.get("role") or "").strip().upper()


def current_user_id() -> str:
    return str(session.get("user_id") or "").strip()


def is_authenticated() -> bool:
    role = current_role()
    return bool(current_user_id()) and role in ALL_ROLES


def role_required(*allowed_roles: str) -> Callable:
    allowed = {str(role).strip().upper() for role in allowed_roles if str(role).strip()}

    def decorator(fn: Callable) -> Callable:
        @wraps(fn)
        def wrapped(*args, **kwargs):
            if not is_authenticated():
                if wants_json(request):
                    return jsonify({"error": "authentication required"}), 401
                return redirect("/login-selection")

            role = current_role()
            if allowed and role not in allowed:
                if wants_json(request):
                    return jsonify({"error": "forbidden", "role": role}), 403
                return redirect("/login-selection")
            return fn(*args, **kwargs)

        return wrapped

    return decorator
