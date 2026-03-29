"""Delivery assignment, status, and GPS tracking services."""

from __future__ import annotations

import uuid
from typing import Dict, List, Optional

from models.constants import (
    DELIVERY_STATUS_ASSIGNED,
    DELIVERY_STATUS_DELIVERED,
    DELIVERY_STATUS_OUT_FOR_DELIVERY,
    DELIVERY_STATUS_PICKED_UP,
    DELIVERY_STATUSES,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_OUT_FOR_DELIVERY,
    ORDER_STATUS_SHIPPED,
)
from services.firestore_ctx import get_db
from services.order_service import get_order, update_order_status
from utils.http import to_float, utc_now_iso


DELIVERY_ORDERS_COLLECTION = "delivery_orders"
DELIVERY_LOCATIONS_COLLECTION = "delivery_locations"
CASH_HANDOVERS_COLLECTION = "cash_handovers"


LOCAL_TO_ORDER_STATUS = {
    DELIVERY_STATUS_ASSIGNED: ORDER_STATUS_SHIPPED,
    DELIVERY_STATUS_PICKED_UP: ORDER_STATUS_SHIPPED,
    DELIVERY_STATUS_OUT_FOR_DELIVERY: ORDER_STATUS_OUT_FOR_DELIVERY,
    DELIVERY_STATUS_DELIVERED: ORDER_STATUS_DELIVERED,
}


def _delivery_ref():
    return get_db().collection(DELIVERY_ORDERS_COLLECTION)


def _locations_ref():
    return get_db().collection(DELIVERY_LOCATIONS_COLLECTION)


def _cash_ref():
    return get_db().collection(CASH_HANDOVERS_COLLECTION)


def create_or_update_delivery(order_id: str, delivery_agent_id: str, status: str = DELIVERY_STATUS_ASSIGNED) -> Dict:
    order_id = str(order_id or "").strip()
    delivery_agent_id = str(delivery_agent_id or "").strip()
    status = str(status or DELIVERY_STATUS_ASSIGNED).strip().upper()

    if not order_id or not delivery_agent_id:
        raise ValueError("order_id and delivery_agent_id are required")
    if status not in DELIVERY_STATUSES:
        raise ValueError("invalid delivery status")

    payload = {
        "delivery_id": order_id,
        "order_id": order_id,
        "delivery_agent_id": delivery_agent_id,
        "status": status,
        "updated_at": utc_now_iso(),
    }
    if status == DELIVERY_STATUS_PICKED_UP:
        payload["pickup_time"] = utc_now_iso()
    if status == DELIVERY_STATUS_DELIVERED:
        payload["delivered_time"] = utc_now_iso()

    _delivery_ref().document(order_id).set(payload, merge=True)

    order_status = LOCAL_TO_ORDER_STATUS.get(status)
    if order_status:
        try:
            update_order_status(order_id, order_status)
        except Exception:
            # Keep delivery update resilient even if order status transition is stale.
            pass

    return get_delivery(order_id) or payload


def get_delivery(delivery_id: str) -> Optional[Dict]:
    delivery_id = str(delivery_id or "").strip()
    if not delivery_id:
        return None

    snap = _delivery_ref().document(delivery_id).get()
    if not snap.exists:
        return None
    row = snap.to_dict() or {}
    row.setdefault("delivery_id", snap.id)
    row["delivery_id"] = str(row.get("delivery_id") or snap.id)
    row["order_id"] = str(row.get("order_id") or row.get("delivery_id") or "")
    row["delivery_agent_id"] = str(row.get("delivery_agent_id") or "")
    row["status"] = str(row.get("status") or DELIVERY_STATUS_ASSIGNED).upper()
    return row


def list_agent_deliveries(delivery_agent_id: str) -> List[Dict]:
    delivery_agent_id = str(delivery_agent_id or "").strip()
    if not delivery_agent_id:
        return []

    rows = []
    for doc in _delivery_ref().where("delivery_agent_id", "==", delivery_agent_id).stream():
        delivery = doc.to_dict() or {}
        delivery.setdefault("delivery_id", doc.id)
        order = get_order(delivery.get("order_id") or doc.id)
        if order:
            delivery["order"] = order
        rows.append(delivery)

    rows.sort(key=lambda row: (row.get("updated_at") or ""), reverse=True)
    return rows


