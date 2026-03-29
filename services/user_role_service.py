"""Role-aware user management over Firestore users collection."""

from __future__ import annotations

import uuid
from typing import Dict, List, Optional, Tuple

from werkzeug.security import check_password_hash, generate_password_hash

from models.constants import (
    ALL_ROLES,
    ROLE_ADMIN,
    ROLE_CUSTOMER,
    ROLE_DELIVERY_AGENT,
    ROLE_SHOP_OWNER,
    USER_STATUS_ACTIVE,
)
from services.firestore_ctx import get_auth_client, get_db
from utils.http import normalize_email, normalize_phone, utc_now_iso


USERS_COLLECTION = "users"


def _users_ref():
    return get_db().collection(USERS_COLLECTION)


def _normalize_role(value: str) -> str:
    role = str(value or "").strip().upper()
    mapping = {
        "ADMIN": ROLE_ADMIN,
        "SUPERADMIN": ROLE_ADMIN,
        "OWNER": ROLE_SHOP_OWNER,
        "SHOP_OWNER": ROLE_SHOP_OWNER,
        "SELLER": ROLE_SHOP_OWNER,
        "USER": ROLE_CUSTOMER,
        "CUSTOMER": ROLE_CUSTOMER,
        "DELIVERY": ROLE_DELIVERY_AGENT,
        "DELIVERY_AGENT": ROLE_DELIVERY_AGENT,
        "AGENT": ROLE_DELIVERY_AGENT,
    }
    return mapping.get(role, role)


def _role_from_legacy_fields(payload: Dict) -> str:
    role = _normalize_role(payload.get("role"))
    if role in {ROLE_ADMIN, ROLE_SHOP_OWNER, ROLE_DELIVERY_AGENT}:
        return role

    is_admin = payload.get("is_admin")
    if is_admin in {1, True, "1"}:
        return ROLE_ADMIN

    global_role = _normalize_role(payload.get("global_role"))
    if global_role in ALL_ROLES:
        return global_role

    store_roles = payload.get("store_roles")
    if isinstance(store_roles, dict):
        for info in store_roles.values():
            role_value = ""
            is_active = True
            if isinstance(info, dict):
                role_value = info.get("role")
                is_active = info.get("active", True) is not False
            elif isinstance(info, str):
                role_value = info
            else:
                continue
            if _normalize_role(role_value) == ROLE_SHOP_OWNER and is_active:
                return ROLE_SHOP_OWNER
        # Legacy fallback: non-empty store_roles usually means owner mapping.
        if len(store_roles) > 0:
            return ROLE_SHOP_OWNER
    elif isinstance(store_roles, (list, tuple, set)) and len(store_roles) > 0:
        return ROLE_SHOP_OWNER

    if payload.get("is_owner") in {1, True, "1"}:
        return ROLE_SHOP_OWNER
    if payload.get("owner") in {1, True, "1"}:
        return ROLE_SHOP_OWNER

    for key in ["owners", "owner_stores", "owned_store_ids", "shop_ids", "store_ids"]:
        value = payload.get(key)
        if isinstance(value, (list, tuple, set)) and len(value) > 0:
            return ROLE_SHOP_OWNER

    if role in ALL_ROLES:
        return role

    return ROLE_CUSTOMER


def _doc_to_user(doc) -> Dict:
    payload = doc.to_dict() or {}
    payload.setdefault("user_id", doc.id)
    payload["user_id"] = str(payload.get("user_id") or doc.id)
    payload["email"] = normalize_email(payload.get("email") or "")
    payload["phone"] = normalize_phone(payload.get("phone") or payload.get("mobile") or "")
    payload["role"] = _role_from_legacy_fields(payload)
    payload["status"] = str(payload.get("status") or USER_STATUS_ACTIVE).upper()
    payload.setdefault("created_at", utc_now_iso())
    return payload


def get_user_by_id(user_id: str) -> Optional[Dict]:
    user_id = str(user_id or "").strip()
    if not user_id:
        return None
    snap = _users_ref().document(user_id).get()
    if snap.exists:
        return _doc_to_user(snap)

    # Backward compatibility: some legacy docs are keyed by email.
    by_email = get_user_by_email(user_id)
    return by_email


def get_user_by_email(email: str) -> Optional[Dict]:
    email = normalize_email(email)
    if not email:
        return None

    direct = _users_ref().document(email).get()
    if direct.exists:
        return _doc_to_user(direct)

    docs = _users_ref().where("email", "==", email).limit(1).stream()
    for doc in docs:
        return _doc_to_user(doc)
    return None


