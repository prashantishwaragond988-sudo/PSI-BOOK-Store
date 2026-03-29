"""HTTP helper utilities for hybrid HTML+JSON endpoints."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict

from flask import Request


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_email(value: str) -> str:
    return (value or "").strip().lower()


def normalize_phone(value: str) -> str:
    return (
        (value or "")
        .replace("+91", "")
        .replace(" ", "")
        .replace("-", "")
        .replace("(", "")
        .replace(")", "")
        .lstrip("0")
    )


def to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def request_data(request: Request) -> Dict[str, Any]:
    if request.is_json:
        return request.get_json(silent=True) or {}
    if request.form:
        return request.form.to_dict(flat=True)
    return {}


def wants_json(request: Request) -> bool:
    if request.is_json:
        return True
    accept = (request.headers.get("Accept") or "").lower()
    if "application/json" in accept:
        return True
    if (request.args.get("format") or "").lower() == "json":
        return True
    return (request.headers.get("X-Requested-With") or "").lower() == "xmlhttprequest"
