"""Typed mapping helpers for API payload validation."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict


@dataclass
class LoginPayload:
    email: str
    password: str
    role: str

    @classmethod
    def from_dict(cls, data: Dict[str, Any], role: str) -> "LoginPayload":
        return cls(
            email=str(data.get("email") or "").strip().lower(),
            password=str(data.get("password") or ""),
            role=role,
        )


@dataclass
class RegisterPayload:
    name: str
    email: str
    phone: str
    password: str
    role: str

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "RegisterPayload":
        return cls(
            name=str(data.get("name") or "").strip(),
            email=str(data.get("email") or "").strip().lower(),
            phone=str(data.get("phone") or "").strip(),
            password=str(data.get("password") or ""),
            role=str(data.get("role") or "CUSTOMER").strip().upper(),
        )