def update_delivery_status(delivery_id: str, status: str) -> Dict:
    status = str(status or "").strip().upper()
    if status not in DELIVERY_STATUSES:
        raise ValueError("invalid delivery status")

    delivery = get_delivery(delivery_id)
    if not delivery:
        raise ValueError("delivery not found")

    payload = {
        "status": status,
        "updated_at": utc_now_iso(),
    }
    if status == DELIVERY_STATUS_PICKED_UP:
        payload["pickup_time"] = utc_now_iso()
    if status == DELIVERY_STATUS_DELIVERED:
        payload["delivered_time"] = utc_now_iso()

    _delivery_ref().document(delivery["delivery_id"]).set(payload, merge=True)

    order_status = LOCAL_TO_ORDER_STATUS.get(status)
    if order_status:
        try:
            update_order_status(delivery["order_id"], order_status)
        except Exception:
            pass

    updated = get_delivery(delivery["delivery_id"])
    return updated or delivery


def update_location(
    delivery_agent_id: str,
    order_id: str,
    latitude: float,
    longitude: float,
    timestamp: str = "",
) -> Dict:
    delivery_agent_id = str(delivery_agent_id or "").strip()
    order_id = str(order_id or "").strip()
    if not delivery_agent_id or not order_id:
        raise ValueError("delivery_agent_id and order_id are required")

    lat = to_float(latitude, None)
    lng = to_float(longitude, None)
    if lat is None or lng is None:
        raise ValueError("latitude and longitude are required")

    location_id = uuid.uuid4().hex
    payload = {
        "location_id": location_id,
        "delivery_agent_id": delivery_agent_id,
        "order_id": order_id,
        "latitude": lat,
        "longitude": lng,
        "timestamp": str(timestamp or utc_now_iso()),
    }

    _locations_ref().document(location_id).set(payload)

    # Keep latest location on order document for quick tracking reads.
    get_db().collection("orders").document(order_id).set(
        {"latest_location": payload},
        merge=True,
    )

    return payload


def latest_location(order_id: str) -> Optional[Dict]:
    order_id = str(order_id or "").strip()
    if not order_id:
        return None

    order = get_order(order_id)
    if order and isinstance(order.get("latest_location"), dict):
        return dict(order.get("latest_location"))

    matches = []
    for doc in _locations_ref().where("order_id", "==", order_id).stream():
        row = doc.to_dict() or {}
        matches.append(row)

    if not matches:
        return None
    matches.sort(key=lambda row: str(row.get("timestamp") or ""), reverse=True)
    return matches[0]


def get_cash_handover(order_id: str) -> Optional[Dict]:
    order_id = str(order_id or "").strip()
    if not order_id:
        return None
    snap = _cash_ref().document(order_id).get()
    if not snap.exists:
        return None
    row = snap.to_dict() or {}
    row.setdefault("handover_id", snap.id)
    row["handover_id"] = str(row.get("handover_id") or snap.id)
    row["order_id"] = str(row.get("order_id") or order_id)
    row["delivery_agent_id"] = str(row.get("delivery_agent_id") or "")
    row["collection_status"] = str(row.get("collection_status") or "PENDING").upper()
    row["collected_amount"] = to_float(row.get("collected_amount"), 0.0)
    return row


def collect_payment(order_id: str, delivery_agent_id: str, amount: float = 0.0, note: str = "") -> Dict:
    order_id = str(order_id or "").strip()
    delivery_agent_id = str(delivery_agent_id or "").strip()
    if not order_id or not delivery_agent_id:
        raise ValueError("order_id and delivery_agent_id are required")

    order = get_order(order_id)
    if not order:
        raise ValueError("order not found")

    due_amount = to_float(order.get("amount_to_collect"), to_float(order.get("total_price"), 0.0))
    amount_value = to_float(amount, 0.0)
    if amount_value <= 0:
        amount_value = due_amount
    if amount_value <= 0:
        raise ValueError("no amount to collect for this order")

    now = utc_now_iso()
    payload = {
        "handover_id": order_id,
        "order_id": order_id,
        "delivery_agent_id": delivery_agent_id,
        "collected_amount": round(amount_value, 2),
        "collection_status": "COLLECTED",
        "note": str(note or "").strip(),
        "collected_at": now,
        "submitted_to_admin_at": "",
        "received_by_admin_at": "",
        "admin_id": "",
        "updated_at": now,
    }
    _cash_ref().document(order_id).set(payload, merge=True)

    get_db().collection("orders").document(order_id).set(
        {
            "payment_status": "COLLECTED_BY_AGENT",
            "amount_to_collect": due_amount,
            "collected_amount": round(amount_value, 2),
            "cash_collection_status": "COLLECTED",
            "cash_collected_by": delivery_agent_id,
            "cash_collected_at": now,
            "updated_at": now,
        },
        merge=True,
    )
    _delivery_ref().document(order_id).set(
        {
            "collected_amount": round(amount_value, 2),
            "cash_collection_status": "COLLECTED",
            "updated_at": now,
        },
        merge=True,
    )

    return get_cash_handover(order_id) or payload


