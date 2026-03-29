"""Analytics and reporting helpers for admin dashboards."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Dict, List

from services.order_service import list_orders, order_totals_snapshot
from utils.http import to_float


def dashboard_analytics() -> Dict:
    return order_totals_snapshot()


def sales_report(days: int = 30) -> List[Dict]:
    days = max(1, int(days or 30))
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    buckets = defaultdict(float)
    for order in list_orders():
        text = str(order.get("created_at") or order.get("time") or "")
        try:
            dt = datetime.fromisoformat(text.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            dt = dt.astimezone(timezone.utc)
        except Exception:
            continue

        if dt < cutoff:
            continue
        key = dt.strftime("%Y-%m-%d")
        buckets[key] += to_float(order.get("total_price"), 0.0)

    rows = [{"date": k, "sales": round(v, 2)} for k, v in buckets.items()]
    rows.sort(key=lambda row: row["date"])
    return rows


def commission_report(days: int = 30) -> Dict:
    rows = sales_report(days=days)
    totals = order_totals_snapshot()
    return {
        "summary": totals,
        "daily_sales": rows,
    }
