"""Store owner profile services using unified 'stores' collection."""

from __future__ import annotations

import uuid
from typing import Dict, List, Optional

from services.firestore_ctx import get_db
from utils.http import utc_now_iso


STORES_COLLECTION = "stores"


def _stores_ref():
    return get_db().collection(STORES_COLLECTION)


def _doc_to_store(doc) -> Dict:
    row = doc.to_dict() or {}
    row.setdefault("store_id", doc.id)
    row["store_id"] = str(row.get("store_id") or row.get("shop_id") or doc.id)
    row["shop_id"] = row["store_id"]  # legacy alias for callers not yet migrated
    row["owner_id"] = str(row.get("owner_id") or "")
    row["name"] = str(row.get("name") or row.get("shop_name") or "")
    row["status"] = str(row.get("status") or "PENDING").upper()
    row["phone"] = str(row.get("phone") or "")
    row["address"] = str(row.get("address") or "")
    row["description"] = str(row.get("description") or "")
    row.setdefault("created_at", utc_now_iso())
    return row


def get_store(store_id: str) -> Optional[Dict]:
    store_id = str(store_id or "").strip()
    if not store_id:
        return None
    snap = _stores_ref().document(store_id).get()
    if not snap.exists:
        return None
    return _doc_to_store(snap)


def get_store_by_owner(owner_id: str) -> Optional[Dict]:
    owner_id = str(owner_id or "").strip()
    if not owner_id:
        return None
    docs = _stores_ref().where("owner_id", "==", owner_id).limit(1).stream()
    for doc in docs:
        return _doc_to_store(doc)
    return None


def list_stores(status: str = "", search: str = "", owner_id: str = "") -> List[Dict]:
    status = str(status or "").strip().upper()
    search = str(search or "").strip()
    owner_id = str(owner_id or "").strip()

    rows: List[Dict] = []
    query = _stores_ref()
    if owner_id:
        query = query.where("owner_id", "==", owner_id)
    for doc in query.stream():
        store = _doc_to_store(doc)
        if status and store.get("status") != status:
            continue
        if search:
            needle = search.lower()
            if needle not in store.get("name", "").lower() and needle not in store.get("owner_id", "").lower():
                continue
        rows.append(store)

    rows.sort(key=lambda row: (row.get("created_at") or ""), reverse=True)
    return rows


def search_stores(query: str) -> List[Dict]:
    """Prefix search by name, owner_id, or store_id."""
    q = str(query or "").strip()
    if not q:
        return list_stores()

    results: List[Dict] = []
    ref = _stores_ref()
    # name prefix search
    for doc in ref.where("name", ">=", q).where("name", "<=", q + "\uf8ff").stream():
        results.append(_doc_to_store(doc))
    # exact owner_id / store_id matches
    for doc in ref.where("owner_id", "==", q).stream():
        results.append(_doc_to_store(doc))
    direct = ref.document(q).get()
    if direct.exists:
        results.append(_doc_to_store(direct))

    # de-duplicate by store_id
    dedup = {}
    for item in results:
        dedup[item["store_id"]] = item
    return list(dedup.values())


def register_store(owner_id: str, payload: Dict) -> Dict:
    owner_id = str(owner_id or "").strip()
    if not owner_id:
        raise ValueError("owner_id required")

    name = str(payload.get("name") or payload.get("shop_name") or "").strip()
    if not name:
        raise ValueError("store name required")

    existing = get_store_by_owner(owner_id)
    if existing:
        updates = {
            "name": name,
            "description": str(payload.get("description") or "").strip(),
            "address": str(payload.get("address") or "").strip(),
            "phone": str(payload.get("phone") or "").strip(),
            "updated_at": utc_now_iso(),
        }
        _stores_ref().document(existing["store_id"]).set(updates, merge=True)
        refreshed = get_store(existing["store_id"])
        return refreshed or existing

    store_id = str(payload.get("store_id") or payload.get("shop_id") or "").strip() or uuid.uuid4().hex
    store = {
        "store_id": store_id,
        "owner_id": owner_id,
        "name": name,
        "description": str(payload.get("description") or "").strip(),
        "address": str(payload.get("address") or "").strip(),
        "phone": str(payload.get("phone") or "").strip(),
        "status": "PENDING",
        "created_at": utc_now_iso(),
    }
    _stores_ref().document(store_id).set(store, merge=True)
    return store


def update_store(store_id: str, payload: Dict) -> Dict:
    store = get_store(store_id)
    if not store:
        raise ValueError("store not found")

    updates = {
        "name": str(payload.get("name") or store.get("name") or "").strip(),
        "description": str(payload.get("description") or store.get("description") or "").strip(),
        "address": str(payload.get("address") or store.get("address") or "").strip(),
        "phone": str(payload.get("phone") or store.get("phone") or "").strip(),
        "updated_at": utc_now_iso(),
    }
    _stores_ref().document(store["store_id"]).set(updates, merge=True)
    refreshed = get_store(store["store_id"])
    return refreshed or store


def approve_store(store_id: str, status: str = "APPROVED") -> Dict:
    status = str(status or "APPROVED").strip().upper()
    if status not in {"APPROVED", "REJECTED", "PENDING"}:
        raise ValueError("invalid store status")

    store = get_store(store_id)
    if not store:
        raise ValueError("store not found")

    _stores_ref().document(store["store_id"]).set(
        {"status": status, "approved_at": utc_now_iso()},
        merge=True,
    )
    refreshed = get_store(store["store_id"])
    return refreshed or store


# Legacy aliases for backward compatibility while templates/routes migrate.
get_shop = get_store
get_shop_by_owner = get_store_by_owner