def submit_cash_to_admin(order_id: str, delivery_agent_id: str) -> Dict:
    order_id = str(order_id or "").strip()
    delivery_agent_id = str(delivery_agent_id or "").strip()
    if not order_id or not delivery_agent_id:
        raise ValueError("order_id and delivery_agent_id are required")

    handover = get_cash_handover(order_id)
    if not handover:
        raise ValueError("payment not collected for this order")
    if str(handover.get("delivery_agent_id") or "") != delivery_agent_id:
        raise ValueError("this order is assigned to another delivery agent")

    now = utc_now_iso()
    _cash_ref().document(order_id).set(
        {
            "collection_status": "SUBMITTED_TO_ADMIN",
            "submitted_to_admin_at": now,
            "updated_at": now,
        },
        merge=True,
    )
    get_db().collection("orders").document(order_id).set(
        {
            "cash_collection_status": "SUBMITTED_TO_ADMIN",
            "cash_submitted_by": delivery_agent_id,
            "cash_submitted_at": now,
            "updated_at": now,
        },
        merge=True,
    )
    _delivery_ref().document(order_id).set(
        {
            "cash_collection_status": "SUBMITTED_TO_ADMIN",
            "updated_at": now,
        },
        merge=True,
    )

    return get_cash_handover(order_id) or handover


def confirm_cash_received(order_id: str, admin_user_id: str) -> Dict:
    order_id = str(order_id or "").strip()
    admin_user_id = str(admin_user_id or "").strip()
    if not order_id:
        raise ValueError("order_id is required")
    if not admin_user_id:
        raise ValueError("admin_user_id is required")

    handover = get_cash_handover(order_id)
    if not handover:
        raise ValueError("handover not found")

    now = utc_now_iso()
    _cash_ref().document(order_id).set(
        {
            "collection_status": "RECEIVED_BY_ADMIN",
            "received_by_admin_at": now,
            "admin_id": admin_user_id,
            "updated_at": now,
        },
        merge=True,
    )
    get_db().collection("orders").document(order_id).set(
        {
            "payment_status": "PAID",
            "cash_collection_status": "RECEIVED_BY_ADMIN",
            "admin_cash_received_by": admin_user_id,
            "admin_cash_received_at": now,
            "shop_owner_payout_status": "READY_FOR_WEEKLY_PAYOUT",
            "updated_at": now,
        },
        merge=True,
    )
    _delivery_ref().document(order_id).set(
        {
            "cash_collection_status": "RECEIVED_BY_ADMIN",
            "updated_at": now,
        },
        merge=True,
    )

    return get_cash_handover(order_id) or handover


def list_cash_handovers(status: str = "") -> List[Dict]:
    target_status = str(status or "").strip().upper()
    rows: List[Dict] = []
    for doc in _cash_ref().stream():
        row = doc.to_dict() or {}
        row.setdefault("handover_id", doc.id)
        row["handover_id"] = str(row.get("handover_id") or doc.id)
        row["order_id"] = str(row.get("order_id") or row["handover_id"])
        row["delivery_agent_id"] = str(row.get("delivery_agent_id") or "")
        row["collection_status"] = str(row.get("collection_status") or "PENDING").upper()
        row["collected_amount"] = to_float(row.get("collected_amount"), 0.0)
        if target_status and row["collection_status"] != target_status:
            continue
        order = get_order(row["order_id"])
        if order:
            row["order"] = order
        rows.append(row)
    rows.sort(key=lambda r: str(r.get("updated_at") or r.get("collected_at") or ""), reverse=True)
    return rows
