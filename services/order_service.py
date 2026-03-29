"""Order lifecycle, commission, and tracking services."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Dict, List, Optional

from models.constants import (
    ADMIN_COMMISSION_RATE,
    DELIVERY_TYPE_COURIER,
    DELIVERY_TYPE_LOCAL,
    DELIVERY_TYPES,
    ORDER_LIFECYCLE,
    ORDER_STATUS_DELIVERED,
    ORDER_STATUS_PLACED,
)
from services.book_service import adjust_stock, get_book
from services.firestore_ctx import get_db
from services.store_service import get_store
from services.user_role_service import get_user_by_id
from utils.http import to_float, to_int, utc_now_iso


ORDERS_COLLECTION = "orders"


def _orders_ref():
    return get_db().collection(ORDERS_COLLECTION)


def _doc_to_order(doc) -> Dict:
    row = doc.to_dict() or {}
    row.setdefault("order_id", doc.id)
    row["order_id"] = str(row.get("order_id") or doc.id)
    row["user_id"] = str(row.get("user_id") or row.get("user") or "")
    row["store_id"] = str(row.get("store_id") or row.get("shop_id") or "")
    row["shop_id"] = row["store_id"]  # alias for legacy templates
    row["total_price"] = to_float(row.get("total_price", row.get("total")), 0.0)
    row["admin_commission"] = to_float(row.get("admin_commission"), 0.0)
    row["shop_owner_amount"] = to_float(row.get("shop_owner_amount"), 0.0)
    row["delivery_type"] = str(row.get("delivery_type") or DELIVERY_TYPE_LOCAL).upper()
    row["delivery_agent_id"] = str(row.get("delivery_agent_id") or "")
    row["order_status"] = str(row.get("order_status") or ORDER_STATUS_PLACED).upper()
    row["payment_status"] = str(row.get("payment_status") or "PENDING").upper()
    row["payment_method"] = str(row.get("payment_method") or "COD").upper()
    row["amount_to_collect"] = to_float(
        row.get("amount_to_collect"),
        row["total_price"] if row["payment_status"] != "PAID" and row["payment_method"] == "COD" else 0.0,
    )
    row["collected_amount"] = to_float(row.get("collected_amount"), 0.0)
    default_cash_status = "NOT_REQUIRED" if row["amount_to_collect"] <= 0 else "PENDING"
    row["cash_collection_status"] = str(row.get("cash_collection_status") or default_cash_status).upper()
    row["cash_collected_by"] = str(row.get("cash_collected_by") or "")
    row["cash_collected_at"] = str(row.get("cash_collected_at") or "")
    row["cash_submitted_by"] = str(row.get("cash_submitted_by") or "")
    row["cash_submitted_at"] = str(row.get("cash_submitted_at") or "")
    row["admin_cash_received_by"] = str(row.get("admin_cash_received_by") or "")
    row["admin_cash_received_at"] = str(row.get("admin_cash_received_at") or "")
    row["shop_owner_payout_status"] = str(row.get("shop_owner_payout_status") or "PENDING").upper()
    row["payout_paid_at"] = str(row.get("payout_paid_at") or "")
    row.setdefault("created_at", row.get("time") or utc_now_iso())
    return row


def commission_breakdown(total_price: float) -> Dict[str, float]:
    total = max(0.0, float(total_price))
    admin_commission = round(total * ADMIN_COMMISSION_RATE, 2)
    shop_owner_amount = round(total - admin_commission, 2)
    return {
        "admin_commission": admin_commission,
        "shop_owner_amount": shop_owner_amount,
    }


def _parse_items(items: List[Dict], fallback_store_id: str = "") -> Dict:
    normalized = []
    total = 0.0
    store_id = fallback_store_id

    if not isinstance(items, list) or not items:
        raise ValueError("items are required")

    for raw in items:
        if not isinstance(raw, dict):
            continue

        book_id = str(raw.get("book_id") or raw.get("book") or "").strip()
        qty = to_int(raw.get("quantity", raw.get("qty")), 0)
        if not book_id or qty <= 0:
            continue

        book = get_book(book_id)
        if not book:
            raise ValueError(f"book not found: {book_id}")

        book_store_id = str(book.get("store_id") or book.get("shop_id") or "").strip()
        if not store_id:
            store_id = book_store_id
        if store_id and book_store_id and store_id != book_store_id:
            raise ValueError("all order items must belong to one store")

        stock = to_int(book.get("stock"), 0)
        if stock < qty:
            raise ValueError(f"insufficient stock for {book.get('title') or book_id}")

        price = to_float(book.get("price"), 0.0)
        line_total = round(price * qty, 2)
        total += line_total
        normalized.append(
            {
                "book_id": book_id,
                "book": book_id,
                "title": book.get("title", ""),
                "quantity": qty,
                "qty": qty,
                "unit_price": price,
                "line_total": line_total,
            }
        )

    if not normalized:
        raise ValueError("items are required")

    return {
        "items": normalized,
        "total_price": round(total, 2),
        "store_id": store_id,
    }


def create_order(user_id: str, payload: Dict) -> Dict:
    user_id = str(user_id or "").strip()
    if not user_id:
        raise ValueError("user_id required")

    parsed = _parse_items(payload.get("items") or [], str(payload.get("store_id") or payload.get("shop_id") or ""))
    store_id = parsed["store_id"]
    if not store_id:
        raise ValueError("store_id is required")

    store = get_store(store_id)
    if store and store.get("status") not in {"APPROVED", "ACTIVE"}:
        raise ValueError("store is not approved")

    delivery_type = str(payload.get("delivery_type") or DELIVERY_TYPE_LOCAL).strip().upper()
    if delivery_type not in DELIVERY_TYPES:
        delivery_type = DELIVERY_TYPE_LOCAL

    payment_method = str(payload.get("payment_method") or "COD").strip().upper() or "COD"
    payment_status = str(payload.get("payment_status") or "PENDING").strip().upper() or "PENDING"
    amount_to_collect = parsed["total_price"] if payment_status != "PAID" and payment_method == "COD" else 0.0
    cash_collection_status = "PENDING" if amount_to_collect > 0 else "NOT_REQUIRED"

    commission = commission_breakdown(parsed["total_price"])
    order_id = str(payload.get("order_id") or "").strip() or uuid.uuid4().hex

    order = {
        "order_id": order_id,
        "user_id": user_id,
        "store_id": store_id,
        "shop_id": store_id,
        "items": parsed["items"],
        "total_price": parsed["total_price"],
        "admin_commission": commission["admin_commission"],
        "shop_owner_amount": commission["shop_owner_amount"],
        "delivery_type": delivery_type,
        "courier_name": str(payload.get("courier_name") or "").strip(),
        "tracking_id": str(payload.get("tracking_id") or "").strip(),
        "delivery_agent_id": str(payload.get("delivery_agent_id") or "").strip(),
        "order_status": ORDER_STATUS_PLACED,
        "payment_status": payment_status,
        "payment_method": payment_method,
        "amount_to_collect": amount_to_collect,
        "collected_amount": 0.0,
        "cash_collection_status": cash_collection_status,
        "cash_collected_by": "",
        "cash_collected_at": "",
        "cash_submitted_by": "",
        "cash_submitted_at": "",
        "admin_cash_received_by": "",
        "admin_cash_received_at": "",
        "shop_owner_payout_status": "PENDING",
        "payout_paid_at": "",
        "shipping_status": (
            str(payload.get("shipping_status") or "SHIPPED").strip().upper()
            if delivery_type == DELIVERY_TYPE_COURIER
            else ""
        ),
        "created_at": utc_now_iso(),
        # Legacy compatibility fields
        "user": user_id,
        "store_id": store_id,
        "total": parsed["total_price"],
        "time": utc_now_iso(),
    }

    _orders_ref().document(order_id).set(order)

    for item in parsed["items"]:
        adjust_stock(item["book_id"], -to_int(item.get("quantity"), 0))

    return order


def get_order(order_id: str) -> Optional[Dict]:
    order_id = str(order_id or "").strip()
    if not order_id:
        return None
    snap = _orders_ref().document(order_id).get()
    if not snap.exists:
        return None
    return _doc_to_order(snap)


def list_orders(user_id: str = "", shop_id: str = "", store_id: str = "") -> List[Dict]:
    user_id = str(user_id or "").strip()
    store_id = str(store_id or shop_id or "").strip()

    rows: List[Dict] = []
    for doc in _orders_ref().stream():
        order = _doc_to_order(doc)
        if user_id and order.get("user_id") != user_id:
            continue
        if store_id and order.get("store_id") != store_id:
            continue
        rows.append(order)

    rows.sort(key=lambda row: (row.get("created_at") or ""), reverse=True)
    return rows


def update_order_status(order_id: str, status: str) -> Dict:
    status = str(status or "").strip().upper()
    if status not in ORDER_LIFECYCLE:
        raise ValueError("invalid order status")

    order = get_order(order_id)
    if not order:
        raise ValueError("order not found")

    current_status = str(order.get("order_status") or ORDER_STATUS_PLACED).upper()
    try:
        current_idx = ORDER_LIFECYCLE.index(current_status)
    except ValueError:
        current_idx = 0

    next_idx = ORDER_LIFECYCLE.index(status)
    if next_idx < current_idx:
        raise ValueError("order status regression is not allowed")

    payload = {
        "order_status": status,
        "updated_at": utc_now_iso(),
    }
    if str(order.get("delivery_type") or "").upper() == DELIVERY_TYPE_COURIER:
        payload["shipping_status"] = status
    _orders_ref().document(order["order_id"]).set(payload, merge=True)

    updated = get_order(order["order_id"])
    return updated or order


def assign_delivery_agent(order_id: str, delivery_agent_id: str) -> Dict:
    order = get_order(order_id)
    if not order:
        raise ValueError("order not found")

    delivery_agent_id = str(delivery_agent_id or "").strip()
    if not delivery_agent_id:
        raise ValueError("delivery_agent_id is required")

    _orders_ref().document(order["order_id"]).set(
        {
            "delivery_agent_id": delivery_agent_id,
            "updated_at": utc_now_iso(),
        },
        merge=True,
    )

    # Create/refresh delivery order for LOCAL deliveries.
    if str(order.get("delivery_type") or DELIVERY_TYPE_LOCAL).upper() == DELIVERY_TYPE_LOCAL:
        get_db().collection("delivery_orders").document(order["order_id"]).set(
            {
                "delivery_id": order["order_id"],
                "order_id": order["order_id"],
                "delivery_agent_id": delivery_agent_id,
                "status": "ASSIGNED",
                "pickup_time": "",
                "delivered_time": "",
                "updated_at": utc_now_iso(),
            },
            merge=True,
        )

    updated = get_order(order["order_id"])
    return updated or order


def _estimated_delivery_from_status(status: str, created_at: str) -> str:
    status = str(status or "").upper()
    created_dt = datetime.utcnow()
    try:
        created_dt = datetime.fromisoformat(str(created_at).replace("Z", "+00:00"))
    except Exception:
        pass

    if status == ORDER_STATUS_DELIVERED:
        return "Delivered"

    eta_hours = {
        "PLACED": 48,
        "CONFIRMED": 36,
        "PACKED": 24,
        "SHIPPED": 12,
        "OUT_FOR_DELIVERY": 3,
    }.get(status, 48)

    eta = created_dt
    try:
        from datetime import timedelta

        eta = created_dt + timedelta(hours=eta_hours)
    except Exception:
        pass

    return eta.isoformat()


def track_order(order_id: str) -> Dict:
    order = get_order(order_id)
    if not order:
        raise ValueError("order not found")

    agent_name = ""
    if order.get("delivery_agent_id"):
        agent = get_user_by_id(order["delivery_agent_id"])
        if agent:
            agent_name = str(agent.get("name") or "")

    status = str(order.get("order_status") or ORDER_STATUS_PLACED).upper()
    flow = []
    current_idx = ORDER_LIFECYCLE.index(status) if status in ORDER_LIFECYCLE else 0
    for idx, step in enumerate(ORDER_LIFECYCLE):
        flow.append(
            {
                "name": step,
                "completed": idx <= current_idx,
                "active": idx == current_idx,
            }
        )

    tracking = {
        "order_id": order["order_id"],
        "status": status,
        "delivery_agent_name": agent_name,
        "estimated_delivery_time": _estimated_delivery_from_status(status, order.get("created_at", "")),
        "flow": flow,
    }

    if str(order.get("delivery_type") or "").upper() == DELIVERY_TYPE_COURIER:
        tracking["courier_name"] = str(order.get("courier_name") or "")
        tracking["tracking_id"] = str(order.get("tracking_id") or "")
        tracking["shipping_status"] = str(order.get("shipping_status") or status)

    return tracking


def order_totals_snapshot() -> Dict[str, float]:
    total_orders = 0
    total_sales = 0.0
    admin_commission_total = 0.0
    shop_owner_payout_total = 0.0

    for doc in _orders_ref().stream():
        order = _doc_to_order(doc)
        total_orders += 1
        total_sales += to_float(order.get("total_price"), 0.0)
        admin_commission_total += to_float(order.get("admin_commission"), 0.0)
        shop_owner_payout_total += to_float(order.get("shop_owner_amount"), 0.0)

    return {
        "total_orders": total_orders,
        "total_sales": round(total_sales, 2),
        "admin_commission_total": round(admin_commission_total, 2),
        "shop_owner_payout_total": round(shop_owner_payout_total, 2),
    }