def get_user_by_phone(phone: str) -> Optional[Dict]:
    phone = normalize_phone(phone)
    if not phone:
        return None

    queries = [
        _users_ref().where("phone", "==", phone).limit(1).stream(),
        _users_ref().where("mobile", "==", phone).limit(1).stream(),
    ]
    for result in queries:
        for doc in result:
            return _doc_to_user(doc)
    return None


def list_users(role: str = "", status: str = "") -> List[Dict]:
    role = str(role or "").strip().upper()
    status = str(status or "").strip().upper()

    users: List[Dict] = []
    for doc in _users_ref().stream():
        row = _doc_to_user(doc)
        if role and row.get("role") != role:
            continue
        if status and row.get("status") != status:
            continue
        users.append(row)

    users.sort(key=lambda row: (row.get("created_at") or ""), reverse=True)
    return users


def _validate_role(role: str) -> str:
    normalized = str(role or ROLE_CUSTOMER).strip().upper()
    if normalized not in ALL_ROLES:
        raise ValueError("Invalid role")
    return normalized


def register_user(name: str, email: str, phone: str, password: str, role: str) -> Dict:
    name = str(name or "").strip()
    email = normalize_email(email)
    phone = normalize_phone(phone)
    password = str(password or "")
    role = _validate_role(role)

    if not name or not email or not password:
        raise ValueError("name, email and password are required")

    existing = get_user_by_email(email)
    if existing:
        raise ValueError("User already exists")

    user_id = uuid.uuid4().hex
    payload = {
        "user_id": user_id,
        "name": name,
        "email": email,
        "phone": phone,
        "password_hash": generate_password_hash(password),
        "role": role,
        "status": USER_STATUS_ACTIVE,
        "created_at": utc_now_iso(),
    }

    _users_ref().document(user_id).set(payload)
    return payload


def upsert_legacy_user_role(email: str, role: str = ROLE_CUSTOMER, name: str = "", phone: str = "") -> Dict:
    """Backfill role fields for existing users without changing old auth behavior."""
    email = normalize_email(email)
    role = _validate_role(role)
    if not email:
        raise ValueError("email required")

    existing = get_user_by_email(email)
    now = utc_now_iso()
    if existing:
        ref = _users_ref().document(existing["user_id"])
        update = {
            "role": existing.get("role") or role,
            "status": existing.get("status") or USER_STATUS_ACTIVE,
            "user_id": existing.get("user_id"),
        }
        if name and not existing.get("name"):
            update["name"] = name
        if phone and not existing.get("phone"):
            update["phone"] = normalize_phone(phone)
        ref.set(update, merge=True)
        refreshed = get_user_by_id(existing["user_id"])
        return refreshed or existing

    user_id = uuid.uuid4().hex
    payload = {
        "user_id": user_id,
        "name": name,
        "email": email,
        "phone": normalize_phone(phone),
        "password_hash": "",
        "role": role,
        "status": USER_STATUS_ACTIVE,
        "created_at": now,
    }
    _users_ref().document(user_id).set(payload)
    return payload


def _password_hash_for_user(user: Dict) -> str:
    """
    Prefer new password_hash field, but support old 'password' hashed field for backward compatibility.
    """
    hash_value = str(user.get("password_hash") or "").strip()
    if hash_value:
        return hash_value
    legacy = str(user.get("password") or "").strip()
    return legacy


def _authenticate_with_firebase(email: str, password: str) -> bool:
    auth_client = get_auth_client()
    if not auth_client:
        return False

    try:
        user = auth_client.sign_in_with_email_and_password(email, password)
        info = auth_client.get_account_info(user.get("idToken"))
        records = info.get("users") if isinstance(info, dict) else []
        if records and records[0].get("emailVerified") is False:
            return False
        return True
    except Exception:
        return False


def _has_shop_owner_record(user: Dict, email: str) -> bool:
    db = get_db()
    user_id = str(user.get("user_id") or "").strip()
    email = normalize_email(email)
    phone = normalize_phone(user.get("phone") or user.get("mobile") or "")

    checks = []
    if user_id:
        checks.append(db.collection("stores").where("owner_id", "==", user_id).limit(1).stream())
        checks.append(db.collection("stores").where("owner_id", "==", user_id).limit(1).stream())
    if email:
        checks.append(db.collection("stores").where("owner_email", "==", email).limit(1).stream())
        checks.append(db.collection("stores").where("email", "==", email).limit(1).stream())
        checks.append(db.collection("stores").where("owner_email", "==", email).limit(1).stream())
        checks.append(db.collection("stores").where("email", "==", email).limit(1).stream())
        checks.append(db.collection("stores").where("created_by", "==", email).limit(1).stream())
    if phone:
        checks.append(db.collection("stores").where("phone", "==", phone).limit(1).stream())
        checks.append(db.collection("stores").where("phone", "==", phone).limit(1).stream())

    for stream in checks:
        for _ in stream:
            return True
    return False


