"""Weekly payout calculations and persistence."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Tuple

from services.firestore_ctx import get_db
from services.order_service import list_orders
from services.store_service import get_store, list_stores
from utils.http import to_float, utc_now_iso


PAYOUTS_COLLECTION = "payouts"


def _payouts_ref():
    return get_db().collection(PAYOUTS_COLLECTION)


def _parse_date(value: str, default: Optional[datetime] = None) -> datetime:
    text = str(value or "").strip()
    if not text:
        if default is not None:
            return default
        return datetime.now(timezone.utc)

    for candidate in [text, text.replace("Z", "+00:00")]:
        try:
            parsed = datetime.fromisoformat(candidate)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed.astimezone(timezone.utc)
        except Exception:
            continue

    if default is not None:
        return default
    return datetime.now(timezone.utc)


def _week_window(week_start: str = "", week_end: str = "") -> Tuple[datetime, datetime]:
    now = datetime.now(timezone.utc)
    if week_start and week_end:
        start = _parse_date(week_start)
        end = _parse_date(week_end)
        if end < start:
            start, end = end, start
        return start, end

    # Default to current calendar week (Mon-Sun).
    start = now - timedelta(days=now.weekday())
    start = start.replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=6, hours=23, minutes=59, seconds=59)
    return start, end


def _within_window(created_at: str, start: datetime, end: datetime) -> bool:
    created = _parse_date(created_at, default=start)
    return start <= created <= end


def weekly_reports(week_start: str = "", week_end: str = "") -> List[Dict]:
    start, end = _week_window(week_start, week_end)

    stores = {store["store_id"]: store for store in list_stores()}
    rows: List[Dict] = []

    per_store: Dict[str, Dict] = {}
    for order in list_orders():
        created_at = str(order.get("created_at") or order.get("time") or "")
        if not _within_window(created_at, start, end):
            continue

        # Pay shop owners only after customer payment is settled.
        payment_status = str(order.get("payment_status") or "").strip().upper()
        if payment_status not in {"PAID", "SUCCESS"}:
            continue

        store_id = str(order.get("store_id") or "").strip()
        if not store_id:
            continue

        bucket = per_store.setdefault(
            store_id,
            {
                "store_id": store_id,
                "shop_id": store_id,  # alias for legacy consumers
                "shop_owner_id": "",
                "week_start": start.isoformat(),
                "week_end": end.isoformat(),
                "total_orders": 0,
                "total_sales": 0.0,
                "admin_commission_total": 0.0,
                "amount_to_pay": 0.0,
            },
        )
        bucket["total_orders"] += 1
        bucket["total_sales"] += to_float(order.get("total_price"), 0.0)
        bucket["admin_commission_total"] += to_float(order.get("admin_commission"), 0.0)
        bucket["amount_to_pay"] += to_float(order.get("shop_owner_amount"), 0.0)

    for store_id, bucket in per_store.items():
        store = stores.get(store_id) or get_store(store_id) or {}
        owner_id = str(store.get("owner_id") or "")
        bucket["shop_owner_id"] = owner_id
        bucket["shop_name"] = str(store.get("name") or store_id)
        bucket["store_name"] = bucket["shop_name"]
        bucket["total_sales"] = round(bucket["total_sales"], 2)
        bucket["admin_commission_total"] = round(bucket["admin_commission_total"], 2)
        bucket["amount_to_pay"] = round(bucket["amount_to_pay"], 2)
        rows.append(bucket)

    rows.sort(key=lambda row: (row.get("amount_to_pay") or 0), reverse=True)
    return rows


def create_weekly_payout(shop_owner_id: str, week_start: str = "", week_end: str = "") -> List[Dict]:
    target_owner = str(shop_owner_id or "").strip()
    reports = weekly_reports(week_start, week_end)
    created: List[Dict] = []

    for report in reports:
        owner_id = str(report.get("shop_owner_id") or "")
        if target_owner and owner_id != target_owner:
            continue

        payout_id = uuid.uuid4().hex
        store_id = str(report.get("store_id") or report.get("shop_id") or "")
        payload = {
            "payout_id": payout_id,
            "shop_owner_id": owner_id,
            "store_id": store_id,
            "shop_id": store_id,  # legacy alias
            "shop_name": str(report.get("shop_name") or report.get("store_name") or ""),
            "store_name": str(report.get("store_name") or report.get("shop_name") or ""),
            "week_start": report.get("week_start"),
            "week_end": report.get("week_end"),
            "total_orders": int(report.get("total_orders") or 0),
            "total_sales": to_float(report.get("total_sales"), 0.0),
            "admin_commission_total": to_float(report.get("admin_commission_total"), 0.0),
            "amount_to_pay": to_float(report.get("amount_to_pay"), 0.0),
            "status": "PENDING",
            "paid_date": "",
            "created_at": utc_now_iso(),
        }
        _payouts_ref().document(payout_id).set(payload)
        created.append(payload)

    return created


def mark_payout_paid(payout_id: str) -> Dict:
    payout_id = str(payout_id or "").strip()
    if not payout_id:
        raise ValueError("payout_id required")

    snap = _payouts_ref().document(payout_id).get()
    if not snap.exists:
        raise ValueError("payout not found")

    _payouts_ref().document(payout_id).set(
        {
            "status": "PAID",
            "paid_date": utc_now_iso(),
            "updated_at": utc_now_iso(),
        },
        merge=True,
    )

    refreshed = _payouts_ref().document(payout_id).get().to_dict() or {}
    refreshed.setdefault("payout_id", payout_id)
    return refreshed


def list_payouts(shop_owner_id: str = "") -> List[Dict]:
    owner_id = str(shop_owner_id or "").strip()

    rows: List[Dict] = []
    for doc in _payouts_ref().stream():
        payout = doc.to_dict() or {}
        payout.setdefault("payout_id", doc.id)
        if owner_id and str(payout.get("shop_owner_id") or "") != owner_id:
            continue
        rows.append(payout)

    rows.sort(key=lambda row: str(row.get("week_start") or ""), reverse=True)
    return rows