def _upgrade_role_if_legacy_owner(user: Dict, email: str) -> Dict:
    role = _normalize_role(user.get("role"))
    # Never downgrade explicit elevated roles.
    if role in {ROLE_ADMIN, ROLE_SHOP_OWNER, ROLE_DELIVERY_AGENT}:
        return user

    # Only upgrade legacy customer-like records to SHOP_OWNER.
    if role != ROLE_CUSTOMER:
        return user

    if _has_shop_owner_record(user, email):
        _users_ref().document(user["user_id"]).set(
            {
                "role": ROLE_SHOP_OWNER,
                "updated_at": utc_now_iso(),
            },
            merge=True,
        )
        refreshed = get_user_by_id(user["user_id"])
        return refreshed or {**user, "role": ROLE_SHOP_OWNER}

    return user


def authenticate_user(email: str, password: str, expected_role: str = "") -> Tuple[Optional[Dict], str]:
    email = normalize_email(email)
    password = str(password or "")
    expected_role = str(expected_role or "").strip().upper()

    if not email or not password:
        return None, "Email and password are required"

    user = get_user_by_email(email)
    if not user:
        return None, "Invalid email or password"

    user = _upgrade_role_if_legacy_owner(user, email)

    if expected_role and user.get("role") != expected_role:
        return None, "Role mismatch"

    if str(user.get("status") or USER_STATUS_ACTIVE).upper() != USER_STATUS_ACTIVE:
        return None, "User is blocked"

    hash_value = _password_hash_for_user(user)
    if hash_value and not check_password_hash(hash_value, password):
        return None, "Invalid email or password"

    if not hash_value:
        if not _authenticate_with_firebase(email=email, password=password):
            return None, "Invalid email or password"
        # Migrate legacy account to password_hash-based Firestore auth.
        _users_ref().document(user["user_id"]).set(
            {
                "password_hash": generate_password_hash(password),
                "role": user["role"],
                "status": user.get("status") or USER_STATUS_ACTIVE,
                "email": email,
                "updated_at": utc_now_iso(),
            },
            merge=True,
        )
        refreshed = get_user_by_id(user["user_id"])
        if refreshed:
            user = refreshed

    return user, ""


def update_user_status(user_id: str, status: str) -> Dict:
    status = str(status or "").strip().upper()
    if status not in {"ACTIVE", "BLOCKED"}:
        raise ValueError("status must be ACTIVE or BLOCKED")

    user = get_user_by_id(user_id)
    if not user:
        raise ValueError("user not found")

    _users_ref().document(user["user_id"]).set({"status": status}, merge=True)
    updated = get_user_by_id(user["user_id"])
    return updated or user


def update_password(user_id: str, password: str) -> None:
    password = str(password or "")
    if len(password) < 6:
        raise ValueError("password must be at least 6 characters")

    user = get_user_by_id(user_id)
    if not user:
        raise ValueError("user not found")

    _users_ref().document(user["user_id"]).set(
        {"password_hash": generate_password_hash(password)},
        merge=True,
    )


def set_user_role(user_id: str, role: str, name: str = "", phone: str = "") -> Dict:
    role = _validate_role(role)
    user = get_user_by_id(user_id)
    if not user:
        raise ValueError("user not found")

    update = {
        "role": role,
        "status": USER_STATUS_ACTIVE,
        "updated_at": utc_now_iso(),
    }
    if name:
        update["name"] = str(name).strip()
    if phone:
        update["phone"] = normalize_phone(phone)
        update["mobile"] = normalize_phone(phone)

    _users_ref().document(user["user_id"]).set(update, merge=True)
    refreshed = get_user_by_id(user["user_id"])
    return refreshed or user


def role_counts() -> Dict[str, int]:
    counts = {role: 0 for role in sorted(ALL_ROLES)}
    for doc in _users_ref().stream():
        user = _doc_to_user(doc)
        role = user.get("role")
        if role in counts:
            counts[role] += 1
    return counts
